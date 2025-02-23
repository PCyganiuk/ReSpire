class PresetEntry
{
  final String title;
  final String description;
  final int breathCount;
  final int inhaleTime;
  final int exhaleTime;
  final int retentionTime;

  const PresetEntry({
    required this.title,
    required this.description,
    required this.breathCount,
    required this.inhaleTime,
    required this.exhaleTime,
    required this.retentionTime
  });
}