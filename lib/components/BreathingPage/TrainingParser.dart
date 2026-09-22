
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
  // For ungrouped stages this is always 0.
  int doneGroupReps = 0;

  int currentStageExecutionIndex = 1;
  int? _lastStageID;
  int _lastGroupRep = 0;

  late List<int> stagesDoneReps;

  late TrainingStage currentTrainingStage;
  late breathing_phase.BreathingPhase currentBreathingPhase;

  final Training training;

  TrainingParser({required this.training}) {
    stagesDoneReps =
        List.filled(training.trainingStages.length, 0);

    if (training.trainingStages.isEmpty) {
      trainingStageID = -1;
      return;
    }

    /*
     * Find the first stage that actually runs.
     *
     * groupId == 0 means an ungrouped stage.
     * For grouped stages, stageReps determines whether
     * the group actually runs.
     */
    for (int i = 0; i < training.trainingStages.length; i++) {
      final stage = training.trainingStages[i];

      final repetitions = _getGroupRepetitions(stage);

      if (repetitions > 0 && stage.reps > 0) {
        trainingStageID = i;
        currentTrainingStage = stage;
        break;
      }
    }

    /*
     * No runnable stages were found.
     */
    if (trainingStageID == 0 &&
        (_getGroupRepetitions(training.trainingStages[0]) <= 0 ||
            training.trainingStages[0].reps <= 0)) {
      trainingStageID = -1;
    }
  }

  /*
   * groupId == 0 means that the stage is not grouped.
   */
  bool _isGrouped(TrainingStage stage) {
    return stage.groupId != 0;
  }

  /*
   * Returns how many times the current stage/group should run.
   *
   * Grouped stage:
   *   stageReps controls repetitions of the entire group.
   *
   * Ungrouped stage:
   *   the stage itself is its own group and runs exactly once.
   */
  int _getGroupRepetitions(TrainingStage stage) {
    if (!_isGrouped(stage)) {
      return 1;
    }

    return stage.stageReps;
  }

  /*
   * Returns the first stage of the group.
   *
   * This is only used for grouped stages.
   */
  int _findFirstStageOfGroup(int groupId) {
    if (groupId == 0) {
      return -1;
    }

    for (int i = 0;
    i < training.trainingStages.length;
    i++) {
      if (training.trainingStages[i].groupId == groupId) {
        return i;
      }
    }

    return -1;
  }

  /*
   * Returns the first stage belonging to the next group.
   *
   * The search starts after the current group and skips
   * all stages belonging to the current group.
   *
   * For an ungrouped stage (groupId == 0), the next stage
   * is simply the next stage in the training.
   */
  int _findFirstStageAfterCurrent(int currentStageID) {
    if (currentStageID < 0 ||
        currentStageID >= training.trainingStages.length) {
      return -1;
    }

    final currentStage =
    training.trainingStages[currentStageID];

    /*
     * Ungrouped stage:
     * simply continue with the next stage.
     */
    if (!_isGrouped(currentStage)) {
      final nextID = currentStageID + 1;

      if (nextID >= training.trainingStages.length) {
        return -1;
      }

      return nextID;
    }

    /*
     * Grouped stage:
     * skip all remaining stages belonging to this group.
     */
    final currentGroupId = currentStage.groupId;

    for (int i = currentStageID + 1;
    i < training.trainingStages.length;
    i++) {
      if (training.trainingStages[i].groupId != currentGroupId) {
        return i;
      }
    }

    return -1;
  }

  /*
   * Move to the next breathing instruction.
   */
  Map<String, dynamic>? nextInstruction() {
    if (trainingStageID == -1) {
      return null;
    }

    currentTrainingStage =
    training.trainingStages[trainingStageID];

    /*
     * ----------------------------------------------------
     * MOVE TO NEXT BREATHING PHASE
     * ----------------------------------------------------
     */
    if (breathingPhaseID <
        currentTrainingStage.breathingPhases.length - 1) {
      breathingPhaseID++;

      return _buildInstruction();
    }

    /*
     * ----------------------------------------------------
     * CURRENT STAGE REPETITION FINISHED
     * ----------------------------------------------------
     */

    breathingPhaseID = 0;
    doneReps++;

    /*
     * The current stage still has repetitions left.
     */
    if (doneReps < currentTrainingStage.reps) {
      return _buildInstruction();
    }

    /*
     * ----------------------------------------------------
     * CURRENT STAGE COMPLETELY FINISHED
     * ----------------------------------------------------
     */

    doneReps = 0;
    stagesDoneReps[trainingStageID]++;

    /*
     * ----------------------------------------------------
     * UNGROUPED STAGE
     * ----------------------------------------------------
     *
     * groupId == 0 means that this stage runs exactly once.
     *
     * stage.reps has already controlled repetitions inside
     * this stage, so we simply move to the next stage.
     */
    if (!_isGrouped(currentTrainingStage)) {
      doneGroupReps = 0;

      final nextStageID =
      _findFirstStageAfterCurrent(trainingStageID);

      if (nextStageID == -1) {
        trainingStageID = -1;
        return null;
      }

      trainingStageID = nextStageID;
      currentTrainingStage =
      training.trainingStages[trainingStageID];

      return _buildInstruction();
    }

    /*
     * ----------------------------------------------------
     * GROUPED STAGE
     * ----------------------------------------------------
     *
     * Check whether another stage belongs to the same group.
     */
    final nextStageID =
        trainingStageID + 1;

    if (nextStageID < training.trainingStages.length &&
        training.trainingStages[nextStageID].groupId ==
            currentTrainingStage.groupId) {
      /*
       * Continue with the next stage of this group.
       */
      trainingStageID = nextStageID;

      currentTrainingStage =
      training.trainingStages[trainingStageID];

      return _buildInstruction();
    }

    /*
     * ----------------------------------------------------
     * END OF GROUP
     * ----------------------------------------------------
     */

    doneGroupReps++;

    final groupRepetitions =
    _getGroupRepetitions(currentTrainingStage);

    /*
     * Repeat the entire group.
     */
    if (doneGroupReps < groupRepetitions) {
      final firstStageID =
      _findFirstStageOfGroup(
        currentTrainingStage.groupId,
      );

      if (firstStageID == -1) {
        trainingStageID = -1;
        return null;
      }

      trainingStageID = firstStageID;

      currentTrainingStage =
      training.trainingStages[trainingStageID];

      return _buildInstruction();
    }

    /*
     * ----------------------------------------------------
     * GROUP COMPLETELY FINISHED
     * ----------------------------------------------------
     */

    doneGroupReps = 0;

    final nextGroupStageID =
    _findFirstStageAfterCurrent(trainingStageID);

    if (nextGroupStageID == -1) {
      trainingStageID = -1;
      return null;
    }

    trainingStageID = nextGroupStageID;

    currentTrainingStage =
    training.trainingStages[trainingStageID];

    return _buildInstruction();
  }

  /*
   * Builds the current breathing instruction.
   *
   * Increment applies to repetitions INSIDE the current
   * stage, not repetitions of the group.
   */
  Map<String, dynamic> _buildInstruction() {
    currentBreathingPhase =
    currentTrainingStage
        .breathingPhases[breathingPhaseID];

    if (_lastStageID != null) {
      if (_lastStageID != trainingStageID || _lastGroupRep != doneGroupReps) {
        currentStageExecutionIndex++;
      }
    }
    _lastStageID = trainingStageID;
    _lastGroupRep = doneGroupReps;

    double durationSeconds =
        currentBreathingPhase.duration;

    /*
     * Increment applies to the current stage repetition.
     *
     * Example:
     *
     * duration = 2.0
     * increment = +0.5
     *
     * rep 0 -> 2.0
     * rep 1 -> 2.5
     * rep 2 -> 3.0
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
      "stageExecutionIndex": currentStageExecutionIndex,
    };
  }

  int countTotalStages() {
    int result = 0;
    int i = 0;

    while (i < training.trainingStages.length) {
      final stage = training.trainingStages[i];
      final groupReps = _getGroupRepetitions(stage);

      if (groupReps <= 0 || stage.reps <= 0) {
        i++;
        if (_isGrouped(stage)) {
          final groupId = stage.groupId;
          while (i < training.trainingStages.length &&
              training.trainingStages[i].groupId == groupId) {
            i++;
          }
        }
        continue;
      }

      if (!_isGrouped(stage)) {
        result += 1;
        i++;
        continue;
      }

      final groupId = stage.groupId;
      int stagesInGroup = 0;

      while (i < training.trainingStages.length &&
          training.trainingStages[i].groupId == groupId) {
        if (training.trainingStages[i].reps > 0) {
          stagesInGroup++;
        }
        i++;
      }

      result += stagesInGroup * groupReps;
    }

    return result;
  }

  /*
   * Counts the total number of breathing phases that
   * will actually be executed.
   *
   * Grouped stage:
   *   phases × stage.reps × group.stageReps
   *
   * Ungrouped stage:
   *   phases × stage.reps
   */
  int countBreathingPhases() {
    int result = 0;

    int i = 0;

    while (i < training.trainingStages.length) {
      final stage =
      training.trainingStages[i];

      /*
       * Skip stages that cannot execute.
       */
      final groupReps =
      _getGroupRepetitions(stage);

      if (groupReps <= 0 || stage.reps <= 0) {
        i++;

        /*
         * If this is a grouped stage, skip the rest
         * of the group as well.
         */
        if (_isGrouped(stage)) {
          final groupId = stage.groupId;

          while (i < training.trainingStages.length &&
              training.trainingStages[i].groupId == groupId) {
            i++;
          }
        }

        continue;
      }

      /*
       * Calculate phases for this stage.
       */
      result +=
          stage.breathingPhases.length *
              stage.reps *
              groupReps;

      /*
       * Ungrouped stage is only this one stage.
       */
      if (!_isGrouped(stage)) {
        i++;
        continue;
      }

      /*
       * Skip remaining stages in the same group.
       */
      final groupId = stage.groupId;

      i++;

      while (i < training.trainingStages.length &&
          training.trainingStages[i].groupId == groupId) {
        final groupedStage =
        training.trainingStages[i];

        result +=
            groupedStage.breathingPhases.length *
                groupedStage.reps *
                groupReps;

        i++;
      }
    }

    return result;
  }

  /*
   * Calculates the complete training duration including
   * preparation.
   */
  double calculateTotalDuration({
    double breathingPhaseDelaySeconds = 0.6,
  }) {
    return training.settings.preparationDuration.toDouble() +
        calculateTrainingDurationWithoutPreparation(
          breathingPhaseDelaySeconds:
          breathingPhaseDelaySeconds,
        );
  }

  /*
   * Calculates training duration without preparation.
   *
   * This uses exactly the same repetition semantics as
   * nextInstruction():
   *
   *   - stage.reps = repetitions inside a stage
   *   - grouped stage.stageReps = repetitions of the group
   *   - ungrouped stage = one group repetition
   *   - phase.increment = increment based on stage rep
   */
  double calculateTrainingDurationWithoutPreparation({
    double breathingPhaseDelaySeconds = 0.6,
  }) {
    double totalSeconds = 0.0;
    int totalBreathingPhases = 0;

    int i = 0;

    while (i < training.trainingStages.length) {
      final stage =
      training.trainingStages[i];

      final groupReps =
      _getGroupRepetitions(stage);

      /*
       * ----------------------------------------------------
       * INVALID / DISABLED STAGE
       * ----------------------------------------------------
       */
      if (groupReps <= 0 || stage.reps <= 0) {
        i++;

        /*
         * Skip the rest of a disabled grouped stage.
         */
        if (_isGrouped(stage)) {
          final groupId = stage.groupId;

          while (i < training.trainingStages.length &&
              training.trainingStages[i].groupId == groupId) {
            i++;
          }
        }

        continue;
      }

      /*
       * ----------------------------------------------------
       * PROCESS CURRENT STAGE
       * ----------------------------------------------------
       */
      for (int rep = 0; rep < stage.reps; rep++) {
        for (final phase in stage.breathingPhases) {
          double phaseDuration =
              phase.duration;

          /*
           * Increment applies to repetitions INSIDE
           * the stage.
           */
          if (phase.increment != null && rep > 0) {
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

      /*
       * ----------------------------------------------------
       * UNGROUPED STAGE
       * ----------------------------------------------------
       *
       * It has already been processed once.
       */
      if (!_isGrouped(stage)) {
        i++;
        continue;
      }

      /*
       * ----------------------------------------------------
       * REMAINING STAGES OF GROUP
       * ----------------------------------------------------
       */

      final groupId = stage.groupId;

      i++;

      while (i < training.trainingStages.length &&
          training.trainingStages[i].groupId == groupId) {
        final groupedStage =
        training.trainingStages[i];

        /*
         * A stage inside a valid group contributes its
         * duration for every repetition of the group.
         */
        for (int rep = 0;
        rep < groupedStage.reps;
        rep++) {
          for (final phase
          in groupedStage.breathingPhases) {
            double phaseDuration =
                phase.duration;

            if (phase.increment != null && rep > 0) {
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

        i++;
      }
    }

    /*
     * Delay occurs between breathing phases.
     */
    totalSeconds +=
        totalBreathingPhases *
            breathingPhaseDelaySeconds;

    return totalSeconds;
  }
}
