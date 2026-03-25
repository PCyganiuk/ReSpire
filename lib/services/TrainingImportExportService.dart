import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:respire/components/Global/SoundAsset.dart';
import 'package:respire/components/Global/Training.dart';
import 'package:respire/services/TrainingJsonConverter.dart';
import 'package:respire/services/TranslationProvider/TranslationProvider.dart';
import 'package:respire/services/UserSoundsDataBase.dart';
import 'package:respire/utils/TextUtils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:respire/services/SoundManagers/SoundManager.dart';

class TrainingImportExportService {

  /// Collects all user sound files referenced in a list of trainings.
  /// Returns a map of { filename -> file bytes }
  static Future<Map<String, Uint8List>> _collectUserSounds(List<Training> trainings) async {
    final Map<String, Uint8List> soundFiles = {};
    final userDb = UserSoundsDatabase();
    final allUserSounds = {
      ...userDb.userShortSounds,
      ...userDb.userLongSounds,
      ...userDb.userCountingSounds,
    };

    // Gather every SoundAsset referenced in each training
    for (final training in trainings) {
      final sounds = training.sounds;
      final candidates = <SoundAsset>[
        sounds.countingSound,
        sounds.nextSound,
        sounds.preparationTrack,
        sounds.endingTrack,
        sounds.stageChangeSound,
        sounds.cycleChangeSound,
        ...sounds.trainingBackgroundPlaylist,
        ...sounds.breathingPhaseCues.values,
        ...sounds.breathingPhaseBackgrounds.values,
        ...sounds.stagePlaylists.values.expand((list) => list),
        ...sounds.perEveryPhaseBreathingPhaseCues.values
            .expand((map) => map.values),
        ...sounds.perEveryPhaseBreathingPhaseBackgrounds.values
            .expand((map) => map.values),
      ];

      for (final asset in candidates) {
        if (asset.type == SoundType.none || asset.type == SoundType.voice) continue;
        if (!allUserSounds.containsKey(asset.name)) continue; // skip built-in sounds
        if (soundFiles.containsKey(asset.name)) continue; // already added

        final file = File(asset.path);
        if (await file.exists()) {
          soundFiles[asset.name] = await file.readAsBytes();
        }
      }
    }

    return soundFiles;
  }

  static Future<bool> exportTraining(Training training, {String? fileName}) async {
    return exportMultipleTrainings([training], fileName: fileName);
  }

  static Future<bool> exportMultipleTrainings(List<Training> trainings, {String? fileName}) async {
    if (trainings.isEmpty) return false;

    try {
      final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final String defaultFileName = fileName ??
          (trainings.length == 1
              ? '${TextUtils.sanitizeFileName(trainings.first.title)}_training.rsp'
              : 'respire_trainings_$timestamp.rsp');

      // Build zip archive
      final archive = Archive();

      // Add JSON
      final String jsonString = TrainingJsonConverter.toJsonMultiple(trainings);
      final jsonBytes = utf8.encode(jsonString);
      archive.addFile(ArchiveFile('trainings.json', jsonBytes.length, jsonBytes));

      // Add user sound files
      final soundFiles = await _collectUserSounds(trainings);
      for (final entry in soundFiles.entries) {
        archive.addFile(ArchiveFile('sounds/${entry.key}', entry.value.length, entry.value));
      }

      final Uint8List zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: TranslationProvider().getTranslation("FilePicker.save_trainings"),
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['rsp'],
        bytes: zipBytes,
      );

      return outputPath != null;
    } catch (e) {
      debugPrint('Error during training export: $e');
      return false;
    }
  }

  static Future<Training?> importTraining() async {
    final trainings = await importTrainings();
    if (trainings == null || trainings.isEmpty) return null;
    return trainings.first;
  }

  static Future<List<Training>?> importTrainings() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['rsp', 'json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final PlatformFile file = result.files.single;

      Uint8List? fileBytes;
      if (file.bytes != null) {
        fileBytes = file.bytes!;
      } else if (file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      }

      if (fileBytes == null) return null;

      // Handle plain JSON (legacy)
      if (file.name.endsWith('.json')) {
        final jsonString = utf8.decode(fileBytes);
        return TrainingJsonConverter.fromJsonMultiple(jsonString);
      }

      // Handle zip
      return await _importFromZip(fileBytes);
    } catch (e) {
      debugPrint('Error during training import: $e');
      return null;
    }
  }

  static Future<List<Training>?> _importFromZip(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final jsonFile = archive.findFile('trainings.json');
    if (jsonFile == null) {
      debugPrint('No trainings.json found in rsp file');
      return null;
    }
    final jsonString = utf8.decode(jsonFile.content as List<int>);

    // ── 1. Register sounds FIRST ──────────────────────────────────────
    final userDb = UserSoundsDatabase();
    final appDir = await getApplicationDocumentsDirectory();
    final soundsDir = Directory('${appDir.path}/user_sounds');
    if (!await soundsDir.exists()) {
      await soundsDir.create(recursive: true);
    }

    for (final archiveFile in archive.files) {
      if (!archiveFile.name.startsWith('sounds/')) continue;
      if (!archiveFile.isFile) continue;

      final soundFileName = archiveFile.name.replaceFirst('sounds/', '');
      if (soundFileName.isEmpty) continue;

      final destPath = '${soundsDir.path}/$soundFileName';
      final destFile = File(destPath);

      if (!await destFile.exists()) {
        await destFile.writeAsBytes(archiveFile.content as List<int>);
      }

      final allUser = {
        ...userDb.userShortSounds,
        ...userDb.userLongSounds,
        ...userDb.userCountingSounds,
      };
      if (allUser.containsKey(soundFileName)) {
        debugPrint('Sound already registered: $soundFileName');
        continue;
      }

      final ext = soundFileName.split('.').last.toLowerCase();
      final isShort = ['wav', 'aiff', 'aif'].contains(ext);

      final asset = SoundAsset(
        name: soundFileName,
        path: destPath,
        type: isShort ? SoundType.cue : SoundType.melody,
      );

      if (isShort) {
        userDb.addShortSound(asset);
      } else {
        userDb.addLongSound(asset);
      }

      debugPrint('Imported user sound: $soundFileName -> $destPath');
    }

    // ── 2. Force refresh so SoundManager._availableSounds is up to date ──
    SoundManager().refreshSoundsList();

    // ── 3. Parse JSON AFTER sounds are registered ─────────────────────
    final trainings = TrainingJsonConverter.fromJsonMultiple(jsonString);

    return trainings;
  }

  static void _remapTrainingSoundPaths(Training training, String soundsDirPath, UserSoundsDatabase userDb) {
    final allUser = {
      ...userDb.userShortSounds,
      ...userDb.userLongSounds,
      ...userDb.userCountingSounds,
    };

    SoundAsset _remap(SoundAsset asset) {
      if (asset.type == SoundType.none || asset.type == SoundType.voice) return asset;
      debugPrint('Trying to remap: name="${asset.name}" type=${asset.type}');
      debugPrint('Available user sounds: ${allUser.keys.toList()}');
      if (!allUser.containsKey(asset.name)) return asset; // built-in, no remap needed
      final localAsset = allUser[asset.name];
      return localAsset ?? asset;
    }

    final sounds = training.sounds;
    sounds.countingSound = _remap(sounds.countingSound);
    sounds.nextSound = _remap(sounds.nextSound);
    sounds.preparationTrack = _remap(sounds.preparationTrack);
    sounds.endingTrack = _remap(sounds.endingTrack);
    sounds.stageChangeSound = _remap(sounds.stageChangeSound);
    sounds.cycleChangeSound = _remap(sounds.cycleChangeSound);

    sounds.trainingBackgroundPlaylist =
        sounds.trainingBackgroundPlaylist.map(_remap).toList();

    sounds.breathingPhaseCues = sounds.breathingPhaseCues
        .map((k, v) => MapEntry(k, _remap(v)));

    sounds.breathingPhaseBackgrounds = sounds.breathingPhaseBackgrounds
        .map((k, v) => MapEntry(k, _remap(v)));

    sounds.stagePlaylists = sounds.stagePlaylists
        .map((k, v) => MapEntry(k, v.map(_remap).toList()));

    sounds.perEveryPhaseBreathingPhaseCues = sounds.perEveryPhaseBreathingPhaseCues
        .map((k, v) => MapEntry(k, v.map((pk, pv) => MapEntry(pk, _remap(pv)))));

    sounds.perEveryPhaseBreathingPhaseBackgrounds = sounds.perEveryPhaseBreathingPhaseBackgrounds
        .map((k, v) => MapEntry(k, v.map((pk, pv) => MapEntry(pk, _remap(pv)))));
  }

  static Future<Training?> importTrainingFromPath(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      if (filePath.endsWith('.rsp')) {
        final trainings = await _importFromZip(bytes);
        return trainings?.isNotEmpty == true ? trainings!.first : null;
      }
      final jsonString = utf8.decode(bytes);
      final trainings = TrainingJsonConverter.fromJsonMultiple(jsonString);
      return trainings.isNotEmpty ? trainings.first : null;
    } catch (e) {
      debugPrint('Error during training import from file $filePath: $e');
      return null;
    }
  }
}