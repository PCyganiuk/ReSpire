import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart'; // add record: ^5.0.0 to pubspec.yaml
import 'package:permission_handler/permission_handler.dart'; // add permission_handler: ^11.0.0

/// Drop this file into your Flutter project.
/// Also add BreathClassifierWrapper.kt to android/app/src/main/kotlin/.
/// See pubspec dependencies comment above.

// ─── Constants ───────────────────────────────────────────────────────────────

/// Must match the sample count the ONNX model expects (~3.5 s @ 44 100 Hz).
const int _kBufferSize = 154350;

/// PCM sample rate used during training.
const int _kSampleRate = 44100;

// ─── Phase enum ──────────────────────────────────────────────────────────────

enum BreathPhase {
  inhale,
  exhale,
  silence;

  String get label {
    switch (this) {
      case BreathPhase.inhale:
        return 'INHALE';
      case BreathPhase.exhale:
        return 'EXHALE';
      case BreathPhase.silence:
        return 'SILENCE';
    }
  }

  Color get color {
    switch (this) {
      case BreathPhase.inhale:
        return const Color(0xFFE05555); // warm red
      case BreathPhase.exhale:
        return const Color(0xFF4CAF7D); // teal green
      case BreathPhase.silence:
        return const Color(0xFF5B8CCC); // calm blue
    }
  }

  IconData get icon {
    switch (this) {
      case BreathPhase.inhale:
        return Icons.arrow_upward_rounded;
      case BreathPhase.exhale:
        return Icons.arrow_downward_rounded;
      case BreathPhase.silence:
        return Icons.horizontal_rule_rounded;
    }
  }
}

// ─── Classifier bridge ───────────────────────────────────────────────────────

/// Calls the native Kotlin ONNX wrapper via a MethodChannel.
class BreathClassifier {
  static const MethodChannel _channel =
      MethodChannel('com.paveuu.respire.breathing_classifier');

  /// Returns the predicted [BreathPhase] for [audioSamples] (Int16 PCM).
  Future<BreathPhase> classify(List<int> audioSamples) async {
    try {
      final bytes = Int16List.fromList(audioSamples).buffer.asUint8List();
      final int index = await _channel.invokeMethod<int>(
            'classifyAudio',
            {'audioData': bytes},
          ) ??
          2; // default → silence
      return _indexToPhase(index);
    } on PlatformException {
      return BreathPhase.silence;
    }
  }

  BreathPhase _indexToPhase(int index) {
    switch (index) {
      case 0:
        return BreathPhase.exhale;
      case 1:
        return BreathPhase.inhale;
      default:
        return BreathPhase.silence;
    }
  }
}

// ─── Main widget ─────────────────────────────────────────────────────────────

/// Standalone widget – drop anywhere in your widget tree.
class BreathMonitorWidget extends StatefulWidget {
  const BreathMonitorWidget({super.key});

  @override
  State<BreathMonitorWidget> createState() => _BreathMonitorWidgetState();
}

class _BreathMonitorWidgetState extends State<BreathMonitorWidget>
    with SingleTickerProviderStateMixin {
  // ── state ──
  bool _isListening = false;
  BreathPhase _phase = BreathPhase.silence;
  String _statusMessage = 'Tap the button to start';

  // ── audio ──
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;
  final List<int> _buffer = [];

  // ── classifier ──
  final BreathClassifier _classifier = BreathClassifier();
  bool _isClassifying = false;

  // ── animation ──
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stopListening();
    _recorder.dispose();
    super.dispose();
  }

  // ─── microphone ────────────────────────────────────────────────────────────

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _statusMessage = 'Microphone permission denied');
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() => _statusMessage = 'Cannot access microphone');
      return;
    }

    _buffer.clear();

    // Stream raw PCM (16-bit, mono, 44 100 Hz)
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _kSampleRate,
        numChannels: 1,
      ),
    );

    _audioSub = stream.listen(_onAudioChunk);

    setState(() {
      _isListening = true;
      _statusMessage = 'Listening…';
      _phase = BreathPhase.silence;
    });
  }

  Future<void> _stopListening() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
    _buffer.clear();
    setState(() {
      _isListening = false;
      _statusMessage = 'Tap the button to start';
      _phase = BreathPhase.silence;
    });
  }

  void _onAudioChunk(Uint8List rawBytes) {
    // rawBytes are little-endian Int16 samples
    final samples = rawBytes.buffer.asInt16List();
    _buffer.addAll(samples);

    // Keep only the last _kBufferSize samples (sliding window)
    if (_buffer.length > _kBufferSize) {
      _buffer.removeRange(0, _buffer.length - _kBufferSize);
    }

    // Classify once the buffer is full and no classification is running
    if (_buffer.length == _kBufferSize && !_isClassifying) {
      _runClassification(List<int>.from(_buffer));
    }
  }

  Future<void> _runClassification(List<int> samples) async {
    _isClassifying = true;
    final phase = await _classifier.classify(samples);
    if (mounted) {
      setState(() => _phase = phase);
    }
    _isClassifying = false;
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTitle(),
                const SizedBox(height: 56),
                _buildPhaseDisplay(),
                const SizedBox(height: 48),
                _buildStatusText(),
                const SizedBox(height: 56),
                _buildToggleButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'BREATH',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'MONITOR',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseDisplay() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        final scale = _isListening ? _pulseAnim.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _phase.color.withOpacity(0.12),
          border: Border.all(
            color: _phase.color.withOpacity(_isListening ? 0.7 : 0.25),
            width: 2,
          ),
          boxShadow: _isListening
              ? [
                  BoxShadow(
                    color: _phase.color.withOpacity(0.25),
                    blurRadius: 48,
                    spreadRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Icon(
                _phase.icon,
                key: ValueKey(_phase),
                size: 48,
                color: _phase.color,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Text(
                _phase.label,
                key: ValueKey(_phase),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                  color: _phase.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        _statusMessage,
        key: ValueKey(_statusMessage),
        style: TextStyle(
          fontSize: 13,
          letterSpacing: 1.5,
          color: Colors.white.withOpacity(0.35),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildToggleButton() {
    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isListening
              ? const Color(0xFFE05555).withOpacity(0.15)
              : Colors.white.withOpacity(0.08),
          border: Border.all(
            color: _isListening
                ? const Color(0xFFE05555).withOpacity(0.6)
                : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Icon(
          _isListening ? Icons.stop_rounded : Icons.mic_rounded,
          size: 32,
          color: _isListening
              ? const Color(0xFFE05555)
              : Colors.white.withOpacity(0.6),
        ),
      ),
    );
  }
}
