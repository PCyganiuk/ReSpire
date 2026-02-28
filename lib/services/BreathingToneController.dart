import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

enum BreathingAudioPhase {
  inhale,
  retention,
  exhale,
  recovery,
}

class BreathingPhase {
  final BreathingAudioPhase phase;
  final double durationSeconds;

  BreathingPhase({
    required this.phase,
    required this.durationSeconds,
  });
}

// A single resonant partial with its own frequency, amplitude weight,
// and independent decay rate — the core of physical gong modeling.
class _Partial {
  final double freqRatio;
  final double weight;
  final double decayRate;
  double phase = 0.0;

  _Partial(this.freqRatio, this.weight, this.decayRate);
}

class BreathingToneController {
  static const int sampleRate = 44100;
  static const int fadeSamples = 0;

  final AudioPlayer _player = AudioPlayer();
  Uint8List? _wavBuffer;
  final Random _rng = Random(42);

  // 528 Hz — "solfeggio MI" frequency, widely used in meditation audio.
  // Higher base = lighter, glassier feel. Try 660.0 for even brighter.
  double baseFrequency;
  final Duration _totalDuration = Duration.zero;

  BreathingToneController({this.baseFrequency = 528.0}) {
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setPlayerMode(PlayerMode.mediaPlayer);
  }

  // ============================================================
  // PARTIAL BANKS
  // Inharmonic ratios from acoustic bowl measurements.
  // High partials have fast decayRate so they die quickly after
  // the strike — leaving only the warm fundamental ringing.
  // ============================================================

  List<_Partial> _inhalePartials() => [
    _Partial(1.000, 1.00, 0.5),   // fundamental — long ring
    _Partial(2.756, 0.38, 2.2),   // bowl shimmer, fades in ~1s
    _Partial(5.231, 0.14, 6.0),   // brief bright sparkle on attack
    _Partial(7.140, 0.05, 12.0),  // instant transient, gone in ms
  ];

  List<_Partial> _retentionPartials() => [
    _Partial(1.000, 1.00, 0.25),  // extremely slow — rings the whole hold
    _Partial(2.756, 0.22, 1.0),
    _Partial(4.651, 0.07, 3.0),
  ];

  List<_Partial> _exhalePartials() => [
    _Partial(1.000, 1.00, 0.7),
    _Partial(2.410, 0.30, 2.5),
    _Partial(4.200, 0.10, 6.0),
    _Partial(6.250, 0.03, 12.0),
  ];

  List<_Partial> _recoveryPartials() => [
    _Partial(1.000, 1.00, 0.4),
    _Partial(2.410, 0.20, 1.8),
    _Partial(4.000, 0.06, 5.0),
  ];

  void prepareTraining(List<BreathingPhase> phases) {
    final List<int> pcmSamples = [];

    const double fadeSeconds = 0.05;
    final int fadeSmp = (fadeSeconds * sampleRate).round();

    // Attack transient: 18ms noise burst simulating mallet strike
    const double attackSeconds = 0.018;
    final int attackSamples = (attackSeconds * sampleRate).round();

    for (final phase in phases) {
      final int samples = (phase.durationSeconds * sampleRate).round();

      final List<_Partial> partials;
      final double baseAmp;
      final double strikeIntensity;
      final double freqCenter;

      switch (phase.phase) {
        case BreathingAudioPhase.inhale:
          partials        = _inhalePartials();
          baseAmp         = 0.30;
          strikeIntensity = 0.50;
          freqCenter      = baseFrequency * 1.0;
          break;

        case BreathingAudioPhase.retention:
          partials        = _retentionPartials();
          baseAmp         = 0.26;
          strikeIntensity = 0.30;
          freqCenter      = baseFrequency * 1.20;
          break;

        case BreathingAudioPhase.exhale:
          partials        = _exhalePartials();
          baseAmp         = 0.27;
          strikeIntensity = 0.40;
          freqCenter      = baseFrequency * 0.98;
          break;

        case BreathingAudioPhase.recovery:
          partials        = _recoveryPartials();
          baseAmp         = 0.22;
          strikeIntensity = 0.28;
          freqCenter      = baseFrequency * 1.10;
          break;
      }

      final double weightSum = partials.fold(0.0, (s, p) => s + p.weight);

      for (int i = 0; i < samples; i++) {
        final double t = i / samples;

        // ------------------------------------------------
        // ATTACK TRANSIENT
        // Crucially, this is NOT multiplied by envShape —
        // it runs at full intensity at i=0 so the strike
        // is heard immediately and clearly.
        // ------------------------------------------------
        double attackNoise = 0.0;
        if (i < attackSamples) {
          final double attackEnv = exp(-i / (attackSamples * 0.3));
          final double noise =
              (_rng.nextDouble() * 2.0 - 1.0) * 0.5 +
                  (_rng.nextDouble() * 2.0 - 1.0) * 0.5;
          attackNoise = noise * attackEnv * strikeIntensity;
        }

        // ------------------------------------------------
        // PARTIAL BANK — each partial decays independently
        // ------------------------------------------------
        double toneSample = 0.0;
        for (final p in partials) {
          final double partialFreq = freqCenter * p.freqRatio;
          p.phase += 2 * pi * partialFreq / sampleRate;
          final double partialAmp = p.weight * exp(-t * p.decayRate);
          toneSample += partialAmp * sin(p.phase);
        }
        toneSample /= weightSum;

        // ------------------------------------------------
        // OVERALL ENVELOPE SHAPE
        //
        // INHALE FIX: instead of easeInOut (which starts at 0),
        // we start at 1.0 and use a gentle ramp-down shape so the
        // strike lands at full volume, then the bowl rings through
        // the full inhale duration naturally via per-partial decay.
        //
        // For exhale we fade out smoothly. Retention and recovery
        // let per-partial decay do the work — no extra shaping needed.
        // ------------------------------------------------
        final double envShape;
        switch (phase.phase) {
          case BreathingAudioPhase.inhale:
          // Start at full volume so strike is heard immediately.
          // Gentle overall swell using a hold-then-fade curve:
          // first 20% holds at 1.0, then eases out softly.
            final double holdEnd = 0.2;
            if (t < holdEnd) {
              envShape = 1.0;
            } else {
              final double tAfterHold = (t - holdEnd) / (1.0 - holdEnd);
              envShape = 1.0 - (_easeInOut(tAfterHold) * 0.35);
            }
            break;

          case BreathingAudioPhase.retention:
            envShape = 1.0; // per-partial decay handles the shape
            break;

          case BreathingAudioPhase.exhale:
            envShape = 1.0 - _easeInOut(t);
            break;

          case BreathingAudioPhase.recovery:
            envShape = 1.0; // per-partial decay handles the shape
            break;
        }

        double sample = (toneSample * baseAmp * envShape) +
            (attackNoise * baseAmp);

        // ------------------------------------------------
        // PHASE EDGE FADES (unchanged from original)
        // ------------------------------------------------
        if (i < fadeSmp) {
          sample *= i / fadeSmp;
        } else if (i > samples - fadeSmp) {
          sample *= (samples - i) / fadeSmp;
        }

        pcmSamples.add((sample * 32767).clamp(-32767.0, 32767.0).toInt());
      }
    }

    final pcm16 = Int16List.fromList(pcmSamples);
    _wavBuffer = _pcmToWav(pcm16);
  }

  // ================================
  // PLAYBACK CONTROL
  // ================================
  Future<void> play() async {
    if (_wavBuffer == null) return;
    await _player.play(BytesSource(_wavBuffer!), volume: 1.0);
  }

  Future<void> pause()  async => _player.pause();
  Future<void> resume() async => _player.resume();
  Future<void> stop()   async => _player.stop();

  Duration get totalDuration => _totalDuration;

  void dispose() {
    _player.dispose();
    _wavBuffer = null;
  }

  // ================================
  // WAV ENCODING
  // ================================
  Uint8List _pcmToWav(Int16List pcm) {
    final int byteRate   = sampleRate * 2;
    final int dataLength = pcm.length * 2;
    final int fileLength = 44 + dataLength;

    final bytes = BytesBuilder();

    bytes.add('RIFF'.codeUnits);
    bytes.add(_intToBytes(fileLength - 8, 4));
    bytes.add('WAVE'.codeUnits);

    bytes.add('fmt '.codeUnits);
    bytes.add(_intToBytes(16, 4));
    bytes.add(_intToBytes(1,  2));
    bytes.add(_intToBytes(1,  2));
    bytes.add(_intToBytes(sampleRate, 4));
    bytes.add(_intToBytes(byteRate,   4));
    bytes.add(_intToBytes(2,  2));
    bytes.add(_intToBytes(16, 2));

    bytes.add('data'.codeUnits);
    bytes.add(_intToBytes(dataLength, 4));

    for (final sample in pcm) {
      bytes.add(_intToBytes(sample, 2));
    }

    return bytes.toBytes();
  }

  List<int> _intToBytes(int value, int byteCount) {
    final b = Uint8List(byteCount);
    for (int i = 0; i < byteCount; i++) {
      b[i] = (value >> (8 * i)) & 0xFF;
    }
    return b;
  }

  double _easeInOut(double t) => t * t * (3 - 2 * t);
}