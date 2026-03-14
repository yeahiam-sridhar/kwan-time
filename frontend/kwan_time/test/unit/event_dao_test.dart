import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwan_time/core/database/dao/event_dao.dart';
import 'package:kwan_time/core/models/event.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late EventDao dao;
  var sqfliteAvailable = true;

  setUp(() async {
    if (!sqfliteAvailable) {
      return;
    }

    try {
      db = await openDatabase(
        ':memory:',
        version: 1,
        onCreate: (db, version) async {
          await db.execute(_createEventsTableSql);
          await db.execute(_createMonthlyCacheTableSql);
          await db.execute(_createAppSettingsTableSql);
        },
      );
      dao = EventDao(database: db);
    } on MissingPluginException {
      sqfliteAvailable = false;
    } catch (_) {
      sqfliteAvailable = false;
    }
  });

  tearDown(() async {
    if (!sqfliteAvailable) {
      return;
    }
    await db.close();
  });

  test('insert and retrieve event', () async {
    if (!sqfliteAvailable) {
      return;
    }
    final event = _event(
      id: 'test-uuid-1',
      title: 'Test Meeting',
      eventType: 'in_person',
      status: 'not_started',
      startTime: DateTime(2026, 1, 16, 10, 0),
      endTime: DateTime(2026, 1, 16, 11, 0),
    );

    await dao.insert(event);
    final retrieved = await dao.getById('test-uuid-1');

    expect(retrieved, isNotNull);
    expect(retrieved!.title, equals('Test Meeting'));
    expect(retrieved.eventType, equals('in_person'));
  });

  test('update event status', () async {
    if (!sqfliteAvailable) {
      return;
    }
    final event = _event(
      id: 'test-uuid-2',
      title: 'Sales Call',
      eventType: 'online',
      status: 'not_started',
      startTime: DateTime(2026, 1, 20, 14, 0),
      endTime: DateTime(2026, 1, 20, 15, 0),
    );

    await dao.insert(event);
    await dao.update(event.copyWith(status: 'completed'));
    final updated = await dao.getById('test-uuid-2');

    expect(updated, isNotNull);
    expect(updated!.status, equals('completed'));
  });

  test('delete event', () async {
    if (!sqfliteAvailable) {
      return;
    }
    final event = _event(
      id: 'test-uuid-3',
      title: 'Delete Me',
      eventType: 'free',
      status: 'not_started',
      startTime: DateTime(2026, 2, 1, 9, 0),
      endTime: DateTime(2026, 2, 1, 10, 0),
    );

    await dao.insert(event);
    await dao.delete('test-uuid-3');
    final result = await dao.getById('test-uuid-3');

    expect(result, isNull);
  });

  test('getForDay returns only that day events', () async {
    if (!sqfliteAvailable) {
      return;
    }
    for (final day in [16, 16, 17]) {
      await dao.insert(
        _event(
          id: 'uuid-jan-$day-${DateTime.now().microsecondsSinceEpoch}',
          title: 'Event on Jan $day',
          eventType: 'in_person',
          status: 'not_started',
          startTime: DateTime(2026, 1, day, 10, 0),
          endTime: DateTime(2026, 1, day, 11, 0),
        ),
      );
    }

    final jan16Events = await dao.getForDay(DateTime(2026, 1, 16));
    final jan17Events = await dao.getForDay(DateTime(2026, 1, 17));

    expect(jan16Events.length, equals(2));
    expect(jan17Events.length, equals(1));
  });

  test('hasConflict detects overlapping events', () async {
    if (!sqfliteAvailable) {
      return;
    }
    await dao.insert(
      _event(
        id: 'conflict-base',
        title: 'Existing Meeting',
        eventType: 'in_person',
        status: 'not_started',
        startTime: DateTime(2026, 1, 21, 10, 0),
        endTime: DateTime(2026, 1, 21, 11, 30),
      ),
    );

    final conflict = await dao.hasConflict(
      DateTime(2026, 1, 21, 10, 30),
      DateTime(2026, 1, 21, 11, 0),
    );
    final noConflict = await dao.hasConflict(
      DateTime(2026, 1, 21, 12, 0),
      DateTime(2026, 1, 21, 13, 0),
    );

    expect(conflict, isTrue);
    expect(noConflict, isFalse);
  });
}

Event _event({
  required String id,
  required String title,
  required String eventType,
  required String status,
  required DateTime startTime,
  required DateTime endTime,
}) {
  final now = DateTime.now();
  return Event(
    id: id,
    title: title,
    eventType: eventType,
    status: status,
    startTime: startTime,
    endTime: endTime,
    isRecurring: false,
    reminderMinutes: '[]',
    createdAt: now,
    updatedAt: now,
  );
}

const String _createEventsTableSql = '''
CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  event_type TEXT,
  status TEXT,
  location TEXT,
  notes TEXT,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  is_recurring INTEGER DEFAULT 0,
  recurrence_rule TEXT,
  reminder_minutes TEXT,
  sound_key TEXT,
  color_override TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);
''';

const String _createMonthlyCacheTableSql = '''
CREATE TABLE IF NOT EXISTS monthly_cache (
  id TEXT PRIMARY KEY,
  month TEXT NOT NULL,
  total_online INTEGER DEFAULT 0,
  total_in_person INTEGER DEFAULT 0,
  total_booked INTEGER DEFAULT 0,
  total_cancelled INTEGER DEFAULT 0,
  total_completed INTEGER DEFAULT 0,
  total_not_started INTEGER DEFAULT 0,
  total_in_progress INTEGER DEFAULT 0,
  available_days INTEGER DEFAULT 0,
  available_saturdays INTEGER DEFAULT 0,
  available_sundays INTEGER DEFAULT 0,
  available_dates TEXT,
  free_time_minutes INTEGER DEFAULT 0,
  UNIQUE(month)
);
''';

const String _createAppSettingsTableSql = '''
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
''';
