import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import 'login_screen.dart';

/// Wraps any widget and redirects to [LoginScreen] if the user is
/// not authenticated.
///
/// Usage in router.dart:
/// ```dart
/// GoRoute(
///   path: '/spaces',
///   builder: (_, __) => const AuthGate(
///     message: 'Sign in to access your spaces',
///     child: SpacesScreen(),
///   ),
/// ),
/// ```
///
/// Screens that do NOT require auth (e.g. personal calendar) use their
/// widget directly — no AuthGate needed.
class AuthGate extends ConsumerWidget {
  const AuthGate({
    super.key,
    required this.child,
    this.message,
  });

  /// The protected screen to show when authenticated.
  final Widget child;

  /// Optional message shown in an amber banner on the login screen —
  /// use this when the user was redirected here from a protected route.
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      // Firebase is resolving the persisted session.
      // Never show LoginScreen here — doing so would flash login for
      // users who are already signed in.
      loading: () => const _AuthLoadingScreen(),

      // Treat auth errors as unauthenticated.
      error: (_, __) => LoginScreen(message: message),

      // Session resolved.
      data: (user) => user != null
          ? child // ← authenticated: show the protected widget
          : LoginScreen(message: message), // ← not signed in
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LOADING SCREEN
// Shown while Firebase resolves the persisted auth session on cold start.
// ══════════════════════════════════════════════════════════════════════════════

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B3E),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'KWAN·TIME',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading your calendars...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.35),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Color(0xFF1565C0),
                strokeWidth: 2,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 600.ms, curve: Curves.easeOut),
      ),
    );
  }
}
