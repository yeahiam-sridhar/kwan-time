import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum SyncStatus { synced, pendingSync, syncError }

class SyncEvent extends Equatable {
  const SyncEvent({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.reminderMinutes,
    required this.version,
    required this.syncStatus,
    required this.isDeleted,
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
  final int version;
  final SyncStatus syncStatus;
  final bool isDeleted;

  static const String sqliteCreateTableStatement = '''
CREATE TABLE IF NOT EXISTS sync_events (
  id TEXT PRIMARY KEY,
  spaceId TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  location TEXT,
  startTime INTEGER NOT NULL,
  endTime INTEGER NOT NULL,
  createdBy TEXT NOT NULL,
  createdByName TEXT,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  reminderMinutes TEXT NOT NULL DEFAULT '[]',
  colorHex TEXT,
  version INTEGER NOT NULL DEFAULT 0,
  syncStatus INTEGER NOT NULL DEFAULT 0,
  isDeleted INTEGER NOT NULL DEFAULT 0
)
''';

  static const List<String> sqliteIndexStatements = <String>[
    'CREATE INDEX IF NOT EXISTS idx_sync_events_spaceId ON sync_events(spaceId);',
    'CREATE INDEX IF NOT EXISTS idx_sync_events_startTime ON sync_events(startTime);',
    'CREATE INDEX IF NOT EXISTS idx_sync_events_updatedAt ON sync_events(updatedAt);',
    'CREATE INDEX IF NOT EXISTS idx_sync_events_syncStatus ON sync_events(syncStatus);',
  ];

  factory SyncEvent.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data =
        (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return SyncEvent(
      id: doc.id,
      spaceId: (data['spaceId'] ?? '') as String,
      title: (data['title'] ?? '') as String,
      description: data['description'] as String?,
      location: data['location'] as String?,
      startTime: _dateTimeFromUnknown(data['startTime']),
      endTime: _dateTimeFromUnknown(data['endTime']),
      createdBy: (data['createdBy'] ?? '') as String,
      createdByName: data['createdByName'] as String?,
      createdAt: _dateTimeFromUnknown(
        data['createdAt'] ?? data['updatedAt'] ?? DateTime.now(),
      ),
      updatedAt: _dateTimeFromUnknown(data['updatedAt'] ?? DateTime.now()),
      reminderMinutes: _remindersFromUnknown(
        data['reminderMinutes'] ?? data['reminders'],
      ),
      colorHex: data['colorHex'] as String?,
      version: _intFromUnknown(data['version'], fallback: 0),
      syncStatus: _syncStatusFromUnknown(data['syncStatus']),
      isDeleted: _boolFromUnknown(data['isDeleted']),
    );
  }

  factory SyncEvent.fromMap(Map<String, dynamic> m) {
    return SyncEvent(
      id: (m['id'] ?? '') as String,
      spaceId: (m['spaceId'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      description: m['description'] as String?,
      location: m['location'] as String?,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        _intFromUnknown(m['startTime']),
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        _intFromUnknown(m['endTime']),
      ),
      createdBy: (m['createdBy'] ?? '') as String,
      createdByName: m['createdByName'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        _intFromUnknown(m['createdAt']),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        _intFromUnknown(m['updatedAt']),
      ),
      reminderMinutes: _remindersFromUnknown(m['reminderMinutes']),
      colorHex: m['colorHex'] as String?,
      version: _intFromUnknown(m['version'], fallback: 0),
      syncStatus: _syncStatusFromUnknown(m['syncStatus']),
      isDeleted: _boolFromUnknown(m['isDeleted']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'spaceId': spaceId,
      'title': title,
      'description': description,
      'location': location,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'reminderMinutes': reminderMinutes,
      'colorHex': colorHex,
      'version': version,
      'syncStatus': syncStatus.index,
      'isDeleted': isDeleted,
    };
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
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
      'version': version,
      'syncStatus': syncStatus.index,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  SyncEvent copyWith({
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
    int? version,
    SyncStatus? syncStatus,
    bool? isDeleted,
  }) {
    return SyncEvent(
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
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  SyncEvent withVersion() {
    return copyWith(
      version: version + 1,
      updatedAt: DateTime.now(),
    );
  }

  SyncEvent markSynced() {
    return copyWith(syncStatus: SyncStatus.synced);
  }

  SyncEvent markPending() {
    return copyWith(syncStatus: SyncStatus.pendingSync);
  }

  bool overlaps(SyncEvent other) {
    return startTime.millisecondsSinceEpoch <
            other.endTime.millisecondsSinceEpoch &&
        endTime.millisecondsSinceEpoch > other.startTime.millisecondsSinceEpoch;
  }

  Duration get duration => endTime.difference(startTime);

  bool get isPast => endTime.isBefore(DateTime.now());

  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        spaceId,
        title,
        description,
        location,
        startTime.millisecondsSinceEpoch,
        endTime.millisecondsSinceEpoch,
        createdBy,
        createdByName,
        createdAt.millisecondsSinceEpoch,
        updatedAt.millisecondsSinceEpoch,
        reminderMinutes,
        colorHex,
        version,
        syncStatus,
        isDeleted,
      ];

  static DateTime _dateTimeFromUnknown(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      final asInt = int.tryParse(value);
      if (asInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return DateTime.now();
  }

  static int _intFromUnknown(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static bool _boolFromUnknown(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is int) {
      return value != 0;
    }
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  static SyncStatus _syncStatusFromUnknown(Object? value) {
    if (value is SyncStatus) {
      return value;
    }
    final index = _intFromUnknown(value, fallback: 0);
    if (index < 0 || index >= SyncStatus.values.length) {
      return SyncStatus.synced;
    }
    return SyncStatus.values[index];
  }

  static List<int> _remindersFromUnknown(Object? value) {
    if (value is List) {
      return value
          .map(_intFromUnknown)
          .where((int item) => item > 0)
          .toSet()
          .toList()
        ..sort();
    }
    if (value is String) {
      if (value.trim().isEmpty) {
        return const <int>[];
      }
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map(_intFromUnknown)
              .where((int item) => item > 0)
              .toSet()
              .toList()
            ..sort();
        }
      } catch (_) {
        return const <int>[];
      }
    }
    return const <int>[];
  }
}
