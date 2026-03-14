import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/space_model.dart';
import 'role_permission_service.dart';

class SpaceException implements Exception {
  SpaceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'SpaceException: $message';
}

class SpaceService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  SpaceService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<SpaceModel> createSpace(String name, String description) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw SpaceException('Not authenticated');
      }

      final ref = _db.collection('spaces').doc();
      await ref.set({
        'id': ref.id,
        'name': name,
        'description': description,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'members': {uid: SpaceRole.admin.name},
        'meta': {
          'eventCount': 0,
          'memberCount': 1,
          'lastActivityAt': FieldValue.serverTimestamp(),
        },
      });

      final snap = await ref.get();
      return SpaceModel.fromFirestore(snap);
    } catch (e, s) {
      debugPrint('[SpaceService] createSpace error: $e\n$s');
      if (e is SpaceException) rethrow;
      throw SpaceException('Failed to create space', cause: e);
    }
  }

  Stream<List<SpaceModel>> streamUserSpaces() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream<List<SpaceModel>>.empty();
    }
    return _db
        .collection('spaces')
        .where('members.$uid', isNotEqualTo: null)
        .snapshots()
        .map((snap) => snap.docs.map(SpaceModel.fromFirestore).toList());
  }

  Future<void> updateSpace(
    String spaceId, {
    String? name,
    String? description,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) {
        updates['name'] = name;
      }
      if (description != null) {
        updates['description'] = description;
      }

      await _db.collection('spaces').doc(spaceId).update(updates);
    } on FirebaseException catch (e, s) {
      debugPrint('[SpaceService] updateSpace error: ${e.code}\n$s');
      throw SpaceException('Failed to update space', cause: e);
    } catch (e, s) {
      debugPrint('[SpaceService] updateSpace error: $e\n$s');
      throw SpaceException('Failed to update space', cause: e);
    }
  }

  Future<void> deleteSpace(String spaceId) async {
    try {
      final ref = _db.collection('spaces').doc(spaceId);
      await _deleteSubcollection(ref.collection('events'));
      await _deleteSubcollection(ref.collection('invites'));
      await ref.delete();
    } on FirebaseException catch (e, s) {
      debugPrint('[SpaceService] deleteSpace error: ${e.code}\n$s');
      throw SpaceException('Failed to delete space', cause: e);
    } catch (e, s) {
      debugPrint('[SpaceService] deleteSpace error: $e\n$s');
      throw SpaceException('Failed to delete space', cause: e);
    }
  }

  Future<void> addMember(String spaceId, String uid, SpaceRole role) async {
    try {
      await _db.collection('spaces').doc(spaceId).update({
        'members.$uid': role.name,
        'meta.memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e, s) {
      debugPrint('[SpaceService] addMember error: ${e.code}\n$s');
      throw SpaceException('Failed to add member', cause: e);
    } catch (e, s) {
      debugPrint('[SpaceService] addMember error: $e\n$s');
      throw SpaceException('Failed to add member', cause: e);
    }
  }

  Future<void> removeMember(String spaceId, String uid) async {
    try {
      await _db.collection('spaces').doc(spaceId).update({
        'members.$uid': FieldValue.delete(),
        'meta.memberCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e, s) {
      debugPrint('[SpaceService] removeMember error: ${e.code}\n$s');
      throw SpaceException('Failed to remove member', cause: e);
    } catch (e, s) {
      debugPrint('[SpaceService] removeMember error: $e\n$s');
      throw SpaceException('Failed to remove member', cause: e);
    }
  }

  Future<void> changeMemberRole(
    String spaceId,
    String uid,
    SpaceRole newRole,
  ) async {
    try {
      await _db.collection('spaces').doc(spaceId).update({
        'members.$uid': newRole.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e, s) {
      debugPrint('[SpaceService] changeMemberRole error: ${e.code}\n$s');
      throw SpaceException('Failed to change member role', cause: e);
    } catch (e, s) {
      debugPrint('[SpaceService] changeMemberRole error: $e\n$s');
      throw SpaceException('Failed to change member role', cause: e);
    }
  }

  Future<void> _deleteSubcollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snap = await collection.limit(500).get();
      if (snap.docs.isEmpty) {
        break;
      }
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
