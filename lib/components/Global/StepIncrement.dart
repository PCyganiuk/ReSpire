import 'package:hive_flutter/hive_flutter.dart';

part 'StepIncrement.g.dart';

@HiveType(typeId: 7)
enum IncrementType {
  @HiveField(0)
  percentage, 
  
  @HiveField(1)
  value
}

@HiveType(typeId: 8)
class StepIncrement {
  
  @HiveField(0)
  final double value;
  
  @HiveField(1)
  final IncrementType type;
  
  const StepIncrement({
    required this.value,
    required this.type
    });

}