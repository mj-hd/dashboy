import 'package:dashboy/emulator/utils.dart';

enum MbcType {
  romOnly,
  mbc1,
  mbc1Ram,
  mbc1RamBattery,
  mbc2,
  mbc2Battery,
  romRam,
  romRamBattery,
  mmm01,
  mmm01Ram,
  mmm01RamBattery,
  mbc3,
  mbc3Ram,
  mbc3RamBattery,
}

extension MbcTypeExt on MbcType {
  static MbcType fromU8(int u8) {
    switch (u8) {
      case 0x00:
        return MbcType.romOnly;
      case 0x01:
        return MbcType.mbc1;
      case 0x02:
        return MbcType.mbc1Ram;
      case 0x03:
        return MbcType.mbc1RamBattery;
      case 0x05:
        return MbcType.mbc2;
      case 0x06:
        return MbcType.mbc2Battery;
      case 0x08:
        return MbcType.romRam;
      case 0x09:
        return MbcType.romRamBattery;
      case 0x0b:
        return MbcType.mmm01;
      case 0x0c:
        return MbcType.mmm01Ram;
      case 0x0d:
        return MbcType.mmm01RamBattery;
      case 0x11:
        return MbcType.mbc3;
      case 0x12:
        return MbcType.mbc3Ram;
      case 0x13:
        return MbcType.mbc3RamBattery;
      default:
        throw ArgumentError.value(u8);
    }
  }
}

class Rom {
  late MbcType mbcType;
  late int romSize;
  late int ramSize;
  late int headerChecksum;
  late List<int> data;

  Rom(this.data) {
    // 0147 - Cartridge Type
    mbcType = MbcTypeExt.fromU8(data[0x0147]);

    // 0148 - ROM Size
    final size = data[0x0148];
    switch (size) {
      case 0x00:
      case 0x01:
      case 0x02:
      case 0x03:
      case 0x04:
      case 0x05:
      case 0x06:
      case 0x07:
      case 0x08:
        romSize = (32 * 1024) << size;
        break;
      case 0x52:
        romSize = (1.1 * 1024 * 1024).floor();
        break;

      case 0x53:
        romSize = (1.2 * 1024 * 1024).floor();
        break;

      case 0x54:
        romSize = (1.5 * 1024 * 1024).floor();
        break;

      default:
        throw ArgumentError.value(size);
    }

    // 0149 - RAM Size
    switch (data[0x0149]) {
      case 0x00:
        ramSize = 0;
        break;
      case 0x01:
        ramSize = 2 * 1024 * 1024;
        break;
      case 0x02:
        ramSize = 8 * 1024 * 1024;
        break;
      case 0x03:
        ramSize = 32 * 1024 * 1024;
        break;
      case 0x04:
        ramSize = 128 * 1024 * 1024;
        break;
      case 0x05:
        ramSize = 64 * 1024 * 1024;
        break;
      default:
        throw ArgumentError.value(data[0x0149]);
    }

    // 014D - Header Checksum
    headerChecksum = data[0x014D];

    var chksum = 0;

    for (var i = 0x0134; i <= 0x014C; i++) {
      chksum = chksum.wrappingSubU8(data[i]).wrappingSubU8(1);
    }

    if (headerChecksum != chksum) {
      throw StateError('header checksum mismatch');
    }

    if (romSize != data.length) {
      throw StateError('rom size mismatch');
    }
  }
}
