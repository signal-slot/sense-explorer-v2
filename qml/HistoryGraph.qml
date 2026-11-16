// SPDX-License-Identifier: BSD-3-Clause
import QtQuick
import QtGraphs

// A history graph with a fixed time window and up to 3 series. push() adds points and drops
// those older than the window. When a value is missing no point is added to that series, so
// the line joins the neighbouring points (gaps are not drawn).
Item {
    id: root
    property real windowSec: 60
    property real yMin: 0
    property real yMax: 100
    property real yTick: 20
    property string yFormat: "%.0f"
    property var names: []       // series names (legend)

    property real latest: 0
    property real lineWidth: 4  // width checked on the board (2 was not tried after GL_UNSIGNED_INT was accepted)
    readonly property var seriesList: [s0, s1, s2]

    function push(t, values) {
        for (let i = 0; i < seriesList.length; i++) {
            const v = values[i]
            if (v === undefined || v === null || isNaN(v))
                continue
            seriesList[i].append(t, v)
        }
        latest = t
        for (let i = 0; i < seriesList.length; i++) {
            const s = seriesList[i]
            let drop = 0
            while (drop < s.count && s.at(drop).x < t - windowSec)
                drop++
            if (drop > 0)
                s.removeMultiple(0, drop)
        }
    }

    function clear() {
        for (let i = 0; i < seriesList.length; i++)
            seriesList[i].clear()
    }

    Row {
        id: legend
        spacing: 14
        anchors.top: parent.top
        anchors.right: parent.right
        Repeater {
            model: root.names
            Row {
                spacing: 5
                Rectangle {
                    width: 14; height: 4; radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.seriesColors[index]
                }
                Text {
                    text: modelData
                    font.pixelSize: Theme.fontLabel
                    color: Theme.dim
                }
            }
        }
    }

    GraphsView {
        anchors.top: legend.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        theme: GraphsTheme {
            colorScheme: GraphsTheme.ColorScheme.Dark
            backgroundColor: Theme.card
            plotAreaBackgroundColor: Theme.card
            labelTextColor: Theme.dim
        }

        axisX: ValueAxis {
            min: root.latest - root.windowSec
            max: root.latest
            tickInterval: root.windowSec / 6
            subTickCount: 0
            labelFormat: "%.0f"
        }
        axisY: ValueAxis {
            min: root.yMin
            max: root.yMax
            tickInterval: root.yTick
            subTickCount: 0
            labelFormat: root.yFormat
        }

        LineSeries { id: s0; color: Theme.seriesColors[0]; width: root.lineWidth }
        LineSeries { id: s1; color: Theme.seriesColors[1]; width: root.lineWidth }
        LineSeries { id: s2; color: Theme.seriesColors[2]; width: root.lineWidth }
    }
}
