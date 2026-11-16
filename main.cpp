// SPDX-License-Identifier: BSD-3-Clause
#include <QtGui/qguiapplication.h>
#include <QtQml/qqmlengine.h>
#include <QtQuick/qquickview.h>

#include "sensorbackend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    SensorBackend sensors;  // the real sensors (read by a Zephyr thread); outlives the view

    QQuickView viewer;
    viewer.setInitialProperties({{"sensors", QVariant::fromValue(&sensors)}});
    viewer.setTitle(QStringLiteral("Sense Explorer"));
    viewer.setSource(QUrl("qrc:/SenseExplorer/App.qml"));
    viewer.setResizeMode(QQuickView::SizeRootObjectToView);
    viewer.setColor("black");
    viewer.show();

    return app.exec();
}
