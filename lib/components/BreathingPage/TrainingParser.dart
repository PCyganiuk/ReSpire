import 'dart:developer';

import 'package:respire/components/Global/TrainingStage.dart';
import 'package:respire/components/Global/BreathingPhase.dart'
as breathing_phase;
import 'package:respire/components/Global/Training.dart';

class TrainingParser {
  int trainingStageID = 0;
  int breathingPhaseID = -1;
  int doneReps = 0;
  int doneStageReps = 0; // Added tracker for Stage Reps

  Training training;
  TrainingStage currentTrainingStage;
  late breathing_phase.BreathingPhase currentBreathingPhase;

  TrainingParser({required this.training})
      : currentTrainingStage = training.trainingStages[0];

  Map<String, dynamic>? nextInstruction() {
    if (breathingPhaseID == currentTrainingStage.breathingPhases.length - 1) {
      breathingPhaseID = 0;
      doneReps++;

      if (doneReps == currentTrainingStage.reps) {
        doneStageReps++; // Completed a full cycle of phase reps

        if (doneStageReps == currentTrainingStage.stageReps) {
          // Completed all stage reps, move to next stage
          trainingStageID++;
          if (trainingStageID == training.trainingStages.length) {
            return null;
          } else {
            currentTrainingStage = training.trainingStages[trainingStageID];
            doneReps = 0;
            doneStageReps = 0;
          }
        } else {
          // Repeat the stage. Reset doneReps so increments start from 0 again.
          doneReps = 0;
        }
      }
    } else {
      breathingPhaseID++;
    }

    currentBreathingPhase =
    currentTrainingStage.breathingPhases[breathingPhaseID];

    double durationSeconds = currentBreathingPhase.duration;
    // doneReps resets to 0 on every new stageRep, so the increment calculation resets perfectly!
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
      "doneStageReps": doneStageReps,
    };
  }

  int countBreathingPhases() {
    int result = 0;
    for (int i = 0; i < training.trainingStages.length; i++) {
      result += (training.trainingStages[i].breathingPhases.length *
          training.trainingStages[i].reps *
          training.trainingStages[i].stageReps); // Include stageReps
    }
    return result;
  }

  double calculateTotalDuration({double breathingPhaseDelaySeconds = 0.6}) {
    double totalSeconds = training.settings.preparationDuration.toDouble();

    int totalBreathingPhases = 0;

    for (int stageIdx = 0;
    stageIdx < training.trainingStages.length;
    stageIdx++) {
      final stage = training.trainingStages[stageIdx];

      for (int sr = 0; sr < stage.stageReps; sr++) { // Stage Reps Loop
        for (int rep = 0; rep < stage.reps; rep++) {
          for (int phaseIdx = 0;
          phaseIdx < stage.breathingPhases.length;
          phaseIdx++) {
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

  double calculateTrainingDurationWithoutPreparation(
      {double breathingPhaseDelaySeconds = 0.6}) {
    // Calculate only the breathing phases duration (without preparation)
    double totalSeconds = 0.0;

    int totalBreathingPhases = 0;

    for (int stageIdx = 0;
    stageIdx < training.trainingStages.length;
    stageIdx++) {
      final stage = training.trainingStages[stageIdx];

      for (int sr = 0; sr < stage.stageReps; sr++) { // Stage Reps Loop
        for (int rep = 0; rep < stage.reps; rep++) {
          for (int phaseIdx = 0;
          phaseIdx < stage.breathingPhases.length;
          phaseIdx++) {
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