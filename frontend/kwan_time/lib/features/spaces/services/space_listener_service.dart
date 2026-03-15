import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/space_event_model.dart';
import '../sync/models/sync_event.dart';
import '../sync/services/notification_scheduler.dart';

/// Listens to every Calendar Space the current user belongs to and
/// schedules local reminders using the production NotificationScheduler.
///
/// FIXED: members map query  → .where('members.$uid', isNull: false)
/// FIXED: subcollection path → spaces/{spaceId}/events
/// FIXED: uses NotificationScheduler (reuses NotificationService)
class SpaceListenerService {
  SpaceListenerService._();
  static final SpaceListenerService instance = SpaceListenerService._();

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // One Firestore events listener per spaceId
  final _eventSubs    = <String, StreamSubscription>{};
  StreamSubscription? _membershipSub;
  bool _running       = false;

  // ── Start after login ─────────────────────────────────────────────────────
  Future<void> start() async {
    if (_running) return;
    _running = true;

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('[SpaceListener] ⚠️ No logged-in user — skipping');
      return;
    }

    debugPrint('[SpaceListener] 🚀 Starting for uid=$uid');

    // ── KEY FIX: query members MAP field, not roles arrays ─────────────────
    // SpaceModel stores: members: { "uid123": "admin", "uid456": "member" }
    // Firestore field path: members.uid123 → "admin"
    // Query: where members.{uid} exists (isNull: false)
    _membershipSub = _db
        .collection('spaces')
        .where('members.$uid', isNull: false)
        .snapshots()
        .listen(
          (snap) {
            final currentIds = snap.docs.map((d) => d.id).toSet();
            debugPrint('[SpaceListener] 📡 Member of '
                '${currentIds.length} space(s): $currentIds');

            // Start listening to new spaces
            for (final id in currentIds) {
              _ensureListening(id);
            }

            // Stop listening to spaces the user left
            final removed =
                _eventSubs.keys.toSet().difference(currentIds);
            for (final id in removed) {
              _eventSubs[id]?.cancel();
              _eventSubs.remove(id);
              debugPrint('[SpaceListener] 🚫 Left space $id');
            }
          },
          onError: (e) =>
              debugPrint('[SpaceListener] ❌ Membership error: $e'),
        );
  }

  // ── Listen to events subcollection for one space ──────────────────────────
  void _ensureListening(String spaceId) {
    if (_eventSubs.containsKey(spaceId)) return;

    debugPrint('[SpaceListener] 👂 Listening: spaces/$spaceId/events');

    // ── KEY FIX: subcollection path spaces/{spaceId}/events ────────────────
    final sub = _db
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .snapshots()
        .listen(
          (snap) {
            if (snap.docChanges.isEmpty) return;
            debugPrint('[SpaceListener] 🔔 Space $spaceId: '
                '${snap.docChanges.length} change(s)');

            for (final change in snap.docChanges) {
              final data = change.doc.data();
              final id   = change.doc.id;

              switch (change.type) {
                case DocumentChangeType.added:
                case DocumentChangeType.modified:
                  if (data != null) {
                    debugPrint('[SpaceListener] ➕ Event $id — scheduling');
                    _scheduleNotification(id, spaceId, data);
                  }
                case DocumentChangeType.removed:
                  debugPrint('[SpaceListener] ➖ Event $id — cancelling');
                  _cancelNotification(id);
              }
            }
          },
          onError: (e) =>
              debugPrint('[SpaceListener] ❌ Events error ($spaceId): $e'),
        );

    _eventSubs[spaceId] = sub;
  }

  // ── Schedule via production NotificationScheduler ─────────────────────────
  Future<void> _scheduleNotification(
    String eventId,
    String spaceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final title = (data['title'] as String?)?.trim() ?? 'Event';

      // Parse startTime (always Timestamp in Firestore)
      DateTime? startTime;
      final rawStart = data['startTime'];
      if (rawStart == null) {
        debugPrint('[SpaceListener] ⚠️ No startTime for $eventId');
        return;
      }
      try {
        startTime = (rawStart as Timestamp).toDate();
      } catch (_) {
        if (rawStart is String) startTime = DateTime.tryParse(rawStart);
      }
      if (startTime == null) {
        debugPrint('[SpaceListener] ⚠️ Bad startTime for $eventId');
        return;
      }

      // Parse endTime
      DateTime endTime = startTime.add(const Duration(hours: 1));
      final rawEnd = data['endTime'];
      if (rawEnd != null) {
        try { endTime = (rawEnd as Timestamp).toDate(); } catch (_) {}
      }

      // Parse reminderMinutes — List<int> or int
      List<int> reminders;
      final rm = data['reminderMinutes'] ?? data['reminders'];
      if (rm is List) {
        reminders = List<int>.from(
            rm.map((e) => (e is num) ? e.toInt() : int.tryParse('$e') ?? 15));
      } else if (rm is num) {
        reminders = [rm.toInt()];
      } else {
        reminders = [15];
      }

      debugPrint('[SpaceListener] 📅 "$title" start=$startTime '
          'reminders=$reminders');

      // Build SyncEvent and use production NotificationScheduler
      // This reuses the same battle-hardened path as Personal Calendar
      final syncEvent = SyncEvent(
        id:              eventId,
        spaceId:         spaceId,
        title:           title,
        description:     data['description'] as String?,
        location:        data['location']    as String?,
        startTime:       startTime,
        endTime:         endTime,
        reminderMinutes: reminders,
        createdBy:       data['createdBy'] as String? ?? '',
        createdAt:       DateTime.now(),
        updatedAt:       DateTime.now(),
        version:         1,
        syncStatus:      SyncStatus.synced,
        isDeleted:       false,
      );

      await NotificationScheduler.instance.scheduleEventReminders(syncEvent);
      debugPrint('[SpaceListener] ✅ Scheduled "$title" '
          'reminders=$reminders');
    } catch (e, st) {
      debugPrint('[SpaceListener] ❌ _scheduleNotification error: $e\n$st');
    }
  }

  // ── Cancel via production NotificationScheduler ───────────────────────────
  Future<void> _cancelNotification(String eventId) async {
    try {
      await NotificationScheduler.instance.cancelEventReminders(eventId);
      debugPrint('[SpaceListener] 🗑️ Cancelled reminders for $eventId');
    } catch (e) {
      debugPrint('[SpaceListener] ❌ _cancelNotification error: $e');
    }
  }

  // ── Stop all listeners on sign out ────────────────────────────────────────
  Future<void> stop() async {
    _running = false;
    await _membershipSub?.cancel();
    _membershipSub = null;
    for (final sub in _eventSubs.values) {
      await sub.cancel();
    }
    _eventSubs.clear();
    debugPrint('[SpaceListener] 🛑 All listeners stopped');
  }
}
