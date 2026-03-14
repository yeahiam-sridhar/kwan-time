// lib/features/spaces/invite/services/deep_link_service.dart
//
// Handles incoming https://kwantime.app/join/{spaceId}?role={role} links.
// Initialised once via deepLinkServiceProvider in app.dart.

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/space_providers.dart';

// ── Provider — top-level, imported by app.dart ────────────────────────────
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService(ref);
});

// ── Pending join state ────────────────────────────────────────────────────
class PendingJoin {
  const PendingJoin({
    required this.spaceId,
    required this.role,
    required this.token,
  });
  final String spaceId;
  final String role;
  final String token;
}

final pendingJoinProvider = StateProvider<PendingJoin?>((ref) => null);

// ══════════════════════════════════════════════════════════════════════════════

class DeepLinkService {
  DeepLinkService(this._ref);

  final Ref _ref;
  final _appLinks = AppLinks();

  /// Call once after Firebase.initializeApp().
  /// Handles both cold-start (getInitialLink) and warm-start (uriLinkStream).
  Future<void> initialize() async {
    // Cold-start link — app was launched via the link
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);
    } catch (e) {
      debugPrint('[DeepLinkService] getInitialLink error: $e');
    }

    // Warm-start stream — app was already running
    _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (e) => debugPrint('[DeepLinkService] stream error: $e'),
    );
  }

  void _handleUri(Uri uri) {
    try {
      if (uri.host != 'kwantime.app') return;

      // New canonical invite format:
      // https://kwantime.app/invite?spaceId=...&role=...&token=...
      if (uri.pathSegments.length != 1 || uri.pathSegments.first != 'invite') {
        return;
      }

      final spaceId = uri.queryParameters['spaceId'];
      final role = uri.queryParameters['role'] ?? 'member';
      final token = uri.queryParameters['token'];
      if (spaceId == null || token == null) {
        return;
      }

      debugPrint(
        '[DeepLinkService] invite link: spaceId=$spaceId role=$role token=$token',
      );

      // If already authenticated → process join immediately
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _ref
            .read(inviteServiceProvider)
            .processJoin(spaceId: spaceId, role: role, token: token)
            .then((result) {
          debugPrint('[DeepLinkService] join result: $result');
        });
      } else {
        // Store pending join — AuthGate will process after login
        _ref.read(pendingJoinProvider.notifier).state =
            PendingJoin(spaceId: spaceId, role: role, token: token);
      }
    } catch (e) {
      debugPrint('[DeepLinkService] _handleUri error: $e');
    }
  }
}
