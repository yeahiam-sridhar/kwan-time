// Firestore service for recording and streaming space activity timeline.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/activity_event.dart';

class ActivityService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ActivityService(this._db, this._auth);

  CollectionReference<Map<String, dynamic>> _activityRef(
    String spaceId,
  ) =>
      _db.collection('spaces').doc(spaceId).collection('activity');

  Stream<List<ActivityEvent>> watchActivity(String spaceId) {
    try {
      return _activityRef(spaceId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map(ActivityEvent.fromFirestore).toList();
      }).handleError((error) {
        debugPrint('watchActivity error: $error');
      });
    } catch (error) {
      debugPrint('watchActivity error: $error');
      return const Stream<List<ActivityEvent>>.empty();
    }
  }

  Future<void> logActivity({
    required String spaceId,
    required String type,
    required String targetId,
    required String targetName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('logActivity error: user not authenticated');
        return;
      }

      await _activityRef(spaceId).add({
        'type': type,
        'actorId': user.uid,
        'actorName': user.displayName ?? 'Unknown',
        'actorPhotoUrl': user.photoURL ?? '',
        'targetId': targetId,
        'targetName': targetName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('logActivity error: $error');
    }
  }
}
