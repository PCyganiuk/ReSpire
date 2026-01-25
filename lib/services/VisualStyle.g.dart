// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'VisualStyle.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VisualStyleAdapter extends TypeAdapter<VisualStyle> {
  @override
  final int typeId = 13;

  @override
  VisualStyle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VisualStyle(
      name: fields[0] as String,
      isSelected: fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, VisualStyle obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.isSelected);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisualStyleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
