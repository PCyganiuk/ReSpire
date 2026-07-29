import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:respire/theme/Colors.dart';

// ─── Floating Indicator Widget (Microphone Version) ──────────────────────────
class BreathMonitorIndicator extends StatefulWidget {
  final ValueNotifier<bool> isPaused;
  final VoidCallback? onCycleComplete;

  const BreathMonitorIndicator({
    super.key,
    required this.isPaused,
    this.onCycleComplete,
  });

  @override
  State<BreathMonitorIndicator> createState() => _BreathMonitorIndicatorState();
}

class _BreathMonitorIndicatorState extends State<BreathMonitorIndicator> {
  static const _channel = MethodChannel('com.paveuu.respire.breathing_classifier');
  static const _bufferSize = 154350; // Samples needed for the ONNX model (~3.5s @ 44.1kHz)
  
  final _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSub;
  final List<int> _audioBuffer = [];
  
  int _currentClass = 1; // 0: Exhale, 1: Other
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

  Future<void> _startMonitoring() async {
    if (_isMonitoring) return;

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      debugPrint('Microphone permission denied');
      return;
    }

    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 44100,
      numChannels: 1,
    );

    try {
      final stream = await _audioRecorder.startStream(config);
      _audioStreamSub = stream.listen(_onAudioChunk);
      setState(() => _isMonitoring = true);
    } catch (e) {
      debugPrint('Error starting audio stream: $e');
    }
  }

  void _onAudioChunk(Uint8List rawBytes) {
    // Some streams return data with an odd offset, which causes asInt16List to fail.
    // If not aligned to 2 bytes, we copy the list to a new one.
    final Uint8List alignedData = (rawBytes.offsetInBytes % 2 == 0)
        ? rawBytes
        : Uint8List.fromList(rawBytes);

    final samples = alignedData.buffer.asInt16List(
      alignedData.offsetInBytes,
      alignedData.length ~/ 2,
    );
    
    _audioBuffer.addAll(samples);

    // Keep the buffer at the required size and classify when we have enough data
    if (_audioBuffer.length >= _bufferSize) {
      // Extract the last 3.5s window
      final window = _audioBuffer.sublist(_audioBuffer.length - _bufferSize);
      
      // Keep half the buffer for sliding window effect (optional overlap)
      _audioBuffer.removeRange(0, _audioBuffer.length - (_bufferSize ~/ 2));
      
      _classify(window);
    }
  }

  Future<void> _classify(List<int> samples) async {
    try {
      // Convert Int16 samples back to raw bytes for the MethodChannel
      final pcmBytes = Int16List.fromList(samples).buffer.asUint8List();
      
      final result = await _channel.invokeMethod<int>('classifyAudio', {
        'audioData': pcmBytes,
      });

      if (mounted && result != null && result != _currentClass) {
        // Detect when an exhale (0) ends and returns to other (1)
        if (_currentClass == 0 && result == 1) {
          widget.onCycleComplete?.call();
          _cycleTimer?.cancel();
          setState(() {
            _showCycleComplete = true;
          });
          _cycleTimer = Timer(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _showCycleComplete = false;
              });
            }
          });
        }

        setState(() {
          _currentClass = result;
        });
      }
    } on PlatformException catch (e) {
      debugPrint('Classification error: ${e.message}');
    }
  }

  void _stopMonitoring() {
    if (!_isMonitoring) return;
    _audioStreamSub?.cancel();
    _audioStreamSub = null;
    _audioRecorder.stop();
    _audioBuffer.clear();
    _cycleTimer?.cancel();
    if (mounted) {
      setState(() {
        _isMonitoring = false;
        _currentClass = 1;
        _showCycleComplete = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 300,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _isMonitoring ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _showCycleComplete
                ? Colors.green         // Green for completion
                : _currentClass == 0
                    ? mediumblue     // Coherent Blue for Exhale
                    : Colors.black.withOpacity(0.6),   // Black for Idle/Other
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Icon(
            _showCycleComplete
                ? Icons.check_circle
                : (_currentClass == 0 ? Icons.air : Icons.mic),
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    ),
    );
  }
}
