import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Firestore: users/{uid}
// {
//   uid:         String
//   name:        String
//   email:       String
//   photoUrl:    String?
//   fcmToken:    String?
//   createdAt:   Timestamp
//   lastLoginAt: Timestamp
//   spaceIds:    Array<String>
// }

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
    required this.lastLoginAt,
    required this.spaceIds,
    this.photoUrl,
    this.fcmToken,
  });

  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final List<String> spaceIds;

  // ── Factories ─────────────────────────────────────────────────────────────

  factory AppUser.fromFirebaseUser(User user) {
    final now = DateTime.now();
    return AppUser(
      uid: user.uid,
      name: user.displayName?.isNotEmpty == true
          ? user.displayName!
          : user.email!.split('@').first,
      email: user.email!,
      photoUrl: user.photoURL,
      createdAt: now,
      lastLoginAt: now,
      spaceIds: const [],
    );
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: data['uid'] as String? ?? doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      fcmToken: data['fcmToken'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt:
          (data['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      spaceIds: List<String>.from(data['spaceIds'] as List? ?? []),
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'fcmToken': fcmToken,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastLoginAt': Timestamp.fromDate(lastLoginAt),
        'spaceIds': spaceIds,
      };

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get displayName => name.isNotEmpty ? name : email.split('@').first;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isNotEmpty) return name[0].toUpperCase();
    return email[0].toUpperCase();
  }

  AppUser copyWith({
    String? name,
    String? photoUrl,
    String? fcmToken,
    DateTime? lastLoginAt,
    List<String>? spaceIds,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        createdAt: createdAt,
        name: name ?? this.name,
        photoUrl: photoUrl ?? this.photoUrl,
        fcmToken: fcmToken ?? this.fcmToken,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
        spaceIds: spaceIds ?? this.spaceIds,
      );

  @override
  List<Object?> get props => [uid, email, name, photoUrl, fcmToken];
}
