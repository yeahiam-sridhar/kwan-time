import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'space_notification_service.dart';

class SpaceListenerService {
  SpaceListenerService._();
  static final SpaceListenerService instance = SpaceListenerService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _spaceSubs = <String, StreamSubscription>{};
  StreamSubscription? _eventSub;
  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('[SpaceListener] ⚠️ No logged in user');
      return;
    }

    await SpaceNotificationService.instance.initialize();
    debugPrint('[SpaceListener] 🚀 Starting for uid=$uid');

    // Watch admin, member, viewer role arrays — all 3 queries
    _watchRole('roles.admins', uid);
    _watchRole('roles.members', uid);
    _watchRole('roles.viewers', uid);
  }

  void _watchRole(String field, String uid) {
    final sub = _db
        .collection('spaces')
        .where(field, arrayContains: uid)
        .snapshots()
        .listen((snap) {
      final ids = snap.docs.map((d) => d.id).toSet();
      debugPrint('[SpaceListener] 📡 $field → ${ids.length} space(s): $ids');
      if (ids.isNotEmpty) _startEventListener(ids.toList());
    }, onError: (e) => debugPrint('[SpaceListener] ❌ $field error: $e'));
    _spaceSubs[field] = sub;
  }

  void _startEventListener(List<String> spaceIds) {
    // Cancel previous event listener
    _eventSub?.cancel();

    // Firestore whereIn max = 10 — take first 10 for now
    final batch = spaceIds.take(10).toList();
    debugPrint('[SpaceListener] 👂 Listening to events for spaces: $batch');

    _eventSub = _db
        .collection('events') // ← TOP-LEVEL collection
        .where('spaceId', whereIn: batch) // ← filter by spaceId field
        .snapshots()
        .listen((snap) {
      debugPrint('[SpaceListener] 🔔 ${snap.docChanges.length} change(s)');
      for (final change in snap.docChanges) {
        final data = change.doc.data();
        final id = change.doc.id;
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            if (data != null) {
              debugPrint('[SpaceListener] ➕ Event changed: $id');
              SpaceNotificationService.instance.scheduleFromData(id, data);
            }
          case DocumentChangeType.removed:
            debugPrint('[SpaceListener] ➖ Event removed: $id');
            SpaceNotificationService.instance.cancelEvent(id);
        }
      }
    }, onError: (e) => debugPrint('[SpaceListener] ❌ Event listener error: $e'));
  }

  Future<void> stop() async {
    _running = false;
    _eventSub?.cancel();
    _eventSub = null;
    for (final s in _spaceSubs.values) {
      s.cancel();
    }
    _spaceSubs.clear();
    debugPrint('[SpaceListener] 🛑 Stopped');
  }
}
