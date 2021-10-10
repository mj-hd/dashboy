import 'dart:typed_data';

import 'package:dashboy/emulator/bus.dart';
import 'package:dashboy/emulator/cpu.dart';
import 'package:dashboy/emulator/joypad.dart';
import 'package:dashboy/emulator/mbc.dart';
import 'package:dashboy/emulator/ppu.dart';
import 'package:dashboy/emulator/rom.dart';

class GameBoy {
  GameBoy();

  late Cpu cpu;
  bool ready = false;

  void load(Rom rom) {
    final mbc = Mbc.fromRom(rom);
    final ppu = Ppu();
    final bus = Bus(ppu, mbc);

    cpu = Cpu(bus: bus);
  }

  void reset() {
    cpu.reset();

    ready = true;
  }

  void press(JoypadKey key) {
    cpu.bus.joypad.press(key);
  }

  void release(JoypadKey key) {
    cpu.bus.joypad.release(key);
  }

  void tick() {
    cpu.tick();
    cpu.bus.tick();
  }

  Uint8List render() {
    return cpu.bus.ppu.render();
  }
}
