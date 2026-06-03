import 'dart:developer';

import 'package:respire/components/Global/TrainingStage.dart';
import 'package:respire/components/Global/BreathingPhase.dart'
as breathing_phase;
import 'package:respire/components/Global/Training.dart';

class TrainingParser {
  int trainingStageID = 0;
  int breathingPhaseID = -1;
  int doneReps = 0;
  late List<int> stagesDoneReps; // Track stage reps for EACH stage

  Training training;
  late TrainingStage currentTrainingStage;
  late breathing_phase.BreathingPhase currentBreathingPhase;

  TrainingParser({required this.training}) {
    stagesDoneReps = List.filled(training.trainingStages.length, 0);

    // Safety check to ensure we start on a valid stage
    for (int i = 0; i < training.trainingStages.length; i++) {
      if (training.trainingStages[i].stageReps > 0) {
        trainingStageID = i;
        break;
      }
    }

    if (training.trainingStages.isEmpty || training.trainingStages[trainingStageID].stageReps == 0) {
      trainingStageID = -1;
    } else {
      currentTrainingStage = training.trainingStages[trainingStageID];
    }
  }

  Map<String, dynamic>? nextInstruction() {
    if (trainingStageID == -1) return null; // Training is finished

    if (breathingPhaseID == currentTrainingStage.breathingPhases.length - 1) {
      breathingPhaseID = 0;
      doneReps++;

      if (doneReps == currentTrainingStage.reps) {
        // We finished one pass of this stage.
        stagesDoneReps[trainingStageID]++;
        doneReps = 0;

        // Move to the next stage in the "Big Loop"
        bool foundNextStage = false;
        int nextID = trainingStageID + 1;

        for (int i = 0; i < training.trainingStages.length; i++) {
          if (nextID >= training.trainingStages.length) {
            nextID = 0; // Wrap around to the start of the stages list!
          }
          if (stagesDoneReps[nextID] < training.trainingStages[nextID].stageReps) {
            trainingStageID = nextID;
            currentTrainingStage = training.trainingStages[trainingStageID];
            foundNextStage = true;
            break;
          }
          nextID++;
        }

        if (!foundNextStage) {
          trainingStageID = -1; // All stages have reached their stageReps limits
          return null;
        }
      }
    } else {
      breathingPhaseID++;
    }

    currentBreathingPhase = currentTrainingStage.breathingPhases[breathingPhaseID];

    double durationSeconds = currentBreathingPhase.duration;
    if (currentBreathingPhase.increment != null && doneReps > 0) {
      final increment = currentBreathingPhase.increment!;
      durationSeconds =
          currentBreathingPhase.duration + (doneReps * increment.value);
    }

    final progressedBreathingPhase = breathing_phase.BreathingPhase(
      duration: durationSeconds,
      breathingPhaseType: currentBreathingPhase.breathingPhaseType,
      sounds: currentBreathingPhase.sounds,
    );

    log('preBreathingPhase: ${progressedBreathingPhase.sounds.preBreathingPhase}, background: ${progressedBreathingPhase.sounds.background}');

    return {
      "breathingPhase": progressedBreathingPhase,
      "remainingTime": (durationSeconds * 1000).truncate(),
      "trainingStageName": currentTrainingStage.name,
      "doneReps": doneReps,
      "doneStageReps": stagesDoneReps[trainingStageID], // Return specific stage's count
    };
  }

  // NOTE: countBreathingPhases() and calculateTotalDuration() math remain EXACTLY the same!
  // Order of addition (A+B+A vs A+A+B) doesn't change the mathematical total, so those functions
  // do not require structural updates and can remain as they are.

  int countBreathingPhases() {
    int result = 0;
    for (int i = 0; i < training.trainingStages.length; i++) {
      result += (training.trainingStages[i].breathingPhases.length *
          training.trainingStages[i].reps *
          training.trainingStages[i].stageReps);
    }
    return result;
  }

  double calculateTotalDuration({double breathingPhaseDelaySeconds = 0.6}) {
    double totalSeconds = training.settings.preparationDuration.toDouble();
    int totalBreathingPhases = 0;

    for (int stageIdx = 0; stageIdx < training.trainingStages.length; stageIdx++) {
      final stage = training.trainingStages[stageIdx];
      for (int sr = 0; sr < stage.stageReps; sr++) {
        for (int rep = 0; rep < stage.reps; rep++) {
          for (int phaseIdx = 0; phaseIdx < stage.breathingPhases.length; phaseIdx++) {
            final phase = stage.breathingPhases[phaseIdx];
            double phaseDuration = phase.duration;
            if (phase.increment != null && rep > 0) {
              final increment = phase.increment!;
              phaseDuration = phase.duration + (rep * increment.value);
            }
            totalSeconds += phaseDuration;
            totalBreathingPhases++;
          }
        }
      }
    }
    totalSeconds += totalBreathingPhases * breathingPhaseDelaySeconds;
    return totalSeconds;
  }

  double calculateTrainingDurationWithoutPreparation({double breathingPhaseDelaySeconds = 0.6}) {
    double totalSeconds = 0.0;
    int totalBreathingPhases = 0;

    for (int stageIdx = 0; stageIdx < training.trainingStages.length; stageIdx++) {
      final stage = training.trainingStages[stageIdx];
      for (int sr = 0; sr < stage.stageReps; sr++) {
        for (int rep = 0; rep < stage.reps; rep++) {
          for (int phaseIdx = 0; phaseIdx < stage.breathingPhases.length; phaseIdx++) {
            final phase = stage.breathingPhases[phaseIdx];
            double phaseDuration = phase.duration;
            if (phase.increment != null && rep > 0) {
              final increment = phase.increment!;
              phaseDuration = phase.duration + (rep * increment.value);
            }
            totalSeconds += phaseDuration;
            totalBreathingPhases++;
          }
        }
      }
    }
    totalSeconds += totalBreathingPhases * breathingPhaseDelaySeconds;
    return totalSeconds;
  }
}