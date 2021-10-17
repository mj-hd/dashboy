import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';

part 'utils.g.dart';

bool isSet(int val, int offset) {
  return val & (1 << offset) > 0;
}

int oneHot(bool? v, int offset) {
  return ((v ?? false) ? 1 : 0) << offset;
}

int bitpack(List<bool> list) {
  return List.generate(8, (i) => oneHot(list[i], 7 - i))
      .fold(0, (acc, v) => acc | v);
}

int decodeX(int opecode) {
  return (opecode >> 3) & 7;
}

int decodeY(int opecode) {
  return opecode & 7;
}

int decodeR(int opecode) {
  return (opecode >> 4) & 3;
}

@JsonSerializable()
class Bit {
  Bit(this.val);

  factory Bit.fromU8(int u8, int index) => Bit(isSet(u8, index));

  bool val;

  void set() {
    val = true;
  }

  void reset() {
    val = false;
  }

  factory Bit.fromJson(Map<String, dynamic> json) => _$BitFromJson(json);
  Map<String, dynamic> toJson() => _$BitToJson(this);
}

class BitFieldU8 {
  BitFieldU8([Map<int, bool>? _values])
      : values = Map.fromEntries(
            List.generate(8, (i) => MapEntry(i, Bit(_values?[i] ?? false))));

  BitFieldU8.fromU8(int u8)
      : values = Map.fromEntries(
            List.generate(8, (i) => MapEntry(i, Bit.fromU8(u8, i))));

  Map<int, Bit> values;

  Bit value(int offset) {
    assert(0 <= offset && offset < 8);
    return values[offset]!;
  }

  int toU8() => List.generate(8, (i) => oneHot(values[i]!.val, i))
      .fold(0, (acc, val) => acc | val);
}

extension IntExt on int {
  int wrappingAddU8(int rhs) {
    return (this + rhs).toU8();
  }

  int wrappingAddU16(int rhs) {
    return (this + rhs).toU16();
  }

  int wrappingSubU8(int rhs) {
    return (this - rhs).toU8();
  }

  int wrappingSubU16(int rhs) {
    return (this - rhs).toU16();
  }

  int rotateLeftU8() {
    final left = isSet(this, 7);
    return ((this << 1) | (left ? 1 : 0)).toU8();
  }

  int rotateRightU8() {
    final right = isSet(this, 0);
    return (this >> 1).toU8() | oneHot(right, 7);
  }

  int toU8() {
    return this & 0xFF;
  }

  int toU16() {
    return this & 0xFFFF;
  }

  int toI8() {
    if (!isSet(this, 7)) return this;

    return this - 0x0100;
  }
}

class Uint8ListConverter implements JsonConverter<Uint8List, List<dynamic>> {
  const Uint8ListConverter();

  @override
  Uint8List fromJson(List<dynamic> json) {
    return Uint8List.fromList(json.whereType<int>().toList());
  }

  @override
  List<dynamic> toJson(Uint8List object) {
    return object.toList();
  }
}
