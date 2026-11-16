// SPDX-License-Identifier: BSD-3-Clause
import QtQuick
import QtQuick.Layouts

// Cards for temperature, humidity and pressure, and a 60-second history of the selected one.
// The graph is switched one quantity at a time so that quantities with different units
// do not share a Y axis.
Item {
    id: root
    required property var backend
    property int selected: 0

    Connections {
        target: root.backend
        function onEnvSample(t, temp, hum, pres) {
            gTemp.push(t, [temp])
            gHum.push(t, [hum])
            gPres.push(t, [pres])
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.gap

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            SensorCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                title: "Temperature"; unit: "°C"
                value: root.backend.temperature; valid: root.backend.envValid
                note: "Reads above room temp (board heat)"
            }
            SensorCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                title: "Humidity"; unit: "%"
                value: root.backend.humidity; valid: root.backend.envValid
            }
            SensorCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                title: "Pressure"; unit: "hPa"; decimals: 1
                value: root.backend.pressure; valid: root.backend.envValid
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            Repeater {
                model: ["Temp", "Humidity", "Pressure"]
                TabButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    label: modelData
                    current: root.selected === index
                    onClicked: root.selected = index
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            HistoryGraph {
                id: gTemp
                anchors.fill: parent; visible: root.selected === 0
                yMin: 25; yMax: 45; yTick: 5; names: ["Temp °C"]
            }
            HistoryGraph {
                id: gHum
                anchors.fill: parent; visible: root.selected === 1
                yMin: 0; yMax: 100; yTick: 20; names: ["Humidity %"]
            }
            HistoryGraph {
                id: gPres
                anchors.fill: parent; visible: root.selected === 2
                yMin: 990; yMax: 1010; yTick: 5; names: ["Pressure hPa"]
            }
        }
    }
}
