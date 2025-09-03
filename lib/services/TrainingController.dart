import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:respire/components/BreathingPage/TrainingParser.dart';
import 'package:respire/components/Global/Sounds.dart';
import 'package:respire/components/Global/Step.dart' as training_step;
import 'package:respire/services/SoundManager.dart';
import 'package:respire/services/TextToSpeechService.dart';
import 'package:respire/services/TranslationProvider/TranslationProvider.dart';

class TrainingController {
  Timer? _timer;
  final TrainingParser parser;
  final ValueNotifier<Queue<training_step.Step?>> stepsQueue =
      ValueNotifier(Queue<training_step.Step?>());
  final ValueNotifier<int> second = ValueNotifier(3);
  final ValueNotifier<bool> isPaused = ValueNotifier(false);
  final ValueNotifier<int> stepsCount = ValueNotifier(0);

  final int _updateInterval = 100; //in milliseconds
  final int _stepDelayDuration = 600; //in milliseconds

  int _remainingTime = 0; //in milliseconds
  int _nextRemainingTime = 0; //in milliseconds
  int _newStepRemainingTime = 0; //in milliseconds

  int _stepDelayRemainingTime = 600; //in milliseconds

  bool _finished = false;
  bool _stepDelay = true;
  int _stopTimer = 2;

  late Sounds _sounds;

  String? _currentSound;

  TranslationProvider translationProvider = TranslationProvider();

  TrainingController(this.parser) {
    SoundManager().stopAllSounds();
    _remainingTime = parser.training.settings.preparationDuration * 1000;
    _sounds = parser.training.sounds;
    _preloadSteps();
    _start();
  }

  void _preloadSteps() {
    stepsQueue.value.add(null);
    _fetchNextStep();
    _nextRemainingTime = _newStepRemainingTime;
    _fetchNextStep();
  }

  void _fetchNextStep() {
    var instructionData = parser.nextInstruction();
    if (instructionData == null) {
      _finished = true;
      stepsQueue.value.add(null);
      return;
    }
    stepsQueue.value.add(instructionData["step"]);
    _newStepRemainingTime = instructionData["remainingTime"];
  }

  void pause() {
    isPaused.value = true;
    SoundManager().pauseSound(_currentSound);
    _timer?.cancel();
  }

  void resume() {
    isPaused.value = false;
    SoundManager().playSound(_currentSound);
    _start();
  }

  Future<void> _handleBackgroundSoundChange(training_step.Step step) async {
    await SoundManager()
        .pauseSoundFadeOut(_currentSound, (_stepDelayDuration / 2).toInt());
    _currentSound = step.sound;
    await SoundManager()
        .playSoundFadeIn(_currentSound, (_stepDelayDuration / 2).toInt());
  }

  void _playCountingSound(previousSecond) {
    switch (_sounds.countingSound) {
      case "Voice":
        TextToSpeechService().readNumber(previousSecond + 1);
        break;
      case "None":
        break;
      default:
        SoundManager().playSound(_sounds.countingSound);
        break;
    }
  }

  void _playNextStepSound(training_step.StepType stepType, String? soundType) {
    switch (soundType) {
      case "Voice":
        String stepName =
            translationProvider.getTranslation("StepType.${stepType.name}");
        TextToSpeechService().speak(stepName);
        break;
      case "None":
        break;
      default:
        SoundManager().playSound(soundType);
        Future.delayed(const Duration(seconds: 1), () {
          SoundManager().stopSound(soundType);
        });
        break;
    }
  }

  void _handleNextStepSoundPhase(training_step.StepType stepType) {
    switch (stepType) {
      case training_step.StepType.inhale:
        _playNextStepSound(stepType, _sounds.nextInhaleSound);
        break;
      case training_step.StepType.exhale:
        _playNextStepSound(stepType, _sounds.nextExhaleSound);
        break;
      case training_step.StepType.recovery:
        _playNextStepSound(stepType, _sounds.nextRecoverySound);
        break;
      case training_step.StepType.retention:
        _playNextStepSound(stepType, _sounds.nextRetentionSound);
        break;
      default:
        break;
    }
  }

  void _handleNextStepSoundOption(training_step.StepType stepType) {
    switch (_sounds.nextSound) {
      case "global":
        _playNextStepSound(stepType, _sounds.nextGlobalSound);
        break;
      case "phase":
        _handleNextStepSoundPhase(stepType);
        break;
      default:
        break;
    }
  }

  void _start() {
    int previousSecond = _remainingTime ~/ 1000;
    DateTime lastTick = DateTime.now();
    _timer =
        Timer.periodic(Duration(milliseconds: _updateInterval), (Timer timer) {
      final now = DateTime.now();
      final int elapsed = now.difference(lastTick).inMilliseconds;
      lastTick = now;

      // voice countdown (only when decreasing full second)
      if (previousSecond > _remainingTime ~/ 1000 && _stopTimer != 0) {
        previousSecond = _remainingTime ~/ 1000;
        second.value = previousSecond + 1;
        _playCountingSound(previousSecond);
      }

      // time update using real elapsed time to reduce drift
      if (_remainingTime > elapsed) {
        _remainingTime -= elapsed;
      } else if (_remainingTime > 0) {
        _remainingTime = 0; // finish this segment
      }

      // step delay for reading the name (enter delay when main time finished)
      if (_remainingTime == 0 && _stepDelay && _stopTimer != 0) {
        stepsCount.value++;
        if (stepsQueue.value.elementAt(1) != null) {
          second.value = 0;
          training_step.Step _step = stepsQueue.value.elementAt(1)!;
          _handleNextStepSoundOption(_step.stepType);
          _handleBackgroundSoundChange(_step);
        }
        _stepDelay = false;
      } else if (_remainingTime == 0 && _stepDelayRemainingTime > 0) {
        // decrement delay with elapsed time
        if (_stepDelayRemainingTime > elapsed) {
          _stepDelayRemainingTime -= elapsed;
        } else {
          _stepDelayRemainingTime = 0;
        }
      }

      // end of delay period, decide next action
      if (_remainingTime == 0 && _stepDelayRemainingTime == 0) {
        if (_finished) {
          if (_stopTimer == 0) {
            second.value = 0;
            _timer?.cancel();
          } else {
            stepsQueue.value.removeFirst();
            stepsQueue.value.add(null);
            stepsQueue.value =
                Queue<training_step.Step?>.from(stepsQueue.value);
            _remainingTime = _nextRemainingTime;
            previousSecond = _remainingTime ~/ 1000;
            _stopTimer--;
            _stepDelay = true;
            _stepDelayRemainingTime = _stepDelayDuration;
          }
        } else if (!_stepDelay) {
          // start new step
          stepsQueue.value.removeFirst();
          _remainingTime = _nextRemainingTime;
          _nextRemainingTime = _newStepRemainingTime;
          previousSecond = _remainingTime ~/ 1000;
          _fetchNextStep();
          stepsQueue.value =
              Queue<training_step.Step?>.from(stepsQueue.value);
          _stepDelay = true;
          _stepDelayRemainingTime = _stepDelayDuration;
        }
      }
    });
  }

  void dispose() {
    TextToSpeechService().stopSpeaking();
    SoundManager().stopAllSounds();
    _timer?.cancel();
  }
}
