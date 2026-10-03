
import 'dart:collection';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:respire/components/Global/BreathingPhase.dart';
import 'package:respire/services/TrainingController.dart';
import 'package:respire/components/Global/TrainingStage.dart';

class BreathingWaveTimeline extends StatefulWidget {
  final TrainingController controller;
  final double preparationDuration;
  final double endingDuration;

  const BreathingWaveTimeline({
    super.key,
    required this.controller,
    this.preparationDuration = 0.0,
    this.endingDuration = 0.0,
  });

  @override
  State<BreathingWaveTimeline> createState() =>
      _BreathingWaveTimelineState();
}

class _BreathingWaveTimelineState extends State<BreathingWaveTimeline>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        return ValueListenableBuilder<int>(
          valueListenable: widget.controller.trainingElapsedMs,
          builder: (_, elapsedMs, __) {
            return CustomPaint(
              size: Size.infinite,
              painter: _BreathingWavePainter(
                controller: widget.controller,
                elapsedMs: elapsedMs,
                pulse: _pulse.value,
                preparationDurationSecs:
                widget.preparationDuration,
                endingDuration:
                widget.endingDuration,
              ),
            );
          },
        );
      },
    );
  }
}

class _BreathingWavePainter extends CustomPainter {
  final TrainingController controller;
  final int elapsedMs;
  final double pulse;
  final double preparationDurationSecs;
  final double endingDuration;

  _BreathingWavePainter({
    required this.controller,
    required this.elapsedMs,
    required this.pulse,
    this.preparationDurationSecs = 0.0,
    this.endingDuration = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final training = controller.parser.training;

    final List<double> phaseIncrements = [];

    /// ----------------------------------------------------
    /// BUILD FULL PHASE LIST
    /// ----------------------------------------------------

    final phases = <BreathingPhase>[];

    /*
     * Preparation is represented as a recovery phase.
     */
    if (preparationDurationSecs > 0) {
      phases.add(
        BreathingPhase(
          duration: preparationDurationSecs,
          breathingPhaseType:
          BreathingPhaseType.recovery,
        ),
      );

      phaseIncrements.add(0.0);
    }

    /*
     * ----------------------------------------------------
     * BUILD TRAINING PHASES
     * ----------------------------------------------------
     *
     * Same semantics as TrainingParser:
     *
     * groupId == 0:
     *     ungrouped stage
     *     -> executed once
     *
     * groupId != 0:
     *     grouped stages
     *     -> entire group repeated stageReps times
     *
     * stage.reps:
     *     repetitions inside the stage
     *
     * phase.increment:
     *     applied according to the stage repetition
     */

    int stageIndex = 0;

    while (stageIndex < training.trainingStages.length) {
      final stage =
      training.trainingStages[stageIndex];

      /*
       * --------------------------------------------------
       * UNGROUPED STAGE
       * --------------------------------------------------
       *
       * groupId == 0 means this stage is independent.
       *
       * Its stageReps value is completely ignored.
       */
      if (stage.groupId == 0) {
        _addStagePhases(
          stage: stage,
          phases: phases,
          phaseIncrements: phaseIncrements,
          repetitions: 1,
        );

        stageIndex++;
        continue;
      }

      /*
       * --------------------------------------------------
       * GROUPED STAGES
       * --------------------------------------------------
       *
       * Find all consecutive stages belonging to the
       * current group.
       */
      final groupId = stage.groupId;
      final groupStages = <TrainingStage>[];

      while (stageIndex <
          training.trainingStages.length) {
        final currentStage =
        training.trainingStages[stageIndex];

        if (currentStage.groupId != groupId) {
          break;
        }

        groupStages.add(currentStage);
        stageIndex++;
      }

      /*
       * The number of repetitions of the whole group is
       * defined by stageReps.
       *
       * All stages in the group should have the same value,
       * as enforced by the training editor/model.
       */
      final groupReps = stage.stageReps;

      if (groupReps <= 0) {
        continue;
      }

      /*
       * Repeat the complete group.
       */
      for (int groupRep = 0;
      groupRep < groupReps;
      groupRep++) {
        for (final groupStage in groupStages) {
          _addStagePhases(
            stage: groupStage,
            phases: phases,
            phaseIncrements: phaseIncrements,
            repetitions: 1,
          );
        }
      }
    }

    /*
     * Ending phase.
     */
    if (endingDuration > 0) {
      phases.add(
        BreathingPhase(
          duration: endingDuration,
          breathingPhaseType:
          BreathingPhaseType.recovery,
        ),
      );

      phaseIncrements.add(0.0);
    }

    if (phases.isEmpty) {
      return;
    }

    /// ----------------------------------------------------
    /// PHASE WIDTH
    /// ----------------------------------------------------

    final minPhaseSec =
    getMinNonZeroPhase(phases)
        .clamp(0.3, double.infinity);

    const minPhasePx = 40.0;

    final pxPerSecond =
        minPhasePx / minPhaseSec;

    /// ----------------------------------------------------
    /// BUILD TIME ENVELOPE
    /// ----------------------------------------------------

    final keys = <_KeyPoint>[];

    int accMs = 0;

    bool prevWasInhale = false;

    for (int j = 0; j < phases.length; j++) {
      final phase = phases[j];

      final bool nextIsInhale =
          j + 1 < phases.length &&
              phases[j + 1].breathingPhaseType ==
                  BreathingPhaseType.inhale;

      final durMs =
      ((phase.duration +
          phaseIncrements[j]) *
          1000)
          .toInt();

      final (from, to) =
      _phaseEnvelope(
        phase,
        nextIsInhale,
        prevWasInhale,
      );

      prevWasInhale =
          j != 0 &&
              phase.breathingPhaseType ==
                  BreathingPhaseType.inhale;

      keys.add(
        _KeyPoint(
          accMs,
          from,
        ),
      );

      accMs += durMs;

      /*
       * Special inhale transition.
       */
      if (to == 0.5) {
        accMs -= 500;

        keys.add(
          _KeyPoint(
            accMs,
            to,
          ),
        );

        keys.add(
          _KeyPoint(
            accMs,
            0.5,
          ),
        );

        accMs += 500;

        keys.add(
          _KeyPoint(
            accMs,
            0.5,
          ),
        );
      } else {
        keys.add(
          _KeyPoint(
            accMs,
            to,
          ),
        );
      }
    }

    final totalMs = accMs;

    final clampedElapsed =
    elapsedMs.clamp(0, totalMs);

    /// ----------------------------------------------------
    /// GEOMETRY
    /// ----------------------------------------------------

    final centerX =
        size.width / 2;

    final centerY =
        size.height / 2;

    final waveHeight =
        size.height * 0.45;

    /// ----------------------------------------------------
    /// SCROLL OFFSET
    /// ----------------------------------------------------

    final scrollX =
        (clampedElapsed / 1000.0) *
            pxPerSecond;

    /// ----------------------------------------------------
    /// PAINT
    /// ----------------------------------------------------

    final paint = Paint()
      ..color = const Color(0xFF2CADC4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    bool started = false;

    const stepMs = 30;

    for (int t = 0;
    t <= totalMs;
    t += stepMs) {
      final timeSec =
          t / 1000.0;

      final x =
          centerX +
              timeSec * pxPerSecond -
              scrollX;

      if (x < -100 ||
          x > size.width + 100) {
        continue;
      }

      final value =
      _interpolate(keys, t);

      final y =
          centerY -
              (value - 0.5) *
                  waveHeight;

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    /// ----------------------------------------------------
    /// DOT POSITION
    /// ----------------------------------------------------

    final dotValue =
    _interpolate(
      keys,
      clampedElapsed,
    );

    final dotY =
        centerY -
            (dotValue - 0.5) *
                waveHeight;

    canvas.drawPath(
      path,
      paint,
    );

    /// ----------------------------------------------------
    /// DOT
    /// ----------------------------------------------------

    const dotRadius = 20.0;

    final dotCenter =
    Offset(
      centerX,
      dotY,
    );

    canvas.drawCircle(
      dotCenter,
      dotRadius,
      Paint()
        ..color =
        const Color(0xFF2496A8),
    );

    /// ----------------------------------------------------
    /// CURRENT PHASE REMAINING TIME
    /// ----------------------------------------------------

    int remainingPhaseMs = 0;

    for (int i = 1;
    i < keys.length;
    i += 2) {
      final start =
          keys[i - 1].time;

      final end =
          keys[i].time;

      if (clampedElapsed >= start &&
          clampedElapsed < end) {
        remainingPhaseMs =
            end - clampedElapsed;
        break;
      }
    }

    final remainingSeconds =
        remainingPhaseMs / 1000;

    final textPainter =
    TextPainter(
      text: TextSpan(
        text:
        remainingSeconds
            .toStringAsFixed(1),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign:
      TextAlign.center,
      textDirection:
      TextDirection.ltr,
    );

    textPainter.layout();

    final textOffset =
        dotCenter -
            Offset(
              textPainter.width / 2,
              textPainter.height / 2,
            );

    textPainter.paint(
      canvas,
      textOffset,
    );
  }

  /*
   * Adds one stage's phases to the timeline.
   *
   * `repetitions` is the number of times the stage itself
   * should be executed.
   *
   * In normal use this is 1 because group repetition is
   * handled outside this function.
   */
  void _addStagePhases({
    required TrainingStage stage,
    required List<BreathingPhase> phases,
    required List<double> phaseIncrements,
    required int repetitions,
  }) {
    if (stage.reps <= 0 ||
        stage.breathingPhases.isEmpty ||
        repetitions <= 0) {
      return;
    }

    /*
     * Repeat the stage itself.
     */
    for (int execution = 0;
    execution < repetitions;
    execution++) {
      /*
       * stage.reps controls repetitions INSIDE the stage.
       */
      for (int rep = 0;
      rep < stage.reps;
      rep++) {
        for (final phase
        in stage.breathingPhases) {
          phases.add(phase);

          /*
           * Increment is based on the repetition
           * inside the stage.
           */
          if (phase.increment != null) {
            phaseIncrements.add(
              rep *
                  phase.increment!.value,
            );
          } else {
            phaseIncrements.add(0.0);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(
      covariant _BreathingWavePainter old,
      ) =>
      old.elapsedMs != elapsedMs ||
          old.pulse != pulse ||
          old.preparationDurationSecs !=
              preparationDurationSecs ||
          old.endingDuration != endingDuration;
}

/// --------------------------------------------------------
/// HELPERS
/// --------------------------------------------------------

(double, double) _phaseEnvelope(
    BreathingPhase phase,
    bool nextIsInhale,
    bool prevWasInhale,
    ) {
  switch (phase.breathingPhaseType) {
    case BreathingPhaseType.inhale:
      if (nextIsInhale) {
        return (0.0, 0.5);
      } else if (prevWasInhale) {
        return (0.5, 1.0);
      }

      return (0.0, 1.0);

    case BreathingPhaseType.retention:
      return (1.0, 1.0);

    case BreathingPhaseType.exhale:
      return (1.0, 0.0);

    case BreathingPhaseType.recovery:
      return (0.0, 0.0);
  }
}

double _interpolate(
    List<_KeyPoint> keys,
    int t,
    ) {
  if (t <= keys.first.time) {
    return keys.first.value;
  }

  if (t >= keys.last.time) {
    return keys.last.value;
  }

  for (int i = 1;
  i < keys.length;
  i++) {
    final a = keys[i - 1];
    final b = keys[i];

    if (t >= a.time &&
        t <= b.time) {
      final f =
          (t - a.time) /
              (b.time - a.time);

      return lerpDouble(
        a.value,
        b.value,
        f,
      )!;
    }
  }

  return 0.5;
}

double getMinNonZeroPhase(
    List<BreathingPhase> phases,
    ) {
  double min = double.infinity;

  for (final p in phases) {
    final d = p.duration;

    if (d > 0 && d < min) {
      min = d;
    }
  }

  return min == double.infinity
      ? 0.3
      : min;
}

class _KeyPoint {
  final int time;
  final double value;

  _KeyPoint(
      this.time,
      this.value,
      );
}