import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../database/db_helper.dart';
import '../models/monthly_summary.dart';
import '../theme/kwan_theme.dart';
import 'event_provider.dart';

final dashboardMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final threeMonthSummaryProvider = FutureProvider<List<MonthlySummary>>((ref) async {
  final startMonth = ref.watch(dashboardMonthProvider);
  final dao = ref.watch(summaryDaoProvider);
  final startKey = _monthKey(startMonth);
  final summaries = await dao.getThreeMonths(startKey);
  if (summaries.length == 3) {
    return summaries;
  }

  final normalized = <MonthlySummary>[];
  for (var i = 0; i < 3; i++) {
    final month = DateTime(startMonth.year, startMonth.month + i, 1);
    final key = _monthKey(month);
    final existing = summaries.where((s) => s.month == key).cast<MonthlySummary?>().firstOrNull;
    if (existing != null) {
      normalized.add(existing);
    } else {
      normalized.add(await dao.recompute(month, ref.read(eventDaoProvider)));
    }
  }
  return normalized;
});

final statusMatrixProvider = FutureProvider<Map<String, int>>((ref) async {
  final eventDao = ref.watch(eventDaoProvider);
  final raw = await eventDao.countByStatusPeriod();
  return _normalizedMatrixKeys(raw);
});

final monthlyBookedCountProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await DbHelper.instance.database;
  final rows = await db.query(
    'monthly_cache',
    columns: ['month', 'total_online', 'total_in_person', 'total_booked'],
    orderBy: 'month ASC',
  );

  return rows.map((row) {
    final month = (row['month'] ?? '') as String;
    final parts = month.split('-');
    final label = parts.length == 2 ? '${parts[0].substring(2, 4)}-${parts[1]}' : month;
    final online = (row['total_online'] as int?) ?? 0;
    final inPerson = (row['total_in_person'] as int?) ?? 0;
    final total = (row['total_booked'] as int?) ?? (online + inPerson);

    return {
      'month': label,
      'online': online,
      'in_person': inPerson,
      'total': total,
    };
  }).toList();
});

final dailyCountsProvider = FutureProvider<Map<String, List<Map<String, dynamic>>>>((ref) async {
  final start = ref.watch(dashboardMonthProvider);
  final eventDao = ref.watch(eventDaoProvider);
  final out = <String, List<Map<String, dynamic>>>{};

  for (var i = 0; i < 3; i++) {
    final month = DateTime(start.year, start.month + i, 1);
    final monthName = DateFormat('MMM').format(month);
    final dbRows = await eventDao.getDailyCountsForMonth(month);
    final byDay = <String, Map<String, dynamic>>{};
    for (final row in dbRows) {
      final day = (row['day'] ?? '') as String;
      byDay[day] = row;
    }

    final rows = <Map<String, dynamic>>[];
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final iso = DateFormat('yyyy-MM-dd').format(date);
      final existing = byDay[iso];
      rows.add({
        'date': DateFormat('dd-MM').format(date),
        'day': DateFormat('EEE').format(date),
        'online': (existing?['online'] as int?) ?? 0,
        'in_person': (existing?['in_person'] as int?) ?? 0,
      });
    }
    out[monthName] = rows;
  }

  return out;
});

final smartInsightsProvider = Provider<List<InsightMessage>>((ref) {
  final summaryAsync = ref.watch(threeMonthSummaryProvider);
  final matrixAsync = ref.watch(statusMatrixProvider);
  final dailyAsync = ref.watch(dailyCountsProvider);
  if (summaryAsync is! AsyncData<List<MonthlySummary>> ||
      matrixAsync is! AsyncData<Map<String, int>> ||
      dailyAsync is! AsyncData<Map<String, List<Map<String, dynamic>>>>) {
    return const [];
  }

  final summaries = summaryAsync.value;
  if (summaries.isEmpty) {
    return const [];
  }
  final current = summaries[0];
  final next = summaries.length > 1 ? summaries[1] : summaries[0];
  final daily = dailyAsync.value;
  final insights = <InsightMessage>[];

  // Rule 1: Heavy day
  var maxEvents = 0;
  String? heavyDate;
  for (final entry in daily.entries) {
    for (final row in entry.value) {
      final total = ((row['online'] as int?) ?? 0) + ((row['in_person'] as int?) ?? 0);
      if (total >= 5 && total > maxEvents) {
        maxEvents = total;
        heavyDate = '${row['date']} ${entry.key}';
      }
    }
  }
  if (maxEvents >= 5 && heavyDate != null) {
    insights.add(
      InsightMessage(
        emoji: '🔥',
        text: 'Heavy day — $maxEvents events on $heavyDate',
        type: InsightType.alert,
      ),
    );
  }

  // Rule 2: Free weekdays (Fridays)
  final freeFridays = current.availableDateList.where((d) => DateFormat('EEE').format(d.date) == 'Fri').length;
  if (freeFridays >= 2) {
    insights.add(
      InsightMessage(
        emoji: '✅',
        text: '$freeFridays free Fridays in ${DateFormat('MMMM').format(DateTime.parse('${current.month}-01'))}',
        type: InsightType.success,
      ),
    );
  }

  // Rule 3: Overloaded month
  final monthDate = DateTime.parse('${current.month}-01');
  final workingDays = _workingDaysInMonth(monthDate.year, monthDate.month);
  final avgPerWorkingDay = workingDays == 0 ? 0 : current.totalBooked / workingDays;
  if (avgPerWorkingDay > 4) {
    insights.add(
      InsightMessage(
        emoji: '⚠️',
        text: '${DateFormat('MMMM').format(monthDate)} is packed — consider buffer days',
        type: InsightType.warning,
      ),
    );
  }

  // Rule 4: Best next date in 7 days
  final now = DateTime.now();
  final next7 = now.add(const Duration(days: 7));
  final freeDates = summaries.expand((s) => s.availableDateList).toList()..sort((a, b) => a.date.compareTo(b.date));
  final nextAvailable = freeDates.where((d) {
    final day = DateTime(d.date.year, d.date.month, d.date.day);
    return !day.isBefore(DateTime(now.year, now.month, now.day)) &&
        !day.isAfter(DateTime(next7.year, next7.month, next7.day));
  }).firstOrNull;
  if (nextAvailable != null) {
    insights.add(
      InsightMessage(
        emoji: '📅',
        text: 'Best availability: ${nextAvailable.display}',
        type: InsightType.info,
      ),
    );
  }

  // Rule 5: Next month spike
  if (current.totalBooked > 0 && next.totalBooked > (current.totalBooked * 1.2)) {
    final pct = (((next.totalBooked - current.totalBooked) / current.totalBooked) * 100).round();
    insights.add(
      InsightMessage(
        emoji: '📈',
        text:
            '${DateFormat('MMMM').format(DateTime.parse('${next.month}-01'))} is $pct% busier than ${DateFormat('MMMM').format(monthDate)}',
        type: InsightType.warning,
      ),
    );
  }

  // Rule 6: Free time
  if (current.freeTimeHours > 40) {
    insights.add(
      InsightMessage(
        emoji: '💚',
        text: '${current.freeTimeHours.round()}h free time this month — schedule deep work',
        type: InsightType.success,
      ),
    );
  }

  return insights;
});

class InsightMessage {
  const InsightMessage({
    required this.emoji,
    required this.text,
    required this.type,
  });

  final String emoji;
  final String text;
  final InsightType type;

  Color get color => switch (type) {
        InsightType.warning => KwanColors.warning,
        InsightType.success => KwanColors.success,
        InsightType.info => KwanColors.info,
        InsightType.alert => KwanColors.error,
      };
}

enum InsightType { warning, success, info, alert }

String _monthKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

Map<String, int> _normalizedMatrixKeys(Map<String, int> source) {
  final out = <String, int>{};
  for (final entry in source.entries) {
    out[entry.key] = entry.value;
    out[entry.key.replaceAll('in_person', 'inperson')] = entry.value;
  }
  return out;
}

int _workingDaysInMonth(int year, int month) {
  final days = DateUtils.getDaysInMonth(year, month);
  var working = 0;
  for (var d = 1; d <= days; d++) {
    final weekday = DateTime(year, month, d).weekday;
    if (weekday != DateTime.saturday && weekday != DateTime.sunday) {
      working++;
    }
  }
  return working;
}
