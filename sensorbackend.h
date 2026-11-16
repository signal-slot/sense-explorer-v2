// SPDX-License-Identifier: BSD-3-Clause
#pragma once
#include <QtCore/qelapsedtimer.h>
#include <QtCore/qobject.h>
#include <QtCore/qtimer.h>
#include <QtCore/qvariant.h>

#include "zephyrsensors.h"

// QML に見せるセンサー値。プロパティ名は MockBackend.qml と同じ(画面側を変えずに差し替える)。
// 値の読み取りは Zephyr のスレッド(zephyrsensors.cpp)で行い、ここでは Qt のスレッドのタイマーで
// 最新値の写しを取るだけにする(Qt のオブジェクトを別のスレッドから触らない)。
// LED とジョイスティックも、Zephyr のスレッド経由で実機とやり取りする(P3)。
class SensorBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool simulated READ simulated CONSTANT)
    Q_PROPERTY(qreal t READ t NOTIFY tChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(int errorCount READ errorCount NOTIFY statusChanged)

    Q_PROPERTY(qreal temperature READ temperature NOTIFY envChanged)
    Q_PROPERTY(qreal humidity READ humidity NOTIFY envChanged)
    Q_PROPERTY(qreal pressure READ pressure NOTIFY envChanged)
    Q_PROPERTY(bool envValid READ envValid NOTIFY envChanged)
    Q_PROPERTY(qreal envUpdated READ envUpdated NOTIFY envChanged)

    Q_PROPERTY(qreal ax READ ax NOTIFY imuChanged)
    Q_PROPERTY(qreal ay READ ay NOTIFY imuChanged)
    Q_PROPERTY(qreal az READ az NOTIFY imuChanged)
    Q_PROPERTY(qreal gx READ gx NOTIFY imuChanged)
    Q_PROPERTY(qreal gy READ gy NOTIFY imuChanged)
    Q_PROPERTY(qreal gz READ gz NOTIFY imuChanged)
    Q_PROPERTY(qreal mx READ mx NOTIFY imuChanged)
    Q_PROPERTY(qreal my READ my NOTIFY imuChanged)
    Q_PROPERTY(qreal mz READ mz NOTIFY imuChanged)
    Q_PROPERTY(qreal roll READ roll NOTIFY imuChanged)
    Q_PROPERTY(qreal pitch READ pitch NOTIFY imuChanged)
    Q_PROPERTY(bool imuValid READ imuValid NOTIFY imuChanged)
    Q_PROPERTY(qreal imuUpdated READ imuUpdated NOTIFY imuChanged)

    Q_PROPERTY(int clear READ clear NOTIFY colorChanged)
    Q_PROPERTY(int red READ red NOTIFY colorChanged)
    Q_PROPERTY(int green READ green NOTIFY colorChanged)
    Q_PROPERTY(int blue READ blue NOTIFY colorChanged)
    Q_PROPERTY(bool colorValid READ colorValid NOTIFY colorChanged)
    Q_PROPERTY(qreal colorUpdated READ colorUpdated NOTIFY colorChanged)

    Q_PROPERTY(QVariantList ledPixels READ ledPixels NOTIFY ledChanged)
    Q_PROPERTY(qreal ledBrightness READ ledBrightness WRITE setLedBrightness NOTIFY ledChanged)

    // 動作確認用の故障の注入(キー E、I、C)。読み取りは続け、画面には「取れない」として見せる。
    Q_PROPERTY(bool failEnv READ failEnv WRITE setFailEnv NOTIFY failChanged)
    Q_PROPERTY(bool failImu READ failImu WRITE setFailImu NOTIFY failChanged)
    Q_PROPERTY(bool failColor READ failColor WRITE setFailColor NOTIFY failChanged)

public:
    explicit SensorBackend(QObject *parent = nullptr);

    bool simulated() const { return false; }
    qreal t() const { return m_t; }
    QString status() const;
    int errorCount() const { return int(m_s.errors); }

    qreal temperature() const { return m_s.temperature; }
    qreal humidity() const { return m_s.humidity; }
    qreal pressure() const { return m_s.pressure; }
    bool envValid() const { return m_s.envValid && !m_failEnv; }
    qreal envUpdated() const { return m_envUpdated; }

    qreal ax() const { return m_s.ax; }
    qreal ay() const { return m_s.ay; }
    qreal az() const { return m_s.az; }
    qreal gx() const { return m_s.gx; }
    qreal gy() const { return m_s.gy; }
    qreal gz() const { return m_s.gz; }
    qreal mx() const { return m_s.mx; }
    qreal my() const { return m_s.my; }
    qreal mz() const { return m_s.mz; }
    qreal roll() const { return m_s.roll; }
    qreal pitch() const { return m_s.pitch; }
    bool imuValid() const { return m_s.imuValid && !m_failImu; }
    qreal imuUpdated() const { return m_imuUpdated; }

    int clear() const { return m_s.clear; }
    int red() const { return m_s.red; }
    int green() const { return m_s.green; }
    int blue() const { return m_s.blue; }
    bool colorValid() const { return m_s.colorValid && !m_failColor; }
    qreal colorUpdated() const { return m_colorUpdated; }

    QVariantList ledPixels() const { return m_led; }
    qreal ledBrightness() const { return m_ledBrightness; }
    void setLedBrightness(qreal v);

    bool failEnv() const { return m_failEnv; }
    bool failImu() const { return m_failImu; }
    bool failColor() const { return m_failColor; }
    void setFailEnv(bool v);
    void setFailImu(bool v);
    void setFailColor(bool v);

    // color は文字列("#rrggbb")で受ける。
    Q_INVOKABLE void setLed(int x, int y, const QString &color);
    Q_INVOKABLE void fillLed(const QString &color);
    Q_INVOKABLE void clearLed();

signals:
    void tChanged();
    void statusChanged();
    void envChanged();
    void imuChanged();
    void colorChanged();
    void ledChanged();
    void failChanged();
    void envSample(qreal t, qreal temp, qreal hum, qreal pres);
    void imuSample(qreal t, qreal ax, qreal ay, qreal az);
    // ジョイスティックが押された("up"、"down"、"left"、"right"、"press")
    void joystickPressed(const QString &dir);

private:
    void poll();
    void pushLed();   // 画面の LED の状態を、Zephyr のスレッド経由で実機に書く

    QTimer m_timer;
    QElapsedTimer m_clock;
    SensorSnapshot m_s;
    qreal m_t = 0;
    qreal m_envUpdated = -1, m_imuUpdated = -1, m_colorUpdated = -1;
    QVariantList m_led;
    qreal m_ledBrightness = 0.25;
    bool m_failEnv = false, m_failImu = false, m_failColor = false;
};
