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
    readonly property var pageNames: ["Environment", "Motion", "Light & LED", "System"]
    // The first three pages are the left/right cycle. The System page is not in it: it is
    // opened with joystick up (or its tab) and left with joystick down (or left/right), and
    // it goes back to the page it was opened from.
    readonly property int cyclePages: 3
    readonly property int systemPage: 3
    property int returnPage: 0

    function showPage(i) {
        if (i === systemPage)
            openSystem()
        else
            page = i
    }
    function openSystem() {
        if (page === systemPage)
            return   // already shown: keep the page to go back to
        returnPage = page
        page = systemPage
    }
    function closeSystem() {
        if (page === systemPage)
            page = returnPage
    }
    // Left (step = cyclePages - 1) and right (step = 1). On the System page they go back.
    function cycle(step) {
        if (page === systemPage)
            closeSystem()
        else
            page = (page + step) % cyclePages
    }

    MockBackend { id: mock; active: win.sensors === mock }

    // Joystick (the same as the arrow keys on a desktop): left and right switch pages, up
    // shows the System page, down goes back from it. The press does nothing.
    Connections {
        target: win.sensors
        function onJoystickPressed(dir) {
            if (dir === "left") win.cycle(win.cyclePages - 1)
            else if (dir === "right") win.cycle(1)
            else if (dir === "up") win.openSystem()
            else if (dir === "down") win.closeSystem()
        }
    }

    // Keyboard, in place of the joystick on a desktop. Left and right switch pages, Up and
    // Down open and close the System page; E, I and C inject a fault into the environment,
    // IMU and colour sensor.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onLeftPressed: win.cycle(win.cyclePages - 1)
        Keys.onRightPressed: win.cycle(1)
        Keys.onUpPressed: win.openSystem()
        Keys.onDownPressed: win.closeSystem()
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
                    onClicked: win.showPage(index)
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
            SystemPage { backend: win.sensors }
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
