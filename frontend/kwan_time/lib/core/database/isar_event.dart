import 'package:isar/isar.dart';

@collection
class IsarEvent {
  Id get isarId => fastHash(id);

  late String id;
  late String title;
  late String eventType;
  late String status;

  @Index()
  late DateTime startTime;

  @Index()
  late DateTime endTime;

  String? location;
  String? notes;
  late bool isRecurring;
  String? recurrenceRule;
  late String reminderMinutes;
  late DateTime createdAt;
  late DateTime updatedAt;
}

int fastHash(String string) {
  var hash = 0xcbf29ce484222325;
  for (var i = 0; i < string.length; i++) {
    final codeUnit = string.codeUnitAt(i);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}
