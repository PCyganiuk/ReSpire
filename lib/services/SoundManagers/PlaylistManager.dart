import 'dart:async';
import 'dart:developer' as dev;

import 'package:respire/services/SoundManagers/SingleSoundManager.dart';

class PlaylistManager {

  SingleSoundManager _delegate = SingleSoundManager();

  int _currentIndex = 0;
  bool _paused = false;
  bool _stopped = false;
  bool _isPlaying = false;
  var _playlistCompleter = Completer<void>();
  List<String> _playlist = [];

  static const int _fadeOutDurationMs = 2500;
  static const int _fadeStepMs = 50;

  Future<void> playPlaylist(List<String> soundNames) async {
    if (soundNames.isEmpty) {
      dev.log('PlaylistManager: Cannot play empty playlist');
      return;
    }

    dev.log('PlaylistManager: Starting playlist with ${soundNames.length} sounds');

    if (_isPlaying) {
      dev.log('PlaylistManager: Stopping previous playlist');
      completePlaylist();
    }

    _currentIndex = 0;
    _paused = false;
    _stopped = false;
    _isPlaying = true;
    _playlist = soundNames;

    for (String soundName in _playlist) {
      await _delegate.loadSound(soundName);
    }

    await resumePlaylist();
  }

  Future<void> resumePlaylist() async {
    if (_playlist.isEmpty || _stopped) {
      dev.log('PlaylistManager: Cannot resume - playlist empty or stopped');
      return;
    }

    dev.log('PlaylistManager: Resuming playlist from index $_currentIndex');

    _playlistCompleter = Completer<void>();
    _paused = false;

    _playNextSound();
  }

  void _playNextSound() async {
    if (_stopped || _paused) {
      dev.log('PlaylistManager: Stopped playing (stopped=$_stopped, paused=$_paused)');
      return;
    }

    if (_playlist.isEmpty) {
      dev.log('PlaylistManager: Playlist is empty');
      return;
    }

    if (_currentIndex >= _playlist.length) {
      _currentIndex = 0;
      dev.log('PlaylistManager: Looping back to start');
    }

    final String soundName = _playlist[_currentIndex];
    dev.log('PlaylistManager: Playing sound ${_currentIndex + 1}/${_playlist.length}: $soundName');

    final player = _delegate.getPlayer(soundName);

    if (player == null) {
      dev.log('PlaylistManager: Player not found for $soundName, skipping');
      _currentIndex++;
      if (!_stopped && !_paused) _playNextSound();
      return;
    }

    // Fade in
    await player.setVolume(0.0);
    _delegate.playSound(soundName);
    await _fadeIn(player);

    // Get duration so we know when to start fading out
    final duration = await player.getDuration();

    if (duration != null) {
      final waitBeforeFadeMs = duration.inMilliseconds - _fadeOutDurationMs - _fadeOutDurationMs;

      if (waitBeforeFadeMs > 0) {
        await Future.any([
          Future.delayed(Duration(milliseconds: waitBeforeFadeMs)),
          _playlistCompleter.future,
        ]);
      }

      if (_paused || _stopped) return;

      // Fade out
      await _fadeOut(player);

      if (_paused || _stopped) return;

      await _delegate.stopSound(soundName);
      await player.setVolume(1.0);
    } else {
      // Fallback: no fade, just wait for natural completion
      await Future.any([
        player.onPlayerComplete.first,
        _playlistCompleter.future,
      ]);
    }

    if (_paused || _stopped) return;

    _currentIndex++;
    _playNextSound();
  }

  Future<void> _fadeIn(dynamic player) async {
    final int steps = (_fadeOutDurationMs / _fadeStepMs).ceil();
    final double delta = 1.0 / steps;
    double volume = 0.0;

    for (int i = 0; i < steps; i++) {
      if (_stopped || _paused) return;
      volume += delta;
      volume = volume.clamp(0.0, 1.0);
      await player.setVolume(volume);
      await Future.delayed(Duration(milliseconds: _fadeStepMs));
    }
    await player.setVolume(1.0);
  }

  Future<void> _fadeOut(dynamic player) async {
    final int steps = (_fadeOutDurationMs / _fadeStepMs).ceil();
    final double delta = 1.0 / steps;
    double volume = 1.0;

    for (int i = 0; i < steps; i++) {
      if (_stopped || _paused) return;
      volume -= delta;
      volume = volume.clamp(0.0, 1.0);
      await player.setVolume(volume);
      await Future.delayed(Duration(milliseconds: _fadeStepMs));
    }
    await player.setVolume(0.0);
  }

  Future<void> pausePlaylist() async {
    if (_paused) {
      dev.log('PlaylistManager: Already paused');
      return;
    }

    dev.log('PlaylistManager: Pausing playlist');

    if (!_playlistCompleter.isCompleted) {
      _playlistCompleter.complete();
    }

    final currentSound = _delegate.currentlyPlaying.value;
    if (currentSound != null) {
      _delegate.pauseSound(currentSound);
    }
    _paused = true;
  }

  void completePlaylist() {
    if (_stopped) {
      dev.log('PlaylistManager: Already stopped');
      return;
    }

    dev.log('PlaylistManager: Completing playlist');

    _stopped = true;
    _paused = false;
    _isPlaying = false;
    _playlist = [];
    _currentIndex = 0;

    if (!_playlistCompleter.isCompleted) {
      _playlistCompleter.complete();
    }

    _delegate.stopAllSounds();
  }
}