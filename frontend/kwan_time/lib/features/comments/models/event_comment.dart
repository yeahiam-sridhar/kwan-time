// Event comment model for comments under space events.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class EventComment {
  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final DateTime createdAt;

  const EventComment({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.createdAt,
  });

  factory EventComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return EventComment(
        id: doc.id,
        text: '',
        authorId: '',
        authorName: 'Unknown',
        authorPhotoUrl: null,
        createdAt: DateTime.now(),
      );
    }

    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    final rawPhotoUrl = data['authorPhotoUrl'];
    String? authorPhotoUrl;
    if (rawPhotoUrl is String && rawPhotoUrl.trim().isNotEmpty) {
      authorPhotoUrl = rawPhotoUrl.trim();
    } else {
      authorPhotoUrl = null;
    }

    return EventComment(
      id: doc.id,
      text: (data['text'] as String?) ?? '',
      authorId: (data['authorId'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? 'Unknown',
      authorPhotoUrl: authorPhotoUrl,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl ?? '',
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is EventComment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
