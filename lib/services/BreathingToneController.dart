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


class BreathingToneController {
  static const int sampleRate = 44100;
  static const double amplitude = 0.3;
  static const double pitchRangeHz = 60.0;
  static const int fadeSamples = 0; // 5 ms

  final AudioPlayer _player = AudioPlayer();
  Uint8List? _wavBuffer;

  double baseFrequency;
  final Duration _totalDuration = Duration.zero;

  BreathingToneController({this.baseFrequency = 220.0}) {
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setPlayerMode(PlayerMode.mediaPlayer);
  }

  // ================================
  // BUILD WHOLE TRAINING SOUND
  // ================================
  void prepareTrainingOld(List<BreathingPhase> phases) {
    final List<int> pcmSamples = [];
    double phaseAccumulator = 0.0;
    double currentFreq = baseFrequency;
    double currentAmp = amplitude;

    const double vibratoDepthHz = 2.0;
    const double vibratoRateHz = 0.15; // very slow
    const double harmonicMix = 0.15;

    for (final phase in phases) {
      final int samples =
      (phase.durationSeconds * sampleRate).round();

      // === PER-PHASE FREQUENCY TARGETS ===
      final double startFreq = currentFreq;
      double endFreq = currentFreq;
      final double startAmp = currentAmp;
      double endAmp = currentAmp;

      switch (phase.phase) {
        case BreathingAudioPhase.inhale:
          endFreq = baseFrequency + pitchRangeHz;
          break;

        case BreathingAudioPhase.exhale:
          endFreq = baseFrequency;
          break;

        case BreathingAudioPhase.retention:
        case BreathingAudioPhase.recovery:
          endFreq = currentFreq; // constant pitch
          break;
      }

      for (int i = 0; i < samples; i++) {
        final double localT = i / samples;

        final double freq =
            startFreq + (endFreq - startFreq) * _easeInOut(localT);

        phaseAccumulator += 2 * pi * freq / sampleRate;

        double amp = amplitude;
        if (i < fadeSamples) {
          amp *= i / fadeSamples;
        } else if (i > samples - fadeSamples) {
          amp *= (samples - i) / fadeSamples;
        }

        pcmSamples.add(
          (sin(phaseAccumulator) * amp * 32767).toInt(),
        );
      }

      // LOCK frequency for next phase
      currentFreq = endFreq;
    }

    final pcm16 = Int16List.fromList(pcmSamples);
    _wavBuffer = _pcmToWav(pcm16);
  }

  void prepareTrainingAlm(List<BreathingPhase> phases) {
    final List<int> pcmSamples = [];
    double phaseAccumulator = 0.0;

    const double vibratoDepthHz = 2.0;
    const double vibratoRateHz = 0.15;
    const double harmonicMix = 0.15;
    const double recoveryGain = 1.3; // 1.15–1.4 feels good

    double inhaleEndAmp = 0.0;
    double exhaleEndAmp = 0.0;

    for (final phase in phases) {
      final int samples =
      (phase.durationSeconds * sampleRate).round();

      for (int i = 0; i < samples; i++) {
        final double t = i / samples;

        // ----------------------------
        // AMPLITUDE ENVELOPE
        // ----------------------------
        double amp;

        switch (phase.phase) {
          case BreathingAudioPhase.inhale:
            amp = amplitude * _easeInOut(t);
            inhaleEndAmp = amp;
            break;

          case BreathingAudioPhase.retention:
            amp = inhaleEndAmp;
            break;

          case BreathingAudioPhase.exhale:
            amp = amplitude * (1.0 - _easeInOut(t));
            exhaleEndAmp = amp;
            break;

          case BreathingAudioPhase.recovery:
            amp = exhaleEndAmp * recoveryGain;
            break;
        }

        // ----------------------------
        // SOFT EDGE FADES
        // ----------------------------
        if (i < fadeSamples) {
          amp *= i / fadeSamples;
        } else if (i > samples - fadeSamples) {
          amp *= (samples - i) / fadeSamples;
        }

        // ----------------------------
        // GENTLE VIBRATO (ALWAYS ON)
        // ----------------------------
        final double vibrato =
            vibratoDepthHz *
                sin(2 * pi * vibratoRateHz * i / sampleRate);

        final double freq = baseFrequency + vibrato;

        phaseAccumulator += 2 * pi * freq / sampleRate;

        // ----------------------------
        // WARM TONE
        // ----------------------------
        //final double sample =
        //    sin(phaseAccumulator) +
        //        harmonicMix * sin(phaseAccumulator * 2);

        //pcmSamples.add(
        //  (sample * amp * 32767).toInt(),
        //);

        // ----------------------------
// GONG/BELL STYLE HARMONICS
// ----------------------------
        double decayRate = 3.0; // bell decay
        double env;

// Hold amplitude constant for retention/recovery
        if (phase.phase == BreathingAudioPhase.retention) {
          env = 1.0;
        } else if (phase.phase == BreathingAudioPhase.recovery) {
          env = 1.0;
        } else {
          env = _easeInOut(t) * exp(-t * decayRate);
        }

// Harmonics
        final List<double> harmonics = [1.0, 2.0, 3.0, 4.5];
        double sample = 0.0;
        for (final h in harmonics) {
          sample += sin(phaseAccumulator * h);
        }
        sample /= harmonics.length;

// Apply amplitude
        sample *= amp * env;

// Soft edge fade
        if (i < fadeSamples) {
          sample *= i / fadeSamples;
        } else if (i > samples - fadeSamples) {
          sample *= (samples - i) / fadeSamples;
        }

        pcmSamples.add((sample * 32767).toInt());

      }
    }

    final pcm16 = Int16List.fromList(pcmSamples);
    _wavBuffer = _pcmToWav(pcm16);
  }

  void prepareTraining(List<BreathingPhase> phases) {
    final List<int> pcmSamples = [];
    double phaseAccumulator = 0.0;

    const double fadeSeconds = 0.05;
    final int fadeSamples = (fadeSeconds * sampleRate).round();

    for (final phase in phases) {
      final int samples = (phase.durationSeconds * sampleRate).round();

      // ==========================
      // PHASE-SPECIFIC SETTINGS
      // ==========================
      late List<double> partials;
      late double decayRate;
      late double startFreq;
      late double endFreq;
      late double baseAmp;

      switch (phase.phase) {
        case BreathingAudioPhase.inhale:
          partials = [1.0, 2.12, 3.01, 4.23, 5.44]; // bright & airy
          decayRate = 2.0;
          startFreq = baseFrequency * 0.9;
          endFreq = baseFrequency * 1.25;
          baseAmp = 0.55;
          break;

        case BreathingAudioPhase.exhale:
          partials = [0.5, 1.0, 1.87, 2.74, 3.6]; // darker
          decayRate = 3.5;
          startFreq = baseFrequency * 1.25;
          endFreq = baseFrequency * 0.85;
          baseAmp = 0.6;
          break;

        case BreathingAudioPhase.retention:
          partials = [1.0, 2.03, 3.9]; // very stable
          decayRate = 6.0;
          startFreq = endFreq = baseFrequency;
          baseAmp = 0.35;
          break;

        case BreathingAudioPhase.recovery:
          partials = [1.0, 1.5, 2.2, 3.1]; // warm & soft
          decayRate = 4.0;
          startFreq = endFreq = baseFrequency * 0.95;
          baseAmp = 0.45;
          break;
      }

      for (int i = 0; i < samples; i++) {
        final double t = i / samples;

        // ==========================
        // FREQUENCY GLIDE
        // ==========================
        final double freq =
            startFreq + (endFreq - startFreq) * _easeInOut(t);

        phaseAccumulator += 2 * pi * freq / sampleRate;

        // ==========================
        // GONG SYNTHESIS
        // ==========================
        double sample = 0.0;
        for (final p in partials) {
          // tiny detune per partial for realism
          final double detune = 1.0 + (p * 0.002);
          sample += sin(phaseAccumulator * p * detune);
        }
        sample /= partials.length;

        // ==========================
        // NATURAL DECAY
        // ==========================
        double amp = baseAmp * exp(-t * decayRate);

        // ==========================
        // PHASE EDGE FADES (0.1s)
        // ==========================
        if (i < fadeSamples) {
          amp *= i / fadeSamples;
        } else if (i > samples - fadeSamples) {
          amp *= (samples - i) / fadeSamples;
        }

        pcmSamples.add((sample * amp * 32767).toInt());
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
    
    await _player.play(
      BytesSource(_wavBuffer!),
      volume: 1.0,
    );
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.resume();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Duration get totalDuration => _totalDuration;

  void dispose() {
    _player.dispose();
    _wavBuffer = null;
  }

  Uint8List _pcmToWav(Int16List pcm) {
    final int byteRate = sampleRate * 2;
    final int dataLength = pcm.length * 2;
    final int fileLength = 44 + dataLength;

    final bytes = BytesBuilder();

    // RIFF header
    bytes.add('RIFF'.codeUnits);
    bytes.add(_intToBytes(fileLength - 8, 4));
    bytes.add('WAVE'.codeUnits);

    // fmt chunk
    bytes.add('fmt '.codeUnits);
    bytes.add(_intToBytes(16, 4)); // PCM
    bytes.add(_intToBytes(1, 2)); // PCM format
    bytes.add(_intToBytes(1, 2)); // mono
    bytes.add(_intToBytes(sampleRate, 4));
    bytes.add(_intToBytes(byteRate, 4));
    bytes.add(_intToBytes(2, 2)); // block align
    bytes.add(_intToBytes(16, 2)); // bits per sample

    // data chunk
    bytes.add('data'.codeUnits);
    bytes.add(_intToBytes(dataLength, 4));

    for (final sample in pcm) {
      // Convert signed 16-bit to little endian bytes
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

  // ================================
  // SMOOTH CURVE
  // ================================
  double _easeInOut(double t) {
    return t * t * (3 - 2 * t); // smoothstep
  }
}
