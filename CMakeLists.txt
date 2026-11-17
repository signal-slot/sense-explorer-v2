# SPDX-License-Identifier: BSD-3-Clause
cmake_minimum_required(VERSION 3.16)
project(sense_explorer LANGUAGES CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 COMPONENTS Core)
find_package(Qt6 COMPONENTS Gui)
find_package(Qt6 COMPONENTS Quick)
find_package(Qt6 COMPONENTS Graphs)

qt_add_executable(sense_explorer
    main.cpp
    sensorbackend.cpp sensorbackend.h
    zephyrsensors.cpp zephyrsensors.h
)

target_link_libraries(sense_explorer PUBLIC
    Qt::Core
    Qt::Gui
    Qt::Quick
    Qt::Graphs
)

# All QML files are in qml/. Main.qml (a Window) is only for the desktop; on the board,
# main.cpp shows App.qml in a QQuickView.
set(SE_QML_FILES
    App Theme StatusBar SensorCard HistoryGraph TabButton
    EnvironmentPage MotionPage LightLedPage SystemPage MockBackend)
set(SE_QML_PATHS)
foreach(n IN LISTS SE_QML_FILES)
    list(APPEND SE_QML_PATHS qml/${n}.qml)
    # put each file at the top of the module in the resource (next to qmldir)
    set_source_files_properties(qml/${n}.qml PROPERTIES QT_RESOURCE_ALIAS ${n}.qml)
endforeach()
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt6_add_qml_module(sense_explorer
    URI SenseExplorer
    VERSION 1.0
    QML_FILES ${SE_QML_PATHS}
)
