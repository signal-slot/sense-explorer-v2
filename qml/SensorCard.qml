// SPDX-License-Identifier: BSD-3-Clause
import QtQuick

// 1 つの値を大きく出すカード。取得できないときは "--" を出し、最後の値を見せない。
Rectangle {
    id: root
    property string title
    property string unit
    property real value: 0
    property bool valid: false
    property int decimals: 1
    property string note: ""

    implicitWidth: 160
    implicitHeight: col.implicitHeight + 20
    radius: 8
    color: Theme.card
    border.width: 1
    border.color: valid ? "transparent" : Theme.warn

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 2
        Text {
            text: root.title
            font.pixelSize: Theme.fontLabel
            color: Theme.dim
        }
        Row {
            spacing: 6
            Text {
                text: root.valid ? root.value.toFixed(root.decimals) : "--"
                font.pixelSize: Theme.fontValue
                font.bold: true
                color: root.valid ? Theme.text : Theme.dim
            }
            Text {
                anchors.baseline: parent.children[0].baseline
                text: root.unit
                font.pixelSize: Theme.fontBody
                color: Theme.dim
            }
        }
        Text {
            visible: root.note.length > 0
            text: root.note
            font.pixelSize: 11
            color: Theme.dim
        }
    }
}
