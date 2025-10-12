import 'package:hive_flutter/hive_flutter.dart';
import 'package:respire/components/Global/Phase.dart';
import 'package:respire/components/Global/Settings.dart';
import 'package:respire/components/Global/Sounds.dart';

part 'Training.g.dart';

@HiveType(typeId: 1)
class Training {

  @HiveField(0)
  String title;

  @HiveField(1)
  String description;

  @HiveField(2)
  List<Phase> phases;

  @HiveField(3)
  Sounds sounds = Sounds();

  @HiveField(4)
  Settings settings = Settings();

  @HiveField(5)
  String? globalBackgroundSound;

  Training({
    required this.title,
    required this.phases,
    this.description = '',
  });

  // Call this method after loading or modifying the training to ensure that all phases and steps have the correct background sounds.
  void propagateBackgroundSounds() {
    for (var phase in phases) {
      phase.propabateBackgroundSound(globalBackgroundSound);
    }
  }
}
