import 'package:hive_flutter/hive_flutter.dart';
import 'package:respire/components/Global/SoundAsset.dart';
import 'package:respire/components/Global/BreathingPhase.dart';
import 'package:uuid/uuid.dart';

part 'TrainingStage.g.dart';

@HiveType(typeId: 2)
class TrainingStage {
  
  @HiveField(0)
  String id = Uuid().v4();

  @HiveField(1)
  String name;

  @HiveField(2)
  int reps;

  //@HiveField(3)
  //double increment;
  
  @HiveField(3)
  List<BreathingPhase> breathingPhases;

  @HiveField(4, defaultValue: 1)
  int stageReps;

  @HiveField(5, defaultValue: 0)
  int groupId;

  TrainingStage({
    required this.reps,
    //required this.increment,
    required this.breathingPhases,
    required this.stageReps,
    required this.groupId,
    this.name = '',
  });

  void addBreathingPhase(BreathingPhase breathingPhase)
  {
    breathingPhases.add(breathingPhase);
  }

  void propagateNextSound(SoundAsset nextSound) {
    // Set the next sound for each breathing phase
    for (var breathingPhase in breathingPhases) {
      breathingPhase.sounds.preBreathingPhase = nextSound;
    }
  }

  void propagateBackgroundSound(SoundAsset globalBackgroundSound) {  
    // Set the background sound for each breathing phase
    for (var breathingPhase in breathingPhases) {
      breathingPhase.sounds.background = globalBackgroundSound;
    }
  }

  String getTotalTimeFormatted() {
    double singleStageCycleTime = 0.0;

    for (var phase in breathingPhases) {
      for (int i = 0; i < reps; i++) {
        if (phase.increment != null) {
          singleStageCycleTime += phase.duration + (phase.increment!.value * i);
        } else {
          singleStageCycleTime += phase.duration;
        }
      }
    }

    // Multiply the time of one complete cycle by the number of stageReps
    double totalTime = singleStageCycleTime * stageReps;

    if (totalTime < 60) {
      return "${totalTime.round()} sec";
    }

    int minutes = (totalTime / 60).round();
    return "~$minutes min";
  }
}