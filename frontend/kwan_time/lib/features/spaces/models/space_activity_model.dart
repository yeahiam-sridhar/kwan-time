import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum ActivityType {
  eventCreated,
  eventUpdated,
  eventDeleted,
  memberJoined,
  memberRemoved,
  commentAdded;

  static ActivityType fromString(String value) => switch (value) {
        'event_created' => ActivityType.eventCreated,
        'event_updated' => ActivityType.eventUpdated,
        'event_deleted' => ActivityType.eventDeleted,
        'member_joined' => ActivityType.memberJoined,
        'member_removed' => ActivityType.memberRemoved,
        'comment_added' => ActivityType.commentAdded,
        _ => ActivityType.eventCreated,
      };

  String get firestoreValue => switch (this) {
        ActivityType.eventCreated => 'event_created',
        ActivityType.eventUpdated => 'event_updated',
        ActivityType.eventDeleted => 'event_deleted',
        ActivityType.memberJoined => 'member_joined',
        ActivityType.memberRemoved => 'member_removed',
        ActivityType.commentAdded => 'comment_added',
      };

  String label(String actorName, String targetName) => switch (this) {
        ActivityType.eventCreated => '$actorName created "$targetName"',
        ActivityType.eventUpdated => '$actorName updated "$targetName"',
        ActivityType.eventDeleted => '$actorName deleted "$targetName"',
        ActivityType.memberJoined => '$actorName joined the space',
        ActivityType.memberRemoved => '$actorName removed $targetName',
        ActivityType.commentAdded => '$actorName commented on "$targetName"',
      };

  IconData get icon => switch (this) {
        ActivityType.eventCreated => Icons.event_available_rounded,
        ActivityType.eventUpdated => Icons.edit_calendar_rounded,
        ActivityType.eventDeleted => Icons.event_busy_rounded,
        ActivityType.memberJoined => Icons.person_add_rounded,
        ActivityType.memberRemoved => Icons.person_remove_rounded,
        ActivityType.commentAdded => Icons.comment_rounded,
      };
}

class SpaceActivity extends Equatable {
  const SpaceActivity({
    required this.id,
    required this.spaceId,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.targetId,
    required this.targetName,
    required this.createdAt,
    this.actorPhotoUrl,
  });

  final String id;
  final String spaceId;
  final ActivityType type;
  final String actorId;
  final String actorName;
  final String? actorPhotoUrl;
  final String targetId;
  final String targetName;
  final DateTime createdAt;

  factory SpaceActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SpaceActivity(
      id: doc.id,
      spaceId: data['spaceId'] as String? ?? '',
      type: ActivityType.fromString(data['type'] as String? ?? ''),
      actorId: data['actorId'] as String? ?? '',
      actorName: data['actorName'] as String? ?? '',
      actorPhotoUrl: data['actorPhotoUrl'] as String?,
      targetId: data['targetId'] as String? ?? '',
      targetName: data['targetName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'spaceId': spaceId,
        'type': type.firestoreValue,
        'actorId': actorId,
        'actorName': actorName,
        'actorPhotoUrl': actorPhotoUrl,
        'targetId': targetId,
        'targetName': targetName,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  @override
  List<Object?> get props => [id, type, actorId, createdAt];
}
