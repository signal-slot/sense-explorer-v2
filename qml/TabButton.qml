// SPDX-License-Identifier: BSD-3-Clause
import QtQuick

// A simple tab button. It does not depend on Qt Quick Controls.
Rectangle {
    id: root
    property string label
    property bool current: false
    signal clicked

    implicitHeight: Theme.touch
    radius: 6
    color: current ? Theme.accent : Theme.card

    Text {
        anchors.centerIn: parent
        text: root.label
        font.pixelSize: Theme.fontBody
        font.bold: root.current
        color: root.current ? Theme.bg : Theme.text
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
