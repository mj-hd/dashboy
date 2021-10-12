import 'dart:typed_data';

import 'package:dashboy/emulator/utils.dart';

const _width = 256;
const _height = 256;

class _LcdControl extends BitFieldU8 {
  _LcdControl() : super({});

  _LcdControl.fromU8(int u8) : super.fromU8(u8);

  Bit get bgWinEnable => value(0);
  Bit get spriteEnable => value(1);
  Bit get spriteSize => value(2);
  Bit get bgTileMapSelect => value(3);
  Bit get tileDataSelect => value(4);
  Bit get windowDisplayEnable => value(5);
  Bit get windowTileMapSelect => value(6);
  Bit get lcdDisplayEnable => value(7);
}

class _LcdStatus extends BitFieldU8 {
  _LcdStatus() : super({});

  _LcdStatus.fromU8(int u8) : super.fromU8(u8);

  Bit get ppuMode0 => value(0);
  Bit get ppuMode1 => value(1);
  Bit get coincidenceFlag => value(2);
  Bit get mode0StatIntEnable => value(3);
  Bit get mode1StatIntEnable => value(4);
  Bit get mode2StatIntEnable => value(5);
  Bit get lycLyStatIntEnable => value(6);
}

class _SpriteFlags extends BitFieldU8 {
  _SpriteFlags() : super({});

  _SpriteFlags.fromU8(int u8) : super.fromU8(u8);

  Bit get paletteNum => value(4);
  Bit get xFlip => value(5);
  Bit get yFlip => value(6);
  Bit get priority => value(7);
}

class _Palette {
  _Palette(this.values);

  List<int> values;

  _Palette.fromU8(int u8)
      : values = List.generate(4, (i) => (u8 >> (2 * i)) & 3);

  int toU8() => values.fold(0, (acc, col) => (acc << 2) | col);
}

class _Oam {
  int yPos = 0;
  int xPos = 0;
  int tileNum = 0;
  _SpriteFlags spriteFlag = _SpriteFlags();
}

enum _Mode {
  hBlank,
  vBlank,
  oamScan,
  drawing,
}

class _OamColor {
  _OamColor({
    this.index = 0,
    this.color = 0,
    this.blend = false,
  });

  final int index;
  final int color;
  final bool blend;

  static List<_OamColor> fromColorIndexes(
      List<int> indexes, bool blend, _Palette palette) {
    return List.generate(8, (i) {
      final index = indexes[i];
      return _OamColor(
        index: index,
        blend: blend,
        color: palette.values[index],
      );
    });
  }
}

class Ppu {
  Ppu();

  final List<int> _vram = List.filled(8 * 1024, 0);

  _Mode _mode = _Mode.oamScan;
  _Mode _prevMode = _Mode.vBlank;

  _LcdControl _lcdControl = _LcdControl();
  _LcdStatus _lcdStatus = _LcdStatus();
  int _windowX = 0;
  int _windowY = 0;
  int _scrollX = 0;
  int _scrollY = 0;

  int _cycles = 0;
  int _lines = 0;

  int _linesCompare = 0;

  _Palette _bgPalette = _Palette.fromU8(0x00);
  _Palette _objectPalette0 = _Palette.fromU8(0x00);
  _Palette _objectPalette1 = _Palette.fromU8(0x00);

  bool intVBlank = false;
  bool intLcdStat = false;

  int _x = 0;
  int _y = 0;

  final List<_Oam> _oam = List.generate(0xA0, (_) => _Oam());
  final List<_Oam> _buffer = [];

  List<int> _bgLine = List.filled(_width, 0);
  List<_OamColor> _oamLine = List.generate(_width, (_) => _OamColor());
  List<int> _curBg = List.filled(8, 0);
  bool _drawingWindow = false;

  Uint8List pixels = Uint8List(4 * _width * _height);

  List<int> _colorToPixel(int color) {
    switch (color) {
      case 0:
        return [0xD8, 0xF7, 0xD7, 0xFF];
      case 1:
        return [0x6C, 0xA6, 0x6B, 0xFF];
      case 2:
        return [0x20, 0x59, 0x4A, 0xFF];
      case 3:
        return [0x00, 0x14, 0x1B, 0xFF];
      default:
        return [0xFF, 0xFF, 0xFF, 0xFF];
    }
  }

  List<int> _tileToIndexes(int tileNum, int row, bool signed) {
    var baseAddr = 0x0000;
    if (signed) {
      baseAddr = 0x9000 - 0x8000;
    }

    var indexAddr = row * 2 + tileNum * 16;
    if (signed) {
      indexAddr = row * 2 + tileNum.toI8() * 16;
    }

    final addr = baseAddr.wrappingAddU16(indexAddr);

    var bit = _vram[addr];
    var color = _vram[addr + 1];

    List<int> indexes = List.filled(8, 0);

    for (var i = 7; i >= 0; i--) {
      final index = ((bit & 1) << 1) | (color & 1);
      indexes[i] = index;

      bit >>= 1;
      color >>= 1;
    }

    return indexes;
  }

  List<int> _tileMapToColors(int tileX, int tileY, int row, bool high) {
    var baseAddr = 0x9800 - 0x8000;
    if (high) {
      baseAddr = 0x9C00 - 0x8000;
    }

    final indexAddr = tileX + tileY * 32;

    final addr = baseAddr.wrappingAddU16(indexAddr);

    final tileNum = _vram[addr];

    return _tileToIndexes(tileNum, row, !_lcdControl.tileDataSelect.val);
  }

  List<_OamColor> _oamToColors(_Oam oam) {
    var row = _y + 16 - oam.yPos;
    var tile = oam.tileNum;

    if (oam.spriteFlag.yFlip.val) {
      var limit = 8;

      if (_lcdControl.spriteSize.val) {
        limit = 16;
      }

      row = limit - row - 1;
    }

    if (row >= 8) {
      row -= 8;
      tile += 1;
    }

    var palette = _objectPalette0;

    if (oam.spriteFlag.paletteNum.val) {
      palette = _objectPalette1;
    }

    final blend = oam.spriteFlag.priority;

    var colors = _OamColor.fromColorIndexes(
        _tileToIndexes(tile, row, false), blend.val, palette);

    if (oam.spriteFlag.xFlip.val) {
      colors = colors.reversed.toList();
    }

    return colors;
  }

  void _scanOam(int i) {
    var size = 8;
    if (_lcdControl.spriteSize.val) {
      size = 16;
    }

    final o = _oam[i];
    final curY = _lines + 16;
    final targetY = o.yPos;

    if (o.xPos > 8 &&
        curY < targetY + size &&
        targetY <= curY &&
        _buffer.length < 10) {
      _buffer.add(o);
    }
  }

  void _drawBg() {
    if (_drawingWindow) {
      return;
    }

    final cx = _x.wrappingAddU8(_scrollX);
    final cy = _y.wrappingAddU8(_scrollY);
    final col = cx % 8;
    final row = cy % 8;
    final tileX = cx ~/ 8;
    final tileY = cy ~/ 8;

    if (col == 0 || _x == 0) {
      _curBg =
          _tileMapToColors(tileX, tileY, row, _lcdControl.bgTileMapSelect.val);
    }

    _bgLine[_x] = _curBg[col];
  }

  void _drawWindow() {
    if (!_drawingWindow && !(_x + 7 == _windowX && _y >= _windowY)) {
      return;
    }

    _drawingWindow = true;

    final cx = _x.wrappingSubU8(_windowX);
    final cy = _y.wrappingSubU8(_windowY);
    final col = cx % 8;
    final row = cy % 8;
    final tileX = cx ~/ 8;
    final tileY = cy ~/ 8;

    if (col == 0 || _x == 0) {
      _curBg = _tileMapToColors(
        tileX,
        tileY,
        row,
        _lcdControl.windowTileMapSelect.val,
      );
    }
    _bgLine[_x] = _curBg[col];
  }

  void _drawSprite() {
    for (final oam in _buffer) {
      if (oam.xPos == _x + 8) {
        final colors = _oamToColors(oam);

        for (var i = 0; i < 8; i++) {
          _oamLine[_x + i] = colors[i];
        }
      }
    }
  }

  void _putPixels(int x) {
    final index = _bgLine[x];
    var color = _bgPalette.values[index];

    final oam = _oamLine[x];

    if ((!oam.blend || index == 0) && oam.index != 0) {
      color = oam.color;
    }

    final pixel = _colorToPixel(color);
    for (var i = 0; i < 4; i++) {
      pixels[(x + _y * _width) * 4 + i] = pixel[i];
    }
  }

  void tick() {
    _cycles += 1;

    if (_cycles >= 456) {
      _cycles = 0;
      _lines += 1;
      _buffer.clear();
      _bgLine = List.filled(_width, 0);
      _oamLine = List.generate(_width, (_) => _OamColor());
    }

    if (_lines >= 154) {
      _lines = 0;
    }

    if (_cycles == 80) {
      _x = 0;
    }

    if (_lines == 0) {
      _y = 0;
    }

    if (_lines < 144) {
      _y = _lines;

      if (0 <= _cycles && _cycles <= 79) {
        _mode = _Mode.oamScan;
      }

      if (_cycles == 80) {
        _mode = _Mode.drawing;
      }

      if (81 <= _cycles && _cycles <= 239) {
        _x += 1;
      }

      if (240 <= _cycles && _cycles <= 455) {
        _mode = _Mode.hBlank;
      }
    }

    if (_lines == 144) {
      _mode = _Mode.vBlank;
    }

    switch (_mode) {
      case _Mode.drawing:
        if (_prevMode != _mode) {
          _lcdStatus.ppuMode0.set();
          _lcdStatus.ppuMode1.set();
        }

        if (_lcdControl.bgWinEnable.val) {
          if (_lcdControl.windowDisplayEnable.val) {
            _drawWindow();
          }

          _drawBg();
        }

        if (_lcdControl.spriteEnable.val) {
          _drawSprite();
        }
        break;
      case _Mode.hBlank:
        if (_prevMode != _mode) {
          _lcdStatus.ppuMode0.reset();
          _lcdStatus.ppuMode1.reset();

          intLcdStat |= _lcdStatus.mode0StatIntEnable.val;

          _lcdStatus.coincidenceFlag.val = _lines == _linesCompare;

          intLcdStat |= _lcdStatus.lycLyStatIntEnable.val &&
              _lcdStatus.coincidenceFlag.val;

          _drawingWindow = false;
        }

        if (_cycles < 400) {
          _putPixels(_cycles - 240);
        }
        break;
      case _Mode.oamScan:
        if (_prevMode != _mode) {
          _lcdStatus.ppuMode0.reset();
          _lcdStatus.ppuMode1.set();

          intLcdStat |= _lcdStatus.mode2StatIntEnable.val;
        }

        if (_cycles % 2 == 0) {
          _scanOam(_cycles ~/ 2);
        }
        break;
      case _Mode.vBlank:
        if (_prevMode != _mode) {
          _lcdStatus.ppuMode0.set();
          _lcdStatus.ppuMode1.reset();

          intVBlank = true;

          intLcdStat |= _lcdStatus.mode1StatIntEnable.val;
        }

        break;
      default:
    }

    _prevMode = _mode;
  }

  int read(int addr) {
    return _vram[addr - 0x8000];
  }

  void write(int addr, int val) {
    _vram[addr - 0x8000] = val;
  }

  int readOam(int addr) {
    final indexAddr = addr - 0xFE00;
    final index = indexAddr ~/ 4;
    final offset = indexAddr % 4;
    final o = _oam[index];

    switch (offset) {
      case 0:
        return o.yPos;
      case 1:
        return o.xPos;
      case 2:
        return o.tileNum;
      case 3:
        return o.spriteFlag.toU8();
      default:
        return 0;
    }
  }

  void writeOam(int addr, int val) {
    final indexAddr = addr - 0xFE00;
    final index = indexAddr ~/ 4;
    final offset = indexAddr % 4;

    switch (offset) {
      case 0:
        _oam[index].yPos = val;
        break;
      case 1:
        _oam[index].xPos = val;
        break;
      case 2:
        _oam[index].tileNum = val;
        break;
      case 3:
        _oam[index].spriteFlag = _SpriteFlags.fromU8(val);
        break;
    }
  }

  int readLcdControl() {
    return _lcdControl.toU8();
  }

  void writeLcdControl(int val) {
    _lcdControl = _LcdControl.fromU8(val);
  }

  int readLcdStatus() {
    return _lcdStatus.toU8();
  }

  void writeLcdStatus(int val) {
    _lcdStatus = _LcdStatus.fromU8(val);
  }

  int readScrollY() {
    return _scrollY;
  }

  void writeScrollY(int val) {
    _scrollY = val;
  }

  int readScrollX() {
    return _scrollX;
  }

  void writeScrollX(int val) {
    _scrollX = val;
  }

  int readLines() {
    return _lines;
  }

  int readLineCompare() {
    return _linesCompare;
  }

  void writeLineCompare(int val) {
    _linesCompare = val;
  }

  int readWindowX() {
    return _windowX;
  }

  void writeWindowX(int val) {
    _windowX = val;
  }

  int readWindowY() {
    return _windowY;
  }

  void writeWindowY(int val) {
    _windowY = val;
  }

  int readBgPalette() {
    return _bgPalette.toU8();
  }

  void writeBgPalette(int val) {
    _bgPalette = _Palette.fromU8(val);
  }

  int readObjectPalette0() {
    return _objectPalette0.toU8();
  }

  void writeObjectPalette0(int val) {
    _objectPalette0 = _Palette.fromU8(val);
  }

  int readObjectPalette1() {
    return _objectPalette1.toU8();
  }

  void writeObjectPalette1(int val) {
    _objectPalette1 = _Palette.fromU8(val);
  }

  Uint8List render() {
    return Uint8List.fromList(pixels.toList());
  }
}
