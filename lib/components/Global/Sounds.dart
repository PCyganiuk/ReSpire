import 'package:hive_flutter/hive_flutter.dart';
import 'package:respire/components/Global/Step.dart';

part 'Sounds.g.dart';

@HiveType(typeId: 9)
class Sounds {

  // // Sound for counting during exercises
  // String? countingSound;

  // // Global switch phase sound to be used across all training
  // String? globalSound;

  // // Sounds for each phase type
  // Map<StepType, String?> stepTypeSounds = {
  //   for (var type in StepType.values) type: null
  // };

  // // Preparation and ending tracks for the training session
  // String? preparationTrack;
  // String? endingTrack;

  // // Background audio for the entire training session
  // String? trainingBackgroundTrack;

  // // Stage tracks for different training stages
  // // key - stage uuid, value - sound name
  // Map<String, String?> stageTracks = {};
  
  // // Audio files for each phase type
  // Map<StepType, String?> stepTypeTracks = {
  //   for (var type in StepType.values) type: null
  // };

  @HiveField(0)
  String? backgroundSound;
  
  @HiveField(1)
  String? nextSound;
  
  @HiveField(2)
  String? inhaleSound;
  
  @HiveField(3)
  String? retentionSound;
  
  @HiveField(4)
  String? exhaleSound;
  
  @HiveField(5)
  String? recoverySound;

  @HiveField(6)
  String? preparationSound;

  @HiveField(7)
  String? nextInhaleSound;

  @HiveField(8)
  String? nextRetentionSound;

  @HiveField(9)
  String? nextExhaleSound;

  @HiveField(10)
  String? nextRecoverySound;

  @HiveField(11)
  String? nextGlobalSound;

  @HiveField(12)
  String? nextVoiceover;

  @HiveField(13)
  String? countingSound;

  @HiveField(14)
  String? endingSound;

  @HiveField(15)
  String? backgroundOptionSound;

  @HiveField(16)
  List<String>? backgroundStagesSounds;

  
void clearUserSound(String soundName) {
    if (backgroundSound == soundName) {
      backgroundSound = null;
    }
    if (inhaleSound == soundName) {
      inhaleSound = null;
    }
    if (retentionSound == soundName) {
      retentionSound = null;
    }
    if (exhaleSound == soundName) {
      exhaleSound = null;
    }
    if (recoverySound == soundName) {
      recoverySound = null;
    }
    if (preparationSound == soundName) {
      preparationSound = null;
    }
    if (nextInhaleSound == soundName) {
      nextInhaleSound = null;
    }
    if (nextRetentionSound == soundName) {
      nextRetentionSound = null;
    }
    if (nextExhaleSound == soundName) {
      nextExhaleSound = null;
    }
    if (nextRecoverySound == soundName) {
      nextRecoverySound = null;
    }
    if (nextGlobalSound == soundName) {
      nextGlobalSound = null;
    }
    if (nextVoiceover == soundName) {
      nextVoiceover = null;
    }
    if (countingSound == soundName) {
      countingSound = null;
    }
    if (endingSound == soundName) {
      endingSound = null;
    }
  }
}
