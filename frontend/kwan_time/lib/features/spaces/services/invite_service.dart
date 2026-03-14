import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/space_invite_model.dart';
import 'role_permission_service.dart';

export '../models/space_invite_model.dart' show JoinResult;

class InviteService {
  // Generate a secure invite link
  // Token = UUID v4 (from `uuid` package)
  // Stored at spaces/{spaceId}/invites/{token}
  Future<String> generateInviteLink(String spaceId, SpaceRole role) async {
    try {
      final token = const Uuid().v4();
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('invites')
          .doc(token)
          .set({
        'token': token,
        'role': role.name,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        // Expires in 7 days
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
        'usedBy': null,
        'usedAt': null,
      });
      return 'https://kwantime.app/invite?spaceId=$spaceId&role=${role.name}&token=$token';
    } catch (e, s) {
      debugPrint('[InviteService] generateInviteLink error: $e\n$s');
      rethrow;
    }
  }

  // Process join from deep link
  Future<JoinResult> processJoin({
    required String spaceId,
    required String role,
    required String token,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return JoinResult.notAuthenticated;

      final inviteRef = FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('invites')
          .doc(token);

      final inviteSnap = await inviteRef.get();
      if (!inviteSnap.exists) return JoinResult.invalidToken;

      final data = inviteSnap.data()!;
      // Check expiry
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) return JoinResult.tokenExpired;
      // Check already used
      if (data['usedBy'] != null) return JoinResult.tokenAlreadyUsed;

      final storedRole = (data['role'] as String?)?.trim();
      final roleToApply = storedRole?.isNotEmpty == true ? storedRole! : role;
      if (SpaceRoleX.fromString(roleToApply) == SpaceRole.none) {
        return JoinResult.error;
      }

      // Best-effort membership check; non-members may not be allowed to read the space doc.
      try {
        final spaceSnap = await FirebaseFirestore.instance
            .collection('spaces')
            .doc(spaceId)
            .get();
        if (!spaceSnap.exists) return JoinResult.spaceNotFound;
        final members = Map<String, String>.from(
          spaceSnap.data()!['members'] as Map? ?? {},
        );
        if (members.containsKey(uid)) return JoinResult.alreadyMember;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') {
          rethrow;
        }
      }

      // Add member + mark invite used (batch)
      final batch = FirebaseFirestore.instance.batch();
      batch.update(FirebaseFirestore.instance.collection('spaces').doc(spaceId), {
        'members.$uid': roleToApply,
        'meta.memberCount': FieldValue.increment(1),
        'meta.lastJoinToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(inviteRef, {
        'usedBy': uid,
        'usedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return JoinResult.joined;
    } catch (e, s) {
      debugPrint('[InviteService] processJoin error: $e\n$s');
      return JoinResult.error;
    }
  }
}
