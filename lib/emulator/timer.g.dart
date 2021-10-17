// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Timer _$TimerFromJson(Map<String, dynamic> json) =>
    Timer()..interrupt = json['interrupt'] as bool;

Map<String, dynamic> _$TimerToJson(Timer instance) => <String, dynamic>{
      'interrupt': instance.interrupt,
    };
