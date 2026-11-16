import QtQuick

// モックのセンサー値。本物の層(C++ の QObject)と同じプロパティ名にして、差し替え可能にする。
// 単位: 温度 °C、湿度 %、気圧 hPa、加速度 m/s²、角速度 rad/s、磁場 µT、角度 度。
Item {
    id: root

    readonly property bool simulated: true
    property bool active: true         // false のときは、タイマーを止める(本物の層を使うとき)
    property real t: 0                 // 起動からの秒数

    // 環境(1 Hz)
    property real temperature: 0
    property real humidity: 0
    property real pressure: 0
    property bool envValid: false
    property real envUpdated: -1       // 最後に正常に取れた時刻(秒)

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
    property real roll: 0              // 静的な傾斜角(加速度のみ。Yaw は出さない)
    property real pitch: 0
    property bool imuValid: false
    property real imuUpdated: -1

    // 色(参考値。校正なし)
    property int clear: 0
    property int red: 0
    property int green: 0
    property int blue: 0
    property bool colorValid: false
    property real colorUpdated: -1

    property int errorCount: 0

    // LED(8x8、"#rrggbb")
    property var ledPixels: Array(64).fill("#000000")
    property real ledBrightness: 0.25  // 0〜1。上限は表示側で 0.5 に抑える

    // 動作確認用の故障の注入(キー E、I、C)
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
    signal joystickPressed(string dir)   // 本物の層と同じ(モックでは出さない)

    // color は String にして保存する。QML の color 型の値をそのまま入れると、
    // 元のプロパティ(選択中の色)の変更が、保存済みの全画素に及ぶ。
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

    Timer {   // 時刻
        interval: 50; running: root.active; repeat: true
        onTriggered: root.t += 0.05
    }
    Timer {   // 環境 1 Hz
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
    Timer {   // 色 2 Hz
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
