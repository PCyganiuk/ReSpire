import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:respire/components/Global/SoundAsset.dart';
import 'package:respire/components/Global/SoundScope.dart';
import 'package:respire/components/Global/Sounds.dart';
import 'package:respire/components/Global/BreathingPhase.dart';
import 'package:respire/components/Global/Training.dart';
import 'package:respire/components/Global/TrainingStage.dart';
import 'package:respire/components/Global/Settings.dart';
import 'package:respire/components/TrainingEditorPage/TrainingStageTile.dart';
import 'package:respire/components/TrainingEditorPage/SoundSelectionRow.dart';
import 'package:respire/components/TrainingEditorPage/PlaylistEditor.dart';
import 'package:respire/components/TrainingEditorPage/StagePhaseSoundEditor.dart';
import 'package:respire/components/TrainingEditorPage/StagePlaylistsEditor.dart';
import 'package:respire/services/SoundManagers/ISoundManager.dart';
import 'package:respire/services/TranslationProvider/TranslationProvider.dart';
import 'package:respire/theme/Colors.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:respire/utils/TextUtils.dart';

import '../services/VisualStyle.dart';

// --- NEW: Helper class to manage list blocks for the UI ---
class _TrainingBlock {
  final int groupId;
  final List<TrainingStage> stages;
  final List<bool> expandedStates;
  final Color? groupColor;

  _TrainingBlock({
    required this.groupId,
    required this.stages,
    required this.expandedStates,
    this.groupColor,
  });
}

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
  late List<TrainingStage> trainingStages;
  late Settings settings;
  late TextEditingController descriptionController;
  late TextEditingController preparationController;
  late TextEditingController endingController;
  late TextEditingController dimAfterController;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _descriptionFocusNode = FocusNode();
  FocusNode? preparationFocusNode = FocusNode();
  FocusNode? endingFocusNode = FocusNode();
  FocusNode? dimAfterFocusNode = FocusNode();
  int _selectedTab = 0;
  late Sounds _sounds;
  late List<bool> expandedStates;
  final int titleMaxLength = 15;

  final List<double> solfeggioFrequencies = [
    174, 285, 396, 417, 528, 639, 741, 852, 963,
  ];

  late int selectedIndex;

  TranslationProvider translationProvider = TranslationProvider();

  // Color palette for grouping
  final List<Color> _groupColors = [
    Colors.blue, Colors.green, Colors.orange,
    Colors.purple, Colors.red, Colors.teal
  ];

  @override
  void initState() {
    super.initState();
    trainingStages = widget.training.trainingStages;
    expandedStates = List.generate(trainingStages.length, (_) => true);
    _sounds = widget.training.sounds;
    descriptionController = TextEditingController(text: widget.training.description);

    preparationController = TextEditingController(text: widget.training.settings.preparationDuration.toString());
    preparationFocusNode = FocusNode();
    preparationFocusNode!.addListener(() {
      if (!(preparationFocusNode?.hasFocus ?? true)) {
        final value = int.tryParse(preparationController.text);
        if (value != null && value > 0) {
          setState(() => widget.training.settings.preparationDuration = value);
        }
      }
    });

    endingController = TextEditingController(text: widget.training.settings.endingDuration.toString());
    endingFocusNode = FocusNode();
    endingFocusNode!.addListener(() {
      if (!(endingFocusNode?.hasFocus ?? true)) {
        final value = int.tryParse(endingController.text);
        if (value != null && value > 0) {
          setState(() => widget.training.settings.endingDuration = value);
        }
      }
    });

    dimAfterController = TextEditingController(text: widget.training.settings.dimScreenAfterSeconds.toString());
    dimAfterFocusNode = FocusNode();

    selectedIndex = solfeggioFrequencies.indexOf(widget.training.settings.binauralBeatFrequency);
    if (selectedIndex == -1) selectedIndex = 0;
  }

  // --- NEW: Block compiler to group contiguous stages for the UI ---
  List<_TrainingBlock> _getBlocks() {
    List<_TrainingBlock> blocks = [];
    if (trainingStages.isEmpty) return blocks;

    int currentGroupId = trainingStages[0].groupId;
    List<TrainingStage> currentStages = [];
    List<bool> currentExpanded = [];

    for (int i = 0; i < trainingStages.length; i++) {
      if (trainingStages[i].groupId == currentGroupId && currentGroupId != 0) {
        currentStages.add(trainingStages[i]);
        currentExpanded.add(expandedStates[i]);
      } else if (trainingStages[i].groupId == 0) {
        if (currentStages.isNotEmpty) {
          blocks.add(_TrainingBlock(
            groupId: currentGroupId,
            stages: currentStages,
            expandedStates: currentExpanded,
            groupColor: _getGroupColor(currentGroupId),
          ));
          currentStages = [];
          currentExpanded = [];
        }
        blocks.add(_TrainingBlock(
          groupId: 0,
          stages: [trainingStages[i]],
          expandedStates: [expandedStates[i]],
        ));
        currentGroupId = 0;
      } else {
        if (currentStages.isNotEmpty) {
          blocks.add(_TrainingBlock(
            groupId: currentGroupId,
            stages: currentStages,
            expandedStates: currentExpanded,
            groupColor: _getGroupColor(currentGroupId),
          ));
        }
        currentGroupId = trainingStages[i].groupId;
        currentStages = [trainingStages[i]];
        currentExpanded = [expandedStates[i]];
      }
    }
    if (currentStages.isNotEmpty) {
      blocks.add(_TrainingBlock(
        groupId: currentGroupId,
        stages: currentStages,
        expandedStates: currentExpanded,
        groupColor: _getGroupColor(currentGroupId),
      ));
    }
    return blocks;
  }

  // Helper to map color value if you store them in widget.training.colorValues
  Color _getGroupColor(int groupId) {
    if (widget.training.colorValues.isNotEmpty) {
      // Basic fallback logic: assign a color based on the modulo of the ID
      return Color(widget.training.colorValues[groupId % widget.training.colorValues.length]);
    }
    return _groupColors[groupId % _groupColors.length];
  }

  // --- NEW: Create Group Dialog ---
  void _showCreateGroupDialog() {
    if (trainingStages.isEmpty) return;

    int newGroupReps = 1;
    List<bool> selectedStages = List.generate(trainingStages.length, (index) => false);
    Color selectedColor = _groupColors[0];
    TextEditingController groupRepsController = TextEditingController(text: "1");

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void commitRepsChange() {
              int val = int.tryParse(groupRepsController.text) ?? 1;
              val = val.clamp(1, 999);
              groupRepsController.text = val.toString();
              setStateDialog(() => newGroupReps = val);
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                "Group Stages",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkerblue),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Group Reps Counter ---
                    Text(
                      "Group Reps",
                      style: TextStyle(fontWeight: FontWeight.bold, color: darkerblue, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: 120,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: darkerblue, width: 2),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {
                              int val = int.tryParse(groupRepsController.text) ?? 1;
                              val = (val - 1).clamp(1, 999);
                              groupRepsController.text = val.toString();
                              commitRepsChange();
                            },
                            child: SizedBox(width: 36, child: Icon(Icons.remove, color: darkerblue)),
                          ),
                          Expanded(
                            child: TextField(
                              controller: groupRepsController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(border: InputBorder.none, isDense: true),
                              style: TextStyle(color: darkerblue, fontWeight: FontWeight.bold, fontSize: 16),
                              onChanged: (value) {
                                int? val = int.tryParse(value);
                                if (val != null && val > 0) newGroupReps = val.clamp(1, 999);
                              },
                              onEditingComplete: () {
                                FocusScope.of(context).unfocus();
                                commitRepsChange();
                              },
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {
                              int val = int.tryParse(groupRepsController.text) ?? 1;
                              val = (val + 1).clamp(1, 999);
                              groupRepsController.text = val.toString();
                              commitRepsChange();
                            },
                            child: SizedBox(width: 36, child: Icon(Icons.add, color: darkerblue)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // --- Color Picker ---
                    Text("Select Color", style: TextStyle(fontWeight: FontWeight.bold, color: darkerblue)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _groupColors.map((color) {
                        return GestureDetector(
                          onTap: () => setStateDialog(() => selectedColor = color),
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: selectedColor == color ? Colors.black : Colors.transparent,
                                  width: 2
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    Divider(color: mediumblue),

                    // --- Stage Selection ---
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: trainingStages.length,
                        itemBuilder: (context, index) {
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_getStageName(index), overflow: TextOverflow.ellipsis),
                            value: selectedStages[index],
                            activeColor: darkerblue,
                            onChanged: (val) {
                              setStateDialog(() => selectedStages[index] = val ?? false);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(translationProvider.getTranslation("PopupButton.cancel"), style: TextStyle(color: darkerblue)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: darkerblue),
                  onPressed: () {
                    // Extract selected stages and group them
                    int newGroupId = DateTime.now().millisecondsSinceEpoch;

                    List<TrainingStage> pulledStages = [];
                    List<bool> pulledExpanded = [];
                    int firstInsertIndex = -1;

                    for (int i = 0; i < trainingStages.length; i++) {
                      if (selectedStages[i]) {
                        if (firstInsertIndex == -1) firstInsertIndex = i;
                        trainingStages[i].groupId = newGroupId;
                        trainingStages[i].stageReps = newGroupReps;
                        pulledStages.add(trainingStages[i]);
                        pulledExpanded.add(expandedStates[i]);
                      }
                    }

                    if (pulledStages.isNotEmpty) {
                      setState(() {
                        // Remove them from current positions
                        trainingStages.removeWhere((stage) => stage.groupId == newGroupId);

                        // Safely remove the expanded states by looping backward
                        for (int i = selectedStages.length - 1; i >= 0; i--) {
                          if (selectedStages[i]) {
                            expandedStates.removeAt(i);
                          }
                        }

                        // Insert them sequentially at the index of the first selected item
                        trainingStages.insertAll(firstInsertIndex, pulledStages);
                        expandedStates.insertAll(firstInsertIndex, pulledExpanded);

                        // Save the chosen color integer to the model
                        // Safely save the chosen color by creating a new mutable list
                        widget.training.colorValues = List.from(widget.training.colorValues)..add(selectedColor.toARGB32());

                        widget.training.trainingStages = trainingStages;
                      });
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text("Create Group", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void ungroup(int groupId) {
    setState(() {
      for (var stage in trainingStages) {
        if (stage.groupId == groupId) {
          stage.groupId = 0;
          stage.stageReps = 1; // reset back to 1 if ungrouped
        }
      }
    });
  }

  // --- NEW: Block-based Reordering ---
  void reorderTrainingBlocks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;

      final blocks = _getBlocks();
      final movedBlock = blocks.removeAt(oldIndex);
      blocks.insert(newIndex, movedBlock);

      // Flatten blocks back into the data arrays
      trainingStages.clear();
      expandedStates.clear();
      for (var block in blocks) {
        trainingStages.addAll(block.stages);
        expandedStates.addAll(block.expandedStates);
      }
      widget.training.trainingStages = trainingStages;
    });
  }

  void expandAllStages() {
    setState(() {
      expandedStates = List.generate(trainingStages.length, (_) => true);
    });
  }

  void collapseAllStages() {
    setState(() {
      expandedStates = List.generate(trainingStages.length, (_) => false);
    });
  }

  void addTrainingStage() {
    setState(() {
      trainingStages.add(TrainingStage(
          reps: 1,
          breathingPhases: [],
          stageReps: 1,
          groupId: 0,
          name: "${translationProvider.getTranslation("TrainingPage.TrainingOverview.training_stage")} ${trainingStages.length + 1}"));
      expandedStates.add(true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      FocusScope.of(context).unfocus();
    });
  }

  void removeTrainingStage(int index) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(translationProvider.getTranslation("TrainingEditorPage.TrainingTab.remove_training_stage_dialog_title")),
          content: Text(translationProvider.getTranslation("TrainingEditorPage.TrainingTab.remove_training_stage_dialog_content")),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(translationProvider.getTranslation("PopupButton.cancel"), style: TextStyle(color: darkerblue)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(translationProvider.getTranslation("PopupButton.remove"), style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete ?? false) {
      setState(() {
        trainingStages.removeAt(index);
        expandedStates.removeAt(index);
      });
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    _descriptionFocusNode.dispose();
    preparationFocusNode?.dispose();
    endingFocusNode?.dispose();
    super.dispose();
  }

  void showEditTitleDialog(BuildContext context) {
    final tempController = TextEditingController(text: widget.training.title);
    bool isError = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              translationProvider.getTranslation("TrainingEditorPage.TrainingTab.edit_title_dialog_title"),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkerblue),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        translationProvider.getTranslation("TrainingEditorPage.TrainingTab.error"),
                        style: TextStyle(color: darkred, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                TextField(
                  controller: tempController,
                  autofocus: true,
                  maxLength: titleMaxLength,
                  decoration: InputDecoration(
                    hintText: translationProvider.getTranslation("TrainingEditorPage.TrainingTab.edit_title_dialog_hint"),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: darkerblue, width: 2.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: darkerblue, width: 2.0),
                    ),
                  ),
                )
              ],
            ),
            actions: [
              TextButton(
                child: Text(translationProvider.getTranslation("PopupButton.cancel"), style: TextStyle(color: darkerblue)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: darkerblue),
                onPressed: () {
                  String text = tempController.text.trim();
                  if (text.isEmpty) {
                    setStateDialog(() => isError = true);
                    return;
                  }
                  setState(() => widget.training.title = text);
                  Navigator.of(context).pop();
                },
                child: Text(translationProvider.getTranslation("PopupButton.save"), style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  String getBrainwaveState(double beatHz) {
    if (beatHz <= 4) return "Delta";
    if (beatHz <= 8) return "Theta";
    if (beatHz <= 12) return "Alpha";
    return "Beta";
  }

  void _showAlert(int emptyStages) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(translationProvider.getTranslation("TrainingEditorPage.Alert.header")),
          content: widget.training.isEmpty()
              ? Text(translationProvider.getTranslation("TrainingEditorPage.Alert.empty_training_message"))
              : Text('${translationProvider.getTranslation("TrainingEditorPage.Alert.empty_stages_message_first_part")}$emptyStages${translationProvider.getTranslation("TrainingEditorPage.Alert.empty_stages_message_second_part")}'),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () {
                if(emptyStages > 0) widget.training.deleteEmptyStages();
                Navigator.pop(context);
                Navigator.pop(context, widget.training);
              },
              child: Text(translationProvider.getTranslation("TrainingEditorPage.Alert.finish_edition_button")),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(translationProvider.getTranslation("TrainingEditorPage.Alert.back_to_edition_button")),
            ),
          ],
        );
      },
    );
  }

  String _getStageName(int index) {
    final trimmed = trainingStages[index].name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final template = translationProvider.getTranslation("TrainingEditorPage.TrainingTab.default_training_stage_name");
    if (template.contains('{number}')) {
      return template.replaceAll('{number}', (index + 1).toString());
    }
    return 'Stage ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    // Generate Blocks for the UI
    final currentBlocks = _getBlocks();

    return WillPopScope(
      onWillPop: () async {
        int emptyStages = widget.training.countEmptyStages();
        if(emptyStages > 0 || widget.training.trainingStages.isEmpty) {
          _showAlert(emptyStages);
        } else {
          Navigator.pop(context, widget.training);
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: Text(
            widget.training.title,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Glacial',),
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.edit, color: darkerblue),
              onPressed: () => showEditTitleDialog(context),
              splashRadius: 20,
            ),
          ],
          backgroundColor: Colors.white,
        ),
        backgroundColor: Colors.white,
        body: Container(
          color: lightblue,
          child: Column(
            children: [
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: CustomSlidingSegmentedControl<int>(
                  children: {
                    0: Text(
                        translationProvider.getTranslation("TrainingEditorPage.tab.training"),
                        style: TextStyle(color: _selectedTab == 0 ? darkerblue : Colors.white, fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal)),
                    1: Text(
                        translationProvider.getTranslation("TrainingEditorPage.tab.sounds"),
                        style: TextStyle(color: _selectedTab == 1 ? darkerblue : Colors.white, fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal)),
                    2: Text(
                        translationProvider.getTranslation("TrainingEditorPage.tab.other"),
                        style: TextStyle(color: _selectedTab == 2 ? darkerblue : Colors.white, fontWeight: _selectedTab == 2 ? FontWeight.bold : FontWeight.normal)),
                  },
                  initialValue: _selectedTab,
                  onValueChanged: (val) {
                    FocusScope.of(context).unfocus();
                    setState(() => _selectedTab = val);
                  },
                  decoration: BoxDecoration(color: darkerblue, borderRadius: BorderRadius.circular(16)),
                  thumbDecoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: Offset(0, 3))],
                  ),
                  innerPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                ),
              ),
              SizedBox(height: 2),
              if (_selectedTab == 0)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: darkerblue, width: 1.5),
                    ),
                    elevation: 2,
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        '${translationProvider.getTranslation("TrainingPage.TrainingOverview.duration")} ${widget.training.getTotalTimeApprox()}',
                        style: TextStyle(fontSize: 18, color: darkerblue, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              if (_selectedTab == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: trainingStages.isEmpty ? null : _showCreateGroupDialog,
                        icon: Icon(Icons.dashboard_customize, color: trainingStages.isEmpty ? Colors.grey : darkerblue),
                        label: Text(
                          "Group Stages",
                          style: TextStyle(color: trainingStages.isEmpty ? Colors.grey : darkerblue),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: expandAllStages,
                            icon: Icon(Icons.unfold_more, color: darkerblue),
                            label: Text(translationProvider.getTranslation("TrainingEditorPage.TrainingTab.expand_all"), style: TextStyle(color: darkerblue)),
                          ),
                          TextButton.icon(
                            onPressed: collapseAllStages,
                            icon: Icon(Icons.unfold_less, color: darkerblue),
                            label: Text(translationProvider.getTranslation("TrainingEditorPage.TrainingTab.collapse_all"), style: TextStyle(color: darkerblue)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _selectedTab == 0
                    ? ReorderableListView(
                  scrollController: _scrollController,
                  onReorder: reorderTrainingBlocks, // Use the new block reorder method
                  proxyDecorator: (child, idx, anim) => Material(color: Colors.transparent, child: child),
                  padding: EdgeInsets.only(bottom: 80),
                  // --- NEW: Map blocks to UI ---
                  children: currentBlocks.asMap().entries.map((entry) {
                    int blockIndex = entry.key;
                    _TrainingBlock block = entry.value;

                    if (block.groupId == 0) {
                      // Standalone stage
                      int actualIndex = trainingStages.indexOf(block.stages.first);
                      return Container(
                        key: ValueKey('block_standalone_${block.stages.first.hashCode}'),
                        child: TrainingStageTile(
                          trainingStage: block.stages.first,
                          trainingStageIndex: actualIndex,
                          isExpanded: expandedStates[actualIndex],
                          onExpandedChanged: (value) => setState(() => expandedStates[actualIndex] = value),
                          onDelete: () => removeTrainingStage(actualIndex),
                          onUpdate: () => setState(() => widget.training.trainingStages = trainingStages),
                        ),
                      );
                    } else {
                      // Grouped stage
                      return Container(
                        key: ValueKey('block_group_${block.groupId}'),
                        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: block.groupColor!.withOpacity(0.15),
                          border: Border.all(color: block.groupColor!, width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            // Group Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: blockIndex,
                                    child: Icon(Icons.drag_indicator, color: block.groupColor!.withOpacity(0.8), size: 28),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Group Reps: ${block.stages.first.stageReps}",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: block.groupColor),
                                  ),
                                  Spacer(),
                                  TextButton.icon(
                                    onPressed: () => ungroup(block.groupId),
                                    icon: Icon(Icons.link_off, size: 18, color: block.groupColor),
                                    label: Text("Ungroup", style: TextStyle(color: block.groupColor, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                            ),
                            // The Stages inside the group
                            ...block.stages.map((stage) {
                              int actualIndex = trainingStages.indexOf(stage);
                              return TrainingStageTile(
                                trainingStage: stage,
                                trainingStageIndex: actualIndex,
                                isExpanded: expandedStates[actualIndex],
                                onExpandedChanged: (value) => setState(() => expandedStates[actualIndex] = value),
                                onDelete: () => removeTrainingStage(actualIndex),
                                onUpdate: () => setState(() => widget.training.trainingStages = trainingStages),
                              );
                            }).toList()
                          ],
                        ),
                      );
                    }
                  }).toList(),
                )
                    : SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    // ... Rest of your UI for Sounds/Other Tabs remains EXACTLY the same ...
                    // (I have omitted the identical code for Tabs 1 & 2 to save vertical space,
                    // just paste your existing _selectedTab == 1 and == 2 code here)
                    child: _selectedTab == 1
                        ? Text("Sounds Tab (Paste existing code here)")
                        : Text("Other Tab (Paste existing code here)")
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _selectedTab == 0
            ? FloatingActionButton.extended(
          onPressed: addTrainingStage,
          backgroundColor: darkerblue,
          label: Text(
              translationProvider.getTranslation("TrainingEditorPage.TrainingTab.add_training_stage_button_label"),
              style: TextStyle(color: Colors.white)),
          icon: Icon(Icons.add, color: Colors.white),
        )
            : null,
      ),
    );
  }

  SoundScope _previousBackgroundScope = SoundScope.global;
  void toggleBinauralBeats(bool? value) {
    setState(() {
      if (value == true) {
        _previousBackgroundScope = _sounds.backgroundSoundScope;
        _sounds.backgroundSoundScope = SoundScope.none;
        widget.training.settings.breathingSoundEnabled = false;
      } else {
        _sounds.backgroundSoundScope = _previousBackgroundScope;
      }
      widget.training.settings.binauralBeatsEnabled = value ?? false;
    });
  }

  List<Widget> buildPhaseSoundRows(SoundListType type, bool isSoundSelection) {
    return [
      for (final phase in BreathingPhaseType.values)
        SoundSelectionRow(
          includeVoiceOption: false,
          labelStyle: TextStyle(overflow: TextOverflow.ellipsis),
          label: translationProvider.getTranslation("BreathingPhaseType.${phase.name}"),
          selectedValue: type == SoundListType.longSounds ? _sounds.breathingPhaseBackgrounds[phase]! : _sounds.breathingPhaseCues[phase]!,
          soundListType: type,
          onChanged: (v) {
            setState(() {
              type == SoundListType.longSounds
                  ? _sounds.breathingPhaseBackgrounds[phase] = v
                  : _sounds.breathingPhaseCues[phase] = v;
            });
          },
          isSoundSelection: isSoundSelection ? true : false,
        ),
    ];
  }
}