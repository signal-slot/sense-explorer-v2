// SPDX-License-Identifier: BSD-3-Clause
import QtQuick

// Mock sensor values, with the same property names as the real backend (the C++ QObject)
// so that either can be used. Units: temperature in degrees C, humidity in %, pressure in
// hPa, acceleration in m/s^2, angular velocity in rad/s, magnetic field in uT, angles in
// degrees.
Item {
    id: root

    readonly property bool simulated: true
    property bool active: true         // when false the timers are stopped (the real backend is in use)
    property real t: 0                 // seconds since start

    // environment (1 Hz)
    property real temperature: 0
    property real humidity: 0
    property real pressure: 0
    property bool envValid: false
    property real envUpdated: -1       // time of the last good reading (s)

    // IMU(20 Hz)
    property real ax: 0
    property real ay: 0
    property real az: 0
    property real gx: 0
    property real gy: 0
    property real gz: 0
    property real mx: 0
    property real my: 0
    property real mz: 0
    property real roll: 0              // static tilt (from the acceleration only; no yaw)
    property real pitch: 0
    property bool imuValid: false
    property real imuUpdated: -1

    // colour (uncalibrated reference values)
    property int clear: 0
    property int red: 0
    property int green: 0
    property int blue: 0
    property bool colorValid: false
    property real colorUpdated: -1

    property int errorCount: 0

    // System page (1 Hz). Fixed texts for the versions: the mock has no C++ side to ask.
    readonly property string zephyrVersion: "mock"
    readonly property string qtVersion: "mock"
    property bool cpuValid: false
    property real cpuLoad: 0           // %, average of all CPUs
    property bool memValid: false
    property real memAllocated: 0      // bytes
    property real memTotal: 0          // bytes (allocated + free)
    property real memPeak: 0           // bytes

    // LED(8x8、"#rrggbb")
    property var ledPixels: Array(64).fill("#000000")
    property real ledBrightness: 0.25  // 0 to 1

    // fault injection for testing (keys E, I and C)
    property bool failEnv: false
    property bool failImu: false
    property bool failColor: false

    readonly property string status: {
        if (t < 1.5)
            return "Starting"
        const n = (envValid ? 1 : 0) + (imuValid ? 1 : 0) + (colorValid ? 1 : 0)
        return n === 3 ? "Ready" : (n === 0 ? "Sensor Error" : "Partial")
    }

    signal envSample(real t, real temp, real hum, real pres)
    signal imuSample(real t, real ax, real ay, real az)
    signal joystickPressed(string dir)   // as in the real backend (never emitted by the mock)

    // Store color as a String. If a QML color value is stored as it is, a later change of
    // the original property (the picked colour) changes every pixel already stored.
    function setLed(x, y, color) {
        const a = ledPixels.slice()
        a[y * 8 + x] = String(color)
        ledPixels = a
    }
    function fillLed(color) {
        ledPixels = Array(64).fill(String(color))
    }
    function clearLed() {
        fillLed("#000000")
    }

    Timer {   // clock
        interval: 50; running: root.active; repeat: true
        onTriggered: root.t += 0.05
    }
    Timer {   // environment, 1 Hz
        interval: 1000; running: root.active; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (root.failEnv) {
                root.envValid = false
                root.errorCount++
                return
            }
            root.temperature = 33 + 2 * Math.sin(root.t / 40) + (Math.random() - 0.5) * 0.2
            root.humidity = 30 - 1.5 * Math.sin(root.t / 40) + (Math.random() - 0.5) * 0.3
            root.pressure = 998.4 + 0.3 * Math.sin(root.t / 90) + (Math.random() - 0.5) * 0.05
            root.envValid = true
            root.envUpdated = root.t
            root.envSample(root.t, root.temperature, root.humidity, root.pressure)
        }
    }
    Timer {   // system, 1 Hz
        interval: 1000; running: root.active; repeat: true; triggeredOnStart: true
        onTriggered: {
            root.cpuLoad = 8 + 6 * Math.sin(root.t / 10) + Math.random() * 2
            root.cpuValid = true
            root.memTotal = 64 * 1024 * 1024
            root.memAllocated = (20 + 2 * Math.sin(root.t / 30)) * 1024 * 1024
            root.memPeak = Math.max(root.memPeak, root.memAllocated)
            root.memValid = true
        }
    }
    Timer {   // IMU 20 Hz
        interval: 50; running: root.active; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (root.failImu) {
                if (root.imuValid)
                    root.errorCount++
                root.imuValid = false
                return
            }
            const rollRad = 0.5 * Math.sin(root.t / 3)
            const pitchRad = 0.3 * Math.sin(root.t / 5 + 1)
            const g = 9.8
            root.ax = -g * Math.sin(pitchRad) + (Math.random() - 0.5) * 0.04
            root.ay = g * Math.sin(rollRad) * Math.cos(pitchRad) + (Math.random() - 0.5) * 0.04
            root.az = g * Math.cos(rollRad) * Math.cos(pitchRad) + (Math.random() - 0.5) * 0.04
            root.gx = 0.5 * Math.cos(root.t / 3) / 3
            root.gy = 0.3 * Math.cos(root.t / 5 + 1) / 5
            root.gz = (Math.random() - 0.5) * 0.04
            root.mx = 21 + Math.sin(root.t / 7)
            root.my = 29 + Math.cos(root.t / 7)
            root.mz = -10
            root.roll = Math.atan2(root.ay, root.az) * 180 / Math.PI
            root.pitch = Math.atan2(-root.ax, Math.hypot(root.ay, root.az)) * 180 / Math.PI
            root.imuValid = true
            root.imuUpdated = root.t
            root.imuSample(root.t, root.ax, root.ay, root.az)
        }
    }
    Timer {   // colour, 2 Hz
        interval: 500; running: root.active; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (root.failColor) {
                if (root.colorValid)
                    root.errorCount++
                root.colorValid = false
                return
            }
            const h = (root.t / 8) % 1
            const c = Qt.hsla(h, 0.8, 0.5, 1)
            root.red = Math.round(c.r * 900)
            root.green = Math.round(c.g * 900)
            root.blue = Math.round(c.b * 900)
            root.clear = root.red + root.green + root.blue
            root.colorValid = true
            root.colorUpdated = root.t
        }
    }
}
