import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final inviteServiceProvider = Provider<InviteService>(
  (ref) => InviteService(),
);

enum JoinResult {
  joined,
  alreadyMember,
  spaceNotFound,
  notAuthenticated,
  invalidRole,
  error,
}

class InviteService {
  static const _validRoles = {'admin', 'member', 'viewer'};

  Future<JoinResult> processJoinRequest(String spaceId, String roleStr) async {
    try {
      // 1. Auth check
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint(
            '[InviteService] join result=JoinResult.notAuthenticated for spaceId=$spaceId');
        return JoinResult.notAuthenticated;
      }

      // 2. Validate role string
      final role = roleStr.toLowerCase().trim();
      if (!_validRoles.contains(role)) {
        debugPrint(
            '[InviteService] join result=JoinResult.invalidRole for spaceId=$spaceId');
        return JoinResult.invalidRole;
      }

      // 3. Fetch space
      final spaceRef =
          FirebaseFirestore.instance.collection('spaces').doc(spaceId);
      final spaceSnap = await spaceRef.get();
      if (!spaceSnap.exists) {
        debugPrint(
            '[InviteService] join result=JoinResult.spaceNotFound for spaceId=$spaceId');
        return JoinResult.spaceNotFound;
      }

      // 4. Check if already a member in any role
      final data = spaceSnap.data()!;
      final roles = (data['roles'] as Map<String, dynamic>?) ?? {};
      final admins = List<String>.from(roles['admins'] as List? ?? []);
      final members = List<String>.from(roles['members'] as List? ?? []);
      final viewers = List<String>.from(roles['viewers'] as List? ?? []);

      if (admins.contains(uid) ||
          members.contains(uid) ||
          viewers.contains(uid)) {
        debugPrint(
            '[InviteService] join result=JoinResult.alreadyMember for spaceId=$spaceId');
        return JoinResult.alreadyMember;
      }

      // 5. Add to correct role array + increment member count atomically
      final batch = FirebaseFirestore.instance.batch();

      batch.update(spaceRef, {
        'roles.${role}s': FieldValue.arrayUnion([uid]),
        'meta.totalMembers': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint(
          '[InviteService] join result=JoinResult.joined for spaceId=$spaceId');
      return JoinResult.joined;
    } catch (e, s) {
      debugPrint('[InviteService] processJoinRequest error: $e\n$s');
      debugPrint(
          '[InviteService] join result=JoinResult.error for spaceId=$spaceId');
      return JoinResult.error;
    }
  }
}
