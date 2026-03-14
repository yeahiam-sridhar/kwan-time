import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/kwan_theme.dart';

class MonthlySummary {
  MonthlySummary({
    required this.id,
    required this.month,
    required this.totalOnline,
    required this.totalInPerson,
    required this.totalBooked,
    required this.totalCancelled,
    required this.totalCompleted,
    required this.totalNotStarted,
    required this.totalInProgress,
    required this.availableDays,
    required this.availableSaturdays,
    required this.availableSundays,
    required this.availableDatesJson,
    required this.freeTimeMinutes,
  });

  factory MonthlySummary.fromMap(Map<String, dynamic> map) => MonthlySummary(
        id: (map['id'] ?? '') as String,
        month: (map['month'] ?? '') as String,
        totalOnline: (map['total_online'] ?? 0) as int,
        totalInPerson: (map['total_in_person'] ?? 0) as int,
        totalBooked: (map['total_booked'] ?? 0) as int,
        totalCancelled: (map['total_cancelled'] ?? 0) as int,
        totalCompleted: (map['total_completed'] ?? 0) as int,
        totalNotStarted: (map['total_not_started'] ?? 0) as int,
        totalInProgress: (map['total_in_progress'] ?? 0) as int,
        availableDays: (map['available_days'] ?? 0) as int,
        availableSaturdays: (map['available_saturdays'] ?? 0) as int,
        availableSundays: (map['available_sundays'] ?? 0) as int,
        availableDatesJson: (map['available_dates'] ?? '[]') as String,
        freeTimeMinutes: (map['free_time_minutes'] ?? 0) as int,
      );

  final String id;
  final String month;
  final int totalOnline;
  final int totalInPerson;
  final int totalBooked;
  final int totalCancelled;
  final int totalCompleted;
  final int totalNotStarted;
  final int totalInProgress;
  final int availableDays;
  final int availableSaturdays;
  final int availableSundays;
  final String availableDatesJson;
  final int freeTimeMinutes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'month': month,
        'total_online': totalOnline,
        'total_in_person': totalInPerson,
        'total_booked': totalBooked,
        'total_cancelled': totalCancelled,
        'total_completed': totalCompleted,
        'total_not_started': totalNotStarted,
        'total_in_progress': totalInProgress,
        'available_days': availableDays,
        'available_saturdays': availableSaturdays,
        'available_sundays': availableSundays,
        'available_dates': availableDatesJson,
        'free_time_minutes': freeTimeMinutes,
      };

  MonthlySummary copyWith({
    String? id,
    String? month,
    int? totalOnline,
    int? totalInPerson,
    int? totalBooked,
    int? totalCancelled,
    int? totalCompleted,
    int? totalNotStarted,
    int? totalInProgress,
    int? availableDays,
    int? availableSaturdays,
    int? availableSundays,
    String? availableDatesJson,
    int? freeTimeMinutes,
  }) =>
      MonthlySummary(
        id: id ?? this.id,
        month: month ?? this.month,
        totalOnline: totalOnline ?? this.totalOnline,
        totalInPerson: totalInPerson ?? this.totalInPerson,
        totalBooked: totalBooked ?? this.totalBooked,
        totalCancelled: totalCancelled ?? this.totalCancelled,
        totalCompleted: totalCompleted ?? this.totalCompleted,
        totalNotStarted: totalNotStarted ?? this.totalNotStarted,
        totalInProgress: totalInProgress ?? this.totalInProgress,
        availableDays: availableDays ?? this.availableDays,
        availableSaturdays: availableSaturdays ?? this.availableSaturdays,
        availableSundays: availableSundays ?? this.availableSundays,
        availableDatesJson: availableDatesJson ?? this.availableDatesJson,
        freeTimeMinutes: freeTimeMinutes ?? this.freeTimeMinutes,
      );

  List<AvailableDate> get availableDateList {
    try {
      final decoded = jsonDecode(availableDatesJson);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .map((e) => '$e')
          .map((display) {
            final parsed = _parseAvailableDate(display, month);
            if (parsed == null) {
              return null;
            }
            return AvailableDate(
              display: display,
              date: parsed,
            );
          })
          .whereType<AvailableDate>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  int get totalEvents => totalOnline + totalInPerson;

  double get onlineRatio {
    if (totalEvents == 0) {
      return 0;
    }
    return totalOnline / totalEvents;
  }

  String get densityLabel {
    if (totalBooked < 20) {
      return 'Light';
    }
    if (totalBooked < 50) {
      return 'Moderate';
    }
    if (totalBooked < 100) {
      return 'Heavy';
    }
    return 'Packed';
  }

  Color get densityColor {
    switch (densityLabel) {
      case 'Light':
        return KwanColors.success;
      case 'Moderate':
        return KwanColors.warning;
      case 'Heavy':
        return KwanColors.inPerson;
      default:
        return KwanColors.error;
    }
  }

  String get monthLabel {
    final parsed = DateTime.tryParse('$month-01');
    if (parsed == null) {
      return month;
    }
    return DateFormat('MMMM yyyy').format(parsed);
  }

  bool get isCurrentMonth {
    final now = DateTime.now();
    final current = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';
    return month == current;
  }

  double get freeTimeHours => freeTimeMinutes / 60.0;

  static DateTime? _parseAvailableDate(String display, String month) {
    final match = RegExp(r'^(\d{2})-(\d{2})').firstMatch(display);
    if (match == null) {
      return null;
    }

    final day = int.tryParse(match.group(1)!);
    final mon = int.tryParse(match.group(2)!);
    final year = int.tryParse(month.split('-').first);
    if (day == null || mon == null || year == null) {
      return null;
    }

    return DateTime(year, mon, day);
  }
}

class AvailableDate {
  const AvailableDate({
    required this.display,
    required this.date,
  });

  final String display;
  final DateTime date;

  bool get isWeekend => date.weekday >= DateTime.saturday;
}
