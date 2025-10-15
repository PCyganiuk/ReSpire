import 'package:hive_flutter/hive_flutter.dart';
import 'package:respire/components/Global/Step.dart';
import 'package:uuid/uuid.dart';

part 'Phase.g.dart';

@HiveType(typeId: 2)
class TrainingStage {

  @HiveField(0)
  String id = Uuid().v4();
  
  @HiveField(1)
  String name;

  @HiveField(2)
  int reps;

  @HiveField(3)
  int increment;
  
  @HiveField(4)
  List<BreathingPhase> breathingPhases;

  @HiveField(5)
  String? trainingStageBackgroundSound; // Is this correct?

  TrainingStage({
    required this.reps,
    required this.increment,
    required this.breathingPhases,
    this.name = '',
  });

  void addBreathingPhase(BreathingPhase breathingPhase)
  {
    breathingPhases.add(breathingPhase);
  }

  void propagateBackgroundSound(String? globalBackgroundSound) {
    // Replace the breathing phase background sound with the global one if it exists
    if (globalBackgroundSound != null) {
      trainingStageBackgroundSound = globalBackgroundSound;
    }
  
    // Set the background sound for each breathing phase
    for (var breathingPhase in breathingPhases) {
      breathingPhase.sounds.background = trainingStageBackgroundSound;
    }
  }
}