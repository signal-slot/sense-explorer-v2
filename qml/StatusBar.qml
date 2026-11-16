import QtQuick

// ヘッダ。接続状態、稼働時間、SIMULATED の表示。
Rectangle {
    id: root
    property string stateText: "Starting"
    property real uptime: 0
    property bool simulated: false

    implicitHeight: 40
    color: Theme.panel

    readonly property color stateColor: stateText === "Ready" ? Theme.ok
        : (stateText === "Partial" ? Theme.warn
        : (stateText === "Sensor Error" ? Theme.error : Theme.dim))

    function fmtUptime(s) {
        const m = Math.floor(s / 60), r = Math.floor(s % 60)
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        Text {
            text: "Sense Explorer"
            font.pixelSize: 18
            font.bold: true
            color: Theme.text
        }
        Text {
            text: "Qt 6 + Zephyr"
            font.pixelSize: Theme.fontLabel
            color: Theme.dim
            anchors.baseline: parent.children[0].baseline
        }
    }

    Rectangle {
        visible: root.simulated
        anchors.centerIn: parent
        width: simText.width + 20
        height: 26
        radius: 13
        color: Theme.simulated
        Text {
            id: simText
            anchors.centerIn: parent
            text: "SIMULATED"
            font.pixelSize: Theme.fontLabel
            font.bold: true
            color: Theme.bg
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        Rectangle {
            width: 12; height: 12; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: root.stateColor
        }
        Text {
            text: root.stateText
            font.pixelSize: Theme.fontBody
            color: root.stateColor
        }
        Text {
            text: "Up " + root.fmtUptime(root.uptime)
            font.pixelSize: Theme.fontLabel
            color: Theme.dim
        }
    }
}
