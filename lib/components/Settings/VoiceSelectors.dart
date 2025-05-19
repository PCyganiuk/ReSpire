import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:respire/services/SettingsProvider.dart';
import 'package:respire/services/TextToSpeechService.dart';

String? selectedLocale;
String? selectedVoice;
List<Map<String, dynamic>> allVoices = [];
List<Map<String, dynamic>> filteredVoices = [];

class VoiceSelector extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _VoiceSelectorState();
}

class _VoiceSelectorState extends State<VoiceSelector> {
  final ttsService = TextToSpeechService();
  final settingsProvider = SettingsProvider();

  @override
  void dispose() {
    super.dispose();
  }

@override
void initState() {
  super.initState();
  loadVoices();
}

Future<void> loadVoices() async {
  var voices = await ttsService.getVoices();
  setState(() {
    allVoices = voices.map<Map<String, dynamic>>((v) => Map<String, dynamic>.from(v)).toList();
  });
}

@override
Widget build(BuildContext context) {
  final locales = allVoices.map((v) => v['locale'] as String).toSet().toList();

  return Column(
    children: [
      DropdownButton<String>(
        value: selectedLocale,
        hint: Text("Wybierz język"),
        items: locales.map((locale) {
          return DropdownMenuItem(value: locale, child: Text(locale));
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedLocale = value;
            filteredVoices = allVoices.where((v) => v['locale'] == value).toList();
            selectedVoice = null; // reset głosu
          });
        },
      ),
      DropdownButton<String>(
        value: selectedVoice,
        hint: Text("Wybierz głos"),
        items: filteredVoices.map((voice) {
          return DropdownMenuItem(
            value: voice['name'].toString(),
            child: Text(voice['name']),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedVoice = value;
            final selected = filteredVoices.firstWhere((v) => v['name'] == value);
            settingsProvider.setVoiceType(selected['locale']);
          });
        },
      )
    ],
  );
}
}