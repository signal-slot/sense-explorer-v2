// SPDX-License-Identifier: BSD-3-Clause
#include "zephyrsensors.h"

#ifdef __ZEPHYR__

#include <math.h>
#include <string.h>

#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/i2c.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/cpu_load.h>
#include <zephyr/sys/mem_stats.h>
#include <zephyr/version.h>

// The devicetree labels are set in zephyr/sensehat.overlay.
static const struct device *const kI2c = DEVICE_DT_GET(DT_NODELABEL(i2c1));
static const struct device *const kHts = DEVICE_DT_GET(DT_NODELABEL(hts221));
static const struct device *const kLps = DEVICE_DT_GET(DT_NODELABEL(lps25hb));
static const struct device *const kAg = DEVICE_DT_GET(DT_NODELABEL(lsm9ds1_ag));
static const struct device *const kMag = DEVICE_DT_GET(DT_NODELABEL(lsm9ds1_m));

static constexpr double kRadToDeg = 57.29577951308232;  // 180 / pi (M_PI is not defined with strict standard settings)
static constexpr uint16_t kColorAddr = 0x39;
static constexpr uint16_t kMcuAddr = 0x46;  // microcontroller of the LED matrix and the joystick
static constexpr int kTickMs = 50;      // IMU 20 Hz
static constexpr int kEnvEvery = 20;    // environment: 1 Hz
static constexpr int kColorEvery = 10;  // colour: 2 Hz
static constexpr int kColorStaleReads = 4;  // "still integrating" this many times in a row (2 s) = error

K_MUTEX_DEFINE(gLock);
static SensorSnapshot gSnap;

static K_THREAD_STACK_DEFINE(gStack, 16384);
static struct k_thread gThread;
static bool gStarted;

// LED request: written by the Qt thread, read by the sensor thread (guarded by gLock)
static uint8_t gLedRgb[64 * 3];
static double gLedBrightness;
static bool gLedDirty;
static uint32_t gJoyPending;

#ifdef CONFIG_SYS_HEAP_RUNTIME_STATS
// Declared only in a private header of Zephyr's libc (lib/libc/common/include/sys_malloc.h);
// it is defined when CONFIG_SYS_HEAP_RUNTIME_STATS is set (and the libc malloc is used).
extern "C" int malloc_runtime_stats_get(struct sys_memory_stats *stats);
#endif

static double val(const struct sensor_value &v)
{
    return sensor_value_to_double(&v);
}

static bool readEnv(double *t, double *h, double *p)
{
    struct sensor_value v;
    if (sensor_sample_fetch(kHts) != 0 || sensor_sample_fetch(kLps) != 0)
        return false;
    if (sensor_channel_get(kHts, SENSOR_CHAN_AMBIENT_TEMP, &v) != 0)
        return false;
    *t = val(v);
    if (sensor_channel_get(kHts, SENSOR_CHAN_HUMIDITY, &v) != 0)
        return false;
    *h = val(v);
    if (sensor_channel_get(kLps, SENSOR_CHAN_PRESS, &v) != 0)
        return false;
    *p = val(v) * 10.0;  // kPa → hPa
    return true;
}

static bool readImu(double a[3], double g[3], double m[3])
{
    struct sensor_value v[3];
    if (sensor_sample_fetch(kAg) != 0 || sensor_sample_fetch(kMag) != 0)
        return false;
    if (sensor_channel_get(kAg, SENSOR_CHAN_ACCEL_XYZ, v) != 0)
        return false;
    for (int i = 0; i < 3; i++)
        a[i] = val(v[i]);
    if (sensor_channel_get(kAg, SENSOR_CHAN_GYRO_XYZ, v) != 0)
        return false;
    for (int i = 0; i < 3; i++)
        g[i] = val(v[i]);
    if (sensor_channel_get(kMag, SENSOR_CHAN_MAGN_XYZ, v) != 0)
        return false;
    for (int i = 0; i < 3; i++)
        m[i] = val(v[i]) * 100.0;  // gauss → µT
    return true;
}

// The colour sensor (presumed to be a TCS3400 family part) is read through its registers,
// because Zephyr's tcs3400 driver waits for an interrupt pin that may not be wired.
// Integration is 64 cycles (about 176 ms), gain 4x.
static bool colorEnable()
{
    int rc = i2c_reg_write_byte(kI2c, kColorAddr, 0x81, 0xc0);
    rc |= i2c_reg_write_byte(kI2c, kColorAddr, 0x8f, 0x01);
    rc |= i2c_reg_write_byte(kI2c, kColorAddr, 0x80, 0x03);  // PON | AEN
    return rc == 0;
}

enum ColorResult { ColorOk, ColorNotReady, ColorError };

static ColorResult readColor(uint16_t out[4])
{
    uint8_t st = 0, d[8];
    if (i2c_reg_read_byte(kI2c, kColorAddr, 0x93, &st) != 0)
        return ColorError;
    if (!(st & 1))
        return ColorNotReady;  // still integrating: keep the previous value, not an error
    if (i2c_burst_read(kI2c, kColorAddr, 0x94, d, sizeof(d)) != 0)
        return ColorError;
    for (int i = 0; i < 4; i++)
        out[i] = static_cast<uint16_t>(d[2 * i] | (d[2 * i + 1] << 8));
    return ColorOk;
}

// The LED matrix takes 192 bytes written from register 0 in one burst: 8 rows of
// (8 R, 8 G, 8 B) values, 5 bits each (0 to 31). A single burst write worked and the
// read-back matched on the board. The pixel positions and orientation were only checked by eye.
static bool ledWrite(const uint8_t rgb[64 * 3], double brightness)
{
    uint8_t fb[192];
    if (brightness < 0)
        brightness = 0;
    if (brightness > 1)
        brightness = 1;
    for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
            for (int c = 0; c < 3; c++) {
                const double v = rgb[(y * 8 + x) * 3 + c] / 255.0 * 31.0 * brightness;
                fb[y * 24 + c * 8 + x] = static_cast<uint8_t>(v + 0.5);
            }
        }
    }
    return i2c_burst_write(kI2c, kMcuAddr, 0x00, fb, sizeof(fb)) == 0;
}

static void threadMain(void *, void *, void *)
{
    // Each group depends only on its own devices: the colour sensor, the joystick and the LED
    // matrix need only the I2C bus, so a missing sensor driver must not stop them.
    const bool busReady = device_is_ready(kI2c);
    const bool envReady = busReady && device_is_ready(kHts) && device_is_ready(kLps);
    const bool imuReady = busReady && device_is_ready(kAg) && device_is_ready(kMag);
    bool colorOn = busReady && colorEnable();
    int colorNotReady = 0;  // consecutive "still integrating" results
    bool imuWasValid = false;
    bool joyWasOk = true;
    uint8_t joyPrev = 0;
    int64_t ledRetryAt = 0;
    int64_t next = k_uptime_get();

    for (int tick = 0;; tick++) {
        next += kTickMs;
        SensorSnapshot s;  // result of this period; published once, at the end
        k_mutex_lock(&gLock, K_FOREVER);
        s = gSnap;
        k_mutex_unlock(&gLock);

        if (tick == 0) {
            if (!envReady)
                s.errors++;
            if (!imuReady)
                s.errors++;
        }

        if (imuReady) {
            double a[3], g[3], m[3];
            if (readImu(a, g, m)) {
                s.ax = a[0]; s.ay = a[1]; s.az = a[2];
                s.gx = g[0]; s.gy = g[1]; s.gz = g[2];
                s.mx = m[0]; s.my = m[1]; s.mz = m[2];
                s.roll = atan2(a[1], a[2]) * kRadToDeg;
                s.pitch = atan2(-a[0], hypot(a[1], a[2])) * kRadToDeg;
                s.imuValid = true;
                s.imuSeq++;
                imuWasValid = true;
            } else {
                s.imuValid = false;
                if (imuWasValid)
                    s.errors++;
                imuWasValid = false;
            }
        }

        if (envReady) {
            if (tick % kEnvEvery == 0) {
                double t, h, p;
                if (readEnv(&t, &h, &p)) {
                    s.temperature = t; s.humidity = h; s.pressure = p;
                    s.envValid = true;
                    s.envSeq++;
                } else {
                    s.envValid = false;
                    s.errors++;
                }
            }
        }

        if (busReady) {
            if (tick % kColorEvery == 0) {
                if (!colorOn)
                    colorOn = colorEnable();  // retry if it failed at start
                uint16_t c[4];
                const ColorResult r = colorOn ? readColor(c) : ColorError;
                colorNotReady = (r == ColorNotReady) ? colorNotReady + 1 : 0;
                if (r == ColorOk) {
                    s.clear = c[0]; s.red = c[1]; s.green = c[2]; s.blue = c[3];
                    s.colorValid = true;
                    s.colorSeq++;
                } else if (r == ColorError || colorNotReady >= kColorStaleReads) {
                    // An error, or "still integrating" for too long: stop showing the old value
                    s.colorValid = false;
                    s.errors++;
                    colorOn = false;  // set it up again in the next period
                    colorNotReady = 0;
                }
            }
            // Joystick: remember the moment a button goes down (bit 0 -> 1)
            uint8_t j = 0;
            if (i2c_reg_read_byte(kI2c, kMcuAddr, 0xf2, &j) == 0) {
                joyWasOk = true;
                const uint8_t pressed = j & ~joyPrev;
                joyPrev = j;
                if (pressed) {
                    k_mutex_lock(&gLock, K_FOREVER);
                    gJoyPending |= pressed;
                    k_mutex_unlock(&gLock);
                    printk("[joy] pressed 0x%02x (reg 0x%02x)\n", pressed, j);
                }
            } else {
                if (joyWasOk)
                    s.errors++;
                joyWasOk = false;
            }

            // LED: write if requested; after a failure, retry one second later
            uint8_t rgb[64 * 3];
            double br = 0;
            bool dirty = false;
            k_mutex_lock(&gLock, K_FOREVER);
            if (gLedDirty && k_uptime_get() >= ledRetryAt) {
                memcpy(rgb, gLedRgb, sizeof(rgb));
                br = gLedBrightness;
                dirty = true;
                gLedDirty = false;
            }
            k_mutex_unlock(&gLock);
            if (dirty) {
                const bool ok = ledWrite(rgb, br);
                printk("[led] write %s\n", ok ? "ok" : "FAILED");
                if (!ok) {
                    s.errors++;
                    ledRetryAt = k_uptime_get() + 1000;
                    k_mutex_lock(&gLock, K_FOREVER);
                    gLedDirty = true;  // a newer request, if any, has already replaced the data
                    k_mutex_unlock(&gLock);
                }
            }
        }

        k_mutex_lock(&gLock, K_FOREVER);
        // errors includes the failures counted above; the other values are this period's result
        gSnap = s;
        k_mutex_unlock(&gLock);

        const int64_t wait = next - k_uptime_get();
        if (wait > 0)
            k_msleep(static_cast<int32_t>(wait));
        else
            next = k_uptime_get();  // if late, do not catch up; reset the time base
    }
}

void sensorsStart()
{
    if (gStarted)
        return;
    gStarted = true;
    k_thread_create(&gThread, gStack, K_THREAD_STACK_SIZEOF(gStack), threadMain, nullptr, nullptr,
                    nullptr, K_PRIO_PREEMPT(10), 0, K_NO_WAIT);
    k_thread_name_set(&gThread, "sensors");
}

uint32_t sensorsTakeJoystick()
{
    k_mutex_lock(&gLock, K_FOREVER);
    const uint32_t v = gJoyPending;
    gJoyPending = 0;
    k_mutex_unlock(&gLock);
    return v;
}

void ledSet(const uint8_t rgb[64 * 3], double brightness)
{
    k_mutex_lock(&gLock, K_FOREVER);
    memcpy(gLedRgb, rgb, sizeof(gLedRgb));
    gLedBrightness = brightness;
    gLedDirty = true;
    k_mutex_unlock(&gLock);
}

void sensorsGet(SensorSnapshot *out)
{
    k_mutex_lock(&gLock, K_FOREVER);
    *out = gSnap;
    k_mutex_unlock(&gLock);
}

void systemStatsGet(SystemStats *out)
{
    *out = SystemStats();
    out->zephyrVersion = KERNEL_VERSION_STRING;
#ifdef CONFIG_CPU_LOAD
    const unsigned cpus = arch_num_cpus();
    int sum = 0;
    bool ok = cpus > 0;
    for (unsigned i = 0; i < cpus && ok; i++) {
        const int load = cpu_load_get_cpu(i, true);
        if (load < 0)
            ok = false;
        else
            sum += load;
    }
    if (ok) {
        out->cpuLoadPermille = sum / int(cpus);
        out->cpuValid = true;
    }
#endif
#ifdef CONFIG_SYS_HEAP_RUNTIME_STATS
    struct sys_memory_stats ms;
    if (malloc_runtime_stats_get(&ms) == 0) {
        out->heapAllocated = ms.allocated_bytes;
        out->heapFree = ms.free_bytes;
        out->heapPeak = ms.max_allocated_bytes;
        out->heapValid = true;
    }
#endif
}

#else  // host (development): no sensors, so nothing is ever available

void sensorsStart() {}
uint32_t sensorsTakeJoystick() { return 0; }
void ledSet(const uint8_t *, double) {}
void sensorsGet(SensorSnapshot *out) { *out = SensorSnapshot(); }
void systemStatsGet(SystemStats *out) { *out = SystemStats(); }

#endif
