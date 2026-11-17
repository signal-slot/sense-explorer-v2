// SPDX-License-Identifier: BSD-3-Clause
#pragma once
// Reads the Sense HAT V2 in a Zephyr thread. It does not depend on Qt (it is kept apart from
// the Qt side so that Zephyr headers and Qt macros do not clash).
// Outside Zephyr (desktop development) nothing is ever available.
#include <stdint.h>

struct SensorSnapshot {
    // Sequence numbers, increased at every update of a group. 0 means never read.
    uint32_t envSeq = 0, imuSeq = 0, colorSeq = 0;
    bool envValid = false, imuValid = false, colorValid = false;
    // temperature in degrees C, humidity in %, pressure in hPa
    double temperature = 0, humidity = 0, pressure = 0;
    // acceleration in m/s^2, angular velocity in rad/s, magnetic field in uT,
    // roll and pitch in degrees (from the acceleration only)
    double ax = 0, ay = 0, az = 0, gx = 0, gy = 0, gz = 0, mx = 0, my = 0, mz = 0;
    double roll = 0, pitch = 0;
    // colour (uncalibrated reference values)
    uint16_t clear = 0, red = 0, green = 0, blue = 0;
    // failures: each one for environment, colour and LED; for the IMU and the joystick, the
    // number of times it stopped being readable
    uint32_t errors = 0;
};

// Joystick presses (register 0xF2 of the microcontroller at 0x46). The thread remembers each
// press so that none is lost between two readings; sensorsTakeJoystick() returns them and
// clears them.
enum JoystickBit : uint32_t {
    JoyDown = 0x01, JoyRight = 0x02, JoyUp = 0x04, JoyPress = 0x08, JoyLeft = 0x10,
};
uint32_t sensorsTakeJoystick();

// LED matrix (8x8; rows from the top, columns from the left). rgb is 64 pixels of 8-bit
// (R, G, B); brightness is 0 to 1 (0 is off). The thread writes it in its next period.
void ledSet(const uint8_t rgb[64 * 3], double brightness);

// System load and memory (for the System page). The CPU values are cumulative cycle counters
// over all CPUs: a load is the change of busyCycles divided by the change of allCycles between
// two readings. The heap values are the bytes of the malloc heap. A group whose source is not
// available (not Zephyr, or the Zephyr option is off) has its valid flag false.
struct SystemStats {
    bool cpuValid = false;
    uint64_t busyCycles = 0;    // non-idle cycles of all CPUs
    uint64_t allCycles = 0;     // non-idle plus idle cycles of all CPUs
    bool heapValid = false;
    uint64_t heapAllocated = 0, heapFree = 0, heapPeak = 0;
    const char *zephyrVersion = nullptr;   // e.g. "4.5.0"; nullptr when not on Zephyr
};
void systemStatsGet(SystemStats *out);

void sensorsStart();                     // starts the reading thread (once)
void sensorsGet(SensorSnapshot *out);    // copies the latest values (guarded by a mutex)
