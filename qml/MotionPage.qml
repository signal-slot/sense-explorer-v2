// SPDX-License-Identifier: BSD-3-Clause
import QtQuick
import QtQuick.Layouts

// 静的な傾斜角(Roll、Pitch)、加速度の 10 秒の履歴、角速度と磁場の数値。
// Yaw は、磁気補正をしていないので出さない。
Item {
    id: root
    required property var backend
    property int skip: 0

    function fmt(v, d) { return backend.imuValid ? v.toFixed(d) : "--" }

    Connections {
        target: root.backend
        function onImuSample(t, ax, ay, az) {
            // 取得 20 Hz に対し、グラフは 10 Hz で足す
            root.skip = (root.skip + 1) % 2
            if (root.skip === 0)
                g.push(t, [ax, ay, az])
        }
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
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 200
                Layout.preferredHeight: 200
                color: Theme.card
                radius: 8
                clip: true
                border.width: 1
                border.color: root.backend.imuValid ? Theme.dim : Theme.warn

                Item {   // 水平線。Roll で回し、Pitch で上下に動かす
                    anchors.centerIn: parent
                    width: 400; height: 400
                    rotation: -root.backend.roll
                    visible: root.backend.imuValid
                    Rectangle {
                        width: parent.width; height: parent.height / 2
                        y: parent.height / 2 + root.backend.pitch * 2
                        color: "#6d4c41"
                    }
                    Rectangle {
                        width: parent.width; height: parent.height / 2
                        y: -parent.height / 2 + root.backend.pitch * 2
                        color: "#1e88e5"
                    }
                }
                Rectangle {   // 中心の目印
                    visible: root.backend.imuValid
                    anchors.centerIn: parent
                    width: 60; height: 3
                    color: Theme.text
                }
                Text {
                    anchors.centerIn: parent
                    visible: !root.backend.imuValid
                    text: "Unavailable"
                    color: Theme.dim
                    font.pixelSize: Theme.fontBody
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.backend.imuValid
                    ? "Roll " + root.backend.roll.toFixed(1) + "°   Pitch " + root.backend.pitch.toFixed(1) + "°"
                    : "Roll --   Pitch --"
                font.pixelSize: Theme.fontBody
                color: Theme.text
            }
            Text {
                Layout.preferredWidth: 220
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Static tilt (accelerometer only). No yaw: no magnetic correction"
                font.pixelSize: 11
                color: Theme.dim
            }
            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.gap

            HistoryGraph {
                id: g
                Layout.fillWidth: true
                Layout.fillHeight: true
                windowSec: 10
                yMin: -12; yMax: 12; yTick: 6
                names: ["X m/s²", "Y m/s²", "Z m/s²"]
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 8
                color: Theme.card
                GridLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    columns: 4
                    rowSpacing: 2
                    Text { text: "Gyro rad/s"; color: Theme.dim; font.pixelSize: Theme.fontLabel }
                    Text { text: "X " + root.fmt(root.backend.gx, 2); color: Theme.text; font.pixelSize: Theme.fontBody }
                    Text { text: "Y " + root.fmt(root.backend.gy, 2); color: Theme.text; font.pixelSize: Theme.fontBody }
                    Text { text: "Z " + root.fmt(root.backend.gz, 2); color: Theme.text; font.pixelSize: Theme.fontBody }
                    Text { text: "Mag µT"; color: Theme.dim; font.pixelSize: Theme.fontLabel }
                    Text { text: "X " + root.fmt(root.backend.mx, 1); color: Theme.text; font.pixelSize: Theme.fontBody }
                    Text { text: "Y " + root.fmt(root.backend.my, 1); color: Theme.text; font.pixelSize: Theme.fontBody }
                    Text { text: "Z " + root.fmt(root.backend.mz, 1); color: Theme.text; font.pixelSize: Theme.fontBody }
                }
            }
        }
    }
}
