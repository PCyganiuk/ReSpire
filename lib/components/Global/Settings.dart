import 'package:hive_flutter/hive_flutter.dart';

part 'Settings.g.dart';

@HiveType(typeId: 10)
class Settings {
  
  @HiveField(0)
  int preparationDuration = 3; //in seconds
  
  @HiveField(1)
  bool differentColors = false;

  
}