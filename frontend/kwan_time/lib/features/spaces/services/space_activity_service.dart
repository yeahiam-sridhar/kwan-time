import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/space_activity_model.dart';

class SpaceActivityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<SpaceActivity>> streamActivity(String spaceId) {
    return _db
        .collection('spaces')
        .doc(spaceId)
        .collection('activity')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(SpaceActivity.fromFirestore).toList());
  }

  Future<void> log({
    required String spaceId,
    required ActivityType type,
    required String actorId,
    required String actorName,
    String? actorPhotoUrl,
    required String targetId,
    required String targetName,
  }) async {
    try {
      await _db.collection('spaces').doc(spaceId).collection('activity').add({
        'type': type.firestoreValue,
        'actorId': actorId,
        'actorName': actorName,
        'actorPhotoUrl': actorPhotoUrl,
        'targetId': targetId,
        'targetName': targetName,
        'createdAt': FieldValue.serverTimestamp(),
        'spaceId': spaceId,
      });
    } catch (e) {
      debugPrint('[SpaceActivityService] log failed: $e');
    }
  }
}
