import 'package:flutter/material.dart';
import 'package:respire/components/Global/SoundAsset.dart';
import 'package:respire/components/TrainingEditorPage/AudioSelectionPopup.dart';
import 'package:respire/services/SoundManagers/ISoundManager.dart';
import 'package:respire/theme/Colors.dart';

///A row containing a name of a sound and the `AudioSelectionPopup`
class SoundSelectionRow extends StatelessWidget {
  final String label;
  final SoundAsset selectedValue;
  final SoundListType soundListType;
  final bool includeNoneOption;
  final bool includeVoiceOption;
  final ValueChanged<SoundAsset> onChanged;
  final TextStyle? labelStyle;
  final bool blueBorder;
  final bool isSoundSelection;

  final bool showSlider;
  final double? sliderValue;
  final ValueChanged<double>? onSliderChanged;

  const SoundSelectionRow({
    super.key,
    required this.label,
    required this.selectedValue,
    required this.soundListType,
    this.includeNoneOption = true,
    required this.includeVoiceOption,
    required this.onChanged,
    this.labelStyle,
    this.blueBorder = false,
    required this.isSoundSelection,

    this.showSlider = false,
    this.sliderValue,
    this.onSliderChanged,
  });

  Future<void> _openPopup(BuildContext context) async {
    final result = await showDialog<SoundAsset>(
      context: context,
      builder: (_) => AudioSelectionPopup(
        includeNoneOption: includeNoneOption,
        includeVoiceOption: includeVoiceOption,
        listType: soundListType,
        selectedValue: selectedValue.name,
        isSoundSelection: isSoundSelection,
      ),
    );

    if (result != null) {
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
          color: blueBorder ? mediumblue : Colors.grey.shade300,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: labelStyle ?? const TextStyle(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
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
          ),

          // OPTIONAL SLIDER
          if (showSlider &&
              sliderValue != null &&
              onSliderChanged != null &&
              selectedValue.name != 'Brak' && selectedValue.name != 'Lektor') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    // Map the actual value (200-10000) to a 0-100 slider scale
                    value: (sliderValue! <= 1000)
                        ? 50.0 * (sliderValue! - 200) / (1000 - 200)
                        : 50.0 + 50.0 * (sliderValue! - 1000) / (10000 - 1000),
                    min: 0,
                    max: 100,
                    activeColor: darkerblue,
                    onChanged: (sliderPos) {
                      double actualValue;

                      // Map the 0-100 slider scale back to actual values
                      if (sliderPos <= 50) {
                        actualValue = 200 + (sliderPos / 50.0) * (1000 - 200);
                        // Snap to nearest 10ms
                        actualValue = (actualValue / 10).round() * 10.0;
                      } else {
                        actualValue = 1000 + ((sliderPos - 50.0) / 50.0) * (10000 - 1000);
                        // Snap to nearest 100ms
                        actualValue = (actualValue / 100).round() * 100.0;
                      }

                      // Ensure it stays strictly within bounds just in case
                      actualValue = actualValue.clamp(200.0, 10000.0);

                      onSliderChanged?.call(actualValue);
                    },
                  ),
                ),
                //const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  child: Text(
                    sliderValue! >= 1000
                        ? "${(sliderValue! / 1000).toStringAsFixed(1).replaceAll('.0', '')} s"
                        : "${sliderValue!.round()} ms",
                    style: TextStyle(
                      color: darkerblue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              ],
            )
          ],
        ],
      ),
    );
  }
}