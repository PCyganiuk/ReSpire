import 'package:flutter/material.dart';
import 'package:respire/components/TrainingEditorPage/AudioSelectionPopup.dart';
import 'package:respire/services/SoundManagers/ISoundManager.dart';
import 'package:respire/services/TranslationProvider/TranslationProvider.dart';

class SoundSelectionRow extends StatelessWidget {
  final String label;
  final String? selectedValue;
  final SoundListType soundListType;
  final ValueChanged<String> onChanged;
  final TextStyle? labelStyle;

  const SoundSelectionRow({
    super.key,
    required this.label,
    required this.selectedValue,
    required this.soundListType,
    required this.onChanged,
    this.labelStyle,
  });

  Future<void> _openPopup(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AudioSelectionPopup(
        listType: soundListType,
        selectedValue: selectedValue,
      ),
    );

    if (result != null && result.isNotEmpty) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
    ), 
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle ?? TextStyle()),
       ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 150), // adjust as needed
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                selectedValue ??
                    TranslationProvider()
                        .getTranslation("TrainingEditorPage.SoundsTab.None"),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.music_note),
              onPressed: () => _openPopup(context),
            ),
          ],
        ),
      ),]
    ),
    );
  }
}