// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Ie _$IeFromJson(Map<String, dynamic> json) => Ie()
  ..values = (json['values'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(int.parse(k), Bit.fromJson(e as Map<String, dynamic>)),
  );

Map<String, dynamic> _$IeToJson(Ie instance) => <String, dynamic>{
      'values': instance.values.map((k, e) => MapEntry(k.toString(), e)),
    };

Bus _$BusFromJson(Map<String, dynamic> json) => Bus(
      Ppu.fromJson(json['ppu'] as Map<String, dynamic>),
      const MbcConverter().fromJson(json['mbc'] as Map<String, dynamic>),
    )
      ..joypad = Joypad.fromJson(json['joypad'] as Map<String, dynamic>)
      ..timer = Timer.fromJson(json['timer'] as Map<String, dynamic>)
      ..ram = (json['ram'] as List<dynamic>).map((e) => e as int).toList()
      ..hram = (json['hram'] as List<dynamic>).map((e) => e as int).toList()
      ..ie = Ie.fromJson(json['ie'] as Map<String, dynamic>)
      ..irqVBlank = json['irqVBlank'] as bool
      ..irqLcdStat = json['irqLcdStat'] as bool
      ..irqTimer = json['irqTimer'] as bool
      ..irqSerial = json['irqSerial'] as bool
      ..irqJoypad = json['irqJoypad'] as bool;

Map<String, dynamic> _$BusToJson(Bus instance) => <String, dynamic>{
      'ppu': instance.ppu,
      'joypad': instance.joypad,
      'timer': instance.timer,
      'ram': instance.ram,
      'hram': instance.hram,
      'mbc': const MbcConverter().toJson(instance.mbc),
      'ie': instance.ie,
      'irqVBlank': instance.irqVBlank,
      'irqLcdStat': instance.irqLcdStat,
      'irqTimer': instance.irqTimer,
      'irqSerial': instance.irqSerial,
      'irqJoypad': instance.irqJoypad,
    };
