// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ppu.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Ppu _$PpuFromJson(Map<String, dynamic> json) => Ppu()
  ..intVBlank = json['intVBlank'] as bool
  ..intLcdStat = json['intLcdStat'] as bool
  ..pixels = const Uint8ListConverter().fromJson(json['pixels'] as List);

Map<String, dynamic> _$PpuToJson(Ppu instance) => <String, dynamic>{
      'intVBlank': instance.intVBlank,
      'intLcdStat': instance.intLcdStat,
      'pixels': const Uint8ListConverter().toJson(instance.pixels),
    };
