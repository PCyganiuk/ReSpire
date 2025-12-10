import 'package:audioplayers/audioplayers.dart';

class AudioPlayerPool {
  AudioPlayerPool({int size = 0}) {
    for (int i = 0; i < size; i++) {
      _items.add(AudioPlayer());
    }
  }
  
  final List<AudioPlayer> _items = [];
  int _cursor = 0;

  AudioPlayer get next {
    _cursor++;
    if (_cursor >= _items.length) {
      _cursor = 0;
    }
    _items[_cursor].dispose();
    _items[_cursor] = AudioPlayer();
    return _items[_cursor];
  }

  int get length => _items.length;

  void dispose() {
    for (var player in _items) {
      player.dispose();
    }
    _items.clear();
  }
}