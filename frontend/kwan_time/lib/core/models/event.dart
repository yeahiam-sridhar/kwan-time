import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/kwan_theme.dart';

class Event {
  Event({
    required this.id,
    required this.title,
    required this.eventType,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    required this.updatedAt,
    this.location,
    this.notes,
    this.isRecurring = false,
    this.recurrenceRule,
    this.reminderMinutes = '[]',
    this.soundKey,
    this.colorOverride,
  });

  factory Event.fromMap(Map<String, dynamic> map) => Event(
        id: (map['id'] ?? '') as String,
        title: (map['title'] ?? '') as String,
        eventType: (map['event_type'] ?? 'in_person') as String,
        status: (map['status'] ?? 'not_started') as String,
        location: map['location'] as String?,
        notes: map['notes'] as String?,
        startTime: DateTime.parse(map['start_time'] as String),
        endTime: DateTime.parse(map['end_time'] as String),
        isRecurring: (map['is_recurring'] ?? 0) == 1,
        recurrenceRule: map['recurrence_rule'] as String?,
        reminderMinutes: (map['reminder_minutes'] ?? '[]') as String,
        soundKey: map['sound_key'] as String?,
        colorOverride: map['color_override'] as String?,
        createdAt: map['created_at'] == null ? DateTime.now() : DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] == null ? DateTime.now() : DateTime.parse(map['updated_at'] as String),
      );

  final String id;
  final String title;
  final String eventType;
  final String status;
  final String? location;
  final String? notes;
  final DateTime startTime;
  final DateTime endTime;
  final bool isRecurring;
  final String? recurrenceRule;
  final String reminderMinutes;
  final String? soundKey;
  final String? colorOverride;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get type => eventType;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'event_type': eventType,
        'status': status,
        'location': location,
        'notes': notes,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'is_recurring': isRecurring ? 1 : 0,
        'recurrence_rule': recurrenceRule,
        'reminder_minutes': reminderMinutes,
        'sound_key': soundKey,
        'color_override': colorOverride,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Event copyWith({
    String? id,
    String? title,
    String? eventType,
    String? status,
    String? location,
    String? notes,
    DateTime? startTime,
    DateTime? endTime,
    bool? isRecurring,
    String? recurrenceRule,
    String? reminderMinutes,
    String? soundKey,
    String? colorOverride,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Event(
        id: id ?? this.id,
        title: title ?? this.title,
        eventType: eventType ?? this.eventType,
        status: status ?? this.status,
        location: location ?? this.location,
        notes: notes ?? this.notes,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        isRecurring: isRecurring ?? this.isRecurring,
        recurrenceRule: recurrenceRule ?? this.recurrenceRule,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        soundKey: soundKey ?? this.soundKey,
        colorOverride: colorOverride ?? this.colorOverride,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  bool get isOnline => eventType == 'online';
  bool get isInPerson => eventType == 'in_person';
  bool get isPast => endTime.isBefore(DateTime.now());
  bool get isFuture => startTime.isAfter(DateTime.now());

  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year && startTime.month == now.month && startTime.day == now.day;
  }

  bool get isHappeningNow {
    final now = DateTime.now();
    return !startTime.isAfter(now) && !endTime.isBefore(now);
  }

  Duration get duration => endTime.difference(startTime);
  Color get typeColor => KwanColors.forType(eventType);
  Color get statusColor => KwanColors.forStatus(status);

  String get timeRangeLabel {
    final f = DateFormat('HH:mm');
    return '${f.format(startTime)} – ${f.format(endTime)}';
  }

  List<int> get reminderList {
    try {
      final decoded = jsonDecode(reminderMinutes);
      if (decoded is List) {
        return decoded.map((e) => int.tryParse('$e') ?? 0).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
}
