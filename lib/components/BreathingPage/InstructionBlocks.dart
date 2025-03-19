import 'package:flutter/material.dart';
import 'package:respire/components/Global/Step.dart' as training_step;

class InstructionBlocks extends StatefulWidget {
  final training_step.Step? previous;
  final training_step.Step? current;
  final training_step.Step? next; 


  const InstructionBlocks({super.key, required this.previous, required this.current, required this.next });

  @override
  State<StatefulWidget> createState() => _InstructionBlocksState();
}

class _InstructionBlocksState extends State<InstructionBlocks> {
  @override
  Widget build(BuildContext context) {
    return Text(
      "prev: ${widget.previous==null && widget.current!=null ? "Get ready" : widget.previous?.stepType.name}\n"
      "current: ${widget.current==null && widget.previous==null ? "Get ready" 
        : (widget.current==null && widget.next==null ? "The end" :widget.current?.stepType.name)}\n"
      "next: ${widget.next==null && widget.current!=null ? "The end" : widget.next?.stepType.name}"
    );
  }
}