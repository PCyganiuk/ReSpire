import 'dart:collection';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:respire/components/Global/BreathingPhase.dart' as breathing_phase;
import 'package:respire/services/TrainingController.dart';

class BreathingWaveTimeline extends StatefulWidget {
  final TrainingController controller;

  const BreathingWaveTimeline({
    super.key,
    required this.controller,
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

  _BreathingWavePainter({
    required this.controller,
    required this.elapsedMs,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final training = controller.parser.training;

    /// ---- BUILD FULL PHASE LIST ----
    final phases = <breathing_phase.BreathingPhase>[];
    //phases.add(breathing_phase.BreathingPhase(duration: 0,breathingPhaseType: breathing_phase.BreathingPhaseType.recovery));
    for (final stage in training.trainingStages) {
      for (int i = 0; i < stage.reps; i++) {
        phases.addAll(stage.breathingPhases);
      }
    }
    if (phases.isEmpty) return;

    /// ---- BUILD TIME ENVELOPE ----
    final keys = <_KeyPoint>[];
    int accMs = 0;

    for (final phase in phases) {
      final durMs = (phase.duration * 1000).toInt();
      final (from, to) = _phaseEnvelope(phase);

      keys.add(_KeyPoint(accMs, from));
      accMs += durMs;
      keys.add(_KeyPoint(accMs, to));
    }

    final totalMs = accMs;
    final clampedElapsed = elapsedMs.clamp(0, totalMs);

    /// ---- GEOMETRY ----
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final waveHeight = size.height * 0.45;
    final stretch = size.width * 3;

    /// ---- SCROLL OFFSET ----
    final scrollX = (clampedElapsed / totalMs) * stretch;

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
      final progress = t / totalMs;
      final x = centerX + progress * stretch - scrollX;

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
    final dotRadius = lerpDouble(16, 26, pulse)!;

    canvas.drawCircle(
      Offset(centerX, dotY),
      dotRadius,
      Paint()..color = const Color(0xFF2496A8),
    );
  }

  @override
  bool shouldRepaint(covariant _BreathingWavePainter old) =>
      old.elapsedMs != elapsedMs || old.pulse != pulse;
}

/// ---- HELPERS ----

(double, double) _phaseEnvelope(breathing_phase.BreathingPhase phase) {
  switch (phase.breathingPhaseType) {
    case breathing_phase.BreathingPhaseType.inhale:
      return (0.0, 1.0); // rise
    case breathing_phase.BreathingPhaseType.retention:
      return (1.0, 1.0); // stay high
    case breathing_phase.BreathingPhaseType.exhale:
      return (1.0, 0.0); // fall
    case breathing_phase.BreathingPhaseType.recovery:
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

class _KeyPoint {
  final int time;
  final double value;
  _KeyPoint(this.time, this.value);
}



