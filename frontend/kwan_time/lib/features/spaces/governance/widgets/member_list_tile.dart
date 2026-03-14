// ============================================================================
// lib/features/spaces/governance/widgets/member_list_tile.dart
// ============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/space_governance_service.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;

  String get initials {
    final List<String> parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty) {
      return parts.first[0].toUpperCase();
    }
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }
}

class MemberListTile extends StatelessWidget {
  const MemberListTile({
    super.key,
    required this.profile,
    required this.role,
    required this.isCurrentUserAdmin,
    required this.onChangeRole,
    required this.onRemove,
  });

  final UserProfile profile;
  final SpaceRole role;
  final bool isCurrentUserAdmin;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;

  Color get _badgeColor => switch (role) {
        SpaceRole.admin => Colors.red.shade400,
        SpaceRole.member => Colors.blue.shade400,
        SpaceRole.viewer => Colors.grey.shade400,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: <Widget>[
          _buildAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RoleBadge(label: role.label, color: _badgeColor),
          if (isCurrentUserAdmin)
            PopupMenuButton<String>(
              color: const Color(0xFF12264A),
              icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.7)),
              onSelected: (String value) {
                if (value == 'change') {
                  onChangeRole();
                } else if (value == 'remove') {
                  onRemove();
                }
              },
              itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'change',
                  child: Text('Change role'),
                ),
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Text('Remove member'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (profile.photoUrl != null && profile.photoUrl!.trim().isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: profile.photoUrl!,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallbackAvatar(),
        ),
      );
    }
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    return CircleAvatar(
      radius: 21,
      backgroundColor: Colors.white.withOpacity(0.12),
      child: Text(
        profile.initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
