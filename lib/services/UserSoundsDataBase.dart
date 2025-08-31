import 'package:hive/hive.dart';

class UserSoundsDatabase {
  static final UserSoundsDatabase _instance = UserSoundsDatabase._internal();
  UserSoundsDatabase._internal();

  factory UserSoundsDatabase() {
    return _instance;
  }

  final _shortBox = Hive.box('userShortSounds');
  final _longBox = Hive.box('userLongSounds');

  final Map<String, String> _userShortSounds = {};
  final Map<String, String> _userLongSounds = {};

  Map<String,String> get userShortSounds => Map.unmodifiable(_userShortSounds);
  Map<String,String> get userLongSounds => Map.unmodifiable(_userLongSounds);

  void loadData()
  {
    final storedMap = _shortBox.get('userShortSounds');
    if (storedMap is Map) {
      _userShortSounds.addAll(storedMap.cast<String, String>());
    }

    final storedMapLong = _longBox.get('userLongSounds');
    if (storedMapLong is Map) {
      _userLongSounds.addAll(storedMapLong.cast<String, String>());
    }
  }

  void addShortSound(MapEntry<String, String> soundPath) {
    if (!_userShortSounds.containsKey(soundPath.key)) {
      _userShortSounds[soundPath.key] = soundPath.value;
      updateDatabase();
    }
  }

  void addLongSound(MapEntry<String, String> soundPath) {
    if (!_userLongSounds.containsKey(soundPath.key)) {
      _userLongSounds[soundPath.key] = soundPath.value;
      updateDatabase();
    }
  }

  void removeShortSound(String soundPath) {
    _userShortSounds.remove(soundPath);
    updateDatabase();
  }

  void removeLongSound(String soundPath) {
    _userLongSounds.remove(soundPath);
    updateDatabase();
  }

  void updateDatabase() {
    _shortBox.put('userShortSounds', _userShortSounds);
    _longBox.put('userLongSounds', _userLongSounds);
  }

}