import 'package:json_annotation/json_annotation.dart';
import 'package:dashboy/emulator/bus.dart';
import 'package:dashboy/emulator/utils.dart';

part 'cpu.g.dart';

class _F extends BitFieldU8 {
  _F();

  _F.fromU8(int u8) : super.fromU8(u8);

  Bit get c => value(4);
  Bit get h => value(5);
  Bit get n => value(6);
  Bit get z => value(7);
}

@JsonSerializable()
class Cpu {
  Cpu({
    required this.bus,
  });

  int _a = 0;
  _F _f = _F();
  int _bc = 0;
  int _de = 0;
  int _hl = 0;
  int _sp = 0;
  int _pc = 0;
  int _stalls = 0;
  bool _ime = false;
  bool _halted = false;

  int _left = -1;

  Bus bus;

  factory Cpu.fromJson(Map<String, dynamic> json) => _$CpuFromJson(json);
  Map<String, dynamic> toJson() => _$CpuToJson(this);

  void reset() {
    _a = 0x01;
    _f = _F.fromU8(0xB0);
    _bc = 0x0013;
    _de = 0x00D8;
    _hl = 0x014D;
    _sp = 0xFFFE;
    _pc = 0x0100;
    _stalls = 0;
  }

  void tick() {
    if (_stalls > 0) {
      _stalls -= 1;

      return;
    }

    _stalls += 4;

    if (_ime && _interrupt()) {
      _ime = false;
      _halted = false;
    }

    if (_halted) {
      return;
    }

    if (_left > 0) _left -= 1;

    if (_left == 0) {
      return;
    }

    final opecode = bus.read(_pc);

    _pc = _pc.wrappingAddU16(1);

    _doMnemonic(opecode);

    // print(
    //     'A: ${_a.toRadixString(16).padLeft(2, "0").toUpperCase()} F: ${_f.toU8().toRadixString(16).padLeft(2, "0").toUpperCase()} B: ${_b.toRadixString(16).padLeft(2, "0").toUpperCase()} C: ${_c.toRadixString(16).padLeft(2, "0").toUpperCase()} D: ${_d.toRadixString(16).padLeft(2, "0").toUpperCase()} E: ${_e.toRadixString(16).padLeft(2, "0").toUpperCase()} H: ${_h.toRadixString(16).padLeft(2, "0").toUpperCase()} L: ${_l.toRadixString(16).padLeft(2, "0").toUpperCase()} SP: ${_sp.toRadixString(16).padLeft(4, "0").toUpperCase()} PC: ${_pc.toRadixString(16).padLeft(4, "0").toUpperCase()} | ${opecode.toRadixString(16).padLeft(4, "0").toUpperCase()}: ');
  }

  int get _b => (_bc & 0xFF00) >> 8;

  int get _c => _bc & 0x00FF;

  int get _d => (_de & 0xFF00) >> 8;

  int get _e => _de & 0x00FF;

  int get _h => (_hl & 0xFF00) >> 8;

  int get _l => _hl & 0x00FF;

  int get _af => (_a << 8) | _f.toU8();

  set _b(int val) {
    _bc &= 0x00FF;
    _bc |= (val << 8).toU16();
  }

  set _c(int val) {
    _bc &= 0xFF00;
    _bc |= val;
  }

  set _d(int val) {
    _de &= 0x00FF;
    _de |= (val << 8).toU16();
  }

  set _e(int val) {
    _de &= 0xFF00;
    _de |= val;
  }

  set _h(int val) {
    _hl &= 0x00FF;
    _hl |= (val << 8).toU16();
  }

  set _l(int val) {
    _hl &= 0xFF00;
    _hl |= val;
  }

  set _af(int val) {
    _a = (val >> 8).toU8();
    _f = _F.fromU8(val & 0x00F0);
  }

  int _r8(int index) {
    switch (index) {
      case 0:
        return _b;
      case 1:
        return _c;
      case 2:
        return _d;
      case 3:
        return _e;
      case 4:
        return _h;
      case 5:
        return _l;
      case 6:
        return bus.read(_hl);
      case 7:
        return _a;
      default:
        throw ArgumentError.value(index);
    }
  }

  void _setR8(int index, int val) {
    switch (index) {
      case 0:
        _b = val;
        break;
      case 1:
        _c = val;
        break;
      case 2:
        _d = val;
        break;
      case 3:
        _e = val;
        break;
      case 4:
        _h = val;
        break;
      case 5:
        _l = val;
        break;
      case 6:
        bus.write(_hl, val);
        break;
      case 7:
        _a = val;
        break;
      default:
        throw ArgumentError.value(index);
    }
  }

  int _r16(int index, bool high) {
    switch (index) {
      case 0:
        return _bc;
      case 1:
        return _de;
      case 2:
        return _hl;
      case 3:
        if (high) {
          return _af;
        } else {
          return _sp;
        }
      default:
        throw ArgumentError.value(index);
    }
  }

  void _setR16(int index, int val, bool high) {
    switch (index) {
      case 0:
        _bc = val;
        break;
      case 1:
        _de = val;
        break;
      case 2:
        _hl = val;
        break;
      case 3:
        if (high) {
          _af = val;
        } else {
          _sp = val;
        }
        break;
      default:
        throw ArgumentError.value(index);
    }
  }

  bool _carryPositive(int left, int right) {
    return (left & 0xFF) + (right & 0xFF) > 0xFF;
  }

  bool _carryNegative(int left, int right) {
    return (left & 0xFF) < (right & 0xFF);
  }

  bool _halfCarryPositive(int left, int right) {
    return (left & 0x0F) + (right & 0x0F) > 0x0F;
  }

  bool _halfCarryNegative(int left, int right) {
    return (left & 0x0F) < (right & 0x0F);
  }

  bool _carryPositiveU16(int left, int right) {
    return (left & 0xFFFF) + (right & 0xFFFF) > 0xFFFF;
  }

  bool _halfCarryPositiveU16U12(int left, int right) {
    return (left & 0x0FFF) + (right & 0x0FFF) > 0x0FFF;
  }

  bool _interrupt() {
    int interrupt = 0x0040;

    if (bus.ie.vBlank.val && bus.irqVBlank) {
      bus.irqVBlank = false;

      _call(interrupt);

      return true;
    }

    interrupt += 0x0008;

    if (bus.ie.lcdStat.val && bus.irqLcdStat) {
      bus.irqLcdStat = false;

      _call(interrupt);

      return true;
    }

    interrupt += 0x0008;

    if (bus.ie.timer.val && bus.irqTimer) {
      bus.irqTimer = false;

      _call(interrupt);

      return true;
    }

    interrupt += 0x0008;

    if (bus.ie.serial.val && bus.irqSerial) {
      bus.irqSerial = false;

      _call(interrupt);

      return true;
    }

    interrupt += 0x0008;

    if (bus.ie.joypad.val && bus.irqJoypad) {
      bus.irqJoypad = false;

      _call(interrupt);

      return true;
    }

    return false;
  }

  void _doMnemonic(int opecode) {
    switch (opecode) {
      // NOP
      case 0x00:
        _nop();
        return;
      // HALT
      case 0x76:
        _halt();
        return;
      // STOP
      case 0x10:
        _stop();
        return;
      // DI
      case 0xF3:
        _di();
        return;
      // EI
      case 0xFB:
        _ei();
        return;
      // LD A, (BC)
      case 0x0A:
        _loadU8AAddrBc();
        return;
      // LD A, (DE)
      case 0x1A:
        _loadU8AAddrDe();
        return;
      // LD (BC), A
      case 0x02:
        _loadU8AddrBcA();
        return;
      // LD (DE), A
      case 0x12:
        _loadU8AddrDeA();
        return;
      // LD A, (nn)
      case 0xFA:
        _loadU8AAddrIm16();
        return;
      // LD (nn), A
      case 0xEA:
        _loadU8AddrIm16A();
        return;
      // LDH A, (C)
      case 0xF2:
        _loadU8AAddrIndexC();
        return;
      // LDH (C), A
      case 0xE2:
        _loadU8AddrIndexCA();
        return;
      // LDH A, (n)
      case 0xF0:
        _loadU8AAddrIndexIm8();
        return;
      // LDH (n), A
      case 0xE0:
        _loadU8AddrIndexIm8A();
        return;
      // LD A, (HL-)
      case 0x3A:
        _loadDecU8AAddrHl();
        return;
      // LD (HL-), A
      case 0x32:
        _loadDecU8AddrHlA();
        return;
      // LD A, (HL+)
      case 0x2A:
        _loadIncU8AAddrHl();
        return;
      // LD (HL+), A
      case 0x22:
        _loadIncU8AddrHlA();
        return;
      // LD (nn), SP
      case 0x08:
        _loadU16AddrIm16Sp();
        return;
      // LD HL, SP+n
      case 0xF8:
        _loadU16HlIndexIm8Sp();
        return;
      // LD SP, HL
      case 0xF9:
        _loadU16SpHl();
        return;
      // ADD A, n
      case 0xC6:
        _addU8AIm8();
        return;
      // ADC A, n
      case 0xCE:
        _addCarryU8AIm8();
        return;
      // SUB n
      case 0xD6:
        _subU8AIm8();
        return;
      // SBC A, n
      case 0xDE:
        _subCarryU8AIm8();
        return;
      // AND A, n
      case 0xE6:
        _andU8AIm8();
        return;
      // OR A, n
      case 0xF6:
        _orU8AIm8();
        return;
      // XOR A, n
      case 0xEE:
        _xorU8AIm8();
        return;
      // CP A, n
      case 0xFE:
        _cpU8AIm8();
        return;
      // ADD SP, n
      case 0xE8:
        _addU16SpIm8();
        return;
      // RLCA
      case 0x07:
        _rlcaU8();
        return;
      // RLA
      case 0x17:
        _rlaU8();
        return;
      // RRCA
      case 0x0F:
        _rrcaU8();
        return;
      // RRA
      case 0x1F:
        _rraU8();
        return;
      // DAA
      case 0x27:
        _decimalAdjustU8A();
        return;
      // CPL
      case 0x2F:
        _complementU8A();
        return;
      // CCF
      case 0x3F:
        _complementCarry();
        return;
      // SCF
      case 0x37:
        _setCarryFlag();
        return;
      // JP nn
      case 0xC3:
        _jpU16();
        return;
      // JP NZ, nn
      case 0xC2:
        _jpU16Nz();
        return;
      // JP Z, nn
      case 0xCA:
        _jpU16Z();
        return;
      // JP NC, nn
      case 0xD2:
        _jpU16Nc();
        return;
      // JP C, nn
      case 0xDA:
        _jpU16C();
        return;
      // JP (HL)
      case 0xE9:
        _jpU16Hl();
        return;
      // JR
      case 0x18:
        _jrU8ImU8();
        return;
      // JR NZ, nn
      case 0x20:
        _jrU8Nz();
        return;
      // JR Z, nn
      case 0x28:
        _jrU8Z();
        return;
      // JR NC, nn
      case 0x30:
        _jrU8Nc();
        return;
      // JR C, nn
      case 0x38:
        _jrU8C();
        return;
      // CALL nn
      case 0xCD:
        _callU16();
        return;
      // CALL NZ, nn
      case 0xC4:
        _callU16Nz();
        return;
      // CALL Z, nn
      case 0xCC:
        _callU16Z();
        return;
      // CALL NC, nn
      case 0xD4:
        _callU16Nc();
        return;
      // CALL C, nn
      case 0xDC:
        _callU16C();
        return;
      // RET
      case 0xC9:
        _ret();
        return;
      // RET NZ
      case 0xC0:
        _retNz();
        return;
      // RET Z
      case 0xC8:
        _retZ();
        return;
      // RET NC
      case 0xD0:
        _retNc();
        return;
      // RET C
      case 0xD8:
        _retC();
        return;
      // RETI
      case 0xD9:
        _reti();
        return;
      // CB Prefixed Instructions
      case 0xCB:
        {
          final prefixed = bus.read(_pc);
          _pc = _pc.wrappingAddU16(1);
          _doMnemonicPrefixed(prefixed);
          return;
        }
    }

    // LD r, r'
    // LD r, (HL)
    // LD (HL), r
    if (0x40 <= opecode && opecode <= 0x7F) {
      _loadU8RR(decodeX(opecode), decodeY(opecode));
      return;
    }

    // LD r, n
    // LD (HL), n
    if (0x06 <= opecode && opecode <= 0x3E && (opecode & 7 == 6)) {
      _loadU8RIm8(decodeX(opecode));
      return;
    }

    // LD rr, nn
    if (0x01 <= opecode && opecode <= 0x31 && (opecode & 15 == 1)) {
      _loadU16RrIm16(decodeR(opecode));
      return;
    }

    // PUSH rr
    if (0xC5 <= opecode && opecode <= 0xF5 && (opecode & 15 == 5)) {
      _pushU16Rr(decodeR(opecode));
      return;
    }

    // POP rr
    if (0xC1 <= opecode && opecode <= 0xF1 && (opecode & 15 == 1)) {
      _popU16Rr(decodeR(opecode));
      return;
    }

    // ADD A, r
    if (0x80 <= opecode && opecode <= 0x87) {
      _addU8AR(decodeY(opecode));
      return;
    }

    // ADC A, r
    if (0x88 <= opecode && opecode <= 0x8f) {
      _addCarryU8AR(decodeY(opecode));
      return;
    }

    // SUB A, r
    if (0x90 <= opecode && opecode <= 0x97) {
      _subU8AR(decodeY(opecode));
      return;
    }

    // SBC A, r
    if (0x98 <= opecode && opecode <= 0x9F) {
      _subCarryU8AR(decodeY(opecode));
      return;
    }

    // AND A, r
    if (0xA0 <= opecode && opecode <= 0xA7) {
      _andU8AR(decodeY(opecode));
      return;
    }

    // OR A, r
    if (0xB0 <= opecode && opecode <= 0xB7) {
      _orU8AR(decodeY(opecode));
      return;
    }

    // XOR A, r
    if (0xA8 <= opecode && opecode <= 0xAF) {
      _xorU8AR(decodeY(opecode));
      return;
    }

    // CP A, r
    if (0xB8 <= opecode && opecode <= 0xBF) {
      _cpU8AR(decodeY(opecode));
      return;
    }

    // INC r
    if (0x04 <= opecode && opecode <= 0x3C && (opecode & 7 == 4)) {
      _incU8R(decodeX(opecode));
      return;
    }

    // DEC r
    if (0x05 <= opecode && opecode <= 0x3D && (opecode & 7 == 5)) {
      _decU8R(decodeX(opecode));
      return;
    }

    // ADD HL, rr
    if (0x09 <= opecode && opecode <= 0x39 && (opecode & 15 == 9)) {
      _addU16HlRr(decodeR(opecode));
      return;
    }

    // INC rr
    if (0x03 <= opecode && opecode <= 0x33 && (opecode & 15 == 3)) {
      _incU16Rr(decodeR(opecode));
      return;
    }

    // DEC rr
    if (0x0B <= opecode && opecode <= 0x3B && (opecode & 15 == 11)) {
      _decU16Rr(decodeR(opecode));
      return;
    }

    // RST 00H~38H
    if (0xC7 <= opecode && (opecode & 7 == 7)) {
      _restart(decodeX(opecode));
      return;
    }

    throw ArgumentError.value(opecode);
  }

  void _doMnemonicPrefixed(int opecode) {
    // SWAP r
    if (0x30 <= opecode && opecode <= 0x37) {
      _swapU8R(decodeY(opecode));
      return;
    }

    // RLC r
    if (0x00 <= opecode && opecode <= 0x07) {
      _rlcU8R(decodeY(opecode));
      return;
    }

    // RL r
    if (0x10 <= opecode && opecode <= 0x17) {
      _rlU8R(decodeY(opecode));
      return;
    }

    // RRC r
    if (0x08 <= opecode && opecode <= 0x0F) {
      _rrcU8R(decodeY(opecode));
      return;
    }

    // RR r
    if (0x18 <= opecode && opecode <= 0x1F) {
      _rrU8R(decodeY(opecode));
      return;
    }

    // SLA r
    if (0x20 <= opecode && opecode <= 0x27) {
      _slaU8R(decodeY(opecode));
      return;
    }

    // SRA r
    if (0x28 <= opecode && opecode <= 0x2F) {
      _sraU8R(decodeY(opecode));
      return;
    }

    // SRL r
    if (0x38 <= opecode && opecode <= 0x3F) {
      _srlU8R(decodeY(opecode));
      return;
    }

    // BIT b, r
    if (0x40 <= opecode && opecode <= 0x7F) {
      _bitU8BitR(decodeY(opecode), decodeX(opecode));
      return;
    }

    // SET b, r
    if (0xC0 <= opecode && opecode <= 0xFF) {
      _setU8BitR(decodeY(opecode), decodeX(opecode));
      return;
    }

    // RES b, r
    if (0x80 <= opecode && opecode <= 0xBF) {
      _resetU8BitR(decodeY(opecode), decodeX(opecode));
      return;
    }

    throw ArgumentError.value(opecode);
  }

  void _nop() {}

  void _halt() {
    _halted = true;
  }

  void _stop() {}

  void _di() {
    _ime = false;
  }

  void _ei() {
    _ime = true;
  }

  void _loadU8RIm8(int index) {
    final val = bus.read(_pc);

    _pc = _pc.wrappingAddU16(1);

    _setR8(index, val);
  }

  void _loadU8RR(int left, int right) {
    final val = _r8(right);
    _setR8(left, val);
  }

  void _loadU8AAddrBc() {
    final val = bus.read(_bc);
    _a = val;
  }

  void _loadU8AAddrDe() {
    final val = bus.read(_de);
    _a = val;
  }

  void _loadU8AddrBcA() {
    bus.write(_bc, _a);
  }

  void _loadU8AddrDeA() {
    bus.write(_de, _a);
  }

  void _loadU8AAddrIm16() {
    final addr = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);
    final val = bus.read(addr);
    _a = val;
  }

  void _loadU8AddrIm16A() {
    final addr = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);
    final val = _a;
    bus.write(addr, val);
  }

  void _loadU8AAddrIndexC() {
    final index = _c;
    final addr = 0xFF00 + index;
    final val = bus.read(addr);
    _a = val;
  }

  void _loadU8AddrIndexCA() {
    final index = _c;
    final addr = 0xFF00 + index;
    bus.write(addr, _a);
  }

  void _loadU8AAddrIndexIm8() {
    final index = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);
    final addr = 0xFF00 + index;
    final val = bus.read(addr);
    _a = val;
  }

  void _loadU8AddrIndexIm8A() {
    final index = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);
    final addr = 0xFF00 + index;
    bus.write(addr, _a);
  }

  void _loadDecU8AAddrHl() {
    final val = bus.read(_hl);
    _hl = _hl.wrappingSubU16(1);
    _a = val;
  }

  void _loadDecU8AddrHlA() {
    bus.write(_hl, _a);
    _hl = _hl.wrappingSubU16(1);
  }

  void _loadIncU8AAddrHl() {
    final val = bus.read(_hl);
    _hl = _hl.wrappingAddU16(1);
    _a = val;
  }

  void _loadIncU8AddrHlA() {
    bus.write(_hl, _a);
    _hl = _hl.wrappingAddU16(1);
  }

  void _loadU16RrIm16(int index) {
    final val = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);
    _setR16(index, val, false);
  }

  void _loadU16AddrIm16Sp() {
    final addr = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);
    final val = _sp;
    bus.writeWord(addr, val);
  }

  void _loadU16HlIndexIm8Sp() {
    final baseAddr = _sp;
    final indexAddr = bus.read(_pc).toI8();
    _pc = _pc.wrappingAddU16(1);
    _hl = baseAddr.wrappingAddU16(indexAddr);

    _f.z.reset();
    _f.n.reset();
    _f.h.val = _halfCarryPositive(baseAddr.toU8(), indexAddr.toU8());
    _f.c.val = _carryPositive(baseAddr.toU8(), indexAddr.toU8());
  }

  void _loadU16SpHl() {
    _sp = _hl;

    _stalls += 8;
  }

  void _pushU16Rr(int index) {
    final val = _r16(index, true);
    _sp = _sp.wrappingSubU16(2);
    bus.writeWord(_sp, val);

    _stalls += 16;
  }

  void _popU16Rr(int index) {
    final val = bus.readWord(_sp);
    _sp = _sp.wrappingAddU16(2);
    _setR16(index, val, true);

    _stalls += 12;
  }

  void _addU8AR(int index) {
    final left = _a;
    final right = _r8(index);
    final result = left.wrappingAddU8(right);

    _a = result;

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.val = _halfCarryPositive(left, right);
    _f.c.val = _carryPositive(left, right);

    _stalls += 4;
  }

  void _addU8AIm8() {
    final right = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);
    final left = _a;
    final result = left.wrappingAddU8(right);

    _a = result;

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.val = _halfCarryPositive(left, right);
    _f.c.val = _carryPositive(left, right);

    _stalls += 8;
  }

  void _addCarryU8AR(int index) {
    final c = _f.c.val ? 1 : 0;
    final right = _r8(index);
    final left = _a;
    final result1 = left.wrappingAddU8(right);
    final result2 = result1.wrappingAddU8(c);

    final c1 = _carryPositive(left, right);
    final h1 = _halfCarryPositive(left, right);
    final c2 = _carryPositive(result1, c);
    final h2 = _halfCarryPositive(result1, c);

    _a = result2;

    _f.z.val = result2 == 0;
    _f.n.reset();
    _f.h.val = h1 || h2;
    _f.c.val = c1 || c2;

    _stalls += 4;
  }

  void _addCarryU8AIm8() {
    final c = _f.c.val ? 1 : 0;
    final right = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);
    final left = _a;
    final result1 = left.wrappingAddU8(right);
    final result2 = result1.wrappingAddU8(c);

    final c1 = _carryPositive(left, right);
    final h1 = _halfCarryPositive(left, right);
    final c2 = _carryPositive(result1, c);
    final h2 = _halfCarryPositive(result1, c);

    _a = result2;

    _f.z.val = result2 == 0;
    _f.n.reset();
    _f.h.val = h1 || h2;
    _f.c.val = c1 || c2;

    _stalls += 8;
  }

  void _subU8AR(int index) {
    final left = _a;
    final right = _r8(index);
    final result = left.wrappingSubU8(right);

    _a = result;

    _f.z.val = result == 0;
    _f.n.set();
    _f.h.val = _halfCarryNegative(left, right);
    _f.c.val = _carryNegative(left, right);

    _stalls += 4;
  }

  void _subU8AIm8() {
    final left = _a;
    final right = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);
    final result = left.wrappingSubU8(right);

    _a = result;

    _f.z.val = result == 0;
    _f.n.set();
    _f.h.val = _halfCarryNegative(left, right);
    _f.c.val = _carryNegative(left, right);

    _stalls += 8;
  }

  void _subCarryU8AR(int index) {
    final c = _f.c.val ? 1 : 0;
    final left = _a;
    final right = _r8(index);
    final result1 = left.wrappingSubU8(right);
    final result2 = result1.wrappingSubU8(c);

    _a = result2;

    final c1 = _carryNegative(left, right);
    final h1 = _halfCarryNegative(left, right);
    final c2 = _carryNegative(result1, c);
    final h2 = _halfCarryNegative(result1, c);

    _f.z.val = result2 == 0;
    _f.n.set();
    _f.h.val = h1 || h2;
    _f.c.val = c1 || c2;

    _stalls += 4;
  }

  void _subCarryU8AIm8() {
    final c = _f.c.val ? 1 : 0;
    final left = _a;
    final right = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);
    final result1 = left.wrappingSubU8(right);
    final result2 = result1.wrappingSubU8(c);

    _a = result2;

    final c1 = _carryNegative(left, right);
    final h1 = _halfCarryNegative(left, right);
    final c2 = _carryNegative(result1, c);
    final h2 = _halfCarryNegative(result1, c);

    _f.z.val = result2 == 0;
    _f.n.set();
    _f.h.val = h1 || h2;
    _f.c.val = c1 || c2;

    _stalls += 8;
  }

  void _andU8AR(int index) {
    final left = _a;
    final right = _r8(index);
    final result = left & right;

    _a = result;

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.set();
    _f.c.reset();

    _stalls += 4;
  }

  void _andU8AIm8() {
    final left = _a;
    final right = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);
    final result = left & right;

    _a = result;

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.set();
    _f.c.reset();

    _stalls += 8;
  }

  void _orU8AR(int index) {
    final left = _a;
    final right = _r8(index);
    final result = left | right;

    _a = result;

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.reset();
    _f.c.reset();

    _stalls += 4;
  }

  void _orU8AIm8() {
    final left = _a;
    final right = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);
    final result = left | right;

    _a = result;

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.reset();
    _f.c.reset();

    _stalls += 8;
  }

  void _xorU8AR(int index) {
    final left = _a;
    final right = _r8(index);
    final result = left ^ right;

    _a = result;

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.reset();
    _f.c.reset();

    _stalls += 4;
  }

  void _xorU8AIm8() {
    final left = _a;
    final right = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);
    final result = left ^ right;

    _a = result;

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.reset();
    _f.c.reset();

    _stalls += 8;
  }

  void _cpU8AR(int index) {
    final left = _a;
    final right = _r8(index);
    final result = left.wrappingSubU8(right);

    _f.z.val = result == 0;
    _f.n.set();
    _f.h.val = _halfCarryNegative(left, right);
    _f.c.val = _carryNegative(left, right);

    _stalls += 4;
  }

  void _cpU8AIm8() {
    final left = _a;
    final right = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);
    final result = left.wrappingSubU8(right);

    _f.z.val = result == 0;
    _f.n.set();
    _f.h.val = _halfCarryNegative(left, right);
    _f.c.val = _carryNegative(left, right);

    _stalls += 8;
  }

  void _incU8R(int index) {
    final left = _r8(index);
    const right = 1;
    final result = left.wrappingAddU8(right);

    _setR8(index, result);

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.val = _halfCarryPositive(left, right);

    _stalls += 4;
  }

  void _decU8R(int index) {
    final left = _r8(index);
    const right = 1;
    final result = left.wrappingSubU8(right);

    _setR8(index, result);

    _f.z.val = result == 0;
    _f.n.set();
    _f.h.val = _halfCarryNegative(left, right);

    _stalls += 4;
  }

  void _addU16HlRr(int index) {
    final left = _hl;
    final right = _r16(index, false);
    final result = left.wrappingAddU16(right);

    _hl = result;

    _f.n.reset();
    _f.h.val = _halfCarryPositiveU16U12(left, right);
    _f.c.val = _carryPositiveU16(left, right);

    _stalls += 8;
  }

  void _addU16SpIm8() {
    final left = _sp;
    final right = bus.read(_pc).toI8();
    _pc = _pc.wrappingAddU16(1);
    final result = left.wrappingAddU16(right);

    _sp = result;

    _f.z.reset();
    _f.n.reset();
    _f.h.val = _halfCarryPositive(left.toU8(), right.toU8());
    _f.c.val = _carryPositive(left.toU8(), right.toU8());

    _stalls += 16;
  }

  void _incU16Rr(int index) {
    final left = _r16(index, false);
    const right = 1;
    final result = left.wrappingAddU16(right);

    _setR16(index, result, false);

    _stalls += 8;
  }

  void _decU16Rr(int index) {
    final left = _r16(index, false);
    const right = 1;
    final result = left.wrappingSubU16(right);

    _setR16(index, result, false);

    _stalls += 8;
  }

  void _rlcaU8() {
    final val = _a;
    final c = (val >> 7) & 1;
    final result = val.rotateLeftU8();

    _a = result;

    _f.z.reset();
    _f.n.reset();
    _f.h.reset();
    _f.c.val = c == 1;

    _stalls += 4;
  }

  void _rlaU8() {
    final val = _a;
    final c = (val >> 7) & 1;
    final result = (val << 1).toU8() | (_f.c.val ? 1 : 0);

    _a = result;

    _f.z.reset();
    _f.n.reset();
    _f.h.reset();
    _f.c.val = c == 1;

    _stalls += 4;
  }

  void _rrcaU8() {
    final val = _a;
    final c = val & 1;
    final result = val.rotateRightU8();

    _a = result;

    _f.z.reset();
    _f.n.reset();
    _f.h.reset();
    _f.c.val = c == 1;

    _stalls += 4;
  }

  void _rraU8() {
    final val = _a;
    final c = val & 1;
    final result = (val >> 1).toU8() | ((_f.c.val ? 1 : 0) << 7);

    _a = result;

    _f.z.reset();
    _f.n.reset();
    _f.h.reset();
    _f.c.val = c == 1;

    _stalls += 4;
  }

  void _rlcU8R(int index) {
    final val = _r8(index);
    final c = (val >> 7) & 1;
    final result = val.rotateLeftU8();

    _setR8(index, result);

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.reset();
    _f.c.val = c == 1;

    _stalls += 8;
  }

  void _rlU8R(int index) {
    final val = _r8(index);
    final c = (val >> 7) & 1;
    final result = (val << 1).toU8() | (_f.c.val ? 1 : 0);

    _setR8(index, result);

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.reset();
    _f.c.val = c == 1;

    _stalls += 8;
  }

  void _rrcU8R(int index) {
    final val = _r8(index);
    final c = val & 1;
    final result = val.rotateRightU8();

    _setR8(index, result);

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.reset();
    _f.c.val = c == 1;

    _stalls += 8;
  }

  void _rrU8R(int index) {
    final val = _r8(index);
    final c = val & 1;
    final result = (val >> 1).toU8() | ((_f.c.val ? 1 : 0) << 7);

    _setR8(index, result);

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.reset();
    _f.c.val = c == 1;

    _stalls += 8;
  }

  void _slaU8R(int index) {
    final val = _r8(index);
    final c = (val >> 7) & 1;
    final result = (val << 1).toU8();

    _setR8(index, result);

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.reset();
    _f.c.val = c == 1;

    _stalls += 8;
  }

  void _sraU8R(int index) {
    final val = _r8(index);
    final c = val & 1;
    final result = (val >> 1).toU8() | oneHot(isSet(val, 7), 7);

    _setR8(index, result);

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.reset();
    _f.c.val = c == 1;

    _stalls += 8;
  }

  void _srlU8R(int index) {
    final val = _r8(index);
    final c = val & 1;
    final result = (val >> 1).toU8();

    _setR8(index, result);

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.reset();
    _f.c.val = c == 1;

    _stalls += 8;
  }

  void _bitU8BitR(int index, int bit) {
    final left = _r8(index);
    final right = bit;
    final result = (left >> right) & 1;

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.set();

    _stalls += 8;
  }

  void _setU8BitR(int index, int bit) {
    final left = _r8(index);
    final right = bit;
    final result = left | (1 << right);

    _setR8(index, result);

    _stalls += 8;
  }

  void _resetU8BitR(int index, int bit) {
    final left = _r8(index);
    final right = bit;
    final result = left & ~(1 << right);

    _setR8(index, result);

    _stalls += 8;
  }

  void _jpU16() {
    final addr = bus.readWord(_pc);

    _pc = addr;

    _stalls += 16;
  }

  void _jpU16Nz() {
    final addr = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);

    if (!_f.z.val) {
      _pc = addr;
    }

    _stalls += 16;
  }

  void _jpU16Z() {
    final addr = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);

    if (_f.z.val) {
      _pc = addr;
    }

    _stalls += 16;
  }

  void _jpU16Nc() {
    final addr = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);

    if (!_f.c.val) {
      _pc = addr;
    }

    _stalls += 16;
  }

  void _jpU16C() {
    final addr = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);

    if (_f.c.val) {
      _pc = addr;
    }

    _stalls += 16;
  }

  void _jpU16Hl() {
    _pc = _hl;

    _stalls += 4;
  }

  void _jrU8ImU8() {
    final index = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);
    _pc = _pc.wrappingAddU16(index.toI8());

    _stalls += 12;
  }

  void _jrU8Nz() {
    final index = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);

    if (!_f.z.val) {
      _pc = _pc.wrappingAddU16(index.toI8());
    }

    _stalls += 12;
  }

  void _jrU8Z() {
    final index = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);

    if (_f.z.val) {
      _pc = _pc.wrappingAddU16(index.toI8());
    }

    _stalls += 12;
  }

  void _jrU8Nc() {
    final index = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);

    if (!_f.c.val) {
      _pc = _pc.wrappingAddU16(index.toI8());
    }

    _stalls += 12;
  }

  void _jrU8C() {
    final index = bus.read(_pc);
    _pc = _pc.wrappingAddU16(1);

    if (_f.c.val) {
      _pc = _pc.wrappingAddU16(index.toI8());
    }

    _stalls += 12;
  }

  void _call(int addr) {
    _sp = _sp.wrappingSubU16(2);
    bus.writeWord(_sp, _pc);
    _pc = addr;

    _stalls += 24;
  }

  void _callU16() {
    final addr = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);

    _call(addr);
  }

  void _callU16Nz() {
    final addr = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);

    if (!_f.z.val) {
      _call(addr);
    }
  }

  void _callU16Z() {
    final addr = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);

    if (_f.z.val) {
      _call(addr);
    }
  }

  void _callU16Nc() {
    final addr = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);

    if (!_f.c.val) {
      _call(addr);
    }
  }

  void _callU16C() {
    final addr = bus.readWord(_pc);
    _pc = _pc.wrappingAddU16(2);

    if (_f.c.val) {
      _call(addr);
    }
  }

  void _restart(int param) {
    final addr = param * 0x08;
    _sp = _sp.wrappingSubU16(2);
    bus.writeWord(_sp, _pc);
    _pc = addr;

    _stalls += 16;
  }

  void _ret() {
    final addr = bus.readWord(_sp);
    _sp = _sp.wrappingAddU16(2);
    _pc = addr;

    _stalls += 16;
  }

  void _retNz() {
    final addr = bus.readWord(_sp);

    if (!_f.z.val) {
      _sp = _sp.wrappingAddU16(2);
      _pc = addr;
    }

    _stalls += 20;
  }

  void _retZ() {
    final addr = bus.readWord(_sp);

    if (_f.z.val) {
      _sp = _sp.wrappingAddU16(2);
      _pc = addr;
    }

    _stalls += 20;
  }

  void _retNc() {
    final addr = bus.readWord(_sp);

    if (!_f.c.val) {
      _sp = _sp.wrappingAddU16(2);
      _pc = addr;
    }

    _stalls += 20;
  }

  void _retC() {
    final addr = bus.readWord(_sp);

    if (_f.c.val) {
      _sp = _sp.wrappingAddU16(2);
      _pc = addr;
    }

    _stalls += 20;
  }

  void _reti() {
    final addr = bus.readWord(_sp);
    _sp = _sp.wrappingAddU16(2);
    _pc = addr;

    _ime = true;

    _stalls += 16;
  }

  void _swapU8R(int index) {
    final val = _r8(index);
    final high = val & 0xF0;
    final low = val & 0x0F;
    final result = (high >> 4) | (low << 4);

    _setR8(index, result);

    _f.z.val = result == 0;
    _f.n.reset();
    _f.h.reset();
    _f.c.reset();

    _stalls += 8;
  }

  void _decimalAdjustU8A() {
    // @see https://forums.nesdev.com/viewtopic.php?t=15944
    if (!_f.n.val) {
      if (_f.c.val || _a > 0x99) {
        _a = _a.wrappingAddU8(0x60);
        _f.c.set();
      }
      if (_f.h.val || (_a & 0x0F) > 0x09) {
        _a = _a.wrappingAddU8(0x06);
      }
    } else {
      if (_f.c.val) {
        _a = _a.wrappingSubU8(0x60);
      }
      if (_f.h.val) {
        _a = _a.wrappingSubU8(0x06);
      }
    }

    _f.z.val = _a == 0;
    _f.h.reset();

    _stalls += 4;
  }

  void _complementU8A() {
    final val = _a;
    final result = (~val).toU8();

    _a = result;
    _f.n.set();
    _f.h.set();

    _stalls += 4;
  }

  void _complementCarry() {
    final c = _f.c.val;
    final result = !c;

    _f.n.reset();
    _f.h.reset();
    _f.c.val = result;

    _stalls += 4;
  }

  void _setCarryFlag() {
    _f.n.reset();
    _f.h.reset();
    _f.c.set();

    _stalls += 4;
  }
}
