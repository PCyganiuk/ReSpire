import 'package:flutter/material.dart';
import 'package:respire/components/Global/Training.dart';
import 'package:respire/pages/BreathingPage.dart';
import 'package:respire/pages/TrainingEditorPage.dart';
import 'package:respire/services/PresetDataBase.dart';
import 'package:respire/theme/Colors.dart';

class TrainingPage extends StatefulWidget {
  final int index;
  final PresetDataBase db = PresetDataBase();

  TrainingPage({
    super.key,
    required this.index,
  });

  @override
  _TrainingPageState createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  late Training training;

  @override
  void initState() {
    super.initState();
    training = widget.db.presetList[widget.index];
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          title: Text(training.title,
              style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'Glacial',
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          backgroundColor: Colors.white,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              }),
        ),
        backgroundColor: mediumblue,
        body: Column(children: [
          Row(
            children: [
              Padding(
                padding: EdgeInsets.all(10),
                child: IconButton(
                    icon: Icon(Icons.share_rounded, color: darkgrey),
                    style: IconButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 207, 206, 206)),
                    onPressed: () => {}),
              ),
              Spacer(),
              Padding(
                  padding: EdgeInsets.all(10),
                  child: IconButton(
                      icon: Icon(Icons.edit_rounded, color: darkerblue),
                      style:
                          IconButton.styleFrom(backgroundColor: Colors.white),
                      onPressed: () async {
                        final updated = await Navigator.push<Training>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrainingEditorPage(
                              training: widget.db.presetList[widget.index],
                            ),
                          ),
                        );
                        if (updated != null) {
                          setState(() {
                            widget.db.presetList[widget.index] = updated;
                            widget.db.updateDataBase();
                          });
                        }
                      })),
              Padding(
                  padding: EdgeInsets.all(10),
                  child: IconButton(
                    icon: Icon(Icons.delete_rounded, color: darkerblue),
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                    onPressed: removeTraining,
                  )),
            ],
          ),
          Padding(
              padding: EdgeInsets.all(10),
              child: Container(
                  width: screenWidth - 20,
                  constraints: BoxConstraints(
                    minHeight: 80,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                      padding: EdgeInsets.all(15),
                      child: Container(
                          width: screenWidth - 40,
                          decoration: BoxDecoration(
                            color: lightblue,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                training.description == ''
                                    ? "No description provided."
                                    : training.description,
                                style: TextStyle(color: greenblue),
                              ),
                            ),
                          ))))),
          Padding(
              padding: EdgeInsets.all(20),
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BreathingPage(training: training),
                  ),
                ),
                style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(70),
                      bottomRight: Radius.circular(35),
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(70),
                    ))),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Text("Start training",
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'Glacial',
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                      )),
                ),
              ))
        ]));
  }

  Future<void> removeTraining() async {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Delete Training"),
            content: Text("Are you sure you want to delete this training?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  widget.db.deletePreset(widget.index);
                  Navigator.pop(context);
                  setState(() {});
                  Navigator.pop(context, true);
                },
                child: Text("Delete"),
              ),
            ],
          );
        });
  }
}
