import 'package:hive/hive.dart';
import 'package:respire/components/Global/SoundAsset.dart';
import 'package:respire/services/SoundManagers/ISoundManager.dart';
import 'package:respire/services/SoundManagers/SoundManager.dart';

class UserSoundsDatabase {
  static final UserSoundsDatabase _instance = UserSoundsDatabase._internal();
  UserSoundsDatabase._internal();

  factory UserSoundsDatabase() {
    return _instance;
  }

  final _shortBox = Hive.box('userShortSounds');
  final _longBox = Hive.box('userLongSounds');

  final Map<String, SoundAsset> _userShortSounds = {};
  final Map<String, SoundAsset> _userLongSounds = {};

  Map<String,SoundAsset> get userShortSounds => Map.unmodifiable(_userShortSounds);
  Map<String,SoundAsset> get userLongSounds => Map.unmodifiable(_userLongSounds);

  void loadData()
  {
    final storedMap = _shortBox.get('userShortSounds');
    if (storedMap is Map) {
      _userShortSounds.addAll(storedMap.cast<String, SoundAsset>());
    }

    final storedMapLong = _longBox.get('userLongSounds');
    if (storedMapLong is Map) {
      _userLongSounds.addAll(storedMapLong.cast<String, SoundAsset>());
    }
  }

  void addShortSound(SoundAsset sound) {
    if (!_userShortSounds.containsKey(sound.name)) {
      _userShortSounds[sound.name] = sound;
      updateDatabase();
    }
  }

  void addLongSound(SoundAsset sound) {
    if (!_userLongSounds.containsKey(sound.name)) {
      _userLongSounds[sound.name] = sound;
      updateDatabase();
    }
  }

  void removeSound(String soundName, SoundListType type) {
    if (type == SoundListType.longSounds) {
      _userLongSounds.remove(soundName);
    } else {
      _userShortSounds.remove(soundName);
    }
    updateDatabase();
    postRemoveSound(soundName, type);
  }

  void postRemoveSound(String soundName, SoundListType type) {
    SoundManager().removeUserSound(soundName, type);
  }

  void updateDatabase() {
    _shortBox.put('userShortSounds', _userShortSounds);
    _longBox.put('userLongSounds', _userLongSounds);
    SoundManager().refreshSoundsList();
  }

}