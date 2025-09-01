import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:respire/components/TrainingEditorPage/AudioListTile.dart';
import 'package:respire/services/SoundManager.dart';
import 'package:respire/services/UserSoundsDataBase.dart';
import 'package:respire/theme/Colors.dart';

class AudioSelectionPopup extends StatefulWidget {
  final SoundListType listType;
  final String? selectedValue;
  const AudioSelectionPopup({super.key, required this.listType, required this.selectedValue});

  @override
  State<AudioSelectionPopup> createState() => _AudioSelectionPopupState();
}

class _AudioSelectionPopupState extends State<AudioSelectionPopup>{
  
    final SoundManager _soundManager = SoundManager();
  
  Future<void> _togglePlay(String soundName) async {
    if (_soundManager.currentlyPlaying.value == soundName) {
      await _soundManager.stopSound(soundName);
    } else {
      await _soundManager.playSound(soundName);
    }
  }

  @override
  Widget build(BuildContext context) {
    
    final Map<String,String> userItems = 
      widget.listType == SoundListType.longSounds
          ? UserSoundsDatabase().userLongSounds
          : UserSoundsDatabase().userShortSounds;

    final items = {
      "None": null,
      ..._soundManager.getSounds(widget.listType),
      ...userItems,
    };


    final combinedLength = items.length + (userItems.isNotEmpty ? 1 : 0) + userItems.length;

    return AlertDialog(
      actions: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addCustomSound,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Add Custom Sound", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: darkerblue),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
      title: const Text('Select Audio'),
      content: SizedBox(
        width: 300,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {

              if (index == items.length && userItems.isNotEmpty) {
              return const Divider(
                thickness: 1,
                color: Colors.grey,
              );
            }

              final entry = items.entries.elementAt(index);
              return ValueListenableBuilder<String?>(
                valueListenable: _soundManager.currentlyPlaying,
                builder: (context, currentlyPlaying, _) {
                  return AudioListTile(
                    entry: entry,
                    isPlaying: currentlyPlaying == entry.key,
                    isSelected: widget.selectedValue == entry.key || widget.selectedValue == entry.value,
                    onPlayToggle: () => _togglePlay(entry.key),
                    onTap: () => Navigator.of(context).pop(entry.key),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _addCustomSound() async {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio
      );

    if (result != null && result.files.single.path != null) {
      MapEntry<String, String> newSound = MapEntry(result.files.single.name, result.files.single.path!);

      widget.listType == SoundListType.longSounds
          ? UserSoundsDatabase().addLongSound(newSound)
          : UserSoundsDatabase().addShortSound(newSound);

      setState(() {}); 
    }
  }

  @override
  void dispose() {
    _soundManager.stopAllSounds();
    super.dispose();
  }
}