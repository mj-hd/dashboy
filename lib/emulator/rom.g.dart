// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rom.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Rom _$RomFromJson(Map<String, dynamic> json) => Rom(
      (json['data'] as List<dynamic>).map((e) => e as int).toList(),
    )
      ..mbcType = $enumDecode(_$MbcTypeEnumMap, json['mbcType'])
      ..romSize = json['romSize'] as int
      ..ramSize = json['ramSize'] as int
      ..headerChecksum = json['headerChecksum'] as int;

Map<String, dynamic> _$RomToJson(Rom instance) => <String, dynamic>{
      'mbcType': _$MbcTypeEnumMap[instance.mbcType],
      'romSize': instance.romSize,
      'ramSize': instance.ramSize,
      'headerChecksum': instance.headerChecksum,
      'data': instance.data,
    };

const _$MbcTypeEnumMap = {
  MbcType.romOnly: 'romOnly',
  MbcType.mbc1: 'mbc1',
  MbcType.mbc1Ram: 'mbc1Ram',
  MbcType.mbc1RamBattery: 'mbc1RamBattery',
  MbcType.mbc2: 'mbc2',
  MbcType.mbc2Battery: 'mbc2Battery',
  MbcType.romRam: 'romRam',
  MbcType.romRamBattery: 'romRamBattery',
  MbcType.mmm01: 'mmm01',
  MbcType.mmm01Ram: 'mmm01Ram',
  MbcType.mmm01RamBattery: 'mmm01RamBattery',
  MbcType.mbc3: 'mbc3',
  MbcType.mbc3Ram: 'mbc3Ram',
  MbcType.mbc3RamBattery: 'mbc3RamBattery',
};
