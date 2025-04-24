import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:respire/components/BreathingPage/Circle.dart';
import 'package:respire/components/BreathingPage/InstructionSlider.dart';
import 'package:respire/components/BreathingPage/TrainingParser.dart';
import 'package:respire/components/Global/Training.dart';
import 'package:respire/components/Global/Step.dart' as training_step;
import 'package:respire/services/TextToSpeechService.dart';


class BreathingPage extends StatefulWidget {
  final Training training;

  const BreathingPage({super.key, required this.training});

  @override
  State<StatefulWidget> createState() => _BreathingPageState();
}

void _showConfirmationDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Exit"),
        content: Text(
            "Are you sure you want exit?\nIf you click \"Yes\" your session will end.",
            textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("No"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text("Yes"),
          ),
        ],
      );
    },
  );
}

class _BreathingPageState extends State<BreathingPage> {
  
  late TrainingParser parser;
  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();

  training_step.Step? _currentStep;
  training_step.Step? _nextStep;

  int _remainingTime = 3000;
  int _nextRemainingTime = 0; //in milliseconds
  int _pauseRemainingTime = 600;
  int _newStepRemainingTime = 0;

  bool _finished = false;
  bool _pause = true;
  bool _stopTimer = false;
  
  final int _minimumDurationTime = 100; //in milliseconds
  final int _pauseDuration = 600;  //in milliseconds

  final GlobalKey<InstructionSliderState> _instructionBlocksKey = GlobalKey();
  int _stepsCount = 0;

  @override
  void initState() {
    super.initState();
    parser = TrainingParser(training: widget.training);
    _fetchNextStep();
    _currentStep = _nextStep;
    _nextRemainingTime = _newStepRemainingTime;
    _fetchNextStep();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _instructionBlocksKey.currentState?.addNewStep(_currentStep, true);
      _instructionBlocksKey.currentState?.addNewStep(_nextStep, false);
      _startTraining();
    });
  }

  void _startTraining() async{ 
    int previousSecond = _remainingTime~/1000; // subtracting one to skip the first second and audio bugging
     _stopwatch.start();
    _timer = Timer.periodic(Duration(milliseconds: _minimumDurationTime),
        (Timer timer) {
      setState(() {
        // Whenever the second changes, might want to change the calculations
        // if we decide to switch to seconds instead of milliseconds!
        if(previousSecond > _remainingTime~/1000)
        {
          previousSecond = _remainingTime~/1000;
          TextToSpeechService().readNumber(previousSecond+1);
        }

        if (_remainingTime >= _minimumDurationTime) {
          _remainingTime -= _minimumDurationTime;
         
        }
        else if(_pause) {
          _instructionBlocksKey.currentState?.next();
          _stepsCount++;
          TextToSpeechService().speak(_currentStep!.stepType.name);
          _pause = false; 

        } else if(_pauseRemainingTime >= _minimumDurationTime){
          _pauseRemainingTime -= _minimumDurationTime;

        }else if (_finished) {
          if(_stopTimer) {
            _instructionBlocksKey.currentState?.next();
            pauseTimer();
          } else {
            _remainingTime = _nextRemainingTime;
            previousSecond = _remainingTime~/1000;
            _stopTimer = true;
          }
          
        } else{
          _currentStep = _nextStep;
          _remainingTime = _nextRemainingTime;
          _nextRemainingTime =_newStepRemainingTime;
          previousSecond = _remainingTime~/1000;
          _fetchNextStep();
          _instructionBlocksKey.currentState?.addNewStep(_nextStep, false);
          _pause = true;
          _pauseRemainingTime = _pauseDuration;
        }
      });
    });
  }

  void _fetchNextStep() {
    var instructionData = parser.nextInstruction();

    if (instructionData == null) {
      _finished = true;
      _nextStep = null;
      return;
    }
    setState(() {
      _nextStep = instructionData["step"];
      _newStepRemainingTime = instructionData["remainingTime"];
    });
  }

    void pauseTimer() {
    _timer?.cancel();
    _stopwatch.stop();
  }

  void resumeTimer() {
    _stopwatch.start();
     _startTraining();
  }

  @override
  void dispose() {
    pauseTimer();
    TextToSpeechService().stopSpeaking();
    super.dispose();
  }

  Widget textInCircle() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${(_remainingTime / 1000).toDouble()}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            _currentStep != null
                ? {_showConfirmationDialog(context)}
                : Navigator.pop(context);
          },
        ),
        title: Text("ReSpire"),
        centerTitle: true,
        backgroundColor: Colors.grey,
      ),
      body: Column(
        children: [
          SizedBox(height: 16),
          //Title
          Text(widget.training.title,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),

          InstructionSlider(key: _instructionBlocksKey),

          Text(
            '$_stepsCount / ${parser.countSteps()}',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Circle(
                    step: _currentStep,
                    child: textInCircle(),
                  ),
                ],
              )
            )
          ),
        ],
      ),
    );
  }
}
