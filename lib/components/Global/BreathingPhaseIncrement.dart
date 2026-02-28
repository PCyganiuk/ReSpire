import 'package:hive_flutter/hive_flutter.dart';

part 'BreathingPhaseIncrement.g.dart';

@HiveType(typeId: 5)
enum BreathingPhaseIncrementType {
  @HiveField(0)
  percentage,

  @HiveField(1)
  value
}

@HiveType(typeId: 6)

///In order to edit breathing phase incrementation, simply replace the old object with a new one
class BreathingPhaseIncrement {
  @HiveField(0)
  final double value;

  @HiveField(1)
  final BreathingPhaseIncrementType type;

  const BreathingPhaseIncrement({required this.value, required this.type})
      : assert(value >= 0,
            "Invalid BreathingPhaseIncrement: value must be non-negative.");
}
