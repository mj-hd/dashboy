import 'dart:math';

import 'package:dashboy/emulator/rom.dart';

abstract class Mbc {
  int read(int addr);
  void write(int addr, int val);

  factory Mbc.fromRom(Rom rom) {
    switch (rom.mbcType) {
      case MbcType.romOnly:
        return RomOnly(rom);
      case MbcType.mbc1:
      case MbcType.mbc1Ram:
      case MbcType.mbc1RamBattery:
        return Mbc1(rom);

      default:
        throw ArgumentError.value(rom.mbcType);
    }
  }
}

class RomOnly implements Mbc {
  RomOnly(this._rom);

  final Rom _rom;
  final List<int> _ram = List.filled(8 * 1024, 0, growable: false);

  @override
  int read(int addr) {
    if (addr >= 0xA000) {
      return _ram[addr - 0xA000];
    }

    return _rom.data[addr];
  }

  @override
  void write(int addr, int val) {
    if (addr >= 0xA000) {
      _ram[addr - 0xA000] = val;
    }

    return;
  }
}

enum Mbc1SelectMode {
  rom,
  ram,
}

class Mbc1 implements Mbc {
  Mbc1(this._rom);

  final Rom _rom;
  final List<int> _ram = List.filled(32 * 1024, 0, growable: false);
  int _romBank = 1;
  int _ramBank = 0;

  bool _enableRam = true;
  Mbc1SelectMode _selectMode = Mbc1SelectMode.rom;

  int _readRomFromBank(int addr) {
    final baseAddr = _romBank * 16 * 1024;
    final indexAddr = addr - 0x4000;
    return _rom.data[baseAddr + indexAddr];
  }

  int _readRamFromBank(int addr) {
    if (!_enableRam) {
      print("disabled ram read");
      return 0;
    }

    final baseAddr = _ramBank * 8 * 1024;
    final indexAddr = addr - 0xA000;
    return _ram[baseAddr + indexAddr];
  }

  void _writeRamIntoBank(int addr, int val) {
    if (!_enableRam) {
      print("disabled ram write");
      return;
    }

    final baseAddr = _ramBank * 8 * 1024;
    final indexAddr = addr - 0xA000;

    _ram[baseAddr + indexAddr] = val;
  }

  @override
  int read(int addr) {
    if (0x0000 <= addr && addr <= 0x3FFF) return _rom.data[addr];
    if (0x4000 <= addr && addr <= 0x7FFF) return _readRomFromBank(addr);
    if (0xA000 <= addr && addr <= 0xBFFF) return _readRamFromBank(addr);

    return 0;
  }

  @override
  void write(int addr, int val) {
    if (0x0000 <= addr && addr <= 0x1FFF) {
      if ((val & 0x0F) == 0x0A) {
        _enableRam = true;
      } else {
        _enableRam = false;
      }
      return;
    }

    if (0x2000 <= addr && addr <= 0x3FFF) {
      final bank = val & 0x1F;

      _romBank = max(bank, 1);
      return;
    }

    if (0x4000 <= addr && addr <= 0x5FFF) {
      switch (_selectMode) {
        case Mbc1SelectMode.rom:
          final bankHigh = val & 0x03;

          _romBank |= bankHigh << 5;
          break;

        case Mbc1SelectMode.ram:
          final bank = val & 0x03;

          _ramBank = bank;
          break;
      }
      return;
    }

    if (0x6000 <= addr && addr <= 0x7FFF) {
      if (val == 0x01) {
        _selectMode = Mbc1SelectMode.ram;
      } else {
        _selectMode = Mbc1SelectMode.rom;
      }
      return;
    }

    _writeRamIntoBank(addr, val);
  }
}
