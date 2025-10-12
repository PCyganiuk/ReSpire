import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:respire/components/BreathingPage/TrainingParser.dart';
import 'package:respire/components/Global/Step.dart' as training_step;
import 'package:respire/services/SoundManager.dart';
import 'package:respire/services/TextToSpeechService.dart';
import 'package:respire/services/TranslationProvider/TranslationProvider.dart';

class TrainingController {
  Timer? _timer;
  final TrainingParser parser;
  final ValueNotifier<Queue<training_step.Step?>> stepsQueue =
      ValueNotifier(Queue<training_step.Step?>());
  final Queue<String?> _phaseNameQueue = Queue<String?>();
  final ValueNotifier<int> second = ValueNotifier(3);
  final ValueNotifier<bool> isPaused = ValueNotifier(false);
  final ValueNotifier<int> stepsCount = ValueNotifier(0);
  final ValueNotifier<String> currentPhaseName = ValueNotifier('');

  final int _updateInterval = 100; //in milliseconds
  final int _stepDelayDuration = 600; //in milliseconds

  int _remainingTime = 0; //in milliseconds
  int _nextRemainingTime = 0; //in milliseconds
  int _newStepRemainingTime = 0; //in milliseconds

  int _stepDelayRemainingTime = 600; //in milliseconds

  bool _finished = false;
  bool _stepDelay = true;
  int _stopTimer = 2;

  String? _currentSound;

  TranslationProvider translationProvider = TranslationProvider();

  TrainingController(this.parser) {
    SoundManager().stopAllSounds();
    _remainingTime = parser.training.settings.preparationDuration * 1000;
    _preloadSteps();
    _start();
  }

  void _preloadSteps() {
    stepsQueue.value.add(null);
    _phaseNameQueue.add(null);
    _updateCurrentPhaseLabel();
    _fetchNextStep();
    _nextRemainingTime = _newStepRemainingTime;
    _fetchNextStep();
    //_fetchNextStep();
  }

  void _fetchNextStep() {
    var instructionData = parser.nextInstruction();

    //no more instructions
    if (instructionData == null) {
      _finished = true;
      stepsQueue.value.add(null);
      _phaseNameQueue.add(null);
      return;
    }

    //reading instruction
    stepsQueue.value.add(instructionData["step"]);
    _phaseNameQueue.add(_resolvePhaseName(
        instructionData["phaseName"] as String?, parser.phaseID));
    _newStepRemainingTime = instructionData["remainingTime"];
  }

  void pause() {
    isPaused.value = true;
    if (_currentSound != null) {
      SoundManager().pauseSound(_currentSound!);
    }
    _timer?.cancel();
  }

  void resume() {
    isPaused.value = false;
    if (_currentSound != null) {
      SoundManager().playSound(_currentSound!);
    }
    _start();
  }

  Future<void> handleStepChange(training_step.Step step) async {
    await SoundManager()
        .pauseSoundFadeOut(_currentSound, (_stepDelayDuration / 2).toInt());
    _currentSound = step.sound;
    await SoundManager()
        .playSoundFadeIn(_currentSound, (_stepDelayDuration / 2).toInt());
  }

  void _start() {
    int previousSecond = _remainingTime ~/ 1000;
    _timer =
        Timer.periodic(Duration(milliseconds: _updateInterval), (Timer timer) {
      //voice
      if (previousSecond > _remainingTime ~/ 1000 && _stopTimer != 0) {
        previousSecond = _remainingTime ~/ 1000;
        second.value = previousSecond + 1;
        TextToSpeechService().readNumber(previousSecond + 1);
      }

      //time update
      if (_remainingTime >= _updateInterval) {
        _remainingTime -= _updateInterval;
      }

      //step dalay for reading the name
      else if (_stepDelay && _stopTimer != 0) {
        stepsCount.value++;
        _updateCurrentPhaseLabel(peekNext: true);
        if (stepsQueue.value.elementAt(1) != null) {
          second.value = 0;
          training_step.Step _step = stepsQueue.value.elementAt(1)!;
          handleStepChange(_step);
          String stepName =
              translationProvider.getTranslation("StepType.${_step.stepType.name}");
          TextToSpeechService().speak(stepName);
        }
        _stepDelay = false;

        //step delay time update
      } else if (_stepDelayRemainingTime >= _updateInterval) {
        _stepDelayRemainingTime -= _updateInterval;

        //two last steps
      } else if (_finished) {
        //last step
        if (_stopTimer == 0) {
          second.value = 0;
          _timer?.cancel();
          currentPhaseName.value = '';

          //one step before last
        } else {
          stepsQueue.value.removeFirst();
          if (_phaseNameQueue.isNotEmpty) {
            _phaseNameQueue.removeFirst();
          }
          stepsQueue.value.add(null);
          _phaseNameQueue.add(null);
          stepsQueue.value = Queue<training_step.Step?>.from(stepsQueue.value);
          _updateCurrentPhaseLabel();
          _remainingTime = _nextRemainingTime;
          previousSecond = _remainingTime ~/ 1000;
          _stopTimer--;
          _stepDelay = true;
          _stepDelayRemainingTime = _stepDelayDuration;
        }

        //new step updates
      } else {
        stepsQueue.value.removeFirst();
        if (_phaseNameQueue.isNotEmpty) {
          _phaseNameQueue.removeFirst();
        }
        _remainingTime = _nextRemainingTime;
        _nextRemainingTime = _newStepRemainingTime;
        previousSecond = _remainingTime ~/ 1000;
        _fetchNextStep();
        stepsQueue.value = Queue<training_step.Step?>.from(stepsQueue.value);
        _updateCurrentPhaseLabel();
        _stepDelay = true;
        _stepDelayRemainingTime = _stepDelayDuration;
      }
    });
  }

  void dispose() {
    TextToSpeechService().stopSpeaking();
    SoundManager().stopAllSounds();
    _timer?.cancel();
    currentPhaseName.dispose();
  }

  String _resolvePhaseName(String? rawName, int phaseIndex) {
    final cleaned = rawName?.trim();
    if (cleaned != null && cleaned.isNotEmpty) {
      return cleaned;
    }
    return _defaultStageName(phaseIndex);
  }

  void _updateCurrentPhaseLabel({bool peekNext = false}) {
    String? name;
    if (peekNext) {
      if (_phaseNameQueue.length > 1) {
        name = _phaseNameQueue.elementAt(1);
      } else {
        name = null;
      }
    } else {
      if (_phaseNameQueue.isEmpty) {
        name = null;
      } else {
        name = _phaseNameQueue.first;
      }
    }

    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      currentPhaseName.value = '';
    } else {
      currentPhaseName.value = trimmed;
    }
  }

  String _defaultStageName(int index) {
    final template = translationProvider
        .getTranslation("BreathingPage.default_stage_name");
    if (template.contains('{number}')) {
      return template.replaceAll('{number}', (index + 1).toString());
    }
    return 'Stage ${index + 1}';
  }
}
