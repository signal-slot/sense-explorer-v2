// SPDX-License-Identifier: BSD-3-Clause
#include "sensorbackend.h"

#include <QtCore/qglobal.h>
#include <QtGui/qcolor.h>

SensorBackend::SensorBackend(QObject *parent) : QObject(parent)
{
    m_led.reserve(64);
    for (int i = 0; i < 64; i++)
        m_led.append(QStringLiteral("#000000"));
    m_clock.start();
    sensorsStart();
    pushLed();  // start with all LEDs off, even if the matrix still shows an old picture
    m_timer.setInterval(50);  // same as the IMU period of the Zephyr thread (20 Hz)
    connect(&m_timer, &QTimer::timeout, this, &SensorBackend::poll);
    m_timer.start();
    m_sysTimer.setInterval(1000);
    connect(&m_sysTimer, &QTimer::timeout, this, &SensorBackend::pollSystem);
    m_sysTimer.start();
    pollSystem();  // the first reading; the CPU load needs a second one
}

QString SensorBackend::zephyrVersion() const
{
    // From the last reading: asking Zephyr again would restart the CPU load window.
    return m_sys.zephyrVersion ? QString::fromLatin1(m_sys.zephyrVersion) : QString();
}

QString SensorBackend::qtVersion() const
{
    return QString::fromLatin1(QT_VERSION_STR);
}

void SensorBackend::pollSystem()
{
    SystemStats s;
    systemStatsGet(&s);
    // CPU load: systemStatsGet() reports the load since the previous reading. The first
    // reading covers the time since boot, so it is not shown.
    const bool cpuValid = s.cpuValid && m_sysHadReading;
    const qreal cpuLoad = qBound(0.0, s.cpuLoadPermille / 10.0, 100.0);
    m_sysHadReading = s.cpuValid;
    m_sys = s;
    m_cpuValid = cpuValid;
    m_cpuLoad = cpuLoad;
    emit systemChanged();
}

QString SensorBackend::status() const
{
    if (m_t < 1.5)
        return QStringLiteral("Starting");
    const int n = (envValid() ? 1 : 0) + (imuValid() ? 1 : 0) + (colorValid() ? 1 : 0);
    return n == 3 ? QStringLiteral("Ready")
                  : (n == 0 ? QStringLiteral("Sensor Error") : QStringLiteral("Partial"));
}

void SensorBackend::poll()
{
    const SensorSnapshot prev = m_s;
    const QString prevStatus = status();
    SensorSnapshot s;
    sensorsGet(&s);
    m_s = s;
    m_t = static_cast<double>(m_clock.elapsed()) / 1000.0;
    emit tChanged();

    if (s.envSeq != prev.envSeq || s.envValid != prev.envValid) {
        if (s.envValid && s.envSeq != prev.envSeq)
            m_envUpdated = m_t;
        emit envChanged();
        if (envValid() && s.envSeq != prev.envSeq)
            emit envSample(m_t, s.temperature, s.humidity, s.pressure);
    }
    if (s.imuSeq != prev.imuSeq || s.imuValid != prev.imuValid) {
        if (s.imuValid && s.imuSeq != prev.imuSeq)
            m_imuUpdated = m_t;
        emit imuChanged();
        if (imuValid() && s.imuSeq != prev.imuSeq)
            emit imuSample(m_t, s.ax, s.ay, s.az);
    }
    if (s.colorSeq != prev.colorSeq || s.colorValid != prev.colorValid) {
        if (s.colorValid && s.colorSeq != prev.colorSeq)
            m_colorUpdated = m_t;
        emit colorChanged();
    }
    if (s.errors != prev.errors || status() != prevStatus)
        emit statusChanged();

    const uint32_t joy = sensorsTakeJoystick();
    if (joy) {
        static const struct { uint32_t bit; const char *name; } kKeys[] = {
            {JoyUp, "up"}, {JoyDown, "down"}, {JoyLeft, "left"}, {JoyRight, "right"},
            {JoyPress, "press"},
        };
        for (const auto &k : kKeys) {
            if (joy & k.bit)
                emit joystickPressed(QString::fromLatin1(k.name));
        }
    }
}

void SensorBackend::pushLed()
{
    uint8_t rgb[64 * 3];
    for (int i = 0; i < 64; i++) {
        const QColor c(m_led.at(i).toString());
        rgb[i * 3] = uint8_t(c.red());
        rgb[i * 3 + 1] = uint8_t(c.green());
        rgb[i * 3 + 2] = uint8_t(c.blue());
    }
    ledSet(rgb, m_ledBrightness);
}

void SensorBackend::setLedBrightness(qreal v)
{
    if (qFuzzyCompare(m_ledBrightness, v))
        return;
    m_ledBrightness = v;
    pushLed();
    emit ledChanged();
}

void SensorBackend::setLed(int x, int y, const QString &color)
{
    if (x < 0 || x >= 8 || y < 0 || y >= 8)
        return;
    m_led[y * 8 + x] = color;
    pushLed();
    emit ledChanged();
}

void SensorBackend::fillLed(const QString &color)
{
    for (int i = 0; i < 64; i++)
        m_led[i] = color;
    pushLed();
    emit ledChanged();
}

void SensorBackend::clearLed()
{
    fillLed(QStringLiteral("#000000"));
}

void SensorBackend::setFailEnv(bool v)
{
    if (m_failEnv == v)
        return;
    m_failEnv = v;
    emit failChanged();
    emit envChanged();
    emit statusChanged();
}

void SensorBackend::setFailImu(bool v)
{
    if (m_failImu == v)
        return;
    m_failImu = v;
    emit failChanged();
    emit imuChanged();
    emit statusChanged();
}

void SensorBackend::setFailColor(bool v)
{
    if (m_failColor == v)
        return;
    m_failColor = v;
    emit failChanged();
    emit colorChanged();
    emit statusChanged();
}
