import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/space_comment_model.dart';

class SpaceCommentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<SpaceComment>> streamComments(String spaceId, String eventId) {
    return _db
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .doc(eventId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(SpaceComment.fromFirestore).toList());
  }

  Future<void> addComment({
    required String spaceId,
    required String eventId,
    required String text,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
  }) async {
    final batch = _db.batch();

    final commentRef = _db
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .doc(eventId)
        .collection('comments')
        .doc();

    batch.set(commentRef, {
      'id': commentRef.id,
      'eventId': eventId,
      'spaceId': spaceId,
      'text': text.trim(),
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(
      _db.collection('spaces').doc(spaceId).collection('events').doc(eventId),
      {'commentCount': FieldValue.increment(1)},
    );

    await batch.commit();
  }

  Future<void> deleteComment({
    required String spaceId,
    required String eventId,
    required String commentId,
  }) async {
    final batch = _db.batch();
    batch.delete(_db
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .doc(eventId)
        .collection('comments')
        .doc(commentId));
    batch.update(
      _db.collection('spaces').doc(spaceId).collection('events').doc(eventId),
      {'commentCount': FieldValue.increment(-1)},
    );
    await batch.commit();
  }
}
