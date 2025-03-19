import 'dart:async';

import 'package:flutter/material.dart';
import 'package:respire/components/BreathingPage/Circle.dart';
import 'package:respire/components/BreathingPage/InstructionBlocks.dart';
import 'package:respire/components/BreathingPage/TrainingParser.dart';
import 'package:respire/components/Global/Training.dart';
import 'package:respire/components/Global/Step.dart' as training_step;

class BreathingPage extends StatefulWidget{
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


class _BreathingPageState extends State<BreathingPage>
{
  late TrainingParser parser;
  Timer? _timer;
  training_step.Step? previousStep;
  training_step.Step? currentStep;
  training_step.Step? nextStep;
  int remainingTime = 3000; //in milliseconds
  int nextStepRemainingTime = 0;
  int stepsCount = 0;
  int minimumDurationTime = 100; //in milliseconds
  bool finished = false;

  @override
  void initState() {
    super.initState();
    parser = TrainingParser(training: widget.training);
    _startTraining();
  }

  void _startTraining() {
    _fetchNextStep();
    _timer = Timer.periodic(Duration(milliseconds: minimumDurationTime), (Timer timer) {
      setState(() {
        if (remainingTime > 0) {
          remainingTime -= minimumDurationTime;
        } else if (finished){
          previousStep = currentStep;
          currentStep = null;
          _timer?.cancel();
        } else {
          previousStep = currentStep;
          currentStep = nextStep;
          remainingTime = nextStepRemainingTime;
          _fetchNextStep();
        }
      });
    });
  }

void _fetchNextStep() {
  var instructionData = parser.nextInstruction();

  if (instructionData == null) {
    finished = true;
    nextStep = null;
    return;
  }

  setState(() {
    nextStep = instructionData["step"];
    nextStepRemainingTime = instructionData["remainingTime"];
    stepsCount = instructionData["stepsCount"];
  });
}

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back), 
          onPressed: () {
            currentStep != null ? _showConfirmationDialog(context) : Navigator.pop(context);
          },
        ),
        title: Text("ReSpire"),
        centerTitle: true,
        backgroundColor: Colors.grey,
      ),
      body: Column (
         children: [
          Text(widget.training.title, style: TextStyle(fontSize: 16),),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, 
                children: [
                  InstructionBlocks(previous: previousStep, current: currentStep, next: nextStep),
                  Circle(key: ValueKey(remainingTime), time: remainingTime),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '$stepsCount / ${parser.countSteps()}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
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