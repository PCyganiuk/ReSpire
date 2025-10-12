import 'package:hive_flutter/hive_flutter.dart';
import 'package:respire/components/Global/Step.dart';

part 'Phase.g.dart';

@HiveType(typeId: 2)
class Phase {
  
  @HiveField(0)
  int reps;
  
  @HiveField(1)
  int doneRepsCounter = 0;

  @HiveField(2)
  int increment = 0; // in seconds
  
  @HiveField(3)
  List<Step> steps;

  @HiveField(4)
  String name;

  Phase({
    required this.reps,
    required this.increment,
    required this.steps,
    this.name = '',
  });

  void addStep(Step step)
  {
    steps.add(step);
  }
}