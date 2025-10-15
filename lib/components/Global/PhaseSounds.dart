import 'package:hive_flutter/hive_flutter.dart';

part 'PhaseSounds.g.dart';

@HiveType(typeId: 11)
class BreathingPhaseSounds {
  
  @HiveField(0)
  String? preBreathingPhase;

  @HiveField(1)
  String? background;

  BreathingPhaseSounds({
    this.preBreathingPhase,
    this.background
  });
}