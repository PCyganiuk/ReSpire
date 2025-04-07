import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  static final TextToSpeechService _instance = TextToSpeechService._internal();
  factory TextToSpeechService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();

  TextToSpeechService._internal();


  Future<void> init() async{
    await _flutterTts.setLanguage("en-US");
    _flutterTts.setErrorHandler((error) {
      log("TTS Error: $error");
    });
  }


  String _numberToText(int number)
  {
    if (number < 0 || number > 99)
    {
      throw ArgumentError("Number $number is invalid! It should be between 0 and 99.");
    }
    List<String> digitWords = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"];
    List<String> tensWords = ["twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"];

    if (number <= 19)
    {
      return digitWords[number];
    }
    else if (number%10 == 0)
    {
      return tensWords[(number~/10)-2];
    }
    
    return "${tensWords[(number~/10)-2]} ${digitWords[(number%10)]}";

  }

  Future<void>speak(int number) async
  {
    await _flutterTts.setLanguage("en-US");
    log("Speaking... (value=$number)");
    await _flutterTts.speak(_numberToText(number));
    log("Finished speaking.");
  }

  void stopSpeaking()
  {
    _flutterTts.stop();
  }

}