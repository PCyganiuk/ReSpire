class VisualStyle {
  final String name;
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
      return ring;
    }
    return availableStyles.firstWhere(
          (lang) => lang.name == name,
      orElse: () => ring,
    );
  }
}