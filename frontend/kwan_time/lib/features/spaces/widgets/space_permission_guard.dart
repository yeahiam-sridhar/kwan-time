import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/space_role.dart';
import '../providers/space_providers.dart';

class SpacePermissionGuard extends ConsumerWidget {
  const SpacePermissionGuard({
    super.key,
    required this.spaceId,
    required this.requiredRole,
    required this.child,
    this.fallback,
  });

  final String spaceId;
  final SpaceRole requiredRole;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(spaceRoleProvider(spaceId));
    final hasPermission = switch (requiredRole) {
      SpaceRole.admin => role == SpaceRole.admin,
      SpaceRole.member => role == SpaceRole.admin || role == SpaceRole.member,
      SpaceRole.viewer => role != SpaceRole.none,
      SpaceRole.none => false,
    };
    if (hasPermission) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}
