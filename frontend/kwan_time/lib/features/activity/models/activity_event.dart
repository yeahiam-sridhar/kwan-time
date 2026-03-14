// Activity event model for space timeline records.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class ActivityEvent {
  final String id;
  final String type;

  final String actorId;
  final String actorName;
  final String? actorPhotoUrl;

  final String? targetId;
  final String? targetName;

  final DateTime createdAt;

  const ActivityEvent({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    this.actorPhotoUrl,
    this.targetId,
    this.targetName,
    required this.createdAt,
  });

  factory ActivityEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return ActivityEvent(
        id: doc.id,
        type: '',
        actorId: '',
        actorName: 'Unknown',
        actorPhotoUrl: null,
        targetId: null,
        targetName: null,
        createdAt: DateTime.now(),
      );
    }

    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    final rawActorPhotoUrl = data['actorPhotoUrl'];
    final rawTargetId = data['targetId'];
    final rawTargetName = data['targetName'];

    final actorPhotoUrl = (rawActorPhotoUrl is String &&
            rawActorPhotoUrl.trim().isNotEmpty)
        ? rawActorPhotoUrl.trim()
        : null;
    final targetId =
        (rawTargetId is String && rawTargetId.trim().isNotEmpty)
            ? rawTargetId.trim()
            : null;
    final targetName =
        (rawTargetName is String && rawTargetName.trim().isNotEmpty)
            ? rawTargetName.trim()
            : null;

    return ActivityEvent(
      id: doc.id,
      type: (data['type'] as String?) ?? '',
      actorId: (data['actorId'] as String?) ?? '',
      actorName: (data['actorName'] as String?) ?? 'Unknown',
      actorPhotoUrl: actorPhotoUrl,
      targetId: targetId,
      targetName: targetName,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'actorId': actorId,
      'actorName': actorName,
      'actorPhotoUrl': actorPhotoUrl ?? '',
      'targetId': targetId ?? '',
      'targetName': targetName ?? '',
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is ActivityEvent && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
