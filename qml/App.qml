// SPDX-License-Identifier: BSD-3-Clause
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// The UI itself. The window is created by Main.qml (tools/shot.sh renders only this file).
Rectangle {
    id: win
    width: 800
    height: 480
    color: Theme.bg

    property int page: 0
    // Source of the sensor values. On the board, main.cpp passes the real backend (the C++
    // SensorBackend); on a desktop the mock is used.
    property var sensors: mock
    readonly property var backend: sensors
    readonly property var pageNames: ["Environment", "Motion", "Light & LED"]

    MockBackend { id: mock; active: win.sensors === mock }

    // Joystick: left and right switch pages (the same as the arrow keys on a desktop)
    Connections {
        target: win.sensors
        function onJoystickPressed(dir) {
            if (dir === "left") win.page = (win.page + 2) % 3
            else if (dir === "right") win.page = (win.page + 1) % 3
        }
    }

    // Keyboard, in place of the joystick on a desktop. Left and right switch pages;
    // E, I and C inject a fault into the environment, IMU and colour sensor.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onLeftPressed: win.page = (win.page + 2) % 3
        Keys.onRightPressed: win.page = (win.page + 1) % 3
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_E) win.sensors.failEnv = !win.sensors.failEnv
            else if (e.key === Qt.Key_I) win.sensors.failImu = !win.sensors.failImu
            else if (e.key === Qt.Key_C) win.sensors.failColor = !win.sensors.failColor
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StatusBar {
            Layout.fillWidth: true
            stateText: win.sensors.status
            uptime: win.sensors.t
            simulated: win.sensors.simulated
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.gap
            spacing: Theme.gap
            Repeater {
                model: win.pageNames
                TabButton {
                    required property int index
                    required property string modelData
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
            EnvironmentPage { backend: win.sensors }
            MotionPage { backend: win.sensors }
            LightLedPage { backend: win.sensors }
        }

        Rectangle {   // footer
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: Theme.panel
            function age(u) { return u < 0 ? "--" : (win.sensors.t - u).toFixed(0) + " s ago" }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Last update  Env " + parent.age(win.sensors.envUpdated)
                    + " / IMU " + parent.age(win.sensors.imuUpdated)
                    + " / Color " + parent.age(win.sensors.colorUpdated)
                font.pixelSize: 12
                color: Theme.dim
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Rate  Env 1 Hz / IMU 20 Hz (graph 10 Hz) / Color 2 Hz    Errors " + win.sensors.errorCount
                font.pixelSize: 12
                color: win.sensors.errorCount > 0 ? Theme.warn : Theme.dim
            }
        }
    }
}
