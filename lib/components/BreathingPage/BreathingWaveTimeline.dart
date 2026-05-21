import 'dart:collection';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:respire/components/Global/BreathingPhase.dart';
import 'package:respire/services/TrainingController.dart';

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
                preparationDurationSecs: widget.preparationDuration,
                endingDuration: widget.endingDuration,
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

    List<double> phaseIncrements = [];


    /// ---- BUILD FULL PHASE LIST (with preparation) ----
    final phases = <BreathingPhase>[];
    // Add preparation phase as a recovery phase at the start
    if (preparationDurationSecs > 0) {
      phases.add(
        BreathingPhase(
          duration: preparationDurationSecs,
          breathingPhaseType: BreathingPhaseType.recovery,
        ),
      );
      phaseIncrements.add(0.0);
    }
    
    for (final stage in training.trainingStages) {
      for (int i = 0; i < stage.reps; i++) {
        for (int j = 0; j < stage.breathingPhases.length; j++) {
          if(stage.breathingPhases[j].increment != null) {
            double tmp = i * stage.breathingPhases[j].increment!.value;
            phaseIncrements.add(tmp);
          }
          else {
            phaseIncrements.add(0.0);
          }
        }
        phases.addAll(stage.breathingPhases);
      }
    }

    if (endingDuration > 0) {
      phases.add(
        BreathingPhase(
          duration: endingDuration,
          breathingPhaseType: BreathingPhaseType.recovery,
        ),
      );
      phaseIncrements.add(0.0);
    }

    if (phases.isEmpty) return;

    final minPhaseSec = getMinNonZeroPhase(phases).clamp(0.3, double.infinity);
    const minPhasePx = 40.0;
    final pxPerSecond = minPhasePx / minPhaseSec;
    /// ---- BUILD TIME ENVELOPE ----
    final keys = <_KeyPoint>[];
    int accMs = 0;
    bool prevWasInhale = false;
    for (int j = 0; j < phases.length; j++) {
      final phase = phases[j];
      final bool nextIsInhale = (j + 1 < phases.length) && (phases[j + 1].breathingPhaseType == BreathingPhaseType.inhale);
      final durMs = ((phase.duration + phaseIncrements[j]) * 1000).toInt();
      final (from, to) = _phaseEnvelope(phase, nextIsInhale, prevWasInhale);
      prevWasInhale = (j != 0) && (phase.breathingPhaseType == BreathingPhaseType.inhale);
      keys.add(_KeyPoint(accMs, from));
      accMs += durMs;
      if (to == 0.5){
        accMs -= 500;
        keys.add(_KeyPoint(accMs, to));

        keys.add(_KeyPoint(accMs, 0.5));
        accMs += 500;
        keys.add(_KeyPoint(accMs, 0.5));
      }
      else {
        keys.add(_KeyPoint(accMs, to));
      }
    }

    final totalMs = accMs;
    // Clamp elapsed time to the total timeline (which now includes preparation)
    final clampedElapsed = elapsedMs.clamp(0, totalMs);

    /// ---- GEOMETRY ----
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final waveHeight = size.height * 0.45;
    //final stretch = size.width * 3;

    /// ---- SCROLL OFFSET ----
    final scrollX = (clampedElapsed / 1000.0) * pxPerSecond;

    /// ---- PAINT ----
    final paint = Paint()
      ..color = const Color(0xFF2CADC4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool started = false;

    const stepMs = 30;
    //double dotY = 0;

    for (int t = 0; t <= totalMs; t += stepMs) {
      final timeSec = t / 1000.0;
      final x = centerX + timeSec * pxPerSecond - scrollX;

      if (x < -100 || x > size.width + 100) continue;

      final value = _interpolate(keys, t);
      final y = centerY - (value - 0.5) * waveHeight;

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
      if ((x - centerX).abs() < stepMs) {
        //dotY = y;
      }
    }
    // ---- DOT POSITION (DIRECT, TIME-BASED) ----
    final dotValue = _interpolate(keys, clampedElapsed);
    final dotY = centerY - (dotValue - 0.5) * waveHeight;


    canvas.drawPath(path, paint);

    /// ---- DOT ----
    //final dotRadius = lerpDouble(16, 26, pulse)!;
    final dotRadius = 20.0;
    final dotCenter = Offset(centerX, dotY);

    canvas.drawCircle(
      dotCenter,
      dotRadius,
      Paint()..color = const Color(0xFF2496A8),
    );
    /// ---- CURRENT PHASE REMAINING TIME ----
    int remainingPhaseMs = 0;

    for (int i = 1; i < keys.length; i += 2) {
      final start = keys[i - 1].time;
      final end = keys[i].time;

      if (clampedElapsed >= start && clampedElapsed < end) {
        remainingPhaseMs = end - clampedElapsed;
        break;
      }
    }

    final remainingSeconds = (remainingPhaseMs / 1000);

    final textPainter = TextPainter(
      text: TextSpan(
        text: remainingSeconds.toStringAsFixed(1),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final textOffset = dotCenter -
        Offset(textPainter.width / 2, textPainter.height / 2);

    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _BreathingWavePainter old) =>
      old.elapsedMs != elapsedMs || old.pulse != pulse || old.preparationDurationSecs != preparationDurationSecs;
}

/// ---- HELPERS ----

(double, double) _phaseEnvelope(BreathingPhase phase, bool nextIsInhale, bool prevWasInhale) {

  switch (phase.breathingPhaseType) {
    case BreathingPhaseType.inhale:
      if(nextIsInhale) {
        return (0.0, 0.5);
      }
      else if (prevWasInhale){
        return(0.5, 1.0);
      }
      return (0.0, 1.0); // rise
    case BreathingPhaseType.retention:
      return (1.0, 1.0); // stay high
    case BreathingPhaseType.exhale:
      return (1.0, 0.0); // fall
    case BreathingPhaseType.recovery:
      return (0.0, 0.0); // stay low
  }
}

double _interpolate(List<_KeyPoint> keys, int t) {
  if (t <= keys.first.time) return keys.first.value;
  if (t >= keys.last.time) return keys.last.value;

  for (int i = 1; i < keys.length; i++) {
    final a = keys[i - 1];
    final b = keys[i];
    if (t >= a.time && t <= b.time) {
      final f = (t - a.time) / (b.time - a.time);
      return lerpDouble(a.value, b.value, f)!;
    }
  }
  return 0.5;
}

double getMinNonZeroPhase(List<BreathingPhase> phases) {
  double min = double.infinity;

  for (final p in phases) {
    final d = p.duration;
    if (d > 0 && d < min) {
      min = d;
    }
  }

  return min == double.infinity ? 0.3 : min;
}

class _KeyPoint {
  final int time;
  final double value;
  _KeyPoint(this.time, this.value);
}



