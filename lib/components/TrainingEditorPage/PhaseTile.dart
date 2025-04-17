import 'package:flutter/material.dart';
import 'package:respire/components/Global/Phase.dart';
import 'package:respire/components/Global/Step.dart' as respire;
import 'package:respire/components/TrainingEditorPage/StepTile.dart';

class PhaseTile extends StatefulWidget {
  final Phase phase;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;

  const PhaseTile({
    Key? key,
    required this.phase,
    required this.onDelete,
    required this.onUpdate,
  }) : super(key: key);

  @override
  _PhaseTileState createState() => _PhaseTileState();
}

class _PhaseTileState extends State<PhaseTile> {
  late TextEditingController repsController;
  late TextEditingController incrementController;

  @override
  void initState() {
    super.initState();
    repsController =
        TextEditingController(text: widget.phase.reps.toString());
    incrementController = TextEditingController(text: widget.phase.increment.toString());
  }

  @override
  void dispose() {
    repsController.dispose();
    incrementController.dispose();
    super.dispose();
  }

  void addStep() {
    setState(() {
      widget.phase.steps.add(
        respire.Step(
          duration: 5.0,
          stepType: respire.StepType.inhale,
        ),
      );
    });
    widget.onUpdate();
  }

  void removeStep(int index) {
    setState(() {
      widget.phase.steps.removeAt(index);
    });
    widget.onUpdate();
  }

  void updateStep(int index, respire.Step newStep) {
    setState(() {
      widget.phase.steps[index] = newStep;
    });
    widget.onUpdate();
  }

  void reorderStep(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final step = widget.phase.steps.removeAt(oldIndex);
      widget.phase.steps.insert(newIndex, step);
    });
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8.0),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Row(
          children: [
            ReorderableDragStartListener(
              index: 0,
              child: Icon(Icons.drag_handle),
            ),
            SizedBox(width: 8),
            Text("Reps: "),
            Container(
              width: 50,
              child: TextField(
                controller: repsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                ),
                onChanged: (value) {
                  int? newReps = int.tryParse(value);
                  if (newReps != null) {
                    setState(() {
                      widget.phase.reps = newReps;
                    });
                    widget.onUpdate();
                  }
                },
              ),
            ),
            SizedBox(width: 8),
            Text("Inc: "),
            Container(
              width: 50,
              child: TextField(
                controller: incrementController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                  suffixText: '%',
                ),
                onChanged: (value) {
                  int? newIncrement = int.tryParse(value);
                  if (newIncrement != null && newIncrement >= 0 && newIncrement <= 100) {
                    setState(() {
                      widget.phase.increment = newIncrement;
                    });
                    widget.onUpdate();
                  }
                },
              ),
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: widget.onDelete,
            ),
          ],
        ),
        children: [
          ReorderableListView(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            onReorder: reorderStep,
            children: [
              for (int index = 0;
                  index < widget.phase.steps.length;
                  index++)
                StepTile(
                  key: ValueKey(widget.phase.steps[index]),
                  step: widget.phase.steps[index],
                  onStepChanged: (newStep) => updateStep(index, newStep),
                  onDelete: () => removeStep(index),
                  onUpdate: widget.onUpdate,
                ),
            ],
          ),
          TextButton.icon(
            onPressed: addStep,
            icon: Icon(Icons.add),
            label: Text("Add step"),
          ),
        ],
      ),
    );
  }
}
