// SPDX-License-Identifier: BSD-3-Clause
import QtQuick
import QtQuick.Layouts

// 画面の本体。ウィンドウは Main.qml が作る(検証では、このファイルだけを描いて保存する)。
Rectangle {
    id: win
    width: 800
    height: 480
    color: Theme.bg

    property int page: 0
    // センサー値の元。実機では main.cpp が本物(C++ の SensorBackend)を渡し、ホストではモックを使う
    property var sensors: mock
    readonly property var backend: sensors
    readonly property var pageNames: ["Environment", "Motion", "Light & LED"]

    MockBackend { id: mock; active: win.sensors === mock }

    // ジョイスティック: 左右でページ移動(ホストのキーボードの左右キーと同じ)
    Connections {
        target: win.sensors
        function onJoystickPressed(dir) {
            if (dir === "left") win.page = (win.page + 2) % 3
            else if (dir === "right") win.page = (win.page + 1) % 3
        }
    }

    // ジョイスティックの代わり(ホストのキーボード)。左右でページ移動、E/I/C で故障を注入
    Item {
        anchors.fill: parent
        focus: true
        Keys.onLeftPressed: win.page = (win.page + 2) % 3
        Keys.onRightPressed: win.page = (win.page + 1) % 3
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_E) sensors.failEnv = !sensors.failEnv
            else if (e.key === Qt.Key_I) sensors.failImu = !sensors.failImu
            else if (e.key === Qt.Key_C) sensors.failColor = !sensors.failColor
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StatusBar {
            Layout.fillWidth: true
            stateText: sensors.status
            uptime: sensors.t
            simulated: sensors.simulated
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.gap
            spacing: Theme.gap
            Repeater {
                model: win.pageNames
                TabButton {
                    Layout.fillWidth: true
                    label: modelData
                    current: win.page === index
                    onClicked: win.page = index
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.gap
            Layout.rightMargin: Theme.gap
            currentIndex: win.page
            EnvironmentPage { backend: sensors }
            MotionPage { backend: sensors }
            LightLedPage { backend: sensors }
        }

        Rectangle {   // フッタ
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: Theme.panel
            function age(u) { return u < 0 ? "--" : (sensors.t - u).toFixed(0) + " s ago" }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Last update  Env " + parent.age(sensors.envUpdated)
                    + " / IMU " + parent.age(sensors.imuUpdated)
                    + " / Color " + parent.age(sensors.colorUpdated)
                font.pixelSize: 12
                color: Theme.dim
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Rate  Env 1 Hz / IMU 20 Hz (graph 10 Hz) / Color 2 Hz    Errors " + sensors.errorCount
                font.pixelSize: 12
                color: sensors.errorCount > 0 ? Theme.warn : Theme.dim
            }
        }
    }
}
