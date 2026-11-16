// SPDX-License-Identifier: BSD-3-Clause
import QtQuick
import QtQuick.Layouts

// 色センサーの値(参考値)と、8x8 の LED のプレビューと操作。
Item {
    id: root
    required property var backend
    property color picked: "#ff0000"

    readonly property var swatches: [
        {name: "Red", c: "#ff0000"}, {name: "Green", c: "#00ff00"}, {name: "Blue", c: "#0000ff"},
        {name: "Yellow", c: "#ffff00"}, {name: "White", c: "#ffffff"}
    ]
    // センサーの色を画面の色にする。最大のチャンネルを 255 にそろえる(校正なし)
    readonly property color sensed: {
        const m = Math.max(backend.red, backend.green, backend.blue, 1)
        return Qt.rgba(backend.red / m, backend.green / m, backend.blue / m, 1)
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.gap

        ColumnLayout {
            Layout.preferredWidth: 230
            Layout.maximumWidth: 230
            Layout.fillHeight: true
            spacing: Theme.gap

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 8
                color: root.backend.colorValid ? root.sensed : Theme.card
                border.width: 1
                border.color: root.backend.colorValid ? Theme.dim : Theme.warn
                Text {
                    anchors.centerIn: parent
                    visible: !root.backend.colorValid
                    text: "Unavailable"
                    color: Theme.dim
                    font.pixelSize: Theme.fontBody
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.gap
                rowSpacing: Theme.gap
                SensorCard { Layout.fillWidth: true; title: "clear"; unit: ""; decimals: 0; value: root.backend.clear; valid: root.backend.colorValid }
                SensorCard { Layout.fillWidth: true; title: "R"; unit: ""; decimals: 0; value: root.backend.red; valid: root.backend.colorValid }
                SensorCard { Layout.fillWidth: true; title: "G"; unit: ""; decimals: 0; value: root.backend.green; valid: root.backend.colorValid }
                SensorCard { Layout.fillWidth: true; title: "B"; unit: ""; decimals: 0; value: root.backend.blue; valid: root.backend.colorValid }
            }
            Text {
                Layout.preferredWidth: 220
                wrapMode: Text.WordWrap
                text: "Sensor values are uncalibrated references. They do not match the LED colors"
                font.pixelSize: 11
                color: Theme.dim
            }
            Item { Layout.fillHeight: true }
        }

        Grid {   // LED のプレビュー。タップで選んだ色にする
            Layout.alignment: Qt.AlignTop
            columns: 8
            spacing: 3
            Repeater {
                model: 64
                Rectangle {
                    required property int index
                    width: 34; height: 34; radius: 4
                    color: root.backend.ledPixels[index]
                    border.width: 1
                    border.color: Theme.dim
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.backend.setLed(parent.index % 8, Math.floor(parent.index / 8), root.picked)
                    }
                }
            }
        }

        ColumnLayout {   // 色の選択と全面操作
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Theme.gap
            Grid {
                Layout.fillWidth: true
                columns: 2
                spacing: Theme.gap
                Repeater {
                    model: root.swatches
                    Rectangle {
                        required property var modelData
                        width: (parent.width - Theme.gap) / 2
                        height: Theme.touch
                        radius: 6
                        color: modelData.c
                        border.width: root.picked.toString() === modelData.c ? 3 : 1
                        border.color: root.picked.toString() === modelData.c ? Theme.accent : Theme.dim
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.name
                            font.pixelSize: Theme.fontBody
                            color: "#000000"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.picked = parent.modelData.c
                        }
                    }
                }
            }
            TabButton {
                Layout.fillWidth: true
                label: "Fill all"
                onClicked: root.backend.fillLed(root.picked)
            }
            TabButton {
                Layout.fillWidth: true
                label: "Clear"
                onClicked: root.backend.clearLed()
            }
        }
    }
}
