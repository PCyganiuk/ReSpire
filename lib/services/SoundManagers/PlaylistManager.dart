import 'dart:async';
import 'dart:developer' as dev;

import 'package:respire/services/SoundManagers/SingleSoundManager.dart';

class PlaylistManager {

  SingleSoundManager _delegate = SingleSoundManager();

  ///Playlist only variables
  int _currentIndex = 0;
  bool _paused = false;
  bool _stopped = false;
  bool _isPlaying = false;
  var _playlistCompleter = Completer<void>();
  List<String> _playlist = [];
  
  ///Use only to play a new playlist
  Future<void> playPlaylist(List<String> soundNames) async {
    if(soundNames.isEmpty) {
      dev.log('PlaylistManager: Cannot play empty playlist');
      return;
    }
    
    dev.log('PlaylistManager: Starting playlist with ${soundNames.length} sounds');
    
    // Stop any currently playing playlist first
    if (_isPlaying) {
      dev.log('PlaylistManager: Stopping previous playlist');
      completePlaylist();
    }
    
    _currentIndex = 0;
    _paused = false;
    _stopped = false;
    _isPlaying = true;
    _playlist = soundNames;
    
    for(String soundName in _playlist){
      await _delegate.loadSound(soundName);
    }
    
    await resumePlaylist();
  }

  ///Use to resume the playlist after it's been paused
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
    
    if (_currentIndex >= _playlist.length){
      _currentIndex = 0;
      dev.log('PlaylistManager: Looping back to start');
    }

    String soundName = _playlist[_currentIndex];
    dev.log('PlaylistManager: Playing sound $_currentIndex/${_playlist.length}: $soundName');
    
    final player = _delegate.getPlayer(soundName);
    
    if (player == null) {
      dev.log('PlaylistManager: Player not found for $soundName, skipping');
      _currentIndex++;
      if (!_stopped && !_paused) {
        _playNextSound();
      }
      return;
    }

    _delegate.playSound(soundName);

    //Wait for sound to complete or be interrupted
    await Future.any([player.onPlayerComplete.first, _playlistCompleter.future]);
    
    if(_paused || _stopped) {
      dev.log('PlaylistManager: Playback interrupted (paused=$_paused, stopped=$_stopped)');
      return;
    }

    _currentIndex++;
    _playNextSound();
  }

  ///Use to pause the playlist
  Future<void> pausePlaylist() async {
    if(_paused) {
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

  ///Use when the playlist will not be played anymore.
  ///Eg. When we want to stop it completly from playing at the end of a training.
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