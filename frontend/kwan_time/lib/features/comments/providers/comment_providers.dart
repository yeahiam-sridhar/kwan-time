// Riverpod providers for event comments.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event_comment.dart';
import '../services/comment_service.dart';

@immutable
class CommentQuery {
  final String spaceId;
  final String eventId;

  const CommentQuery(this.spaceId, this.eventId);

  @override
  bool operator ==(Object other) =>
      other is CommentQuery &&
      other.spaceId == spaceId &&
      other.eventId == eventId;

  @override
  int get hashCode => Object.hash(spaceId, eventId);
}

final commentServiceProvider = Provider<CommentService>((ref) {
  return CommentService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});

final commentsStreamProvider =
    StreamProvider.family<List<EventComment>, CommentQuery>(
  (ref, query) {
    return ref
        .watch(commentServiceProvider)
        .watchComments(query.spaceId, query.eventId);
  },
);
