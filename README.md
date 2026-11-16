# sense-explorer

Qt 6 / QML demo that shows Sense HAT V2 sensors on a Raspberry Pi 4 running Zephyr.

Sense Explorer shows the temperature, humidity, pressure, motion and light readings of a Sense HAT V2, and drives its 8x8 LED matrix and joystick, from a Qt Quick UI (800x480, touch) running on Zephyr RTOS. The UI is plain QML on top of a small backend interface, so it also runs on a desktop with simulated values.

> **Status (2026-11-16): a demo, run on one board.** Every result below comes from one Raspberry Pi 4 Model B with an 800x480 touch display and one Sense HAT V2, from runs of about four minutes. Long-run stability, memory use and other boards were not checked. See "What was checked".

## Screens

| Page | Shows |
|---|---|
| Environment | Temperature, humidity and pressure cards, and a 60-second history of the selected one |
| Motion | Roll and pitch (from the accelerometer only), a 10-second acceleration history, angular velocity and magnetic field as numbers |
| Light & LED | Colour sensor readings (uncalibrated), and an 8x8 LED editor: pick a colour, touch a cell, fill all, clear |

A joystick left or right press (the left and right keys on a desktop) switches pages. When a sensor cannot be read, its values show `--` and the error counter in the footer goes up.

## How it works

```text
Sense HAT (I2C) <-> Zephyr thread <-> shared memory (mutex) <-> SensorBackend (QObject) <-> QML
```

- One Zephyr thread owns all I2C traffic: sensors, LED matrix and joystick. Qt objects are never touched from that thread.
- `SensorBackend` copies the latest values with a 50 ms `QTimer` in the Qt thread and exposes them as properties and signals. `MockBackend.qml` has the same property names, so the UI runs without hardware.
- The Zephyr side (`zephyrsensors.h`) is four functions: `sensorsStart`, `sensorsGet`, `sensorsTakeJoystick` and `ledSet`. Another platform only has to implement those.

| Device | How it is read |
|---|---|
| Temperature and humidity (HTS221), pressure (LPS25HB), accelerometer, gyroscope and magnetometer (LSM9DS1) | Zephyr's standard sensor drivers (`zephyr/sensehat.conf`, `zephyr/sensehat.overlay`) |
| Colour (TCS3400 family, presumed) | Registers read directly at I2C address 0x39, because Zephyr's `tcs3400` driver waits for an interrupt pin that may not be wired |
| Joystick | Register 0xF2 of the microcontroller at 0x46, polled at 20 Hz; a press is kept until the UI takes it |
| LED matrix | One 192-byte burst write to register 0 of the microcontroller at 0x46 (5-bit values) |

## Requirements

- A Raspberry Pi 4 Model B (`rpi_4b/bcm2711`) with a Sense HAT V2 and a display.
- A Zephyr workspace (v4.5.0 was used), the Zephyr SDK and `west`.
- The `zephyr-module` of [signal-slot/qt6-for-zephyr](https://github.com/signal-slot/qt6-for-zephyr), and a static Qt 6.12 cross build for Zephyr with Qt Quick, Quick Layouts and Qt Graphs, plus a host Qt of the same version.
- [signal-slot/yakogl](https://github.com/signal-slot/yakogl) for OpenGL ES (see below).

## YakoGL: a change is needed for the graphs

Qt Graphs draws its line series through Qt Quick Shapes' curve renderer, which builds 32-bit index geometry without asking for `GL_OES_element_index_uint` (read in the Qt sources). YakoGL's ES 2.0 surface refuses `GL_UNSIGNED_INT` indices, so on the board the line series are not drawn (the axes and labels are).

The runs described here used a local YakoGL change that accepts `GL_UNSIGNED_INT` and advertises the extension. It is **not** in YakoGL's `main`; the problem is reported in [signal-slot/yakogl#6808](https://github.com/signal-slot/yakogl/issues/6808). Until that is resolved, point `YAKOGL` at a tree with such a change, or expect no lines in the graphs.

Grid lines also depend on the `gl_FragData[0]` read fix ([signal-slot/yakogl#6479](https://github.com/signal-slot/yakogl/pull/6479)). Whether the grid is drawn on the board was not checked.

## Building the dependencies

The image needs three things that are not in this repository. The steps follow the scripts of `qt6-for-zephyr` and the notes of this project; a run from scratch on a clean machine was not done.

1. **Zephyr and its SDK.** A west workspace at Zephyr v4.5.0 (the commit pinned in `zephyr-module/tools/rpi4-pins.sh` of `qt6-for-zephyr`), and Zephyr SDK 1.0.1.
2. **Qt 6.12 for Zephyr.** Use the Qt 6.12 port of `qt6-for-zephyr` (the `zephyr-qt6.12` branch at the time of writing). Build a host Qt of the same version first (`QT_HOST_PATH`), then cross-build Qt with OpenGL ES and Qt Graphs:

   ```sh
   WITH_GL=1 QT_SUBMODULES="qtbase;qtdeclarative;qtsvg;qtgraphs" \
   QT_HOST_PATH=/path/to/host-qt PREFIX=$HOME/qt-zephyr-rpi4-graphs-gl \
   ./build-qt-zephyr-rpi4.sh
   ```

   `PREFIX` is what `build-board.sh` takes as `QT_ZEPHYR_PREFIX`. The GL build needs the qtbase change for a 32-bit screen depth that the `qt6-for-zephyr` branch carries (see the header of the script).
3. **YakoGL.** Clone [signal-slot/yakogl](https://github.com/signal-slot/yakogl) at the commit pinned in `rpi4-pins.sh`, plus the change for `GL_UNSIGNED_INT` described above, and point `YAKOGL` at it. It is a Zephyr module that `build-board.sh` adds with `ZEPHYR_EXTRA_MODULES`; it needs a Rust nightly toolchain.

`qt6-for-zephyr` also has `zephyr-module/tools/west-build-rpi4.sh`, which builds any Qt application directory for the same board with the pins checked. `build-board.sh` is the same build with this application's own Kconfig fragment and overlay added.

## Build

### On a desktop

```sh
cmake -S . -B build -DCMAKE_PREFIX_PATH=/path/to/Qt/6.12.0/gcc_64 -GNinja
ninja -C build
```

The binary starts the UI with no sensors, so every value shows `--`. To see simulated values, run the QML file directly:

```sh
/path/to/Qt/6.12.0/gcc_64/bin/qml qml/Main.qml
```

`tools/shot.sh <page> <out.png>` renders a page offscreen to a PNG. Set `QT_HOST_DIR` if Qt is not under `~/Qt/6.12.0/gcc_64`.

### For the Raspberry Pi 4

`build-board.sh` runs `west build` with the right configuration files. The header of the script lists the environment variables it needs (Zephyr workspace, SDK, `qt6-for-zephyr`, the Qt prefixes and YakoGL):

```sh
./build-board.sh            # output: build-board/zephyr/zephyr.bin
```

Writing the image to an SD card is not part of the script.

### Why the layout is not a typical Zephyr application

This is a Qt application, not a Zephyr application with `prj.conf`, `boards/` and `src/`. `CMakeLists.txt` is an ordinary Qt project (`qt_add_executable`, `qt6_add_qml_module`) and does not call `find_package(Zephyr)`.

The Zephyr application is the `qt-app` of `qt6-for-zephyr`, which owns the Zephyr side of the build. It takes any existing Qt application directory through `-DQT_APP_DIR` without changing it, so the same sources also build on a desktop. That is why the board-specific files here (`zephyr/sensehat.conf` and `zephyr/sensehat.overlay`) are not picked up automatically: `build-board.sh` passes them to `west build` with `-DEXTRA_CONF_FILE` and `-DEXTRA_DTC_OVERLAY_FILE`, next to the GL settings of `qt-app`.

(This follows how `qt-app` is described in its `CMakeLists.txt`. Making the application a standard Zephyr one, with its own `find_package(Zephyr)`, was not tried.)

## What was checked

On one board, 2026-11-16, from runs of about 220 to 240 seconds:

| Item | Result | Basis |
|---|---|---|
| UI | No broken text; graph lines drawn; smooth motion | Observation |
| Sensor values | Values change on screen | Observation (the numbers were not checked for plausibility) |
| LED matrix | Off at start; lit and cleared as intended | Observation, and `[led] write ok` in the serial log |
| Joystick | 4 presses (right, left, right, press), all recorded | Serial log |
| Errors | No `GL error`, no exception | Serial log |

Not checked: long runs, memory growth, grid lines, the Motion page by eye, repeated or long joystick presses, LED brightness limits and current, and the colour sensor against the colours on screen.

## Known limits

- The UI text is English only: the board image carries only the Roboto font.
- The colour values are uncalibrated references. The temperature reads above room temperature (board heat; not investigated).
- LED brightness is fixed at a default of 0.25 and cannot be changed from the screen.
- Joystick up, down and press are read but not used by the UI.

## Layout

| Path | Role |
|---|---|
| `main.cpp` | Creates the backend and shows `qrc:/SenseExplorer/App.qml` |
| `sensorbackend.h/.cpp` | The `QObject` backend used on the board |
| `zephyrsensors.h/.cpp` | The Zephyr thread (I2C); a stub on other platforms |
| `qml/` | The UI, `MockBackend.qml` and `Theme.qml` |
| `zephyr/` | Kconfig fragment and devicetree overlay for the Sense HAT |
| `build-board.sh` | Builds the Zephyr image |
| `tools/shot.sh` | Offscreen screenshot of a page |

## License

BSD-3-Clause, the same as the sample code of `qt6-for-zephyr`. See `LICENSE`. Each source file carries an `SPDX-License-Identifier` line.
