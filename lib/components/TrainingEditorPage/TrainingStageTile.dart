import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:respire/components/Global/TrainingStage.dart';
import 'package:respire/components/Global/BreathingPhase.dart' as respire;
import 'package:respire/components/TrainingEditorPage/BreathingPhaseTile.dart';
import 'package:respire/services/TranslationProvider/TranslationProvider.dart';
import 'package:respire/theme/Colors.dart';

class TrainingStageTile extends StatefulWidget {
  final TrainingStage trainingStage;
  final int trainingStageIndex;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;
  final bool isExpanded;
  final ValueChanged<bool> onExpandedChanged;

  final int trainingStageNameMaxLength = 25;

  const TrainingStageTile({
    Key? key,
    required this.trainingStage,
    required this.trainingStageIndex,
    required this.onDelete,
    required this.onUpdate,
    required this.isExpanded,
    required this.onExpandedChanged,
  }) : super(key: key);

  @override
  _TrainingStageTileState createState() => _TrainingStageTileState();
}

class _TrainingStageTileState extends State<TrainingStageTile> {
  late TextEditingController repsController;
  late TextEditingController nameController;

  FocusNode? repsFocusNode;
  FocusNode? nameFocusNode;

  TranslationProvider translationProvider = TranslationProvider();

  @override
  void initState() {
    super.initState();
    repsController = TextEditingController(text: widget.trainingStage.reps.toString());
    nameController = TextEditingController(text: _getInitialName());

    repsFocusNode = FocusNode();
    nameFocusNode = FocusNode();

    repsFocusNode!.addListener(() {
      if (!(repsFocusNode?.hasFocus ?? true)) {
        final value = int.tryParse(repsController.text);
        if (value != null && value > 0) {
          setState(() => widget.trainingStage.reps = value);
        }
        widget.onUpdate();
      }
    });

    nameFocusNode!.addListener(() {
      if (!(nameFocusNode?.hasFocus ?? true)) {
        setState(() => widget.trainingStage.name = nameController.text);
        widget.onUpdate();
      }
    });
  }

  @override
  void didUpdateWidget(TrainingStageTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (repsController.text != widget.trainingStage.reps.toString() && !(repsFocusNode?.hasFocus ?? false)) {
      repsController.text = widget.trainingStage.reps.toString();
    }

    if (nameController.text != widget.trainingStage.name && !(nameFocusNode?.hasFocus ?? false)) {
      nameController.text = _getInitialName();
    }

    if (oldWidget.trainingStageIndex != widget.trainingStageIndex && !(nameFocusNode?.hasFocus ?? false)) {
      nameController.text = _getInitialName();
    }
  }

  @override
  void dispose() {
    repsController.dispose();
    nameController.dispose();
    repsFocusNode?.dispose();
    nameFocusNode?.dispose();
    super.dispose();
  }

  void commitRepsDurationChange() {
    int newReps = int.tryParse(repsController.text) ?? widget.trainingStage.reps;
    newReps = newReps.clamp(1, 999);
    widget.trainingStage.reps = newReps;
    repsController.text = newReps.toString();
    widget.onUpdate();
  }

  void addBreathingPhase() {
    setState(() {
      widget.trainingStage.breathingPhases.add(
        respire.BreathingPhase(
          duration: 5.0,
          breathingPhaseType: respire.BreathingPhaseType.inhale,
        ),
      );
    });
    FocusScope.of(context).unfocus();
    widget.onUpdate();
  }

  void removeBreathingPhase(int index) async{
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(translationProvider.getTranslation("TrainingEditorPage.TrainingTab.BreathingPhaseTile.remove_breathing_phase_dialog_title")),
          backgroundColor: Colors.white,
          content: Text(translationProvider.getTranslation("TrainingEditorPage.TrainingTab.BreathingPhaseTile.remove_breathing_phase_dialog_content")),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(translationProvider.getTranslation("PopupButton.cancel"), style: TextStyle(color: darkerblue)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(translationProvider.getTranslation("PopupButton.remove"), style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete ?? false) {
      setState(() {
        widget.trainingStage.breathingPhases.removeAt(index);
      });
      widget.onUpdate();
    }
  }

  void updateBreathingPhase(int index, respire.BreathingPhase newBreathingPhase) {
    setState(() {
      widget.trainingStage.breathingPhases[index] = newBreathingPhase;
    });
    widget.onUpdate();
  }

  void reorderBreathingPhase(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final breathingPhase = widget.trainingStage.breathingPhases.removeAt(oldIndex);
      widget.trainingStage.breathingPhases.insert(newIndex, breathingPhase);
    });
    widget.onUpdate();
  }

  String _getInitialName() {
    final trimmed = widget.trainingStage.name.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    final template = translationProvider.getTranslation("TrainingEditorPage.TrainingTab.default_training_stage_name");
    if (template.contains('{number}')) {
      return template.replaceAll('{number}', (widget.trainingStageIndex + 1).toString());
    }
    return 'Stage ${widget.trainingStageIndex + 1}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: const Color.fromARGB(255, 255, 255, 255),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ReorderableDragStartListener(
                      index: 0,
                      child: Icon(Icons.drag_handle, color: darkerblue),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            translationProvider.getTranslation("TrainingEditorPage.TrainingTab.TrainingStageTile.name"),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: darkerblue,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 2),
                          Container(
                            height: 35,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: darkerblue, width: 1),
                            ),
                            child: TextField(
                              controller: nameController,
                              focusNode: nameFocusNode,
                              maxLength: widget.trainingStageNameMaxLength,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                                counterText: '',
                              ),
                              style: TextStyle(
                                color: darkerblue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  widget.trainingStage.name = value;
                                });
                              },
                              onEditingComplete: () {
                                widget.onUpdate();
                              },
                              onTapOutside: (event) {
                                FocusScope.of(context).unfocus();
                                widget.onUpdate();
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 4),
                            child: Text(
                              '${nameController.text.length}/${widget.trainingStageNameMaxLength} ${translationProvider.getTranslation("TrainingEditorPage.TrainingTab.TrainingStageTile.characters")}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.fromLTRB(0, 3, 0, 0),
                      icon: Icon(Icons.delete_outlined, color: darkerblue),
                      onPressed: widget.onDelete,
                    ),
                    IconButton(
                      padding: EdgeInsets.fromLTRB(0, 3, 0, 0),
                      icon: Icon(widget.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: darkerblue),
                      onPressed: () {
                        widget.onExpandedChanged(!widget.isExpanded);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: darkerblue, width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // --- C. Phases Reps Column ---
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  translationProvider.getTranslation("TrainingEditorPage.TrainingTab.TrainingStageTile.reps"),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: darkerblue,
                                    fontSize: 10,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: darkerblue.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () {
                                            int currentValue = int.tryParse(repsController.text) ?? 1;
                                            int newValue = (currentValue - 1).clamp(1, 999);
                                            repsController.text = newValue.toString();
                                            setState(() => widget.trainingStage.reps = newValue);
                                            widget.onUpdate();
                                          },
                                          child: Container(width: 24, height: 32, child: Icon(Icons.remove, color: darkerblue, size: 14)),
                                        ),
                                      ),
                                      Container(
                                        width: 28,
                                        height: 32,
                                        alignment: Alignment.center,
                                        child: TextField(
                                          key: ValueKey('reps_${widget.trainingStage.hashCode}'),
                                          controller: repsController,
                                          focusNode: repsFocusNode,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          decoration: InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
                                          style: TextStyle(color: darkerblue, fontWeight: FontWeight.w600, fontSize: 13),
                                          onChanged: (value) {
                                            int? newReps = int.tryParse(value);
                                            if (newReps != null && newReps > 0) {
                                              setState(() => widget.trainingStage.reps = newReps.clamp(1, 999));
                                            }
                                          },
                                          onEditingComplete: commitRepsDurationChange,
                                          onTapOutside: (event) {
                                            FocusScope.of(context).unfocus();
                                            commitRepsDurationChange();
                                          },
                                        ),
                                      ),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () {
                                            int currentValue = int.tryParse(repsController.text) ?? 1;
                                            int newValue = (currentValue + 1).clamp(1, 999);
                                            repsController.text = newValue.toString();
                                            setState(() => widget.trainingStage.reps = newValue);
                                            widget.onUpdate();
                                          },
                                          child: Container(width: 24, height: 32, child: Icon(Icons.add, color: darkerblue, size: 14)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            Spacer(),

                            // --- D. Duration Column ---
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  translationProvider.getTranslation("TrainingPage.TrainingOverview.stage_duration"),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: darkerblue,
                                    fontSize: 10,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Container(
                                  height: 32,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    widget.trainingStage.getTotalTimeFormatted(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: darkerblue,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: widget.isExpanded
                ? Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: ReorderableListView(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    onReorder: reorderBreathingPhase,
                    proxyDecorator: (Widget child, int index, Animation<double> animation) {
                      return Material(
                        color: Colors.transparent,
                        child: child,
                      );
                    },
                    children: [
                      for (int index = 0; index < widget.trainingStage.breathingPhases.length; index++)
                        BreathingPhaseTile(
                          key: ValueKey(widget.trainingStage.breathingPhases[index]),
                          breathingPhase: widget.trainingStage.breathingPhases[index],
                          onBreathingPhaseChanged: (newBreathingPhase) => updateBreathingPhase(index, newBreathingPhase),
                          onDelete: () => removeBreathingPhase(index),
                          onUpdate: widget.onUpdate,
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: addBreathingPhase,
                  icon: Icon(Icons.add, color: darkerblue),
                  label: Text(
                    translationProvider.getTranslation("TrainingEditorPage.TrainingTab.TrainingStageTile.add_breathing_phase_button_label"),
                    style: TextStyle(
                      color: darkerblue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
                : SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}