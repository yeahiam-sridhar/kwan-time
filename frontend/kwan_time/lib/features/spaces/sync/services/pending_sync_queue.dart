import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/db_helper.dart';
import '../models/sync_event.dart';

class FlushResult {
  const FlushResult({
    required this.successCount,
    required this.failureCount,
    required this.failedIds,
  });

  final int successCount;
  final int failureCount;
  final List<String> failedIds;

  bool get isFullSuccess => failureCount == 0;
}

class PendingSyncQueue {
  PendingSyncQueue._();

  static final PendingSyncQueue instance = PendingSyncQueue._();

  Future<void> enqueue(SyncEvent event) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);
    await db.insert(
      'sync_events',
      event.markPending().toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<FlushResult> flush(FirebaseFirestore firestore) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);

    int successCount = 0;
    int failureCount = 0;
    final List<String> failedIds = <String>[];

    final List<Map<String, Object?>> pendingRows = await db.query(
      'sync_events',
      where: 'syncStatus = ? AND isDeleted = 0',
      whereArgs: <Object?>[SyncStatus.pendingSync.index],
      orderBy: 'updatedAt ASC',
    );
    final List<Map<String, Object?>> pendingDeletes = await db.query(
      'sync_events',
      where: 'syncStatus = ? AND isDeleted = 1',
      whereArgs: <Object?>[SyncStatus.pendingSync.index],
      orderBy: 'updatedAt ASC',
    );

    for (final Map<String, Object?> row in pendingRows) {
      final SyncEvent event = SyncEvent.fromMap(row);
      try {
        await firestore
            .collection('spaces')
            .doc(event.spaceId)
            .collection('events')
            .doc(event.id)
            .set(<String, dynamic>{
          ...event.markSynced().toFirestore(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await db.update(
          'sync_events',
          <String, Object?>{
            'syncStatus': SyncStatus.synced.index,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: <Object?>[event.id],
        );
        successCount++;
      } on FirebaseException {
        failureCount++;
        failedIds.add(event.id);
      } catch (_) {
        failureCount++;
        failedIds.add(event.id);
      }
    }

    for (final Map<String, Object?> row in pendingDeletes) {
      final SyncEvent event = SyncEvent.fromMap(row);
      try {
        await firestore
            .collection('spaces')
            .doc(event.spaceId)
            .collection('events')
            .doc(event.id)
            .delete();

        await db.delete(
          'sync_events',
          where: 'id = ?',
          whereArgs: <Object?>[event.id],
        );
        successCount++;
      } on FirebaseException {
        failureCount++;
        failedIds.add(event.id);
      } catch (_) {
        failureCount++;
        failedIds.add(event.id);
      }
    }

    return FlushResult(
      successCount: successCount,
      failureCount: failureCount,
      failedIds: List<String>.unmodifiable(failedIds),
    );
  }

  Future<int> getPendingCount() async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_events WHERE syncStatus = ?',
      <Object?>[SyncStatus.pendingSync.index],
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute(SyncEvent.sqliteCreateTableStatement);
    for (final String statement in SyncEvent.sqliteIndexStatements) {
      await db.execute(statement);
    }
  }
}
