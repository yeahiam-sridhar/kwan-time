import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

// ── Raw Firebase Auth instance ────────────────────────────────────────────
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

// ── Auth state stream  (User? — null = signed out) ────────────────────────
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

// ── Current Firebase User  (nullable, synchronous) ───────────────────────
final currentFirebaseUserProvider = Provider<User?>(
  (ref) => ref.watch(authStateProvider).valueOrNull,
);

// ── Is authenticated ──────────────────────────────────────────────────────
final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(currentFirebaseUserProvider) != null,
);

// ── AppUser from Firestore  (real-time stream) ────────────────────────────
// • user == null  → Stream.value(null)
// • user != null  → streams users/{uid} document
final appUserProvider = StreamProvider<AppUser?>(
  (ref) {
    final user = ref.watch(currentFirebaseUserProvider);
    if (user == null) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  },
);

// ── Current user display name (sync, safe fallback) ──────────────────────
final displayNameProvider = Provider<String>(
  (ref) => ref.watch(appUserProvider).valueOrNull?.displayName ?? '',
);

// ── Auth service instance ─────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(),
);
