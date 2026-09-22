import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:respire/theme/Colors.dart';
import 'package:respire/services/SettingsProvider.dart';

// ─── Floating Indicator Widget (Microphone Version) ──────────────────────────
class BreathMonitorIndicator extends StatefulWidget {
  final ValueNotifier<bool> isPaused;
  final VoidCallback? onCycleComplete;
  final double? threshold;

  const BreathMonitorIndicator({
    super.key,
    required this.isPaused,
    this.onCycleComplete,
    this.threshold,
  });

  @override
  State<BreathMonitorIndicator> createState() =>
      _BreathMonitorIndicatorState();
}

class _BreathMonitorIndicatorState extends State<BreathMonitorIndicator> {
  static const _classifierChannel =
  MethodChannel('com.paveuu.respire.breathing_classifier');

  static const _audioChannel =
  MethodChannel('com.paveuu.respire.audio');

  // ONNX model input:
  // 154350 samples / 44100 Hz ≈ 3.5 seconds.
  static const _bufferSize = 154350;

  final AudioRecorder _audioRecorder = AudioRecorder();

  StreamSubscription<Uint8List>? _audioStreamSub;

  final List<int> _audioBuffer = [];

  int _currentClass = 1; // 0 = Exhale, 1 = Other

  bool _isMonitoring = false;
  bool _showCycleComplete = false;

  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();

    widget.isPaused.addListener(_onPauseStateChanged);

    if (!widget.isPaused.value) {
      _startMonitoring();
    }
  }

  @override
  void didUpdateWidget(covariant BreathMonitorIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isPaused != widget.isPaused) {
      oldWidget.isPaused.removeListener(_onPauseStateChanged);
      widget.isPaused.addListener(_onPauseStateChanged);
    }
  }

  @override
  void dispose() {
    widget.isPaused.removeListener(_onPauseStateChanged);

    _stopMonitoring();

    _audioRecorder.dispose();

    super.dispose();
  }

  void _onPauseStateChanged() {
    if (widget.isPaused.value) {
      _stopMonitoring();
    } else {
      _startMonitoring();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Microphone selection
  // ───────────────────────────────────────────────────────────────────────────

  Future<InputDevice?> _getPreferredInputDevice() async {
    try {
      final result = await _audioChannel.invokeMethod<dynamic>(
        'getPreferredInputDevice',
      );

      if (result == null) {
        debugPrint('Audio: no preferred input device returned');
        return null;
      }

      final map = Map<String, dynamic>.from(result as Map);

      final id = map['id']?.toString();
      final label = map['label']?.toString() ?? 'Unknown microphone';
      final type = map['type']?.toString() ?? 'unknown';
      final isExternal = map['isExternal'] == true;

      if (id == null || id.isEmpty) {
        debugPrint('Audio: preferred device has no ID');
        return null;
      }

      debugPrint(
        'Audio: selected device '
            'id=$id '
            'label="$label" '
            'type=$type '
            'external=$isExternal',
      );

      return InputDevice(
        id: id,
        label: label,
      );
    } on PlatformException catch (e) {
      debugPrint(
        'Audio: failed to get preferred input device: '
            '${e.code}: ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('Audio: failed to get preferred input device: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Recording
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _startMonitoring() async {
    if (_isMonitoring) {
      return;
    }

    final status = await Permission.microphone.request();

    if (status != PermissionStatus.granted) {
      debugPrint('Microphone permission denied');
      return;
    }

    final preferredDevice = await _getPreferredInputDevice();

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 44100,
      numChannels: 1,

      // Do not modify the signal before it reaches the classifier.
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,

      // Prefer the external device selected by Android.
      device: preferredDevice,

      androidConfig: const AndroidRecordConfig(
        manageBluetooth: true,
        speakerphone: false,
      ),
    );

    try {
      debugPrint(
        'Audio: starting recorder with device '
            '${preferredDevice?.id ?? "default"}',
      );

      final stream = await _audioRecorder.startStream(config);

      _audioStreamSub = stream.listen(
        _onAudioChunk,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Audio stream error: $error');
        },
      );

      if (mounted) {
        setState(() {
          _isMonitoring = true;
        });
      }

      debugPrint('Audio: monitoring started');
    } catch (e) {
      debugPrint(
        'Audio: failed to start with selected device: $e',
      );

      // Some Android devices expose a device through AudioManager but the
      // recorder cannot explicitly route to it. Retry with the platform
      // default device instead of completely disabling monitoring.
      if (preferredDevice != null) {
        debugPrint(
          'Audio: retrying with Android default input device',
        );

        try {
          final fallbackConfig = RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 44100,
            numChannels: 1,
            autoGain: false,
            echoCancel: false,
            noiseSuppress: false,
            device: null,
            androidConfig: const AndroidRecordConfig(
              manageBluetooth: true,
              speakerphone: false,
            ),
          );

          final stream =
          await _audioRecorder.startStream(fallbackConfig);

          _audioStreamSub = stream.listen(
            _onAudioChunk,
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Audio fallback stream error: $error');
            },
          );

          if (mounted) {
            setState(() {
              _isMonitoring = true;
            });
          }

          debugPrint('Audio: fallback monitoring started');
        } catch (fallbackError) {
          debugPrint(
            'Audio: fallback recorder also failed: $fallbackError',
          );
        }
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Audio processing
  // ───────────────────────────────────────────────────────────────────────────

  void _onAudioChunk(Uint8List rawBytes) {
    if (rawBytes.isEmpty) {
      return;
    }

    // PCM16 requires 2-byte alignment.
    final Uint8List alignedData =
    (rawBytes.offsetInBytes % 2 == 0)
        ? rawBytes
        : Uint8List.fromList(rawBytes);

    final sampleCount = alignedData.length ~/ 2;

    if (sampleCount <= 0) {
      return;
    }

    final samples = alignedData.buffer.asInt16List(
      alignedData.offsetInBytes,
      sampleCount,
    );

    _audioBuffer.addAll(samples);

    if (_audioBuffer.length >= _bufferSize) {
      // Take the newest 3.5-second window.
      final window = _audioBuffer.sublist(
        _audioBuffer.length - _bufferSize,
      );

      // Keep half of the window for 50% overlap.
      _audioBuffer.removeRange(
        0,
        _audioBuffer.length - (_bufferSize ~/ 2),
      );

      _classify(window);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ONNX classification
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _classify(List<int> samples) async {
    try {
      final pcmBytes =
      Int16List.fromList(samples).buffer.asUint8List();

      final result = await _classifierChannel.invokeMethod<int>(
        'classifyAudio',
        {
          'audioData': pcmBytes,
          'threshold': widget.threshold ??
              SettingsProvider().settings.breathThreshold,
        },
      );

      if (!mounted || result == null || result == _currentClass) {
        return;
      }

      // Previous state: Exhale
      // New state: Other
      //
      // This marks the completion of a breathing cycle.
      if (_currentClass == 0 && result == 1) {
        widget.onCycleComplete?.call();

        _cycleTimer?.cancel();

        setState(() {
          _showCycleComplete = true;
        });

        _cycleTimer = Timer(
          const Duration(seconds: 1),
              () {
            if (!mounted) {
              return;
            }

            setState(() {
              _showCycleComplete = false;
            });
          },
        );
      }

      setState(() {
        _currentClass = result;
      });
    } on PlatformException catch (e) {
      debugPrint(
        'Classification error: ${e.code}: ${e.message}',
      );
    } catch (e) {
      debugPrint('Classification error: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Stop
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _stopMonitoring() async {
    _audioStreamSub?.cancel();
    _audioStreamSub = null;

    try {
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint('Audio: error while stopping recorder: $e');
    }

    _audioBuffer.clear();

    _cycleTimer?.cancel();
    _cycleTimer = null;

    if (mounted) {
      setState(() {
        _isMonitoring = false;
        _currentClass = 1;
        _showCycleComplete = false;
      });
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _isMonitoring ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _showCycleComplete
              ? Colors.green
              : _currentClass == 0
              ? mediumblue
              : Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          _showCycleComplete
              ? Icons.check_circle
              : (_currentClass == 0
              ? Icons.air
              : Icons.mic),
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}