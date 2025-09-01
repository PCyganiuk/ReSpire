import 'package:flutter/material.dart';
import 'package:respire/theme/Colors.dart';

class AudioListTile extends StatelessWidget {
  final MapEntry<String, String?> entry;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayToggle;
  final bool isSelected;

  const AudioListTile({
    super.key,
    required this.entry,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayToggle,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: isSelected,
        selectedColor: Colors.black,
        textColor: Colors.black,
        titleTextStyle: isSelected ? TextStyle(fontWeight: FontWeight.bold):TextStyle(fontWeight: FontWeight.normal),
        selectedTileColor: Color.fromARGB(99, 156, 156, 156),
        leading: IconButton(onPressed: onPlayToggle, icon: entry.value == null ? Icon(Icons.volume_off, color: Colors.grey) : isPlaying ? Icon(Icons.pause, color: Colors.red) : Icon(Icons.play_arrow, color: Colors.green)),
        title: Text(entry.key, overflow: TextOverflow.fade, maxLines: 1,),
        onTap: onTap,
      ),
    );
  }
}