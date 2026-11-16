pragma Singleton
import QtQuick

// 色と寸法の一覧。7 インチ(800x480)のタッチ操作を想定する。
QtObject {
    readonly property color bg: "#12161d"
    readonly property color panel: "#1c222c"
    readonly property color card: "#252d3a"
    readonly property color text: "#eef2f7"
    readonly property color dim: "#9aa6b8"
    readonly property color accent: "#4fc3f7"
    readonly property color ok: "#66bb6a"
    readonly property color warn: "#ffb74d"
    readonly property color error: "#ef5350"
    readonly property color simulated: "#ff7043"
    readonly property var seriesColors: ["#4fc3f7", "#ffb74d", "#81c784"]

    readonly property int touch: 48        // タッチ対象の最小の高さ(px)
    readonly property int gap: 8
    readonly property int fontLabel: 14
    readonly property int fontBody: 16
    readonly property int fontValue: 36
}
