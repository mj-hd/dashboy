import 'package:dashboy/emulator/joypad.dart';
import 'package:dashboy/emulator/mbc.dart';
import 'package:dashboy/emulator/ppu.dart';
import 'package:dashboy/emulator/timer.dart';
import 'package:dashboy/emulator/utils.dart';

class Ie extends BitFieldU8 {
  Ie() : super({});

  Ie.fromU8(int u8) : super.fromU8(u8);

  Bit get vBlank => value(0);
  Bit get lcdStat => value(1);
  Bit get timer => value(2);
  Bit get serial => value(3);
  Bit get joypad => value(4);
}

class Bus {
  Bus(this.ppu, this.mbc);

  Ppu ppu = Ppu();
  Joypad joypad = Joypad();
  Timer timer = Timer();

  List<int> ram = List.filled(0x8000, 0);
  List<int> hram = List.filled(0x0080, 0);
  Mbc mbc;

  Ie ie = Ie();

  bool _prevSerial = false;
  bool _intSerial = false;

  void tick() {
    ppu.tick();
    timer.tick();
  }

  bool get irqVBlank => ppu.intVBlank;
  set irqVBlank(bool val) {
    ppu.intVBlank = val;
  }

  bool get irqLcdStat => ppu.intLcdStat;
  set irqLcdStat(bool val) {
    ppu.intLcdStat = val;
  }

  bool get irqTimer => timer.interrupt;
  set irqTimer(bool val) {
    timer.interrupt = val;
  }

  bool get irqSerial => _intSerial;
  set irqSerial(bool val) {
    _intSerial = val;
  }

  bool get irqJoypad => joypad.interrupt;
  set irqJoypad(bool val) {
    joypad.interrupt = val;
  }

  int read(int addr) {
    if (0x0000 <= addr && addr <= 0x7FFF) return mbc.read(addr);
    if (0x8000 <= addr && addr <= 0x9FFF) return ppu.read(addr);
    if (0xA000 <= addr && addr <= 0xBFFF) return mbc.read(addr);
    if (0xC000 <= addr && addr <= 0xDFFF) return ram[addr - 0xC000];
    if (0xE000 <= addr && addr <= 0xFDFF) return ram[addr - 0xE000];
    if (0xFE00 <= addr && addr <= 0xFE9F) return ppu.readOam(addr);
    if (0xFEA0 <= addr && addr <= 0xFEFF) return 0;
    if (0xFF00 == addr) return joypad.read();
    if (0xFF01 == addr) return readSerial();
    if (0xFF02 == addr) return readSerialCtrl();
    if (0xFF04 == addr) return timer.readDiv();
    if (0xFF05 == addr) return timer.readTima();
    if (0xFF06 == addr) return timer.readTma();
    if (0xFF07 == addr) return timer.readTac();
    if (0xFF0F == addr) return readIrq();
    if (0xFF40 == addr) return ppu.readLcdControl();
    if (0xFF41 == addr) return ppu.readLcdStatus();
    if (0xFF42 == addr) return ppu.readScrollY();
    if (0xFF43 == addr) return ppu.readScrollX();
    if (0xFF44 == addr) return ppu.readLines();
    if (0xFF45 == addr) return ppu.readLineCompare();
    if (0xFF47 == addr) return ppu.readBgPalette();
    if (0xFF48 == addr) return ppu.readObjectPalette0();
    if (0xFF49 == addr) return ppu.readObjectPalette1();
    if (0xFF4A == addr) return ppu.readWindowY();
    if (0xFF4B == addr) return ppu.readWindowX();
    if (0xFF80 <= addr && addr <= 0xFFFE) return hram[addr - 0xFF80];
    if (0xFFFF == addr) return ie.toU8();

    return 0;
  }

  int readWord(int addr) {
    final low = read(addr);
    final high = read(addr + 1);

    return ((high) << 8) | low;
  }

  int readIrq() {
    return bitpack([
      false,
      false,
      false,
      joypad.interrupt,
      _intSerial,
      timer.interrupt,
      ppu.intLcdStat,
      ppu.intVBlank
    ]);
  }

  int readSerial() {
    // シリアル通信は一旦実装せず、デバッグ用途にだけ使う
    return 0;
  }

  int readSerialCtrl() {
    // シリアル通信は一旦実装せず、デバッグ用途にだけ使う
    return 0;
  }

  void write(int addr, int val) {
    if (0x0000 <= addr && addr <= 0x7FFF) {
      mbc.write(addr, val);
    }
    if (0x8000 <= addr && addr <= 0x9FFF) {
      ppu.write(addr, val);
    }
    if (0xA000 <= addr && addr <= 0xBFFF) {
      mbc.write(addr, val);
    }
    if (0xC000 <= addr && addr <= 0xDFFF) {
      ram[addr - 0xC000] = val;
    }
    if (0xE000 <= addr && addr <= 0xFDFF) {
      ram[addr - 0xE000] = val;
    }
    if (0xFE00 <= addr && addr <= 0xFE9F) {
      ppu.writeOam(addr, val);
    }
    if (0xFEA0 <= addr && addr <= 0xFEFF) {
      return;
    }
    if (0xFF00 == addr) {
      joypad.write(val);
    }
    if (0xFF01 == addr) {
      writeSerial(val);
    }
    if (0xFF02 == addr) {
      writeSerialCtrl(val);
    }
    if (0xFF04 == addr) {
      timer.writeDiv(val);
    }
    if (0xFF05 == addr) {
      timer.writeTima(val);
    }
    if (0xFF06 == addr) {
      timer.writeTma(val);
    }
    if (0xFF07 == addr) {
      timer.writeTac(val);
    }
    if (0xFF0F == addr) {
      writeIrq(val);
    }
    if (0xFF40 == addr) {
      ppu.writeLcdControl(val);
    }
    if (0xFF41 == addr) {
      ppu.writeLcdStatus(val);
    }
    if (0xFF42 == addr) {
      ppu.writeScrollY(val);
    }
    if (0xFF43 == addr) {
      ppu.writeScrollX(val);
    }
    if (0xFF45 == addr) {
      ppu.writeLineCompare(val);
    }
    if (0xFF46 == addr) {
      writeDma(val);
    }
    if (0xFF47 == addr) {
      ppu.writeBgPalette(val);
    }
    if (0xFF48 == addr) {
      ppu.writeObjectPalette0(val);
    }
    if (0xFF49 == addr) {
      ppu.writeObjectPalette1(val);
    }
    if (0xFF4A == addr) {
      ppu.writeWindowY(val);
    }
    if (0xFF4B == addr) {
      ppu.writeWindowX(val);
    }
    if (0xFF80 <= addr && addr <= 0xFFFE) {
      hram[addr - 0xFF80] = val;
    }
    if (0xFFFF == addr) {
      ie = Ie.fromU8(val);
    }
  }

  void writeWord(int addr, int val) {
    final low = val.toU8();
    final high = (val >> 8).toU8();

    write(addr, low);
    write(addr + 1, high);
  }

  void writeIrq(int val) {
    ppu.intVBlank = isSet(val, 0);
    ppu.intLcdStat = isSet(val, 1);
    timer.interrupt = isSet(val, 2);
    _intSerial = isSet(val, 3);
    joypad.interrupt = isSet(val, 4);
  }

  void writeSerial(int val) {
    // 未実装
  }

  void writeSerialCtrl(int val) {
    final cur = isSet(val, 7);

    if (_prevSerial && !cur) {
      _intSerial = true;
    }

    _prevSerial = cur;
  }

  void writeDma(int val) {
    final baseAddr = (val << 8).toU16();

    for (var i = 0; i < 0x100; i++) {
      write(0xFE00 + i, read(baseAddr + i));
    }
  }
}
