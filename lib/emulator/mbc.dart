import 'dart:math';

import 'package:dashboy/emulator/rom.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mbc.g.dart';

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

class MbcConverter implements JsonConverter<Mbc, Map<String, dynamic>> {
  const MbcConverter();

  @override
  Mbc fromJson(Map<String, dynamic> json) {
    if (json['romOnly'] != null) {
      return RomOnly.fromJson(json['romOnly']);
    }

    if (json['mbc1'] != null) {
      return Mbc1.fromJson(json['mbc1']);
    }

    throw ArgumentError.value(json);
  }

  @override
  Map<String, dynamic> toJson(Mbc object) {
    return {
      if (object is RomOnly) 'romOnly': object,
      if (object is Mbc1) 'mbc1': object,
    };
  }
}

@JsonSerializable()
class RomOnly implements Mbc {
  RomOnly(this.rom);

  final Rom rom;
  final List<int> _ram = List.filled(8 * 1024, 0, growable: false);

  @override
  int read(int addr) {
    if (addr >= 0xA000) {
      return _ram[addr - 0xA000];
    }

    return rom.data[addr];
  }

  @override
  void write(int addr, int val) {
    if (addr >= 0xA000) {
      _ram[addr - 0xA000] = val;
    }

    return;
  }

  factory RomOnly.fromJson(Map<String, dynamic> json) =>
      _$RomOnlyFromJson(json);
  Map<String, dynamic> toJson() => _$RomOnlyToJson(this);
}

enum Mbc1SelectMode {
  rom,
  ram,
}

@JsonSerializable()
class Mbc1 implements Mbc {
  Mbc1(this.rom);

  final Rom rom;
  final List<int> _ram = List.filled(32 * 1024, 0, growable: false);
  int _romBank = 1;
  int _ramBank = 0;

  bool _enableRam = true;
  Mbc1SelectMode _selectMode = Mbc1SelectMode.rom;

  factory Mbc1.fromJson(Map<String, dynamic> json) => _$Mbc1FromJson(json);
  Map<String, dynamic> toJson() => _$Mbc1ToJson(this);

  int _readRomFromBank(int addr) {
    final baseAddr = _romBank * 16 * 1024;
    final indexAddr = addr - 0x4000;
    return rom.data[baseAddr + indexAddr];
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
    if (0x0000 <= addr && addr <= 0x3FFF) return rom.data[addr];
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
          final bankHigh = max(val & 0x03, 1);

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
