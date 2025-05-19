import 'dart:developer';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:respire/services/SettingsProvider.dart';

class TextToSpeechService {
  static final TextToSpeechService _instance = TextToSpeechService._internal();
  factory TextToSpeechService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();

  TextToSpeechService._internal();


  Future<void> init() async{
    var settings = SettingsProvider();
    settings.addListener(() async {
    String newVoice = settings.getVoiceType();
    await _flutterTts.setLanguage(newVoice);
    log("Voice changed to: $newVoice");
    });
    await settings.init();
    await _flutterTts.setLanguage(SettingsProvider().getVoiceType());
    _flutterTts.setErrorHandler((error) {
      log("TTS Error: $error");
    });
  }

  Future<dynamic> getVoices() async {
    var voices = await _flutterTts.getVoices;
    return voices;
  }

  Future<void>readNumber(int number) async
  {
    // Cannot reproduce, but sometimes the language resets and needs to be set again even after init is called.
    // Leaving this in code in case something like this ever happens again. (Seems like the only viable solution)
    //await _flutterTts.setLanguage("en-US"); // maybe call it with a language fetched from app settings instead?
    log("Speaking... (value=$number)");
    await _flutterTts.speak(number.toString());
    log("Finished speaking.");
  }

  Future<void>speak(String text) async
  {
    // Cannot reproduce, but sometimes the language resets and needs to be set again even after init is called.
    // Leaving this in code in case something like this ever happens again. (Seems like the only viable solution)
    //await _flutterTts.setLanguage("en-US"); // maybe call it with a language fetched from app settings instead?
    log("Speaking... (value=$text)");
    await _flutterTts.speak(text);
    log("Finished speaking.");
  }

  void stopSpeaking()
  {
    _flutterTts.stop();
  }

}