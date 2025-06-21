// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Phase.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhaseAdapter extends TypeAdapter<Phase> {
  @override
  final int typeId = 2;

  @override
  Phase read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    // Support old format (3 fields: reps, doneRepsCounter, steps)
    final int reps = fields[0] as int;
    final int doneCount = fields[1] as int;
    int increment;
    List<Step> steps;
    if (numOfFields == 3) {
      // old data without increment field
      increment = 0;
      steps = (fields[2] as List).cast<Step>();
    } else {
      increment = fields[2] as int;
      steps = (fields[3] as List).cast<Step>();
    }
    return Phase(reps: reps, increment: increment, steps: steps)
      ..doneRepsCounter = doneCount;
  }

  @override
  void write(BinaryWriter writer, Phase obj) {
    writer
      ..writeByte(4) // number of fields
      ..writeByte(0)
      ..write(obj.reps)
      ..writeByte(1)
      ..write(obj.doneRepsCounter)
      ..writeByte(2)
      ..write(obj.increment)
      ..writeByte(3)
      ..write(obj.steps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhaseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
