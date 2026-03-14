import 'package:flutter_riverpod/flutter_riverpod.dart';

// Centralised permission authority.
// All UI permission checks go through this service - never inline.

enum SpaceRole { admin, member, viewer, none }

extension SpaceRoleX on SpaceRole {
  static SpaceRole fromString(String? value) => switch (value) {
        'admin' => SpaceRole.admin,
        'member' => SpaceRole.member,
        'viewer' => SpaceRole.viewer,
        _ => SpaceRole.none,
      };

  String get label => switch (this) {
        SpaceRole.admin => 'Admin',
        SpaceRole.member => 'Member',
        SpaceRole.viewer => 'Viewer',
        SpaceRole.none => 'None',
      };
}

class RolePermissionService {
  // Events
  bool canCreateEvent(SpaceRole role) =>
      role == SpaceRole.admin || role == SpaceRole.member;

  bool canEditEvent(SpaceRole role, String createdBy, String currentUid) =>
      role == SpaceRole.admin ||
      (role == SpaceRole.member && createdBy == currentUid);

  bool canDeleteEvent(SpaceRole role) => role == SpaceRole.admin;

  // Space management
  bool canInviteMembers(SpaceRole role) => role == SpaceRole.admin;
  bool canRemoveMember(SpaceRole role) => role == SpaceRole.admin;
  bool canEditSpace(SpaceRole role) => role == SpaceRole.admin;
  bool canDeleteSpace(SpaceRole role) => role == SpaceRole.admin;
  bool canChangeRoles(SpaceRole role) => role == SpaceRole.admin;

  bool canLeaveSpace(SpaceRole role) => role == SpaceRole.member;

  bool canViewSpace(SpaceRole role) => role != SpaceRole.none;
}

// Top-level provider
final rolePermissionServiceProvider =
    Provider<RolePermissionService>((ref) => RolePermissionService());
