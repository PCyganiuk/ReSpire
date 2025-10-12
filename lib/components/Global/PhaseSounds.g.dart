// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'PhaseSounds.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhaseSoundsAdapter extends TypeAdapter<PhaseSounds> {
  @override
  final int typeId = 11;

  @override
  PhaseSounds read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhaseSounds(
      prePhase: fields[0] as String?,
      background: fields[1] as String?,
      counting: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PhaseSounds obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.prePhase)
      ..writeByte(1)
      ..write(obj.background)
      ..writeByte(2)
      ..write(obj.counting);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhaseSoundsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
