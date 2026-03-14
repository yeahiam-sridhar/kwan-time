import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../../core/database/db_helper.dart';
import '../../../../core/models/event.dart';
import '../../../../core/services/notification_service.dart';
import '../models/sync_event.dart';

class NotificationScheduler {
  NotificationScheduler._();

  static final NotificationScheduler instance = NotificationScheduler._();

  static const String _createNotificationIdsTable = '''
CREATE TABLE IF NOT EXISTS notification_ids (
  notifId INTEGER NOT NULL,
  eventId TEXT NOT NULL,
  reminderMinutes INTEGER NOT NULL,
  PRIMARY KEY (notifId)
)
''';

  Future<void> scheduleEventReminders(SyncEvent event) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);
    await cancelEventReminders(event.id);

    final DateTime now = DateTime.now();
    for (final int reminder in event.reminderMinutes.toSet().toList()..sort()) {
      final DateTime triggerTime =
          event.startTime.subtract(Duration(minutes: reminder));
      if (!triggerTime.isAfter(now)) {
        continue;
      }

      final int notifId = _stableNotificationId(event.id, reminder);
      await db.insert(
        'notification_ids',
        <String, Object?>{
          'notifId': notifId,
          'eventId': event.id,
          'reminderMinutes': reminder,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      try {
        await NotificationService.instance.scheduleEventReminder(
          _toCoreEvent(event),
          reminder,
        );
      } catch (_) {
        await db.delete(
          'notification_ids',
          where: 'notifId = ?',
          whereArgs: <Object?>[notifId],
        );
      }
    }
  }

  Future<void> cancelEventReminders(String eventId) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);

    await db.query(
      'notification_ids',
      columns: <String>['notifId'],
      where: 'eventId = ?',
      whereArgs: <Object?>[eventId],
    );

    await NotificationService.instance.cancelEventReminders(eventId);
    await db.delete(
      'notification_ids',
      where: 'eventId = ?',
      whereArgs: <Object?>[eventId],
    );
  }

  Future<void> rescheduleAllForSpace(String spaceId) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);

    final List<Map<String, Object?>> rows = await db.query(
      'sync_events',
      where: 'spaceId = ? AND isDeleted = 0 AND startTime > ?',
      whereArgs: <Object?>[spaceId, DateTime.now().millisecondsSinceEpoch],
      orderBy: 'startTime ASC',
    );

    for (final Map<String, Object?> row in rows) {
      final SyncEvent event = SyncEvent.fromMap(row);
      await scheduleEventReminders(event);
    }
  }

  String reminderTitle(SyncEvent event) => '⏰ ${event.title}';

  String reminderBody(int reminderMinutes) {
    switch (reminderMinutes) {
      case 60:
        return 'Starts in 1 hour';
      case 30:
        return 'Starts in 30 minutes';
      case 10:
        return 'Starts in 10 minutes';
      case 5:
        return 'Starting in 5 minutes';
      default:
        return 'Starts in $reminderMinutes minutes';
    }
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute(_createNotificationIdsTable);
  }

  int _stableNotificationId(String eventId, int reminderMinutes) {
    final int id = '${eventId}_$reminderMinutes'.hashCode.abs() % 2147483647;
    return id == 0 ? 1 : id;
  }

  Event _toCoreEvent(SyncEvent event) {
    return Event(
      id: event.id,
      title: reminderTitle(event),
      eventType: 'in_person',
      status: 'not_started',
      startTime: event.startTime,
      endTime: event.endTime,
      createdAt: event.createdAt,
      updatedAt: event.updatedAt,
      location: event.location,
      notes: event.description,
      reminderMinutes: jsonEncode(event.reminderMinutes),
    );
  }
}
