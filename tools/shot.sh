#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Usage: tools/shot.sh <page number> <output PNG> [wait ms] [fault keys, e.g. EIC]
# Renders App.qml offscreen (with the simulated values), waits, and saves a PNG.
Q=${QT_HOST_DIR:-$HOME/Qt/6.12.0/gcc_64}   # host Qt; override with QT_HOST_DIR
export LD_LIBRARY_PATH=$Q/lib QT_QPA_PLATFORM=offscreen
D="$(cd "$(dirname "$0")/../qml" && pwd)"
PAGE=${1:-0}; OUT=${2:-/tmp/shot.png}; WAIT=${3:-4000}; FAIL=${4:-}
T=$(mktemp -d)
cat > "$T/Shot.qml" <<QML
import QtQuick
import "file:$D"
Item {
    id: host
    width: 800; height: 480
    App { id: app; anchors.fill: parent; page: $PAGE
        Component.onCompleted: {
            if ("$FAIL".indexOf("E") >= 0) backend.failEnv = true
            if ("$FAIL".indexOf("I") >= 0) backend.failImu = true
            if ("$FAIL".indexOf("C") >= 0) backend.failColor = true
        }
    }
    Timer { interval: $WAIT; running: true
        onTriggered: host.grabToImage(function(r) { console.log("save", r.saveToFile("$OUT")); Qt.quit() }) }
}
QML
timeout 60 $Q/bin/qml "$T/Shot.qml" 2>&1 | head -30
rm -rf "$T"
