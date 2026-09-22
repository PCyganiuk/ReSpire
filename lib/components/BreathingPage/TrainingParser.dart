import 'dart:developer';

import 'package:respire/components/Global/TrainingStage.dart';
import 'package:respire/components/Global/BreathingPhase.dart'
as breathing_phase;
import 'package:respire/components/Global/Training.dart';

class TrainingParser {
  int trainingStageID = 0;
  int breathingPhaseID = -1;

  // Repetition of the current stage.
  int doneReps = 0;

  // Repetition of the current group.
  int doneGroupReps = 0;

  late List<int> stagesDoneReps;

  late TrainingStage currentTrainingStage;
  late breathing_phase.BreathingPhase currentBreathingPhase;

  TrainingParser({required this.training}) {
    stagesDoneReps =
        List.filled(training.trainingStages.length, 0);

    if (training.trainingStages.isEmpty) {
      trainingStageID = -1;
      return;
    }

    // Find first stage belonging to a group that actually runs.
    for (int i = 0; i < training.trainingStages.length; i++) {
      if (training.trainingStages[i].stageReps > 0) {
        trainingStageID = i;
        currentTrainingStage =
        training.trainingStages[i];
        break;
      }
    }

    if (trainingStageID == 0 &&
        training.trainingStages[0].stageReps == 0) {
      trainingStageID = -1;
    }
  }

  final Training training;

  Map<String, dynamic>? nextInstruction() {
    if (trainingStageID == -1) {
      return null;
    }

    currentTrainingStage =
    training.trainingStages[trainingStageID];

    /*
     * Move to the next breathing phase.
     */
    if (breathingPhaseID <
        currentTrainingStage.breathingPhases.length - 1) {
      breathingPhaseID++;
    } else {
      /*
       * We finished the current breathing cycle.
       */
      breathingPhaseID = 0;
      doneReps++;

      /*
       * We still have repetitions of the current stage.
       */
      if (doneReps < currentTrainingStage.reps) {
        return _buildInstruction();
      }

      /*
       * Current stage is finished.
       */
      doneReps = 0;

      stagesDoneReps[trainingStageID]++;

      /*
       * Check whether another stage belongs to
       * the current group.
       */
      final nextStageID = trainingStageID + 1;

      if (nextStageID < training.trainingStages.length &&
          training.trainingStages[nextStageID].groupId ==
              currentTrainingStage.groupId) {
        /*
         * Continue with the next stage in this group.
         */
        trainingStageID = nextStageID;
        currentTrainingStage =
        training.trainingStages[trainingStageID];

        return _buildInstruction();
      }

      /*
       * We reached the end of the current group.
       */
      doneGroupReps++;

      /*
       * Repeat the whole group.
       */
      if (doneGroupReps < currentTrainingStage.stageReps) {
        final firstStageID =
        _findFirstStageOfGroup(
          currentTrainingStage.groupId,
        );

        trainingStageID = firstStageID;

        currentTrainingStage =
        training.trainingStages[trainingStageID];

        return _buildInstruction();
      }

      /*
       * The group is completely finished.
       *
       * Find the first stage of the next group.
       */
      doneGroupReps = 0;

      final nextGroupStageID =
      _findFirstStageOfNextGroup(
        currentTrainingStage.groupId,
      );

      if (nextGroupStageID == -1) {
        /*
         * No more groups.
         */
        trainingStageID = -1;
        return null;
      }

      trainingStageID = nextGroupStageID;

      currentTrainingStage =
      training.trainingStages[trainingStageID];

      return _buildInstruction();
    }

    return _buildInstruction();
  }

  int _findFirstStageOfGroup(int groupId) {
    for (int i = 0;
    i < training.trainingStages.length;
    i++) {
      if (training.trainingStages[i].groupId == groupId) {
        return i;
      }
    }

    return -1;
  }

  int _findFirstStageOfNextGroup(int currentGroupId) {
    bool foundCurrentGroup = false;

    for (int i = 0;
    i < training.trainingStages.length;
    i++) {
      final stage =
      training.trainingStages[i];

      if (stage.groupId == currentGroupId) {
        foundCurrentGroup = true;
        continue;
      }

      if (foundCurrentGroup) {
        return i;
      }
    }

    return -1;
  }

  Map<String, dynamic> _buildInstruction() {
    currentBreathingPhase =
    currentTrainingStage
        .breathingPhases[breathingPhaseID];

    double durationSeconds =
        currentBreathingPhase.duration;

    /*
     * Increment applies to repetitions INSIDE
     * the current stage.
     */
    if (currentBreathingPhase.increment != null &&
        doneReps > 0) {
      final increment =
      currentBreathingPhase.increment!;

      durationSeconds =
          currentBreathingPhase.duration +
              (doneReps * increment.value);
    }

    final progressedBreathingPhase =
    breathing_phase.BreathingPhase(
      duration: durationSeconds,
      breathingPhaseType:
      currentBreathingPhase.breathingPhaseType,
      sounds: currentBreathingPhase.sounds,
    );

    log(
      'preBreathingPhase: '
          '${progressedBreathingPhase.sounds.preBreathingPhase}, '
          'background: '
          '${progressedBreathingPhase.sounds.background}',
    );

    return {
      "breathingPhase": progressedBreathingPhase,
      "remainingTime":
      (durationSeconds * 1000).truncate(),
      "trainingStageName":
      currentTrainingStage.name,
      "doneReps": doneReps,
      "doneStageReps": doneGroupReps,
    };
  }

  int countBreathingPhases() {
    int result = 0;

    final groups = <int, List<TrainingStage>>{};

    for (final stage in training.trainingStages) {
      groups
          .putIfAbsent(stage.groupId, () => [])
          .add(stage);
    }

    for (final group in groups.values) {
      if (group.isEmpty) continue;

      final groupReps = group.first.stageReps;

      for (final stage in group) {
        result +=
            stage.breathingPhases.length *
                stage.reps *
                groupReps;
      }
    }

    return result;
  }

  double calculateTotalDuration({
    double breathingPhaseDelaySeconds = 0.6,
  }) {
    double totalSeconds =
    training.settings.preparationDuration.toDouble();

    int totalBreathingPhases = 0;

    final groups = <int, List<TrainingStage>>{};

    for (final stage in training.trainingStages) {
      groups
          .putIfAbsent(stage.groupId, () => [])
          .add(stage);
    }

    for (final group in groups.values) {
      if (group.isEmpty) continue;

      final groupReps = group.first.stageReps;

      for (final stage in group) {
        for (int rep = 0;
        rep < stage.reps;
        rep++) {
          for (final phase in stage.breathingPhases) {
            double phaseDuration =
                phase.duration;

            if (phase.increment != null &&
                rep > 0) {
              final increment =
              phase.increment!;

              phaseDuration =
                  phase.duration +
                      (rep * increment.value);
            }

            totalSeconds +=
                phaseDuration * groupReps;

            totalBreathingPhases +=
                groupReps;
          }
        }
      }
    }

    totalSeconds +=
        totalBreathingPhases *
            breathingPhaseDelaySeconds;

    return totalSeconds;
  }

  double calculateTrainingDurationWithoutPreparation({
    double breathingPhaseDelaySeconds = 0.6,
  }) {
    double totalSeconds = 0.0;

    int totalBreathingPhases = 0;

    final groups = <int, List<TrainingStage>>{};

    for (final stage in training.trainingStages) {
      groups
          .putIfAbsent(stage.groupId, () => [])
          .add(stage);
    }

    for (final group in groups.values) {
      if (group.isEmpty) continue;

      final groupReps = group.first.stageReps;

      for (final stage in group) {
        for (int rep = 0;
        rep < stage.reps;
        rep++) {
          for (final phase in stage.breathingPhases) {
            double phaseDuration =
                phase.duration;

            if (phase.increment != null &&
                rep > 0) {
              final increment =
              phase.increment!;

              phaseDuration =
                  phase.duration +
                      (rep * increment.value);
            }

            totalSeconds +=
                phaseDuration * groupReps;

            totalBreathingPhases +=
                groupReps;
          }
        }
      }
    }

    totalSeconds +=
        totalBreathingPhases *
            breathingPhaseDelaySeconds;

    return totalSeconds;
  }
}