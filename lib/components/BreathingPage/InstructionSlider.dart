import 'package:flutter/material.dart';
import 'package:respire/components/Global/Step.dart' as training_step;

class InstructionBlock {
  final String text;
  double position;

  InstructionBlock({required this.text, required this.position});
}

class InstructionSlider extends StatefulWidget {

  const InstructionSlider({super.key});

  @override
  State<InstructionSlider> createState() => InstructionSliderState();
}

class InstructionSliderState extends State<InstructionSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final double spacing = 160.0;
  final Duration duration = Duration(milliseconds: 400);

  List<InstructionBlock> _blocks = [];

  @override
  void initState() {
    super.initState();
   
    _blocks.add(
      InstructionBlock(
        text: "Get ready", 
        position: 0.0)
    );
    
    _controller = AnimationController(vsync: this, duration: duration);
    _animation = Tween<double>(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        setState(() {
          _blocks.removeWhere((b) => b.position <= -2);
          _blocks.forEach(
              (b) => b.position += _animation.value); // apply final position
          _blocks.forEach((b) => b.position -= 1); // shift left
        });
      }
    });
  }

  void next() {
    if (!_controller.isAnimating) {
      _controller.forward();
    }
  }

  void addNewStep(training_step.Step? step, bool isFirstStep) {
    String stepName = step==null ? "The end": _stepType(step);
    _blocks.add(
      InstructionBlock(
        text: stepName, 
        position: isFirstStep ? 1.0 : 2.0)
    );
  }

   String _firstToUpperCase(String str) {
    return str[0].toUpperCase() + str.substring(1).toLowerCase();
  }

   String _breathDepth(training_step.Step? step) {
    if (step!.breathDepth == null) return "";
    return _firstToUpperCase(step.breathDepth!.name);
  }

  String _breathType(training_step.Step? step) {
    if (step!.breathType == null) return "";
    return _firstToUpperCase(step.breathType!.name);
  }

  String _stepType(training_step.Step? step) {
    if (step == null) return "";

  String str = _firstToUpperCase(step.stepType.name);
    switch (str) {

      case "Inhale":
        if (step.breathType!=null) {
          str += "\n${_breathType(step)}";
        }
        if (step.breathDepth!=null) {
          str += "\n${_breathDepth(step)}";
        }
        str += "\n${step.duration} sec";
        return str;

      case "Exhale":
        String str = "Exhale";
        if (step.breathType!=null) {
          str += "\n${_breathType(step)}";
        }
        if (step.breathDepth!=null) {
          str += "\n${_breathDepth(step)}";
        }
        str += "\n${step.duration} sec";
        return str;

      case "Recovery" || "Retention":
        return "$str\n${step.duration} sec";

      default:
        return "";
    }
  }

  double _calculateScale(double position) {
    final dist = (position).abs();
    return 1.0 - 0.25 * dist;
  }

  Widget _buildBlock(
      {required double positionX,
      required double scale,
      required String text}) {
    return Positioned(
      left: 200 + positionX - 60, // offset to center + half block width
      top: 50,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            style: TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 400,
          height: 220,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (_, __) {
              return Stack(
                children: _blocks.map((block) {
                  final animatedPos = block.position + _animation.value;
                  return _buildBlock(
                    positionX: animatedPos * spacing,
                    scale: _calculateScale(animatedPos),
                    text: block.text,
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
