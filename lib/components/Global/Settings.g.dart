// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 8;

  @override
  Settings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Settings()
      ..preparationDuration = fields[0] as int
      ..endingDuration = fields[1] as int
      ..binauralBeatsEnabled = fields[2] as bool
      ..binauralBaseFrequency = fields[3] as double
      ..binauralBeatFrequency = fields[4] as double
      ..dimScreenEnabled = fields[5] as bool
      ..dimScreenAfterSeconds = fields[6] as int
      ..visualStyle = fields[7] as VisualStyle
      ..breathingSoundEnabled = fields[8] as bool
      ..breathMonitoringEnabled = fields[9] == null ? false : fields[9] as bool
      ..breathThreshold = fields[10] == null ? 0.6 : fields[10] as double;
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.preparationDuration)
      ..writeByte(1)
      ..write(obj.endingDuration)
      ..writeByte(2)
      ..write(obj.binauralBeatsEnabled)
      ..writeByte(3)
      ..write(obj.binauralBaseFrequency)
      ..writeByte(4)
      ..write(obj.binauralBeatFrequency)
      ..writeByte(5)
      ..write(obj.dimScreenEnabled)
      ..writeByte(6)
      ..write(obj.dimScreenAfterSeconds)
      ..writeByte(7)
      ..write(obj.visualStyle)
      ..writeByte(8)
      ..write(obj.breathingSoundEnabled)
      ..writeByte(9)
      ..write(obj.breathMonitoringEnabled)
      ..writeByte(10)
      ..write(obj.breathThreshold);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
