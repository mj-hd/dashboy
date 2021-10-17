import 'package:dashboy/emulator/utils.dart';
import 'package:json_annotation/json_annotation.dart';

part 'timer.g.dart';

enum _Clock {
  clock4096,
  clock262144,
  clock65536,
  clock16384,
}

@JsonSerializable()
class Timer {
  Timer();

  int _counter = 0;
  int _tima = 0;
  int _tma = 0;
  bool _enable = false;
  _Clock _clock = _Clock.clock4096;
  bool _prev = false;

  bool interrupt = false;

  factory Timer.fromJson(Map<String, dynamic> json) => _$TimerFromJson(json);
  Map<String, dynamic> toJson() => _$TimerToJson(this);

  void _sync() {
    var cur = false;

    if (_enable) {
      int mask;
      switch (_clock) {
        case _Clock.clock4096:
          mask = 1 << 9;
          break;

        case _Clock.clock262144:
          mask = 1 << 3;
          break;

        case _Clock.clock65536:
          mask = 1 << 5;
          break;

        case _Clock.clock16384:
          mask = 1 << 7;
          break;
      }

      cur = _counter & mask > 0;
    }

    if (_prev && !cur) {
      _tima = _tima.wrappingAddU8(1);

      if (_counter % 4 == 0 && _tima == 0) {
        _tima = _tma;
        interrupt = true;
      }
    }

    _prev = cur;
  }

  void tick() {
    _counter = _counter.wrappingAddU16(1);

    _sync();
  }

  int readDiv() => (_counter >> 8).toU8();

  void writeDiv(int _) {
    _counter = 0;
  }

  int readTima() => _tima;

  void writeTima(int val) {
    _sync();

    _tima = val;
  }

  int readTma() => _tma;

  void writeTma(int val) {
    _tma = val;

    _sync();
  }

  int readTac() {
    return bitpack([
      false,
      false,
      false,
      false,
      false,
      _enable,
      isSet(_clock.index, 1),
      isSet(_clock.index, 0)
    ]);
  }

  void writeTac(int val) {
    _enable = isSet(val, 2);

    final index = val & 3;

    _clock = _Clock.values[index];
  }
}
