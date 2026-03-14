import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SpaceEvent extends Equatable {
  const SpaceEvent({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.reminderMinutes,
    required this.commentCount,
    this.description,
    this.location,
    this.createdByName,
    this.colorHex,
  });

  final String id;
  final String spaceId;
  final String title;
  final String? description;
  final String? location;
  final DateTime startTime;
  final DateTime endTime;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<int> reminderMinutes;
  final String? colorHex;
  final int commentCount;

  factory SpaceEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final reminderRaw = data['reminderMinutes'] ?? data['reminders'];
    return SpaceEvent(
      id: doc.id,
      spaceId: data['spaceId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      location: data['location'] as String?,
      // Always read as Timestamp - never int or String.
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reminderMinutes: _parseReminderMinutes(reminderRaw),
      colorHex: data['colorHex'] as String?,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory SpaceEvent.fromMap(Map<String, dynamic> m) {
    return SpaceEvent(
      id: m['id'] as String? ?? '',
      spaceId: m['spaceId'] as String? ?? '',
      title: m['title'] as String? ?? '',
      description: m['description'] as String?,
      location: m['location'] as String?,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (m['startTime'] as num?)?.toInt() ?? 0,
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (m['endTime'] as num?)?.toInt() ?? 0,
      ),
      createdBy: m['createdBy'] as String? ?? '',
      createdByName: m['createdByName'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (m['createdAt'] as num?)?.toInt() ??
            (m['startTime'] as num?)?.toInt() ??
            0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (m['updatedAt'] as num?)?.toInt() ??
            (m['endTime'] as num?)?.toInt() ??
            0,
      ),
      reminderMinutes: _parseReminderMinutes(m['reminderMinutes']),
      colorHex: m['colorHex'] as String?,
      commentCount: (m['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'spaceId': spaceId,
        'title': title,
        'description': description,
        'location': location,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'reminderMinutes': jsonEncode(reminderMinutes),
        'colorHex': colorHex,
        'commentCount': commentCount,
      };

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'spaceId': spaceId,
        'title': title,
        'description': description,
        'location': location,
        // Always write as Timestamp - never int or String.
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
        'reminderMinutes': reminderMinutes,
        'colorHex': colorHex,
        'commentCount': commentCount,
      };

  Duration get duration => endTime.difference(startTime);

  bool get isAllDay => duration.inHours >= 23;

  bool get isPast => endTime.isBefore(DateTime.now());

  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  bool overlaps(SpaceEvent other) =>
      startTime.isBefore(other.endTime) && endTime.isAfter(other.startTime);

  SpaceEvent copyWith({
    String? id,
    String? spaceId,
    String? title,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<int>? reminderMinutes,
    String? colorHex,
    int? commentCount,
  }) {
    return SpaceEvent(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      colorHex: colorHex ?? this.colorHex,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  @override
  List<Object?> get props => [id, spaceId, title, startTime, endTime, updatedAt];

  static List<int> _parseReminderMinutes(dynamic raw) {
    if (raw == null) {
      return const [];
    }
    if (raw is List) {
      return raw.map((e) => (e as num).toInt()).toList();
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => (e as num).toInt()).toList();
        }
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }
}
