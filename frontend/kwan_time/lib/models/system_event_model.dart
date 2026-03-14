class SystemEventModel {
  const SystemEventModel({
    required this.id,
    required this.title,
    required this.date,
    required this.category,
    required this.emoji,
    this.isSystemEvent = true,
    required this.regionCode,
  });

  final String id;
  final String title;
  final DateTime date;
  final String category;
  final String emoji;
  final bool isSystemEvent;
  final String regionCode;
}
