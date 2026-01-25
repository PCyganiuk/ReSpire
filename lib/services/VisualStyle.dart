import 'package:hive/hive.dart';

part 'VisualStyle.g.dart';


@HiveType(typeId: 13)
class VisualStyle {
  @HiveField(0)
  final String name;
  @HiveField(1)
  bool isSelected;

  VisualStyle({
    required this.name,
    required this.isSelected
});

  static VisualStyle ring = VisualStyle(name: "ring", isSelected: true);
  static VisualStyle timeline = VisualStyle(name: "timeline", isSelected: false);

  static List<VisualStyle> availableStyles = [
    ring,
    timeline
  ];

  static VisualStyle fromString(String? name) {
    if (name == null || name.isEmpty) {
      return timeline;
    }
    return availableStyles.firstWhere(
          (lang) => lang.name == name,
      orElse: () => timeline,
    );
  }
}