import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:respire/components/BreathingPage/TrainingParser.dart';
import 'package:respire/components/Global/Settings.dart';
import 'package:respire/components/Global/SoundAsset.dart';
import 'package:respire/components/Global/SoundScope.dart';
import 'package:respire/components/Global/Sounds.dart';
import 'package:respire/components/Global/BreathingPhase.dart' as breathing_phase;
import 'package:respire/components/Global/TrainingStage.dart';
import 'package:respire/services/BinauralBeatGenerator.dart';
import 'package:respire/services/SoundManagers/PlaylistManager.dart';
import 'package:respire/services/SoundManagers/SoundManager.dart';
import 'package:respire/services/TextToSpeechService.dart';
import 'package:respire/services/TranslationProvider/TranslationProvider.dart';
import 'BreathingToneController.dart';

class TrainingController {
  Timer? _timer;
  final TrainingParser parser;

  VoidCallback? onTrainingFinished;
  VoidCallback? onEndingStarted;

  final ValueNotifier<Queue<breathing_phase.BreathingPhase?>>
  breathingPhasesQueue =
  ValueNotifier(Queue<breathing_phase.BreathingPhase?>());

  final Queue<String?> _trainingStageNameQueue = Queue<String?>();
  final Queue<String?> _trainingStageIdQueue = Queue<String?>();
  final Queue<int?> _cycleIndexQueue = Queue<int?>();
  final Queue<int?> _stageExecutionIndexQueue = Queue<int?>();

  final ValueNotifier<int> second = ValueNotifier(3);
  final ValueNotifier<bool> isPaused = ValueNotifier(false);
  final ValueNotifier<int> breathingPhasesCount = ValueNotifier(0);
  final ValueNotifier<String> currentTrainingStageName =
  ValueNotifier('');
  final ValueNotifier<int> currentStageIndex = ValueNotifier(0);
  final ValueNotifier<int> totalStages = ValueNotifier(0);
  final ValueNotifier<int> currentCycleIndex = ValueNotifier(0);

  bool playCycleSound = false;

  final ValueNotifier<int> totalCycles = ValueNotifier(0);
  final ValueNotifier<bool> showLabels = ValueNotifier(true);
  final ValueNotifier<int> trainingElapsedMs = ValueNotifier(0);
  final ValueNotifier<int> remainingMs = ValueNotifier(0);

  final int _updateInterval = 25;
  int countingStep = 0;

  int _remainingTime = 0;
  int _nextRemainingTime = 0;
  int _newBreathingPhaseRemainingTime = 0;

  late int _endingDuration;
  late int preparationDurationMs;

  List<TrainingStage> trainingStages = [];

  bool end = false;
  bool _finishedLoadingBreathingPhases = false;
  bool _nextPhaseSoundPlayed = false;
  int _stopTimer = 2;

  late Sounds _sounds;
  late Settings _settings;

  String? _currentSound;
  String? _currentTrainingStageId;

  late SoundManager soundManager;
  late PlaylistManager playlistManager;
  late BinauralBeatGenerator binauralGenerator;
  late BreathingToneController breathingToneController;

  bool _isUsingPlaylist = false;
  bool _preparationPhaseCompleted = false;
  bool _endingInitiated = false;

  late BuildContext _context;

  TranslationProvider translationProvider = TranslationProvider();

  // ---------------------------------------------------------------------------
  // COUNTING SOUND STATE
  // ---------------------------------------------------------------------------

  /// Training time at which the last counting sound was handled.
  ///
  /// This must NOT be a local variable inside _start(), because _start()
  /// is also called after pause/resume.
  int _lastCountingTimeMs = 0;

  TrainingController(this.parser) {
    soundManager = SoundManager();
    soundManager.stopAllSounds();

    playlistManager = PlaylistManager();
    binauralGenerator = BinauralBeatGenerator();

    if (parser.training.settings.breathingSoundEnabled) {
      breathingToneController =
          BreathingToneController(baseFrequency: 100.0);
    }

    countingStep = parser.training.sounds.countingFrequencyMs.toInt();

    _sounds = parser.training.sounds;
    _settings = parser.training.settings;

    preparationDurationMs = _settings.preparationDuration * 1000;

    showLabels.value = false;

    // Initialize current stage ID to the first stage
    if (parser.training.trainingStages.isNotEmpty) {
      _currentTrainingStageId = parser.training.trainingStages[0].id;

      totalStages.value =
          parser.countTotalStages();

      trainingStages =
          parser.training.trainingStages;

      currentStageIndex.value = 1;
      currentCycleIndex.value = 1;

      totalCycles.value =
          parser.training.trainingStages[0].reps;
    }

    // Binaural beats will be started after preparation phase
    dev.log(
      'TrainingController: '
          'binauralBeatsEnabled=${_settings.binauralBeatsEnabled}',
    );

    _preloadBreathingPhases();
    _initializePreparationSound();
    _loadEndingSoundDuration();

    // Global playlist will be started after preparation phase.
  }

  void setContext(BuildContext context) {
    _context = context;
  }

  void _initializePreparationSound() async {
    final bool hasSound =
        _sounds.preparationTrack.type != SoundType.none;

    _currentSound =
    hasSound ? _sounds.preparationTrack.name : null;

    if (_settings.preparationDuration == 0 && hasSound) {
      final duration =
      await soundManager.getSoundDuration(_currentSound!);

      _remainingTime = duration!.inMilliseconds;
    } else {
      _remainingTime =
          _settings.preparationDuration * 1000;
    }

    second.value = max(1, (_remainingTime / 1000).ceil());

    _start();
  }

  void _loadEndingSoundDuration() async {
    if (_settings.endingDuration == 0 &&
        _sounds.endingTrack.type != SoundType.none) {
      _endingDuration =
          (await soundManager.getSoundDuration(
            _sounds.endingTrack.name,
          ))!.inMilliseconds;
    } else {
      _endingDuration =
          _settings.endingDuration * 1000;
    }
  }

  void _preloadBreathingPhases() {
    breathingPhasesQueue.value.add(null);
    _logQueue('ADD', phase: null);

    _trainingStageNameQueue.add(null);
    _trainingStageIdQueue.add(null);
    _stageExecutionIndexQueue.add(null);

    _updateCurrentTrainingStageLabel();

    _fetchNextBreathingPhase();

    _nextRemainingTime =
        _newBreathingPhaseRemainingTime;

    _fetchNextBreathingPhase();

    if (parser.training.settings.breathingSoundEnabled) {
      _prepareBreathingTone();
    }
  }

  void _prepareBreathingTone() {
    final List<BreathingPhase> phases = [];

    for (final stage in trainingStages) {
      for (int i = 0; i < stage.reps; i++) {
        for (final phase in stage.breathingPhases) {
          phases.add(
            BreathingPhase(
              phase: _mapPhaseType(
                phase.breathingPhaseType,
              ),
              durationSeconds: phase.duration,
            ),
          );
        }
      }
    }

    breathingToneController.prepareTraining(phases);
  }

  BreathingAudioPhase _mapPhaseType(
      breathing_phase.BreathingPhaseType type,
      ) {
    switch (type) {
      case breathing_phase.BreathingPhaseType.inhale:
        return BreathingAudioPhase.inhale;

      case breathing_phase.BreathingPhaseType.exhale:
        return BreathingAudioPhase.exhale;

      case breathing_phase.BreathingPhaseType.retention:
        return BreathingAudioPhase.retention;

      case breathing_phase.BreathingPhaseType.recovery:
        return BreathingAudioPhase.recovery;
    }
  }

  void _fetchNextBreathingPhase() {
    final instructionData = parser.nextInstruction();

    if (instructionData == null) {
      _finishedLoadingBreathingPhases = true;

      breathingPhasesQueue.value.add(null);
      _logQueue('ADD (finish)', phase: null);

      _trainingStageNameQueue.add(null);
      _trainingStageIdQueue.add(null);
      _stageExecutionIndexQueue.add(null);

      dev.log(
        'TrainingController: No more phases to fetch',
      );

      return;
    }

    _cycleIndexQueue.add(
      instructionData["doneReps"],
    );

    _stageExecutionIndexQueue.add(
      instructionData["stageExecutionIndex"] as int?,
    );

    breathingPhasesQueue.value.add(
      instructionData["breathingPhase"],
    );

    _logQueue(
      'ADD',
      phase: instructionData["breathingPhase"],
    );

    _trainingStageNameQueue.add(
      _resolveTrainingStageName(
        instructionData["trainingStageName"] as String?,
        parser.trainingStageID,
      ),
    );

    String? stageId;

    if (parser.trainingStageID <
        parser.training.trainingStages.length) {
      stageId =
          parser.training
              .trainingStages[parser.trainingStageID]
              .id;
    }

    _trainingStageIdQueue.add(stageId);

    dev.log(
      'TrainingController: Fetched phase for stage: '
          '$stageId '
          '(parser.trainingStageID=${parser.trainingStageID})',
    );

    _newBreathingPhaseRemainingTime =
    instructionData["remainingTime"];
  }

  void _logQueue(
      String action, {
        breathing_phase.BreathingPhase? phase,
      }) {
    final List<String> queueNames =
    breathingPhasesQueue.value.map((p) {
      if (p == null) {
        return 'null';
      }

      return '${p.breathingPhaseType.name} '
          '(${p.duration ~/ 1000}s)';
    }).toList();

    final phaseName = phase == null
        ? 'null'
        : '${phase.breathingPhaseType.name} '
        '(${phase.duration ~/ 1000}s)';

    dev.log(
      '[QUEUE] $action: $phaseName | '
          'Queue: [$queueNames]',
    );
  }

  void pause() {
    isPaused.value = true;

    if (!_preparationPhaseCompleted || _endingInitiated) {
      soundManager.pauseSound(_currentSound);

      _timer?.cancel();

      return;
    }

    // Stop all sounds to account for longer counting sounds
    // that are not stored in _currentSound.
    soundManager.stopAllSounds();

    if (parser.training.settings.breathingSoundEnabled) {
      breathingToneController.pause();
    }

    if (_isUsingPlaylist) {
      playlistManager.pausePlaylist();
    }

    if (_settings.binauralBeatsEnabled) {
      binauralGenerator.pause();
    }

    _timer?.cancel();
  }

  void resume() {
    isPaused.value = false;

    if (!_preparationPhaseCompleted || _endingInitiated) {
      soundManager.playSound(_currentSound);

      _timer?.cancel();

      _start();

      return;
    }

    if (_isUsingPlaylist) {
      playlistManager.resumePlaylist();
    }

    if (parser.training.settings.breathingSoundEnabled) {
      breathingToneController.resume();
    }

    if (_settings.binauralBeatsEnabled) {
      binauralGenerator.resume();
    }

    _start();
  }

  void _playCountingSound(int currentSecond) {
    if (_settings.breathingSoundEnabled) {
      return;
    }

    switch (_sounds.countingSound.type) {
      case SoundType.voice:
      // TextToSpeechService().readNumber(currentSecond);
        break;

      case SoundType.none:
        break;

      default:
        soundManager.playSound(
          _sounds.countingSound.name,
        );
        break;
    }
  }

  Future<void> _playEndingSound(
      String? endingBackgroundSound,
      int changeTime,
      ) async {
    if (_currentSound != null) {
      await soundManager.pauseSoundFadeOut(
        _currentSound,
        changeTime,
      );
    }

    _currentSound = endingBackgroundSound;

    if (endingBackgroundSound != null) {
      soundManager.playSoundFadeIn(
        endingBackgroundSound,
        changeTime,
      );
    }
  }

  void _playShortSound(String soundName) {
    soundManager.playSound(soundName);

    Future.delayed(
      const Duration(seconds: 1),
          () {
        soundManager.stopSound(soundName);
      },
    );
  }

  void _playPreBreathingPhaseSound(
      breathing_phase.BreathingPhase breathingPhase,
      ) {
    if (_settings.breathingSoundEnabled) {
      return;
    }

    switch (
    breathingPhase.sounds.preBreathingPhase.type) {
      case SoundType.voice:
        final String breathingPhaseName =
        translationProvider.getTranslation(
          "BreathingPhaseType."
              "${breathingPhase.breathingPhaseType.name}",
        );

        TextToSpeechService().speak(
          breathingPhaseName,
        );

        break;

      case SoundType.none:
        break;

      default:
        _playShortSound(
          breathingPhase.sounds.preBreathingPhase.name,
        );

        break;
    }
  }

  bool triggered = false;

  // Switch to a new stage's playlist
  void _switchToStagePlaylist(String stageId) {
    if (_sounds.backgroundSoundScope !=
        SoundScope.perStage) {
      return;
    }

    if (_isUsingPlaylist) {
      playlistManager.completePlaylist();
      _isUsingPlaylist = false;
    }

    if (_sounds.stagePlaylists.containsKey(stageId) &&
        _sounds.stagePlaylists[stageId]!.isNotEmpty) {
      final playlist =
      _sounds.stagePlaylists[stageId]!;

      _isUsingPlaylist = true;

      playlistManager.playPlaylist(
        playlist.map((s) => s.name).toList(),
      );

      _currentSound = null;

      dev.log(
        'Switched to stage playlist: '
            '$stageId (${playlist.length} sounds)',
      );
    }
  }

  Future<void> _handleBackgroundSoundChange(
      String? nextBackgroundSound,
      int changeTime,
      ) async {
    if (_settings.breathingSoundEnabled) {
      return;
    }

    // Global playlist should play continuously.
    if (_sounds.backgroundSoundScope ==
        SoundScope.global &&
        _sounds.trainingBackgroundPlaylist.isNotEmpty) {
      return;
    }

    // Per-stage playlist is handled separately.
    if (_sounds.backgroundSoundScope ==
        SoundScope.perStage) {
      return;
    }

    if (_sounds.backgroundSoundScope ==
        SoundScope.perPhase ||
        _sounds.backgroundSoundScope ==
            SoundScope.perEveryPhaseInEveryStage) {
      if (_currentSound != null) {
        if (_currentSound != nextBackgroundSound ||
            _currentSound == "Odliczanie") {
          await soundManager.pauseSoundFadeOut(
            _currentSound,
            changeTime,
          );
        }

        if (_currentSound == "Odliczanie") {
          await soundManager.stopSound(
            _currentSound,
          );
        }
      }

      if (nextBackgroundSound != null &&
          (_currentSound != nextBackgroundSound ||
              _currentSound == "Odliczanie")) {
        _currentSound = nextBackgroundSound;

        soundManager.playSoundFadeIn(
          nextBackgroundSound,
          changeTime,
        );
      }

      return;
    }

    if (_currentSound != nextBackgroundSound) {
      if (_isUsingPlaylist) {
        playlistManager.completePlaylist();
        _isUsingPlaylist = false;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // TIMER
  // ---------------------------------------------------------------------------

  void _start() {
    final DateTime startTime = DateTime.now();

    // IMPORTANT:
    //
    // _start() is called both when the training starts and when it resumes.
    // Therefore we must synchronize the counting reference here.
    //
    // Without this, a local `counter = 0` would be recreated after every
    // resume while trainingElapsedMs still contains the old elapsed time.
    // That caused several counting sounds to be played immediately after
    // resume.
    final int currentTrainingTimeMs = max(
      0,
      trainingElapsedMs.value - preparationDurationMs,
    );

    _lastCountingTimeMs = currentTrainingTimeMs;

    soundManager.playSound(_currentSound);

    _timer?.cancel();

    _timer = Timer.periodic(
      Duration(milliseconds: _updateInterval),
          (Timer timer) {
        final DateTime now = DateTime.now();

        final int elapsed =
            now.difference(startTime).inMilliseconds;

        // Recalculate the reference time after every tick.
        //
        // This is more reliable than relying on the nominal 25 ms
        // Timer.periodic interval.
        final int previousElapsed =
            elapsed;

        // We need a separate local timestamp for the next tick.
        //
        // This variable is replaced below through `lastTick`.
      },
    );

    // Replace the temporary timer above with the actual timer implementation.
    _timer?.cancel();

    DateTime lastTick = DateTime.now();

    _timer = Timer.periodic(
      Duration(milliseconds: _updateInterval),
          (Timer timer) {
        final DateTime now = DateTime.now();

        final int elapsed =
            now.difference(lastTick).inMilliseconds;

        lastTick = now;

        if (elapsed <= 0) {
          return;
        }

        trainingElapsedMs.value += elapsed;

        // -------------------------------------------------------------------
        // COUNTING SOUND
        // -------------------------------------------------------------------

        final int trainingTimeMs = max(
          0,
          trainingElapsedMs.value -
              preparationDurationMs,
        );

        if (!end &&
            countingStep > 0 &&
            trainingTimeMs - _lastCountingTimeMs >=
                countingStep) {
          // IMPORTANT:
          // Synchronize to the CURRENT time instead of trying to replay
          // counting events that happened while paused.
          _lastCountingTimeMs = trainingTimeMs;

          if ((!_preparationPhaseCompleted &&
              _sounds.preparationTrack.type ==
                  SoundType.none) ||
              (_preparationPhaseCompleted &&
                  !_endingInitiated) ||
              (_endingInitiated &&
                  _sounds.endingTrack.type ==
                      SoundType.none)) {
            final int currentSecond =
            max(
              1,
              (_remainingTime / 1000).ceil(),
            );

            _playCountingSound(currentSecond);
          }
        }

        // -------------------------------------------------------------------
        // REMAINING TIME
        // -------------------------------------------------------------------

        if (_remainingTime > elapsed) {
          _remainingTime -= elapsed;

          if (breathingPhasesQueue.value.length > 1 &&
              breathingPhasesQueue.value.elementAt(1) !=
                  null) {
            final nextPhase =
            breathingPhasesQueue.value.elementAt(1)!;

            if (!_nextPhaseSoundPlayed &&
                _remainingTime <= 100) {
              _playPreBreathingPhaseSound(
                nextPhase,
              );

              _nextPhaseSoundPlayed = true;
            }

            if (_remainingTime <= 300 &&
                _remainingTime > 200) {
              final breathing_phase.BreathingPhase
              breathingPhase =
              breathingPhasesQueue.value
                  .elementAt(1)!;

              _handleBackgroundSoundChange(
                breathingPhase.sounds.background.name,
                500,
              );
            }
          }
        } else if (_remainingTime > 0) {
          _remainingTime = 0;
        }

        // Keep displayed countdown at minimum 1.
        second.value = max(
          1,
          (_remainingTime / 1000).ceil(),
        );

        remainingMs.value = _remainingTime;

        // -------------------------------------------------------------------
        // PHASE FINISHED
        // -------------------------------------------------------------------

        if (_remainingTime == 0) {
          breathingPhasesCount.value++;

          if (breathingPhasesCount.value == 1 &&
              _settings.binauralBeatsEnabled) {
            final trainingDuration =
            parser.calculateTrainingDurationWithoutPreparation();

            dev.log(
              'Starting binaural beats: '
                  'Left=${_settings.binauralBaseFrequency}Hz, '
                  'Right=${_settings.binauralBeatFrequency + _settings.binauralBaseFrequency}Hz, '
                  'Duration=${trainingDuration}s',
            );

            binauralGenerator.start(
              _settings.binauralBaseFrequency,
              _settings.binauralBeatFrequency +
                  _settings.binauralBaseFrequency,
              durationSeconds: trainingDuration,
            );
          }

          if (breathingPhasesCount.value == 1 &&
              !_preparationPhaseCompleted) {
            soundManager.stopSound(_currentSound);

            _currentSound = null;
            _preparationPhaseCompleted = true;

            showLabels.value = true;

            if (parser.training.settings.breathingSoundEnabled) {
              breathingToneController.play();
            } else {
              if (_sounds.backgroundSoundScope ==
                  SoundScope.global &&
                  _sounds.trainingBackgroundPlaylist
                      .isNotEmpty) {
                _isUsingPlaylist = true;

                playlistManager.playPlaylist(
                  _sounds.trainingBackgroundPlaylist
                      .map((s) => s.name)
                      .toList(),
                );
              } else if (_sounds.backgroundSoundScope ==
                  SoundScope.perStage &&
                  _currentTrainingStageId != null) {
                _switchToStagePlaylist(
                  _currentTrainingStageId!,
                );
              }
            }
          }

          if (breathingPhasesQueue.value.elementAt(1) !=
              null) {
            if (_trainingStageNameQueue.length > 1 &&
                _trainingStageNameQueue.elementAt(1) !=
                    null) {
              _updateCurrentTrainingStageLabel(
                peekNext: true,
              );
            }
          } else {
            currentTrainingStageName.value = '';
          }

          // ---------------------------------------------------------------
          // END / NEXT PHASE
          // ---------------------------------------------------------------

          if (_remainingTime == 0) {
            if (_endingInitiated) {
              second.value = 0;
              end = true;

              _timer?.cancel();

              onTrainingFinished?.call();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_context.mounted && Navigator.canPop(_context)) {
                  Navigator.pop(_context);
                }
              });
              return;
            }

            if (_finishedLoadingBreathingPhases) {
              tryUpdateStageCounter();

              final removedPhase =
              breathingPhasesQueue.value.removeFirst();

              _logQueue(
                'REMOVE',
                phase: removedPhase,
              );

              breathingPhasesQueue.value.add(null);

              _logQueue(
                'ADD (END)',
                phase: null,
              );

              breathingPhasesQueue.value =
              Queue<
                  breathing_phase.BreathingPhase?
              >.from(
                breathingPhasesQueue.value,
              );

              _logQueue('REBUILD');

              _stopTimer--;

              if (_stopTimer == 0) {
                _endingInitiated = true;
                onEndingStarted?.call();

                soundManager.stopSound(
                  _currentSound,
                );

                if (!_settings.breathingSoundEnabled) {
                  _playShortSound(
                    parser.training.sounds
                        .stageChangeSound.name,
                  );
                }

                _remainingTime = _endingDuration;

                _currentSound =
                    _sounds.endingTrack.name;

                if (_isUsingPlaylist) {
                  playlistManager.completePlaylist();
                  _isUsingPlaylist = false;
                }

                showLabels.value = false;

                _playEndingSound(
                  _sounds.endingTrack.name,
                  500,
                );
              } else {
                _remainingTime =
                    _nextRemainingTime;
              }
            } else {
              tryUpdateStageCounter();

              final removedPhase =
              breathingPhasesQueue.value.removeFirst();

              _logQueue(
                'REMOVE',
                phase: removedPhase,
              );

              _remainingTime =
                  _nextRemainingTime;

              if (_trainingStageNameQueue
                  .isNotEmpty) {
                _trainingStageNameQueue
                    .removeFirst();
              }

              if (_trainingStageIdQueue
                  .isNotEmpty) {
                _trainingStageIdQueue
                    .removeFirst();
              }

              _nextRemainingTime =
                  _newBreathingPhaseRemainingTime;

              _fetchNextBreathingPhase();

              _nextPhaseSoundPlayed = false;

              breathingPhasesQueue.value =
              Queue<
                  breathing_phase.BreathingPhase?
              >.from(
                breathingPhasesQueue.value,
              );

              _logQueue('REBUILD');

              _updateCurrentTrainingStageLabel();
            }
          }
        }
      },
    );
  }

  void tryUpdateStageCounter() {
    String? newStageId;

    if (_stageExecutionIndexQueue.length > 1) {
      final nextStageIndex = _stageExecutionIndexQueue.elementAt(1);
      if (nextStageIndex != null) {
        currentStageIndex.value = nextStageIndex;
      }
    }
    if (_stageExecutionIndexQueue.isNotEmpty) {
      _stageExecutionIndexQueue.removeFirst();
    }

    if (_trainingStageIdQueue.length > 1) {
      newStageId =
          _trainingStageIdQueue.elementAt(1);
    }

    if (newStageId != null &&
        _currentTrainingStageId != newStageId) {
      _currentTrainingStageId = newStageId;

      if (!_settings.breathingSoundEnabled) {
        _playShortSound(
          parser.training.sounds
              .stageChangeSound.name,
        );
      }

      for (int i = 0;
      i < parser.training.trainingStages.length;
      i++) {
        if (parser.training.trainingStages[i].id ==
            newStageId) {
          totalCycles.value =
              parser.training.trainingStages[i].reps;
          break;
        }
      }

      if (_sounds.backgroundSoundScope ==
          SoundScope.perStage) {
        _switchToStagePlaylist(
          _currentTrainingStageId!,
        );
      }
    }

    if (_currentTrainingStageId != null) {
      dev.log(
        "Queue: $_cycleIndexQueue "
            "PlayCycle: $playCycleSound",
      );

      if (playCycleSound && !_endingInitiated) {
        if (!_settings.breathingSoundEnabled) {
          _playShortSound(
            parser.training.sounds
                .cycleChangeSound.name,
          );
        }

        playCycleSound = false;
      }

      if (_cycleIndexQueue.length > 1 &&
          _cycleIndexQueue.elementAt(0) !=
              _cycleIndexQueue.elementAt(1) &&
          _cycleIndexQueue.elementAt(0) !=
              totalCycles.value - 1) {
        playCycleSound = true;
      }
    }

    currentCycleIndex.value =
    _cycleIndexQueue.isNotEmpty
        ? 1 +
        (_cycleIndexQueue.removeFirst() ?? 0)
        : 1;
  }

  void dispose() {
    TextToSpeechService().stopSpeaking();

    soundManager.stopAllSounds();

    playlistManager.completePlaylist();

    binauralGenerator.stop();

    _timer?.cancel();

    currentTrainingStageName.dispose();
    currentStageIndex.dispose();

    if (parser.training.settings.breathingSoundEnabled) {
      breathingToneController.dispose();
    }

    totalStages.dispose();
  }

  String _resolveTrainingStageName(
      String? rawName,
      int trainingStageIndex,
      ) {
    final cleaned = rawName?.trim();

    if (cleaned != null && cleaned.isNotEmpty) {
      return cleaned;
    }

    return _defaultStageName(
      trainingStageIndex,
    );
  }

  void _updateCurrentTrainingStageLabel({
    bool peekNext = false,
  }) {
    String? name;

    if (peekNext) {
      if (_trainingStageNameQueue.length > 1) {
        name =
            _trainingStageNameQueue.elementAt(1);
      } else {
        name = null;
      }
    } else {
      if (_trainingStageNameQueue.isEmpty) {
        name = null;
      } else {
        name =
            _trainingStageNameQueue.first;
      }
    }

    final trimmed = name?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      currentTrainingStageName.value = '';
    } else {
      currentTrainingStageName.value = trimmed;
    }
  }

  String _defaultStageName(int index) {
    final template =
    translationProvider.getTranslation(
      "BreathingPage.default_stage_name",
    );

    if (template.contains('{number}')) {
      return template.replaceAll(
        '{number}',
        (index + 1).toString(),
      );
    }

    return 'Stage ${index + 1}';
  }
}