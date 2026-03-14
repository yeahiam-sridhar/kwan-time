import 'package:cloud_firestore/cloud_firestore.dart';

class SpaceInvite {
  final String id;
  final String spaceId;
  final String role;
  final String token;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool revoked;

  const SpaceInvite({
    required this.id,
    required this.spaceId,
    required this.role,
    required this.token,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    required this.revoked,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !revoked && !isExpired;

  factory SpaceInvite.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SpaceInvite(
      id: doc.id,
      spaceId: d['spaceId'] ?? '',
      role: d['role'] ?? 'viewer',
      token: d['token'] ?? '',
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      expiresAt: (d['expiresAt'] as Timestamp).toDate(),
      revoked: d['revoked'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'spaceId': spaceId,
        'role': role,
        'token': token,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'revoked': revoked,
      };
}

enum JoinResult {
  joined,
  notAuthenticated,
  alreadyMember,
  invalidToken,
  tokenExpired,
  tokenAlreadyUsed,
  spaceNotFound,
  error,
}

extension JoinResultMessage on JoinResult {
  String get message => switch (this) {
        JoinResult.joined => 'You have joined the calendar space!',
        JoinResult.alreadyMember => 'You are already part of this calendar.',
        JoinResult.notAuthenticated => 'Please sign in to join this space.',
        JoinResult.invalidToken => 'Invalid invitation link.',
        JoinResult.tokenExpired => 'This invitation link has expired.',
        JoinResult.tokenAlreadyUsed => 'This invitation is no longer valid.',
        JoinResult.spaceNotFound => 'Calendar space not found.',
        JoinResult.error => 'Could not join space. Please try again.',
      };
}
