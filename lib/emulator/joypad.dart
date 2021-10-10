import 'package:dashboy/emulator/utils.dart';

enum JoypadKey {
  a,
  b,
  up,
  down,
  left,
  right,
  select,
  start,
}

class Joypad {
  Joypad();

  bool _up = false;
  bool _down = false;
  bool _left = false;
  bool _right = false;
  bool _a = false;
  bool _b = false;
  bool _start = false;
  bool _select = false;

  bool _direction = false;
  bool _button = false;

  bool interrupt = false;

  void press(JoypadKey key) {
    switch (key) {
      case JoypadKey.a:
        _a = true;
        break;
      case JoypadKey.b:
        _b = true;
        break;
      case JoypadKey.select:
        _select = true;
        break;
      case JoypadKey.start:
        _start = true;
        break;
      case JoypadKey.up:
        _up = true;
        break;
      case JoypadKey.down:
        _down = true;
        break;
      case JoypadKey.right:
        _right = true;
        break;
      case JoypadKey.left:
        _left = true;
        break;
    }

    interrupt = true;
  }

  void release(JoypadKey key) {
    switch (key) {
      case JoypadKey.a:
        _a = false;
        break;
      case JoypadKey.b:
        _b = false;
        break;
      case JoypadKey.select:
        _select = false;
        break;
      case JoypadKey.start:
        _start = false;
        break;
      case JoypadKey.up:
        _up = false;
        break;
      case JoypadKey.down:
        _down = false;
        break;
      case JoypadKey.right:
        _right = false;
        break;
      case JoypadKey.left:
        _left = false;
        break;
    }
  }

  int readButton() {
    return bitpack(
        [true, true, false, !_direction, !_start, !_select, !_b, !_a]);
  }

  int readDirection() {
    return bitpack(
        [true, true, !_button, false, !_down, !_up, !_left, !_right]);
  }

  int read() {
    if (_direction) {
      return readDirection();
    }

    if (_button) {
      return readButton();
    }

    return 0xFF;
  }

  void write(int val) {
    _direction = !isSet(val, 5);
    _button = !isSet(val, 4);
  }
}
