import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import '../../spaces/services/space_listener_service.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // â”€â”€ Google Sign-In â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<AppUser> signInWithGoogle() async {
    try {
      final gUser = await GoogleSignIn(
        scopes: ['email', 'profile'],
      ).signIn();
      if (gUser == null) {
        throw const AuthException('Google sign-in was cancelled.');
      }
      final gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      await _syncProfile(result.user!);
      return AppUser.fromFirebaseUser(result.user!);
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_humanizeCode(e.code));
    } catch (_) {
      throw const AuthException('Google sign-in failed. Try again.');
    }
  }

  // â”€â”€ Email / Password Sign-In â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<AppUser> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _syncProfile(result.user!);
      return AppUser.fromFirebaseUser(result.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_humanizeCode(e.code));
    }
  }

  // â”€â”€ Email / Password Registration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await result.user!.updateDisplayName(name);
      await _syncProfile(result.user!, forceCreate: true);
      return AppUser.fromFirebaseUser(result.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_humanizeCode(e.code));
    }
  }

  // â”€â”€ Sign Out â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> signOut() async {
    try {
      await SpaceListenerService.instance.stop();
      await FirebaseAuth.instance.signOut();
      try {
        // disconnect() clears cached account selection -> chooser appears next login
        await GoogleSignIn().disconnect();
      } catch (_) {
        await GoogleSignIn().signOut(); // fallback if no Google session
      }
    } catch (e, s) {
      debugPrint('[AuthService] signOut error: $e\n$s');
      // Never rethrow -- sign-out must always succeed from user's perspective
    }
  }

  // â”€â”€ Password Reset â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_humanizeCode(e.code));
    }
  }

  // â”€â”€ Sync Firestore Profile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _syncProfile(User user, {bool forceCreate = false}) async {
    try {
      final ref = _db.collection('users').doc(user.uid);
      final doc = await ref.get();
      if (!doc.exists || forceCreate) {
        await ref.set(AppUser.fromFirebaseUser(user).toFirestore());
      } else {
        await ref.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          if (user.photoURL != null) 'photoUrl': user.photoURL,
          if (user.displayName != null) 'name': user.displayName,
        });
      }
    } on FirebaseException catch (e) {
      // Profile sync failure is non-fatal - log and continue
      // ignore: avoid_print
      debugPrint('[AuthService] _syncProfile failed: ${e.message}');
    }
  }

  // â”€â”€ Error Code Mapping â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _humanizeCode(String code) => switch (code) {
        'user-not-found' => 'No account found with this email.',
        'wrong-password' => 'Incorrect password. Please try again.',
        'invalid-credential' => 'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for this email.',
        'invalid-email' => 'Please enter a valid email address.',
        'weak-password' => 'Password must be at least 6 characters.',
        'too-many-requests' => 'Too many attempts. Please wait a moment.',
        'network-request-failed' =>
          'No internet connection. Check your network.',
        'user-disabled' => 'This account has been disabled.',
        'operation-not-allowed' => 'This sign-in method is not enabled.',
        _ => 'Authentication failed. Please try again.',
      };
}

// ignore: depend_on_referenced_packages
void debugPrint(String message) => print(message);
