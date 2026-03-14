import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/event.dart';
import '../db_helper.dart';

class EventDao {
  EventDao({Database? database}) : _database = database;

  final Database? _database;

  Future<Database> _db() async {
    if (_database != null) {
      return _database!;
    }
    return DbHelper.instance.database;
  }

  Future<String> insert(Event event) async {
    final db = await _db();
    await db.insert(
      'events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return event.id;
  }

  Future<Event?> getById(String id) async {
    final db = await _db();
    final rows = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Event.fromMap(rows.first);
  }

  Future<List<Event>> getForMonth(DateTime month) async {
    final db = await _db();
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final rows = await db.query(
      'events',
      where: 'start_time >= ? AND start_time < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'start_time ASC',
    );
    return rows.map(Event.fromMap).toList();
  }

  Future<List<Event>> getForDay(DateTime day) async {
    final db = await _db();
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final rows = await db.query(
      'events',
      where: 'start_time >= ? AND start_time < ?',
      whereArgs: [dayStart.toIso8601String(), dayEnd.toIso8601String()],
      orderBy: 'start_time ASC',
    );
    return rows.map(Event.fromMap).toList();
  }

  Future<List<Event>> getForDateRange(DateTime from, DateTime to) async {
    final db = await _db();
    final rows = await db.query(
      'events',
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'start_time ASC',
    );
    return rows.map(Event.fromMap).toList();
  }

  Future<int> update(Event event) async {
    final db = await _db();
    final count = await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
    debugPrint('[EventDao] updated $count rows for id: ${event.id}');
    return count;
  }

  Future<int> delete(String id) async {
    final db = await _db();
    final count = await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('[EventDao] deleted $count rows for id: $id');
    return count;
  }

  Future<List<Event>> searchByTitle(String query) async {
    final db = await _db();
    final rows = await db.query(
      'events',
      where: 'title LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'start_time ASC',
    );
    return rows.map(Event.fromMap).toList();
  }

  Future<Map<String, int>> countByTypeForMonth(DateTime month) async {
    final db = await _db();
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final rows = await db.rawQuery(
      '''
      SELECT event_type, COUNT(*) AS count
      FROM events
      WHERE start_time >= ? AND start_time < ?
      GROUP BY event_type
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final out = <String, int>{};
    for (final row in rows) {
      final type = (row['event_type'] ?? 'unknown') as String;
      final count = (row['count'] as int?) ?? 0;
      out[type] = count;
    }
    return out;
  }

  Future<Map<String, int>> countByStatusPeriod() async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();

    final rows = await db.rawQuery(
      '''
      SELECT
        CASE
          WHEN end_time < ? THEN 'past'
          WHEN date(start_time) = date(?) THEN 'current'
          WHEN start_time > ? THEN 'future'
          ELSE 'current'
        END AS period,
        COALESCE(event_type, 'unknown') AS event_type,
        COALESCE(status, 'unknown') AS status,
        COUNT(*) AS count
      FROM events
      GROUP BY period, event_type, status
      ''',
      [now, now, now],
    );

    final out = <String, int>{};
    for (final row in rows) {
      final period = row['period']! as String;
      final type = row['event_type']! as String;
      final status = row['status']! as String;
      final count = (row['count'] as int?) ?? 0;
      out['${period}_${type}_$status'] = count;
    }

    return out;
  }

  Future<List<Map<String, dynamic>>> getDailyCountsForMonth(
      DateTime month) async {
    final db = await _db();
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final rows = await db.rawQuery(
      '''
      SELECT
        date(start_time) AS day,
        SUM(CASE WHEN event_type = 'online' THEN 1 ELSE 0 END) AS online,
        SUM(CASE WHEN event_type = 'in_person' THEN 1 ELSE 0 END) AS in_person
      FROM events
      WHERE start_time >= ? AND start_time < ?
      GROUP BY date(start_time)
      ORDER BY day ASC
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return rows;
  }

  Future<List<String>> getAvailableDates(DateTime month) async {
    final db = await _db();
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT date(start_time) AS day
      FROM events
      WHERE start_time >= ? AND start_time < ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final busyDays = <String>{};
    for (final row in rows) {
      final day = row['day'] as String?;
      if (day != null) {
        busyDays.add(day);
      }
    }

    final available = <String>[];
    final totalDays = DateUtils.getDaysInMonth(month.year, month.month);
    for (var day = 1; day <= totalDays; day++) {
      final date = DateTime(month.year, month.month, day);
      final key = DateFormat('yyyy-MM-dd').format(date);
      if (busyDays.contains(key)) {
        continue;
      }
      available.add('${DateFormat('dd-MM').format(date)} ${_dayShort(date)}');
    }

    return available;
  }

  Future<bool> hasConflict(DateTime start, DateTime end,
      {String? excludeId}) async {
    final db = await _db();
    final where = StringBuffer('start_time < ? AND end_time > ?');
    final args = <Object?>[
      end.toIso8601String(),
      start.toIso8601String(),
    ];

    if (excludeId != null && excludeId.isNotEmpty) {
      where.write(' AND id != ?');
      args.add(excludeId);
    }

    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM events WHERE $where',
      args,
    );
    final count = (rows.first['count'] as int?) ?? 0;
    return count > 0;
  }

  String _dayShort(DateTime date) => switch (date.weekday) {
        DateTime.monday => 'Mo',
        DateTime.tuesday => 'Tu',
        DateTime.wednesday => 'We',
        DateTime.thursday => 'Th',
        DateTime.friday => 'Fr',
        DateTime.saturday => 'Sa',
        DateTime.sunday => 'Su',
        _ => '',
      };
}
