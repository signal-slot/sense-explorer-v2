import QtQuick
import QtQuick.Layouts

// 温度・湿度・気圧のカードと、選んだ 1 つの量の 60 秒の履歴。
// 単位の違う量を同じ Y 軸に混ぜないため、グラフは 1 つずつ切り替える。
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
