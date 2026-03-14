import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authStateProvider =
    StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

final currentUserProvider =
    Provider<User?>((ref) => ref.watch(authStateProvider).valueOrNull);

final isAuthenticatedProvider =
    Provider<bool>((ref) => ref.watch(currentUserProvider) != null);
