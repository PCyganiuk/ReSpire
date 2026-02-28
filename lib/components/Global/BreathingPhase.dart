import 'package:hive_flutter/hive_flutter.dart';
import 'package:respire/components/Global/BreathingPhaseSounds.dart';
import 'package:respire/components/Global/BreathingPhaseIncrement.dart';

part 'BreathingPhase.g.dart';

@HiveType(typeId: 3)
enum BreathingPhaseType {
  @HiveField(0)
  inhale,

  @HiveField(1)
  exhale,

  @HiveField(2)
  retention,

  @HiveField(3)
  recovery
}

@HiveType(typeId: 4)
class BreathingPhase {
  @HiveField(0)
  final double duration; // in seconds

  @HiveField(1)
  BreathingPhaseIncrement? increment;

  @HiveField(2)
  BreathingPhaseType breathingPhaseType;

  @HiveField(3)
  BreathingPhaseSounds sounds = BreathingPhaseSounds();

  BreathingPhase({
    required this.duration,
    this.increment,
    this.breathingPhaseType = BreathingPhaseType.inhale,
    BreathingPhaseSounds? sounds,
  }) {
    this.sounds = sounds ?? BreathingPhaseSounds();
  }
}