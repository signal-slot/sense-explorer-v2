// SPDX-License-Identifier: BSD-3-Clause
#pragma once
// Sense HAT V2 のセンサーを、Zephyr のスレッドで読む層。Qt には依存しない(Zephyr のヘッダーと
// Qt のマクロが衝突しないよう、Qt 側とは別のファイルに分ける)。
// Zephyr 以外(ホストの開発用)では、値は常に「取得できない」になる。
#include <stdint.h>

struct SensorSnapshot {
    // 各グループの更新ごとに増える通し番号。0 は「まだ一度も取れていない」。
    uint32_t envSeq = 0, imuSeq = 0, colorSeq = 0;
    bool envValid = false, imuValid = false, colorValid = false;
    // 温度 °C、湿度 %、気圧 hPa
    double temperature = 0, humidity = 0, pressure = 0;
    // 加速度 m/s²、角速度 rad/s、磁場 µT、傾斜角 度(加速度のみ)
    double ax = 0, ay = 0, az = 0, gx = 0, gy = 0, gz = 0, mx = 0, my = 0, mz = 0;
    double roll = 0, pitch = 0;
    // 色(参考値。校正なし)
    uint16_t clear = 0, red = 0, green = 0, blue = 0;
    // 読み取りの失敗の数(環境と色は失敗ごと、IMU は取れなくなった回数)
    uint32_t errors = 0;
};

// ジョイスティック(0x46 のレジスタ 0xF2)の押下。押された瞬間を、読み取りの周期の間に取りこぼさない
// よう、スレッド側で記憶しておき、sensorsTakeJoystick() が取り出す(取り出すと消える)。
enum JoystickBit : uint32_t {
    JoyDown = 0x01, JoyRight = 0x02, JoyUp = 0x04, JoyPress = 0x08, JoyLeft = 0x10,
};
uint32_t sensorsTakeJoystick();

// LED マトリクス(8x8、行は上から、列は左から)。rgb は 64 画素 × (R, G, B) の 8 ビット、
// brightness は 0〜1(0 で消灯)。実際の書き込みは、スレッドが次の周期に行う。
void ledSet(const uint8_t rgb[64 * 3], double brightness);

void sensorsStart();                     // 読み取りのスレッドを 1 回だけ起こす
void sensorsGet(SensorSnapshot *out);    // 最新値の写しを返す(スレッド間は mutex で守る)
