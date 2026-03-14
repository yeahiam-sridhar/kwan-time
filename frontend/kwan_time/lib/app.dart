// lib/app.dart
//
// Root application widget.
// AuthGate routes authenticated users to BottomNavShell,
// unauthenticated users to LoginScreen.
// DeepLinkService is initialised here once, after the widget tree is ready.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'core/router/router.dart' show HomeShell;
// ── Auth screens ──────────────────────────────────────────────────────────
import 'features/auth/screens/login_screen.dart';

// ── App shell (frozen — do not modify this file) ──────────────────────────
import 'core/navigation/bottom_nav_shell.dart';

// ── Deep link service — THIS IS THE IMPORT THAT WAS MISSING ──────────────
import 'features/spaces/invite/services/deep_link_service.dart';
import 'features/spaces/providers/space_providers.dart';
import 'features/spaces/services/invite_service.dart';
import 'features/spaces/screens/spaces_screen.dart';

// pendingJoinProvider and PendingJoin live in deep_link_service.dart —
// no separate import needed, they come in with the line above.

/// Root application widget.
class KwanTimeApp extends ConsumerWidget {
  const KwanTimeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'KWAN·TIME',
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1B3E),
      ),
    );
  }
}

/// Authentication gate.
/// Listens to FirebaseAuth.authStateChanges() and routes:
///   loading         → _SplashScreen   (no login flash on cold start)
///   authenticated   → BottomNavShell
///   unauthenticated → LoginScreen
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  StreamSubscription<User?>? _authSub;
  User? _lastAuthUser;

  @override
  void initState() {
    super.initState();
    // Initialise deep link service after the first frame.
    // deepLinkServiceProvider is imported above — no compile error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(deepLinkServiceProvider).initialize());
    });

    // BottomNavShell is frozen and calls FirebaseAuth.signOut() directly.
    // Ensure we still clear cached Google account selection on sign-out so the
    // chooser appears next login.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      final wasSignedIn = _lastAuthUser != null;
      _lastAuthUser = user;
      if (!wasSignedIn || user != null) {
        return;
      }
      try {
        await GoogleSignIn().disconnect();
      } catch (_) {
        try {
          await GoogleSignIn().signOut();
        } catch (_) {
          // ignore
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Resolving persisted session — never show LoginScreen yet
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // Authenticated
        if (snapshot.hasData) {
          // Process any pending deep-link join that arrived before auth.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final pending = ref.read(pendingJoinProvider);
            if (pending == null) {
              return;
            }
            ref.read(pendingJoinProvider.notifier).state = null;

            final result = await ref.read(inviteServiceProvider).processJoin(
                  spaceId: pending.spaceId,
                  role: pending.role,
                  token: pending.token,
                );
            if (!context.mounted) {
              return;
            }

            final message = switch (result) {
              JoinResult.joined => 'Joined space successfully',
              JoinResult.alreadyMember => 'You are already a member',
              JoinResult.tokenExpired => 'Invite link expired',
              JoinResult.tokenAlreadyUsed => 'Invite link already used',
              JoinResult.invalidToken => 'Invalid invite link',
              JoinResult.spaceNotFound => 'Space not found',
              JoinResult.notAuthenticated => 'Please sign in to join',
              JoinResult.error => 'Could not join space. Try again.',
            };
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          });
          return const BottomNavShell(
            calendarTab: HomeShell(),
            spacesTab: SpacesScreen(),
          );
        }

        // Not authenticated
        return const LoginScreen();
      },
    );
  }
}

/// Shown while Firebase resolves the persisted auth session on cold start.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1B3E),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'KWAN·TIME',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1.0,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(fontSize: 14, color: Colors.white38),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Color(0xFF1565C0),
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
