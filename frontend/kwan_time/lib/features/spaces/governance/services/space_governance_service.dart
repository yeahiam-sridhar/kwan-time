// ============================================================================
// lib/features/spaces/governance/services/space_governance_service.dart
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum SpaceRole { admin, member, viewer }

extension SpaceRoleX on SpaceRole {
  String get firestoreField => switch (this) {
        SpaceRole.admin => 'roles.admins',
        SpaceRole.member => 'roles.members',
        SpaceRole.viewer => 'roles.viewers',
      };

  String get label => switch (this) {
        SpaceRole.admin => 'Admin',
        SpaceRole.member => 'Member',
        SpaceRole.viewer => 'Viewer',
      };
}

enum InviteResult {
  success,
  alreadyMember,
  userNotFound,
}

class SpaceGovernanceService {
  SpaceGovernanceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  Future<void> updateSpaceMetadata(
    String spaceId, {
    String? name,
    String? description,
    String? colorHex,
  }) async {
    try {
      final Map<String, dynamic> updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) {
        updates['name'] = name;
      }
      if (description != null) {
        updates['description'] = description;
      }
      if (colorHex != null) {
        updates['colorHex'] = colorHex;
      }
      await firestore.collection('spaces').doc(spaceId).update(updates);
    } on FirebaseException catch (e) {
      debugPrint('[SpaceGovernanceService] updateSpaceMetadata: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('[SpaceGovernanceService] updateSpaceMetadata: $e');
      rethrow;
    }
  }

  Future<InviteResult> inviteUserByEmail(
    String spaceId,
    String email,
    SpaceRole role,
  ) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> userQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        return InviteResult.userNotFound;
      }

      final String invitedUid =
          (userQuery.docs.first.data()['uid'] ?? userQuery.docs.first.id)
              .toString();

      final DocumentReference<Map<String, dynamic>> spaceRef =
          firestore.collection('spaces').doc(spaceId);
      final DocumentSnapshot<Map<String, dynamic>> spaceSnap =
          await spaceRef.get();
      if (!spaceSnap.exists) {
        return InviteResult.userNotFound;
      }

      final Map<String, dynamic> data = spaceSnap.data() ?? <String, dynamic>{};
      final Map<String, dynamic> roles =
          (data['roles'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final List<String> admins = List<String>.from(roles['admins'] ?? <String>[]);
      final List<String> members =
          List<String>.from(roles['members'] ?? <String>[]);
      final List<String> viewers =
          List<String>.from(roles['viewers'] ?? <String>[]);

      final bool alreadyMember = admins.contains(invitedUid) ||
          members.contains(invitedUid) ||
          viewers.contains(invitedUid);
      if (alreadyMember) {
        return InviteResult.alreadyMember;
      }

      await spaceRef.update(<String, dynamic>{
        role.firestoreField: FieldValue.arrayUnion(<String>[invitedUid]),
        'meta.totalMembers': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return InviteResult.success;
    } on FirebaseException catch (e) {
      debugPrint('[SpaceGovernanceService] inviteUserByEmail: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('[SpaceGovernanceService] inviteUserByEmail: $e');
      rethrow;
    }
  }

  Future<void> changeRole(
    String spaceId,
    String userId,
    SpaceRole newRole,
  ) async {
    try {
      final WriteBatch batch = firestore.batch();
      final DocumentReference<Map<String, dynamic>> ref =
          firestore.collection('spaces').doc(spaceId);
      batch.update(ref, <String, dynamic>{
        'roles.admins': FieldValue.arrayRemove(<String>[userId]),
      });
      batch.update(ref, <String, dynamic>{
        'roles.members': FieldValue.arrayRemove(<String>[userId]),
      });
      batch.update(ref, <String, dynamic>{
        'roles.viewers': FieldValue.arrayRemove(<String>[userId]),
      });
      batch.update(ref, <String, dynamic>{
        newRole.firestoreField: FieldValue.arrayUnion(<String>[userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      debugPrint('[SpaceGovernanceService] changeRole: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('[SpaceGovernanceService] changeRole: $e');
      rethrow;
    }
  }

  Future<void> removeMember(String spaceId, String userId) async {
    try {
      final WriteBatch batch = firestore.batch();
      final DocumentReference<Map<String, dynamic>> ref =
          firestore.collection('spaces').doc(spaceId);
      batch.update(ref, <String, dynamic>{
        'roles.admins': FieldValue.arrayRemove(<String>[userId]),
      });
      batch.update(ref, <String, dynamic>{
        'roles.members': FieldValue.arrayRemove(<String>[userId]),
      });
      batch.update(ref, <String, dynamic>{
        'roles.viewers': FieldValue.arrayRemove(<String>[userId]),
      });
      batch.update(ref, <String, dynamic>{
        'meta.totalMembers': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      debugPrint('[SpaceGovernanceService] removeMember: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('[SpaceGovernanceService] removeMember: $e');
      rethrow;
    }
  }

  Future<void> leaveSpace(String spaceId) async {
    try {
      final String? uid = auth.currentUser?.uid;
      if (uid == null) {
        throw StateError('Not authenticated');
      }
      await removeMember(spaceId, uid);
    } on FirebaseException catch (e) {
      debugPrint('[SpaceGovernanceService] leaveSpace: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('[SpaceGovernanceService] leaveSpace: $e');
      rethrow;
    }
  }

  Future<void> deleteSpace(String spaceId) async {
    try {
      final String? currentUid = auth.currentUser?.uid;
      if (currentUid == null) {
        throw StateError('Not authenticated');
      }

      final DocumentReference<Map<String, dynamic>> spaceRef =
          firestore.collection('spaces').doc(spaceId);
      final DocumentSnapshot<Map<String, dynamic>> spaceSnap =
          await spaceRef.get();
      if (!spaceSnap.exists) {
        return;
      }

      final String ownerId = (spaceSnap.data()?['ownerId'] ?? '').toString();
      if (ownerId != currentUid) {
        throw StateError('Only the owner can delete this space');
      }

      await _deleteSubcollection(spaceRef.collection('events'));
      await _deleteSubcollection(spaceRef.collection('eventComments'));
      await _deleteSubcollection(spaceRef.collection('joinRequests'));

      await spaceRef.delete();
    } on FirebaseException catch (e) {
      debugPrint('[SpaceGovernanceService] deleteSpace: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('[SpaceGovernanceService] deleteSpace: $e');
      rethrow;
    }
  }

  Future<void> transferOwnership(
    String spaceId,
    String newOwnerId,
  ) async {
    try {
      final String? oldOwnerId = auth.currentUser?.uid;
      if (oldOwnerId == null) {
        throw StateError('Not authenticated');
      }
      final WriteBatch batch = firestore.batch();
      final DocumentReference<Map<String, dynamic>> ref =
          firestore.collection('spaces').doc(spaceId);
      batch.update(ref, <String, dynamic>{
        'ownerId': newOwnerId,
        'roles.admins': FieldValue.arrayUnion(<String>[newOwnerId]),
      });
      batch.update(ref, <String, dynamic>{
        'roles.admins': FieldValue.arrayRemove(<String>[oldOwnerId]),
      });
      batch.update(ref, <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      debugPrint('[SpaceGovernanceService] transferOwnership: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('[SpaceGovernanceService] transferOwnership: $e');
      rethrow;
    }
  }

  Future<void> _deleteSubcollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await collection.limit(500).get();
      if (snap.docs.isEmpty) {
        break;
      }
      final WriteBatch batch = firestore.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
