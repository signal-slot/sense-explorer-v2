// SPDX-License-Identifier: BSD-3-Clause
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Zephyr and Qt versions, CPU load and malloc heap use, updated once per second.
// A value that cannot be read shows "--". The fourth page of the left/right cycle.
Item {
    id: root
    required property var backend

    readonly property real mib: 1024 * 1024
    readonly property bool memOk: backend.memValid && backend.memTotal > 0

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.gap

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            SensorCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                title: "CPU load"; unit: "%"; decimals: 0
                value: root.backend.cpuLoad; valid: root.backend.cpuValid
                note: "Average of all CPU cores"
            }
            SensorCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                title: "Memory (malloc heap)"; unit: "%"; decimals: 1
                value: root.memOk ? 100 * root.backend.memAllocated / root.backend.memTotal : 0
                valid: root.memOk
                note: root.memOk
                    ? (root.backend.memAllocated / root.mib).toFixed(1) + " of "
                      + (root.backend.memTotal / root.mib).toFixed(1) + " MiB, peak "
                      + (root.backend.memPeak / root.mib).toFixed(1) + " MiB"
                    : ""
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: versions.implicitHeight + 20
            radius: 8
            color: Theme.card
            Column {
                id: versions
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 6
                Text {
                    text: "Versions"
                    font.pixelSize: Theme.fontLabel
                    color: Theme.dim
                }
                Text {
                    text: "Zephyr  " + (root.backend.zephyrVersion.length > 0 ? root.backend.zephyrVersion : "--")
                    font.pixelSize: Theme.fontBody
                    color: Theme.text
                }
                Text {
                    text: "Qt  " + (root.backend.qtVersion.length > 0 ? root.backend.qtVersion : "--")
                    font.pixelSize: Theme.fontBody
                    color: Theme.text
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
