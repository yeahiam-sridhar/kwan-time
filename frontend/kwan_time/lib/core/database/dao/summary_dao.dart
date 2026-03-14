import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/monthly_summary.dart';
import '../db_helper.dart';
import 'event_dao.dart';

class SummaryDao {
  Future<MonthlySummary?> getForMonth(String month) async {
    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'monthly_cache',
      where: 'month = ?',
      whereArgs: [month],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return MonthlySummary.fromMap(rows.first);
  }

  Future<List<MonthlySummary>> getThreeMonths(String startMonth) async {
    final start = _monthStringToDate(startMonth);
    final eventDao = EventDao();
    final out = <MonthlySummary>[];

    for (var i = 0; i < 3; i++) {
      final monthDate = DateTime(start.year, start.month + i, 1);
      final monthKey = _monthKey(monthDate);
      final cached = await getForMonth(monthKey);
      if (cached != null) {
        out.add(cached);
        continue;
      }

      final computed = await recompute(monthDate, eventDao);
      out.add(computed);
    }

    return out;
  }

  Future<void> upsert(MonthlySummary summary) async {
    final db = await DbHelper.instance.database;
    await db.insert(
      'monthly_cache',
      summary.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MonthlySummary> recompute(DateTime month, EventDao eventDao) async {
    final db = await DbHelper.instance.database;
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);
    final monthKey = _monthKey(month);

    final typeCounts = await eventDao.countByTypeForMonth(month);
    final totalOnline = typeCounts['online'] ?? 0;
    final totalInPerson = typeCounts['in_person'] ?? 0;

    final statusRows = await db.rawQuery(
      '''
      SELECT status, COUNT(*) AS count
      FROM events
      WHERE start_time >= ? AND start_time < ?
      GROUP BY status
      ''',
      [monthStart.toIso8601String(), monthEnd.toIso8601String()],
    );

    var totalCancelled = 0;
    var totalCompleted = 0;
    var totalNotStarted = 0;
    var totalInProgress = 0;
    for (final row in statusRows) {
      final status = (row['status'] ?? '') as String;
      final count = (row['count'] as int?) ?? 0;
      switch (status) {
        case 'cancelled':
          totalCancelled = count;
          break;
        case 'completed':
          totalCompleted = count;
          break;
        case 'not_started':
          totalNotStarted = count;
          break;
        case 'in_progress':
          totalInProgress = count;
          break;
      }
    }

    final availableDates = await eventDao.getAvailableDates(month);
    var availableSaturdays = 0;
    var availableSundays = 0;
    for (final d in availableDates) {
      if (d.endsWith('Sa')) {
        availableSaturdays++;
      } else if (d.endsWith('Su')) {
        availableSundays++;
      }
    }

    final totalBooked = totalOnline + totalInPerson;

    final durationRows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM((julianday(end_time) - julianday(start_time)) * 24 * 60), 0)
          AS booked_minutes
      FROM events
      WHERE start_time >= ? AND start_time < ?
      ''',
      [monthStart.toIso8601String(), monthEnd.toIso8601String()],
    );
    final bookedMinutes = ((durationRows.first['booked_minutes'] as num?) ?? 0).round();

    final totalMinutesInMonth = monthEnd.difference(monthStart).inMinutes;
    final freeTimeMinutes = (totalMinutesInMonth - bookedMinutes).clamp(0, totalMinutesInMonth);

    final summary = MonthlySummary(
      id: monthKey,
      month: monthKey,
      totalOnline: totalOnline,
      totalInPerson: totalInPerson,
      totalBooked: totalBooked,
      totalCancelled: totalCancelled,
      totalCompleted: totalCompleted,
      totalNotStarted: totalNotStarted,
      totalInProgress: totalInProgress,
      availableDays: availableDates.length,
      availableSaturdays: availableSaturdays,
      availableSundays: availableSundays,
      availableDatesJson: jsonEncode(availableDates),
      freeTimeMinutes: freeTimeMinutes,
    );

    await upsert(summary);
    return summary;
  }

  Future<void> invalidate(String month) async {
    final db = await DbHelper.instance.database;
    await db.delete(
      'monthly_cache',
      where: 'month = ?',
      whereArgs: [month],
    );
  }

  DateTime _monthStringToDate(String month) {
    final parts = month.split('-');
    if (parts.length != 2) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, 1);
    }

    final year = int.tryParse(parts.first);
    final mon = int.tryParse(parts.last);
    if (year == null || mon == null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, 1);
    }

    return DateTime(year, mon, 1);
  }

  String _monthKey(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
}
