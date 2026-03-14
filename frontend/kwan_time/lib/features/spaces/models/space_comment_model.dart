import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SpaceComment extends Equatable {
  const SpaceComment({
    required this.id,
    required this.eventId,
    required this.spaceId,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.authorPhotoUrl,
  });

  final String id;
  final String eventId;
  final String spaceId;
  final String text;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final DateTime createdAt;

  factory SpaceComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SpaceComment(
      id: doc.id,
      eventId: data['eventId'] as String? ?? '',
      spaceId: data['spaceId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'eventId': eventId,
        'spaceId': spaceId,
        'text': text,
        'authorId': authorId,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  String get initials {
    final parts = authorName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';
  }

  @override
  List<Object?> get props => [id, eventId, authorId, createdAt];
}
