import 'package:flutter/material.dart';
import 'dart:async';
import 'package:respire/components/Global/Training.dart';
import 'package:respire/components/Global/Phase.dart';
import 'package:respire/components/TrainingEditorPage/PhaseTile.dart';
import 'package:respire/theme/Colors.dart';

class TrainingEditorPage extends StatefulWidget {
  final Training training;

  const TrainingEditorPage({
    Key? key,
    required this.training,
  }) : super(key: key);

  @override
  _TrainingEditorPageState createState() => _TrainingEditorPageState();
}

class _TrainingEditorPageState extends State<TrainingEditorPage> {
  late List<Phase> phases;
  final ScrollController _scrollController = ScrollController();
  TextEditingController trainingNameController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    phases = widget.training.phases;
    trainingNameController.text = widget.training.title;
  }

  void saveTraining() {
    // TODO: implement actual saving logic, e.g., write to local storage or call an API
    print("Training saved: ${widget.training.title}");
  }

  void addPhase() {
    setState(() {
      phases.add(Phase(reps: 3, steps: [], increment: 0));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
    saveTraining();
  }

  void removePhase(int index) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Remove phase?'),
          content: Text('Are you sure you want to remove this phase?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmDelete ?? false) {
      setState(() {
        phases.removeAt(index);
      });
      saveTraining();
    }
  }

  void reorderPhase(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final phase = phases.removeAt(oldIndex);
      phases.insert(newIndex, phase);
    });
    saveTraining();
  }

  @override
  void dispose() {
    trainingNameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Automatically return updated training when popping
        Navigator.pop(context, widget.training);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: trainingNameController,
            decoration: InputDecoration(border: InputBorder.none),
            style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w800),
            onChanged: (value) {
              widget.training.title = value;
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(Duration(milliseconds: 500), () {
                saveTraining();
              });
            },
          ),
          backgroundColor: Colors.white,
        ),
        backgroundColor: mediumblue,
        body: ReorderableListView(
          scrollController: _scrollController,
          onReorder: reorderPhase,
           proxyDecorator: (Widget child, int index, Animation<double> animation) {
            return Material(
              color: Colors.transparent, 
              child: child,
            );
          },
          padding: EdgeInsets.only(bottom: 80),
          children: [
            for (int index = 0; index < phases.length; index++)
              PhaseTile(
                key: ValueKey('phase_$index'),
                phase: phases[index],
                onDelete: () => removePhase(index),
                onUpdate: () {
                  setState(() {
                    widget.training.phases = phases;
                  });
                  saveTraining();
                },
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: addPhase,
          backgroundColor: Colors.white,       
          child: Icon(
            Icons.add,
            color: darkerblue,                 
          ),
        ),
      ),
    );
  }
}
