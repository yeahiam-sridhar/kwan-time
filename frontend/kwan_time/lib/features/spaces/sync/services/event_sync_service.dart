import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/db_helper.dart';
import '../models/conflict_result.dart';
import '../models/sync_event.dart';
import 'conflict_detector.dart';
import 'notification_scheduler.dart';
import 'pending_sync_queue.dart';

class ConflictException implements Exception {
  const ConflictException(this.result);

  final ConflictResult result;
}

class EventSyncService {
  EventSyncService({
    required this.firestore,
    required this.auth,
    ConflictDetector? conflictDetector,
    PendingSyncQueue? pendingQueue,
    NotificationScheduler? notificationScheduler,
  })  : _conflictDetector = conflictDetector ?? ConflictDetector(),
        _pendingQueue = pendingQueue ?? PendingSyncQueue.instance,
        _notificationScheduler =
            notificationScheduler ?? NotificationScheduler.instance;

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final ConflictDetector _conflictDetector;
  final PendingSyncQueue _pendingQueue;
  final NotificationScheduler _notificationScheduler;

  Future<SyncEvent> createEvent(SyncEvent event) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);

    final ConflictResult conflict = await _conflictDetector.checkConflict(
      spaceId: event.spaceId,
      startTime: event.startTime,
      endTime: event.endTime,
    );
    if (conflict.hasConflict) {
      throw ConflictException(conflict);
    }

    final DateTime now = DateTime.now();
    final String createdBy = event.createdBy.isNotEmpty
        ? event.createdBy
        : (auth.currentUser?.uid ?? '');
    final SyncEvent pendingEvent = event.copyWith(
      createdBy: createdBy,
      createdAt: event.createdAt,
      updatedAt: now,
      syncStatus: SyncStatus.pendingSync,
      isDeleted: false,
    );

    await db.insert(
      'sync_events',
      pendingEvent.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    try {
      await _notificationScheduler.scheduleEventReminders(pendingEvent);
    } catch (_) {}

    try {
      await _eventRef(pendingEvent.spaceId, pendingEvent.id).set(
        <String, dynamic>{
          ...pendingEvent.toFirestore(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final SyncEvent synced = pendingEvent.markSynced().copyWith(
            updatedAt: DateTime.now(),
          );
      await db.update(
        'sync_events',
        synced.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[synced.id],
      );
      return synced;
    } on FirebaseException {
      await _pendingQueue.enqueue(pendingEvent);
      return pendingEvent;
    } catch (_) {
      await _pendingQueue.enqueue(pendingEvent);
      return pendingEvent;
    }
  }

  Future<SyncEvent> updateEvent(SyncEvent event) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);

    final ConflictResult conflict = await _conflictDetector.checkConflict(
      spaceId: event.spaceId,
      startTime: event.startTime,
      endTime: event.endTime,
      excludeEventId: event.id,
    );
    if (conflict.hasConflict) {
      throw ConflictException(conflict);
    }

    final List<Map<String, Object?>> existingRows = await db.query(
      'sync_events',
      where: 'id = ?',
      whereArgs: <Object?>[event.id],
      limit: 1,
    );
    final SyncEvent? existing =
        existingRows.isEmpty ? null : SyncEvent.fromMap(existingRows.first);
    final int baseVersion = existing?.version ?? event.version;
    final SyncEvent updated = event.copyWith(
      createdBy: event.createdBy.isNotEmpty
          ? event.createdBy
          : (existing?.createdBy ?? auth.currentUser?.uid ?? ''),
      createdAt: existing?.createdAt ?? event.createdAt,
      updatedAt: DateTime.now(),
      version: baseVersion + 1,
      syncStatus: SyncStatus.pendingSync,
      isDeleted: false,
    );

    await db.insert(
      'sync_events',
      updated.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    try {
      await _notificationScheduler.cancelEventReminders(updated.id);
      await _notificationScheduler.scheduleEventReminders(updated);
    } catch (_) {}

    try {
      await _eventRef(updated.spaceId, updated.id).set(
        <String, dynamic>{
          ...updated.toFirestore(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final SyncEvent synced = updated.markSynced().copyWith(
            updatedAt: DateTime.now(),
          );
      await db.update(
        'sync_events',
        synced.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[synced.id],
      );
      return synced;
    } on FirebaseException {
      await _pendingQueue.enqueue(updated);
      return updated;
    } catch (_) {
      await _pendingQueue.enqueue(updated);
      return updated;
    }
  }

  Future<void> deleteEvent(String eventId, String spaceId) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);

    final List<Map<String, Object?>> existingRows = await db.query(
      'sync_events',
      where: 'id = ?',
      whereArgs: <Object?>[eventId],
      limit: 1,
    );
    final SyncEvent? existing =
        existingRows.isEmpty ? null : SyncEvent.fromMap(existingRows.first);
    if (existing != null) {
      final SyncEvent softDeleted = existing.withVersion().copyWith(
            isDeleted: true,
            syncStatus: SyncStatus.pendingSync,
            updatedAt: DateTime.now(),
          );
      await db.insert(
        'sync_events',
        softDeleted.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    try {
      await _notificationScheduler.cancelEventReminders(eventId);
    } catch (_) {}

    try {
      await _eventRef(spaceId, eventId).delete();
      await db.delete(
        'sync_events',
        where: 'id = ?',
        whereArgs: <Object?>[eventId],
      );
    } on FirebaseException {
      if (existing != null) {
        await _pendingQueue.enqueue(
          existing.copyWith(
            isDeleted: true,
            syncStatus: SyncStatus.pendingSync,
            updatedAt: DateTime.now(),
          ),
        );
      }
    } catch (_) {
      if (existing != null) {
        await _pendingQueue.enqueue(
          existing.copyWith(
            isDeleted: true,
            syncStatus: SyncStatus.pendingSync,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
  }

  Future<List<SyncEvent>> loadEventsForSpace(String spaceId) async {
    final List<SyncEvent> local = await loadCachedEventsForSpace(spaceId);
    unawaited(_refreshFromFirestore(spaceId));
    return local;
  }

  Future<List<SyncEvent>> loadCachedEventsForSpace(String spaceId) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);
    final List<Map<String, Object?>> rows = await db.query(
      'sync_events',
      where: 'spaceId = ? AND isDeleted = 0',
      whereArgs: <Object?>[spaceId],
      orderBy: 'startTime ASC',
    );
    return rows.map(SyncEvent.fromMap).toList();
  }

  Future<void> reconcileWithFirestore(
    String spaceId,
    List<SyncEvent> firestoreEvents,
  ) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);

    final List<Map<String, Object?>> localRows = await db.query(
      'sync_events',
      where: 'spaceId = ?',
      whereArgs: <Object?>[spaceId],
    );
    final Map<String, SyncEvent> localById = <String, SyncEvent>{
      for (final Map<String, Object?> row in localRows)
        SyncEvent.fromMap(row).id: SyncEvent.fromMap(row),
    };

    for (final SyncEvent remote in firestoreEvents) {
      final SyncEvent remoteSynced = remote.copyWith(
        syncStatus: SyncStatus.synced,
      );
      final SyncEvent? local = localById[remote.id];
      if (local == null) {
        await db.insert(
          'sync_events',
          remoteSynced.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        continue;
      }

      final int remoteUpdated = remote.updatedAt.millisecondsSinceEpoch;
      final int localUpdated = local.updatedAt.millisecondsSinceEpoch;
      if (remoteUpdated > localUpdated) {
        await db.insert(
          'sync_events',
          remoteSynced.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else if (localUpdated > remoteUpdated &&
          local.syncStatus == SyncStatus.synced) {
        try {
          await _eventRef(spaceId, local.id).set(
            <String, dynamic>{
              ...local.toFirestore(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } on FirebaseException {
          await _pendingQueue.enqueue(local.markPending());
        } catch (_) {
          await _pendingQueue.enqueue(local.markPending());
        }
      }
    }
  }

  Future<void> reconcileSingleEvent(SyncEvent event) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);

    final List<Map<String, Object?>> rows = await db.query(
      'sync_events',
      where: 'id = ?',
      whereArgs: <Object?>[event.id],
      limit: 1,
    );
    if (rows.isEmpty) {
      await db.insert(
        'sync_events',
        event.copyWith(syncStatus: SyncStatus.synced).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    final SyncEvent local = SyncEvent.fromMap(rows.first);
    final int remoteUpdated = event.updatedAt.millisecondsSinceEpoch;
    final int localUpdated = local.updatedAt.millisecondsSinceEpoch;

    if (remoteUpdated > localUpdated) {
      await db.insert(
        'sync_events',
        event.copyWith(syncStatus: SyncStatus.synced).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    if (localUpdated > remoteUpdated && local.syncStatus == SyncStatus.synced) {
      try {
        await _eventRef(local.spaceId, local.id).set(
          <String, dynamic>{
            ...local.toFirestore(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } on FirebaseException {
        await _pendingQueue.enqueue(local.markPending());
      } catch (_) {
        await _pendingQueue.enqueue(local.markPending());
      }
    }
  }

  Future<void> handleRemoteDelete(String eventId) async {
    final Database db = await DbHelper.instance.database;
    await _ensureSchema(db);

    await db.update(
      'sync_events',
      <String, Object?>{
        'isDeleted': 1,
        'syncStatus': SyncStatus.synced.index,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[eventId],
    );
    try {
      await _notificationScheduler.cancelEventReminders(eventId);
    } catch (_) {}
  }

  Future<void> startupSync(String spaceId) async {
    await _pendingQueue.flush(firestore);

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('events')
          .where('isDeleted', isEqualTo: false)
          .orderBy('startTime')
          .get();
      final List<SyncEvent> remote =
          snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        return SyncEvent.fromFirestore(doc);
      }).toList();
      await reconcileWithFirestore(spaceId, remote);
    } on FirebaseException {
      // Keep offline cache as source of truth when fetch fails.
    } catch (_) {
      // Keep startup resilient.
    }

    try {
      await _notificationScheduler.rescheduleAllForSpace(spaceId);
    } catch (_) {}
  }

  Future<void> _refreshFromFirestore(String spaceId) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('events')
          .where('isDeleted', isEqualTo: false)
          .orderBy('startTime')
          .get();
      final List<SyncEvent> remote =
          snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        return SyncEvent.fromFirestore(doc);
      }).toList();
      await reconcileWithFirestore(spaceId, remote);
    } on FirebaseException {
      // Remote refresh should not crash cache-first loads.
    } catch (_) {}
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute(SyncEvent.sqliteCreateTableStatement);
    for (final String statement in SyncEvent.sqliteIndexStatements) {
      await db.execute(statement);
    }
  }

  DocumentReference<Map<String, dynamic>> _eventRef(
    String spaceId,
    String eventId,
  ) {
    return firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .doc(eventId);
  }
}
