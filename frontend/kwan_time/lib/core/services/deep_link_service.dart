import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uni_links/uni_links.dart';

import '../../features/spaces/models/space_invite_model.dart';
import '../../features/spaces/services/invite_service.dart' hide JoinResult;

/// Parsed data from an incoming deep link
class InviteDeepLink {
  final String spaceId;
  final String role;
  final String token;

  const InviteDeepLink({
    required this.spaceId,
    required this.role,
    required this.token,
  });
}

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  StreamSubscription? _sub;

  /// Call from your root widget's initState
  void initialize({
    required InviteService inviteService,
    required void Function(JoinResult result) onJoinResult,
    required void Function() onNeedsAuth,
  }) {
    // Handle cold-start link
    getInitialUri()
        .then((uri) {
          if (uri != null) {
            _handleUri(uri, inviteService, onJoinResult, onNeedsAuth);
          }
        })
        .catchError((e) {
          debugPrint('[DeepLink] cold start error: $e');
          return null;
        });

    // Handle foreground links
    _sub = uriLinkStream.listen(
      (uri) {
        if (uri != null) {
          _handleUri(uri, inviteService, onJoinResult, onNeedsAuth);
        }
      },
      onError: (e) => debugPrint('[DeepLink] stream error: $e'),
    );
  }

  void dispose() => _sub?.cancel();

  InviteDeepLink? parseUri(Uri uri) {
    // Expected: https://kwantime.app/join/{spaceId}?role=member&token=XYZ
    final segments = uri.pathSegments;
    if (segments.length < 2 || segments[0] != 'join') return null;
    final spaceId = segments[1];
    final role = uri.queryParameters['role'] ?? 'viewer';
    final token = uri.queryParameters['token'] ?? '';
    if (token.isEmpty) return null;
    return InviteDeepLink(spaceId: spaceId, role: role, token: token);
  }

  Future<void> _handleUri(
    Uri uri,
    InviteService inviteService,
    void Function(JoinResult) onJoinResult,
    void Function() onNeedsAuth,
  ) async {
    final link = parseUri(uri);
    if (link == null) return;

    final result = await inviteService.processJoin(
      spaceId: link.spaceId,
      role: link.role,
      token: link.token,
    );

    if (result == JoinResult.notAuthenticated) {
      onNeedsAuth();
    } else {
      onJoinResult(result);
    }
  }
}
