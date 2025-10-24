import 'package:flutter/material.dart';
import 'package:respire/components/Global/SoundAsset.dart';
import 'package:respire/components/TrainingEditorPage/AudioSelectionPopup.dart';
import 'package:respire/services/SoundManagers/ISoundManager.dart';

class SoundSelectionRow extends StatelessWidget {
  final String label;
  final SoundAsset selectedValue;
  final SoundListType soundListType;
  final bool includeVoiceOption;
  final ValueChanged<SoundAsset> onChanged;
  final TextStyle? labelStyle;

  const SoundSelectionRow({
    super.key,
    required this.label,
    required this.selectedValue,
    required this.soundListType,
    required this.includeVoiceOption,
    required this.onChanged,
    this.labelStyle,
  });

  Future<void> _openPopup(BuildContext context) async {
    final result = await showDialog<SoundAsset>(
      context: context,
      builder: (_) => AudioSelectionPopup(
        includeVoiceOption: includeVoiceOption,
        listType: soundListType,
        selectedValue: selectedValue.name,
      ),
    );

    if (result != null) {
      onChanged(result);
    }
  }

    @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle ?? const TextStyle()),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openPopup(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      selectedValue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.music_note, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}