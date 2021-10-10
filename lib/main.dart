import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dashboy/emulator/gameboy.dart';
import 'package:dashboy/emulator/joypad.dart';
import 'package:dashboy/emulator/rom.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

const _width = 160.0;
const _height = 144.0;

void main() {
  final parentRx = ReceivePort();

  Isolate.spawn(_launchGameboy, parentRx.sendPort);

  ValueNotifier<ui.Image?> image = ValueNotifier(null);
  SendPort? childTx;

  parentRx.listen((e) {
    if (e is SendPort) {
      childTx = e;
    }
    if (e is Uint8List) {
      ui.decodeImageFromPixels(e, 256, 256, ui.PixelFormat.rgba8888, (result) {
        image.value = result;
      });
    }
  });

  runApp(MyApp(
    image: image,
    onRomSelected: (bytes) {
      childTx?.send(FileSelectedEvent(bytes));
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

      print('loaded');

      gb.reset();

      print('ready');
    }

    if (message is KeyPressedEvent) {
      if (gb.ready) gb.press(message.key);
      print('key pressed ${message.key}');
    }

    if (message is KeyReleasedEvent) {
      if (gb.ready) gb.release(message.key);
      print('key released ${message.key}');
    }
  });

  while (true) {
    if (gb.ready) {
      for (var i = 0; i < 70224; i++) {
        gb.tick();
      }

      final pixels = gb.render();

      parentTx.send(pixels);
    }

    await Future.delayed(const Duration(milliseconds: 16));
  }
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

class MyApp extends StatelessWidget {
  const MyApp({
    Key? key,
    required this.image,
    required this.onRomSelected,
    required this.onKeyPressed,
    required this.onKeyReleased,
  }) : super(key: key);

  final ValueNotifier<ui.Image?> image;
  final void Function(Uint8List) onRomSelected;
  final void Function(JoypadKey) onKeyPressed;
  final void Function(JoypadKey) onKeyReleased;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboy',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(
        title: 'Dashboy',
        image: image,
        onRomSelected: onRomSelected,
        onKeyPressed: onKeyPressed,
        onKeyReleased: onKeyReleased,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    Key? key,
    required this.title,
    required this.image,
    required this.onRomSelected,
    required this.onKeyPressed,
    required this.onKeyReleased,
  }) : super(key: key);

  final String title;
  final ValueNotifier<ui.Image?> image;
  final void Function(Uint8List) onRomSelected;
  final void Function(JoypadKey) onKeyPressed;
  final void Function(JoypadKey) onKeyReleased;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: _Screen(image: widget.image),
            ),
          ),
          Expanded(
            child: _Controller(
              onKeyPressed: widget.onKeyPressed,
              onKeyReleased: widget.onKeyReleased,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles();
            if (result == null) return;

            var bytes = result.files.first.bytes;

            if (bytes == null) {
              final file = File(result.paths.first!);

              bytes = await file.readAsBytes();
            }

            widget.onRomSelected(bytes);
          },
          child: const Icon(
            Icons.file_upload,
            color: Colors.white,
          )),
    );
  }
}

class _Screen extends StatefulWidget {
  const _Screen({
    Key? key,
    required this.image,
  }) : super(key: key);

  final ValueNotifier<ui.Image?> image;

  @override
  State<StatefulWidget> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  @override
  void initState() {
    super.initState();

    widget.image.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) => CustomPaint(
        painter: _ScreenPainter(
          widget.image.value,
          constraints.maxWidth,
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 100,
          right: 40,
          width: 50,
          height: 40,
          child: _ControllerButton(
            onPressed: () => onKeyPressed(JoypadKey.a),
            onReleased: () => onKeyReleased(JoypadKey.a),
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
          width: 50,
          height: 40,
          child: _ControllerButton(
            onPressed: () => onKeyPressed(JoypadKey.b),
            onReleased: () => onKeyReleased(JoypadKey.b),
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
            child: const Icon(
              Icons.arrow_left_rounded,
              color: Colors.white,
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
            child: const Icon(
              Icons.arrow_right_rounded,
              color: Colors.white,
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
            child: const Icon(
              Icons.arrow_upward_rounded,
              color: Colors.white,
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
            child: const Icon(
              Icons.arrow_downward_rounded,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: 80,
          width: 100,
          height: 40,
          child: _ControllerButton(
            onPressed: () => onKeyPressed(JoypadKey.select),
            onReleased: () => onKeyReleased(JoypadKey.select),
            child: const Text(
              'SELECT',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: 200,
          width: 100,
          height: 40,
          child: _ControllerButton(
            onPressed: () => onKeyPressed(JoypadKey.start),
            onReleased: () => onKeyReleased(JoypadKey.start),
            child: const Text(
              'START',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ControllerButton extends StatelessWidget {
  const _ControllerButton({
    Key? key,
    required this.onPressed,
    required this.onReleased,
    required this.child,
  }) : super(key: key);

  final void Function() onPressed;
  final void Function() onReleased;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.lightBlue,
      elevation: 1,
      child: InkWell(
        onTapDown: (_) => onPressed(),
        onTap: () => onReleased(),
        child: Center(child: child),
      ),
    );
  }
}

class _ScreenPainter extends CustomPainter {
  _ScreenPainter(this.image, this.width);

  final ui.Image? image;
  final double width;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = Paint();

    final height = (_height / _width) * width;

    if (image != null) {
      canvas.drawImageRect(
        image!,
        const Rect.fromLTWH(0, 0, _width, _height),
        Rect.fromLTWH(
          0,
          0,
          width,
          height,
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
