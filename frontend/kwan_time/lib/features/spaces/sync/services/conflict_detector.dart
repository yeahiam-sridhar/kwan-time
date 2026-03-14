import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/db_helper.dart';
import '../models/conflict_result.dart';
import '../models/sync_event.dart';

class ConflictDetector {
  Future<ConflictResult> checkConflict({
    required String spaceId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeEventId,
  }) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);

    final StringBuffer where = StringBuffer(
      'spaceId = ? AND isDeleted = 0 AND startTime < ? AND endTime > ?',
    );
    final List<Object?> whereArgs = <Object?>[
      spaceId,
      endTime.millisecondsSinceEpoch,
      startTime.millisecondsSinceEpoch,
    ];

    if (excludeEventId != null && excludeEventId.isNotEmpty) {
      where.write(' AND id != ?');
      whereArgs.add(excludeEventId);
    }

    final List<Map<String, Object?>> rows = await db.query(
      'sync_events',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'startTime ASC',
    );

    final List<SyncEvent> conflicts = rows.map(SyncEvent.fromMap).toList();
    if (conflicts.isEmpty) {
      return ConflictResult.none();
    }

    final int latestEndMs = conflicts
        .map((SyncEvent event) => event.endTime.millisecondsSinceEpoch)
        .reduce((int a, int b) => a > b ? a : b);
    final Duration duration = endTime.difference(startTime);
    final DateTime suggestedStart = DateTime.fromMillisecondsSinceEpoch(
      latestEndMs,
    ).add(const Duration(minutes: 15));
    final DateTime suggestedEnd = suggestedStart.add(duration);
    final DateFormat formatter = DateFormat('h:mm a');
    final String suggestion =
        'Try ${formatter.format(suggestedStart)} - ${formatter.format(suggestedEnd)}';

    return ConflictResult.conflict(conflicts, suggestion: suggestion);
  }

  Future<DateTime> findNextFreeSlot({
    required String spaceId,
    required DateTime preferredStart,
    required Duration duration,
  }) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);

    final DateTime dayStart = DateTime(
      preferredStart.year,
      preferredStart.month,
      preferredStart.day,
    );
    final DateTime dayEnd = dayStart.add(const Duration(days: 1));

    final List<Map<String, Object?>> rows = await db.query(
      'sync_events',
      where: 'spaceId = ? AND isDeleted = 0 AND startTime < ? AND endTime > ?',
      whereArgs: <Object?>[
        spaceId,
        dayEnd.millisecondsSinceEpoch,
        dayStart.millisecondsSinceEpoch,
      ],
      orderBy: 'startTime ASC',
    );
    final List<SyncEvent> events = rows.map(SyncEvent.fromMap).toList();

    DateTime candidate = preferredStart;
    for (int i = 0; i < 672; i++) {
      final DateTime candidateEnd = candidate.add(duration);
      final bool hasConflict = events.any(
        (SyncEvent event) =>
            candidate.millisecondsSinceEpoch <
                event.endTime.millisecondsSinceEpoch &&
            candidateEnd.millisecondsSinceEpoch >
                event.startTime.millisecondsSinceEpoch,
      );

      if (!hasConflict) {
        return candidate;
      }
      candidate = candidate.add(const Duration(minutes: 15));
    }

    return candidate;
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute(SyncEvent.sqliteCreateTableStatement);
    for (final String statement in SyncEvent.sqliteIndexStatements) {
      await db.execute(statement);
    }
  }
}
