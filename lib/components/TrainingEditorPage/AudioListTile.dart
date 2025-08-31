import 'package:flutter/material.dart';

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
        selectedTileColor: Color.fromARGB(99, 156, 156, 156),
        leading: IconButton(onPressed: onPlayToggle, icon: entry.value == null ? Icon(Icons.volume_off, color: Colors.grey) : isPlaying ? Icon(Icons.pause, color: Colors.red) : Icon(Icons.play_arrow, color: Colors.green)),
        title: Text(entry.key, overflow: TextOverflow.fade, maxLines: 1,),
        onTap: onTap,
      ),
    );
  }
}