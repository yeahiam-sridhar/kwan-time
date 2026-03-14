// Firestore service for event comments.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/event_comment.dart';

class CommentService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CommentService(this._db, this._auth);

  CollectionReference<Map<String, dynamic>> _commentsRef(
    String spaceId,
    String eventId,
  ) =>
      _db
          .collection('spaces')
          .doc(spaceId)
          .collection('events')
          .doc(eventId)
          .collection('comments');

  Stream<List<EventComment>> watchComments(String spaceId, String eventId) {
    try {
      return _commentsRef(spaceId, eventId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map(EventComment.fromFirestore).toList();
          })
          .handleError((e) {
            debugPrint('watchComments error: $e');
          });
    } catch (e) {
      debugPrint('watchComments error: $e');
      return const Stream<List<EventComment>>.empty();
    }
  }

  Future<void> addComment(String spaceId, String eventId, String text) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('addComment error: user not authenticated');
        return;
      }

      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        return;
      }

      await _commentsRef(spaceId, eventId).add({
        'text': trimmed,
        'authorId': user.uid,
        'authorName': user.displayName ?? 'Anonymous',
        'authorPhotoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('addComment error: $e');
    }
  }

  Future<void> deleteComment(
    String spaceId,
    String eventId,
    String commentId,
  ) async {
    try {
      if (_auth.currentUser == null) {
        return;
      }
      final uid = _auth.currentUser!.uid;

      final ref = _commentsRef(spaceId, eventId).doc(commentId);
      final snap = await ref.get();

      if (!snap.exists) {
        return;
      }

      final data = snap.data();
      if (data == null) {
        return;
      }

      if (data['authorId'] != uid) {
        debugPrint('Unauthorized delete attempt');
        return;
      }

      await ref.delete();
    } catch (e) {
      debugPrint('deleteComment error: $e');
    }
  }
}
