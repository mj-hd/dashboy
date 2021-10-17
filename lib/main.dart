import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dashboy/emulator/gameboy.dart';
import 'package:dashboy/emulator/joypad.dart';
import 'package:dashboy/emulator/rom.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

const _width = 160.0;
const _height = 144.0;
const _primaryColor = Color.fromARGB(255, 67, 57, 180);
const _buttonColor = Color.fromARGB(255, 140, 25, 82);
const _directionColor = Color.fromARGB(255, 22, 24, 29);
const _gbColor = Color.fromARGB(255, 204, 202, 195);
const _seColor = Color.fromARGB(255, 117, 116, 118);
const _paddingColor = Color.fromARGB(255, 99, 97, 110);
const _screenColor = Color.fromARGB(255, 98, 122, 3);

void main() {
  final parentRx = ReceivePort();

  Isolate.spawn(_launchGameboy, parentRx.sendPort);

  ValueNotifier<ui.Image?> image = ValueNotifier(null);
  ValueNotifier<int> fps = ValueNotifier(0);
  SendPort? childTx;

  parentRx.listen((e) {
    if (e is SendPort) {
      childTx = e;
    }

    if (e is RenderFrameEvent) {
      ui.decodeImageFromPixels(e.frame, 256, 256, ui.PixelFormat.rgba8888,
          (result) {
        image.value = result;
      });
    }

    if (e is FpsUpdateEvent) {
      fps.value = e.fps;
    }

    if (e is SaveStateResponseEvent) {
      final file = File(e.fileName);
      file.createSync();
      file.writeAsStringSync(jsonEncode(e.data));
    }
  });

  runApp(MyApp(
    image: image,
    fps: fps,
    onPause: () {
      childTx?.send(PauseEvent());
    },
    onResume: () {
      childTx?.send(ResumeEvent());
    },
    onRomSelected: (bytes) {
      childTx?.send(FileSelectedEvent(bytes));
    },
    onSaveStateRequested: (fileName) {
      childTx?.send(SaveStateRequestEvent(fileName));
    },
    onLoadState: (data) {
      childTx?.send(LoadStateEvent(data));
    },
    onKeyPressed: (key) {
      childTx?.send(KeyPressedEvent(key));
    },
    onKeyReleased: (key) {
      childTx?.send(KeyReleasedEvent(key));
    },
  ));
}

void _launchGameboy(SendPort parentTx) async {
  final childRx = ReceivePort();

  parentTx.send(childRx.sendPort);

  final gb = GameBoy();

  childRx.listen((message) {
    if (message is FileSelectedEvent) {
      final rom = Rom(message.bytes);

      gb.load(rom);
      gb.reset();
    }

    if (message is PauseEvent) {
      gb.pause();
    }

    if (message is ResumeEvent) {
      gb.resume();
    }

    if (message is SaveStateRequestEvent) {
      final data = gb.saveState();

      parentTx.send(SaveStateResponseEvent(
        message.fileName,
        data,
      ));
    }

    if (message is LoadStateEvent) {
      gb.loadState(message.data);
    }

    if (message is KeyPressedEvent) {
      if (gb.ready) gb.press(message.key);
    }

    if (message is KeyReleasedEvent) {
      if (gb.ready) gb.release(message.key);
    }
  });

  var prevDateTime = DateTime.now();
  var frameCount = 0;
  var fpsTotal = 0.0;
  var sleep = const Duration(milliseconds: 16);

  while (true) {
    if (gb.ready) {
      for (var i = 0; i < 70224; i++) {
        gb.tick();
      }

      final pixels = gb.render();

      parentTx.send(RenderFrameEvent(pixels));
    }

    frameCount += 1;

    await Future.delayed(sleep);

    final current = DateTime.now();
    final elapsed = current.difference(prevDateTime);
    final fps = (1000 / elapsed.inMilliseconds).clamp(0, 80);

    sleep = Duration(
      milliseconds: max((sleep.inMilliseconds + (fps - 60.0)).floor(), 0),
    );

    fpsTotal += fps;

    if (frameCount >= 60) {
      parentTx.send(FpsUpdateEvent((fpsTotal / frameCount).floor()));

      frameCount = 0;
      fpsTotal = 0;
    }

    prevDateTime = current;
  }
}

class FpsUpdateEvent {
  FpsUpdateEvent(this.fps);

  final int fps;
}

class RenderFrameEvent {
  RenderFrameEvent(this.frame);

  final Uint8List frame;
}

class FileSelectedEvent {
  FileSelectedEvent(this.bytes);

  final Uint8List bytes;
}

class KeyPressedEvent {
  KeyPressedEvent(this.key);

  final JoypadKey key;
}

class KeyReleasedEvent {
  KeyReleasedEvent(this.key);

  final JoypadKey key;
}

class PauseEvent {
  PauseEvent();
}

class ResumeEvent {
  ResumeEvent();
}

class SaveStateRequestEvent {
  SaveStateRequestEvent(this.fileName);

  final String fileName;
}

class SaveStateResponseEvent {
  SaveStateResponseEvent(this.fileName, this.data);

  final String fileName;
  final Map<String, dynamic> data;
}

class LoadStateEvent {
  LoadStateEvent(this.data);

  final Map<String, dynamic> data;
}

class MyApp extends StatelessWidget {
  const MyApp({
    Key? key,
    required this.image,
    required this.fps,
    required this.onPause,
    required this.onResume,
    required this.onRomSelected,
    required this.onSaveStateRequested,
    required this.onLoadState,
    required this.onKeyPressed,
    required this.onKeyReleased,
  }) : super(key: key);

  final ValueNotifier<int> fps;
  final ValueNotifier<ui.Image?> image;
  final void Function() onPause;
  final void Function() onResume;
  final void Function(Uint8List) onRomSelected;
  final void Function(String fileName) onSaveStateRequested;
  final void Function(Map<String, dynamic>) onLoadState;
  final void Function(JoypadKey) onKeyPressed;
  final void Function(JoypadKey) onKeyReleased;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DASH BOY',
      theme: ThemeData(
        primaryColor: _primaryColor,
        canvasColor: _gbColor,
      ),
      home: MyHomePage(
        title: 'DASH BOY',
        fps: fps,
        image: image,
        onPause: onPause,
        onResume: onResume,
        onRomSelected: onRomSelected,
        onSaveStateRequested: onSaveStateRequested,
        onLoadState: onLoadState,
        onKeyPressed: onKeyPressed,
        onKeyReleased: onKeyReleased,
      ),
    );
  }
}

class MyHomePage extends HookWidget {
  const MyHomePage({
    Key? key,
    required this.title,
    required this.fps,
    required this.image,
    required this.onPause,
    required this.onResume,
    required this.onRomSelected,
    required this.onSaveStateRequested,
    required this.onLoadState,
    required this.onKeyPressed,
    required this.onKeyReleased,
  }) : super(key: key);

  final String title;
  final ValueNotifier<int> fps;
  final ValueNotifier<ui.Image?> image;
  final void Function() onPause;
  final void Function() onResume;
  final void Function(Uint8List) onRomSelected;
  final void Function(String fileName) onSaveStateRequested;
  final void Function(Map<String, dynamic>) onLoadState;
  final void Function(JoypadKey) onKeyPressed;
  final void Function(JoypadKey) onKeyReleased;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: _primaryColor,
        backgroundColor: _gbColor,
        title: Text(title,
            style: const TextStyle(
              fontSize: 32.0,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
            )),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Screen(
              fps: fps,
              image: image,
            ),
          ),
          Expanded(
            child: _Controller(
              onKeyPressed: onKeyPressed,
              onKeyReleased: onKeyReleased,
            ),
          ),
        ],
      ),
      drawer: _Drawer(
        onPause: onPause,
        onResume: onResume,
        onRomSelected: onRomSelected,
        onSaveStateRequested: onSaveStateRequested,
        onLoadState: onLoadState,
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              withData: true,
            );
            if (result == null) return;

            var bytes = result.files.first.bytes;

            if (bytes == null) return;

            onRomSelected(bytes);
          },
          backgroundColor: _seColor,
          child: const Icon(
            Icons.file_upload,
            color: Colors.white,
          )),
    );
  }
}

class _Drawer extends HookWidget {
  const _Drawer({
    Key? key,
    required this.onPause,
    required this.onResume,
    required this.onRomSelected,
    required this.onSaveStateRequested,
    required this.onLoadState,
  }) : super(key: key);

  final void Function() onPause;
  final void Function() onResume;
  final void Function(Uint8List) onRomSelected;
  final void Function(String fileName) onSaveStateRequested;
  final void Function(Map<String, dynamic>) onLoadState;

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      onPause();

      return () => onResume();
    }, [onPause, onResume]);

    return Drawer(
      child: ListView(
        children: [
          ListTile(
            title: const Text('Save State'),
            onTap: () async {
              final fileName = await FilePicker.platform.saveFile();

              if (fileName == null) {
                return;
              }

              onSaveStateRequested(fileName);
            },
          ),
          ListTile(
            title: const Text('Load State'),
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                withData: true,
              );

              if (result == null) return;

              final bytes = result.files.first.bytes;

              if (bytes == null) return;

              onLoadState(jsonDecode(String.fromCharCodes(bytes)));
            },
          )
        ],
      ),
    );
  }
}

class _Screen extends StatefulWidget {
  const _Screen({
    Key? key,
    required this.fps,
    required this.image,
  }) : super(key: key);

  final ValueNotifier<int> fps;
  final ValueNotifier<ui.Image?> image;

  @override
  State<StatefulWidget> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  @override
  void initState() {
    super.initState();

    widget.image.addListener(_rebuild);
  }

  @override
  void dispose() {
    super.dispose();
    widget.image.removeListener(_rebuild);
  }

  void _rebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _paddingColor,
      child: FittedBox(
        child: Card(
          elevation: 10,
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: _ScreenPainter(
              image: widget.image.value,
            ),
            child: SizedBox(
              width: _width,
              height: _height,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.fps.value.toString(),
                    style: const TextStyle(
                      color: _primaryColor,
                      fontSize: 6.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Controller extends StatelessWidget {
  const _Controller({
    Key? key,
    required this.onKeyPressed,
    required this.onKeyReleased,
  }) : super(key: key);

  final void Function(JoypadKey key) onKeyPressed;
  final void Function(JoypadKey key) onKeyReleased;

  static final _keyToJoypadKeyMap = {
    LogicalKeyboardKey.keyZ: JoypadKey.a,
    LogicalKeyboardKey.keyX: JoypadKey.b,
    LogicalKeyboardKey.keyV: JoypadKey.start,
    LogicalKeyboardKey.keyC: JoypadKey.select,
    LogicalKeyboardKey.arrowUp: JoypadKey.up,
    LogicalKeyboardKey.arrowDown: JoypadKey.down,
    LogicalKeyboardKey.arrowRight: JoypadKey.right,
    LogicalKeyboardKey.arrowLeft: JoypadKey.left,
  };

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      onKeyEvent: (key) {
        final joypadKey = _keyToJoypadKeyMap[key.logicalKey];
        if (joypadKey == null) return;

        if (key is KeyDownEvent) {
          onKeyPressed(joypadKey);
        }
        if (key is KeyUpEvent) {
          onKeyReleased(joypadKey);
        }
      },
      focusNode: FocusNode(),
      autofocus: true,
      child: FittedBox(
        child: SizedBox(
          width: 500,
          height: 400,
          child: ClipPath(
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: const _ControllerPainter(),
              child: Stack(
                children: [
                  Positioned(
                    top: 100,
                    right: 40,
                    width: 60,
                    height: 40,
                    child: _ControllerButton(
                      onPressed: () => onKeyPressed(JoypadKey.a),
                      onReleased: () => onKeyReleased(JoypadKey.a),
                      color: _buttonColor,
                      child: const Text(
                        'A',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    right: 110,
                    width: 60,
                    height: 40,
                    child: _ControllerButton(
                      onPressed: () => onKeyPressed(JoypadKey.b),
                      onReleased: () => onKeyReleased(JoypadKey.b),
                      color: _buttonColor,
                      child: const Text(
                        'B',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    left: 30,
                    width: 50,
                    height: 50,
                    child: _ControllerButton(
                      onPressed: () => onKeyPressed(JoypadKey.left),
                      onReleased: () => onKeyReleased(JoypadKey.left),
                      color: _directionColor,
                      child: const Icon(
                        Icons.arrow_left_rounded,
                        color: Colors.white,
                        semanticLabel: 'left',
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    left: 130,
                    width: 50,
                    height: 50,
                    child: _ControllerButton(
                      onPressed: () => onKeyPressed(JoypadKey.right),
                      onReleased: () => onKeyReleased(JoypadKey.right),
                      color: _directionColor,
                      child: const Icon(
                        Icons.arrow_right_rounded,
                        color: Colors.white,
                        semanticLabel: 'right',
                      ),
                    ),
                  ),
                  Positioned(
                    top: 50,
                    left: 80,
                    width: 50,
                    height: 50,
                    child: _ControllerButton(
                      onPressed: () => onKeyPressed(JoypadKey.up),
                      onReleased: () => onKeyReleased(JoypadKey.up),
                      color: _directionColor,
                      child: const Icon(
                        Icons.arrow_drop_up_sharp,
                        color: Colors.white,
                        semanticLabel: 'up',
                      ),
                    ),
                  ),
                  Positioned(
                    top: 150,
                    left: 80,
                    width: 50,
                    height: 50,
                    child: _ControllerButton(
                      onPressed: () => onKeyPressed(JoypadKey.down),
                      onReleased: () => onKeyReleased(JoypadKey.down),
                      color: _directionColor,
                      child: const Icon(
                        Icons.arrow_drop_down_sharp,
                        color: Colors.white,
                        semanticLabel: 'down',
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 220,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Transform.rotate(
                              angle: -1 / 6 * pi,
                              child: SizedBox(
                                width: 100,
                                height: double.infinity,
                                child: _ControllerButton(
                                  onPressed: () =>
                                      onKeyPressed(JoypadKey.select),
                                  onReleased: () =>
                                      onKeyReleased(JoypadKey.select),
                                  color: _seColor,
                                  child: const Text(
                                    'SELECT',
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: -1 / 6 * pi,
                              child: SizedBox(
                                width: 100,
                                height: double.infinity,
                                child: _ControllerButton(
                                  onPressed: () =>
                                      onKeyPressed(JoypadKey.start),
                                  onReleased: () =>
                                      onKeyReleased(JoypadKey.start),
                                  color: _seColor,
                                  child: const Text(
                                    'START',
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControllerButton extends StatelessWidget {
  const _ControllerButton({
    Key? key,
    required this.color,
    required this.onPressed,
    required this.onReleased,
    required this.child,
  }) : super(key: key);

  final Color color;
  final void Function() onPressed;
  final void Function() onReleased;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: color,
        elevation: 5,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        child: InkWell(
          onTapDown: (_) => onPressed(),
          onTap: () => onReleased(),
          onTapCancel: () => onReleased(),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _ScreenPainter extends CustomPainter {
  const _ScreenPainter({
    required this.image,
  });

  final ui.Image? image;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = Paint()..color = _screenColor;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    if (image != null) {
      canvas.drawImageRect(
        image!,
        const Rect.fromLTWH(0, 0, _width, _height),
        Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class _ControllerPainter extends CustomPainter {
  const _ControllerPainter();

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    const color = Color.fromARGB(60, 117, 113, 103);
    final paint = Paint()..color = color;

    const width = 16.0;
    const height = 80.0;

    canvas.translate(
      size.width - 2 * 6 * width - 10.0,
      size.height - height - 10.0,
    );
    canvas.rotate(-1 / 6 * pi);

    for (int i = 0; i < 6; i++) {
      final x = width * i * 2.0;
      const y = 0.0;
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          y,
          x + width,
          y + height,
          const Radius.circular(4.0),
        ),
        paint,
      );
    }

    canvas.drawRect(
      const Rect.fromLTWH(
        -100,
        height - 30,
        2 * 6 * width + 200,
        200,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
