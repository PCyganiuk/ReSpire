import 'package:hive_flutter/hive_flutter.dart';
import 'package:respire/components/Global/Step.dart';
import 'package:uuid/uuid.dart';

part 'Phase.g.dart';

@HiveType(typeId: 2)
class Phase {

  @HiveField(0)
  String id = Uuid().v4();
  
  @HiveField(1)
  String name;

  @HiveField(2)
  int reps;

  @HiveField(3)
  int increment;
  
  @HiveField(4)
  List<Step> steps;

  @HiveField(5)
  String? phaseBackgroundSound;

  Phase({
    required this.reps,
    required this.increment,
    required this.steps,
    this.name = '',
  });

  void addStep(Step step)
  {
    steps.add(step);
  }

  void propabateBackgroundSound(String? globalBackgroundSound) {
    // Replace the phase background sound with the global one if it exists
    if (globalBackgroundSound != null) {
      phaseBackgroundSound = globalBackgroundSound;
    }

    // Set the background sound for each step in the phase
    for (var step in steps) {
      step.sounds.background = phaseBackgroundSound;
    }
  }
}