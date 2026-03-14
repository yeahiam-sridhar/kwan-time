import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class UserProfileService {
  static Future<void> syncProfile(User firebaseUser) async {
    final DocumentReference<Map<String, dynamic>> ref =
        FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
    final DocumentSnapshot<Map<String, dynamic>> doc = await ref.get();

    if (!doc.exists) {
      await ref.set(
        AppUser.fromFirebaseUser(firebaseUser).toFirestore(),
        SetOptions(merge: true),
      );
      return;
    }

    final Map<String, dynamic> existing =
        doc.data() ?? <String, dynamic>{'name': ''};
    await ref.set(
      <String, dynamic>{
        'uid': firebaseUser.uid,
        'email': firebaseUser.email ?? existing['email'] ?? '',
        'lastLoginAt': FieldValue.serverTimestamp(),
        'photoUrl': firebaseUser.photoURL,
        'name': firebaseUser.displayName ?? existing['name'] ?? '',
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> storeFcmToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      <String, dynamic>{'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  static Future<AppUser?> fetchUser(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return AppUser.fromFirestore(doc);
  }

  static Future<List<AppUser>> fetchUsers(List<String> uids) async {
    if (uids.isEmpty) {
      return <AppUser>[];
    }

    final Set<String> unique = uids.toSet();
    final List<String> input = unique.toList();
    final List<Future<QuerySnapshot<Map<String, dynamic>>>> batches =
        <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (int i = 0; i < input.length; i += 10) {
      final int end = i + 10 > input.length ? input.length : i + 10;
      final List<String> chunk = input.sublist(i, end);
      batches.add(
        FirebaseFirestore.instance
            .collection('users')
            .where('uid', whereIn: chunk)
            .get(),
      );
    }
    final List<QuerySnapshot<Map<String, dynamic>>> results =
        await Future.wait(batches);
    return results
        .expand((QuerySnapshot<Map<String, dynamic>> snap) => snap.docs)
        .map(AppUser.fromFirestore)
        .toList();
  }
}
