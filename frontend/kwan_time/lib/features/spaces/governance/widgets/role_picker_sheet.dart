// ============================================================================
// lib/features/spaces/governance/widgets/role_picker_sheet.dart
// ============================================================================

import 'package:flutter/material.dart';

import '../services/space_governance_service.dart';

class RolePickerSheet extends StatelessWidget {
  const RolePickerSheet({
    super.key,
    this.currentRole,
  });

  final SpaceRole? currentRole;

  static Future<SpaceRole?> show(BuildContext context) {
    return showModalBottomSheet<SpaceRole>(
      context: context,
      backgroundColor: const Color(0xFF102448),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const RolePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Center(
              child: Text(
                'Select Role',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _roleTile(
              context: context,
              role: SpaceRole.admin,
              title: 'Admin',
              description: 'Can edit space and manage members',
              color: Colors.red.shade400,
            ),
            _roleTile(
              context: context,
              role: SpaceRole.member,
              title: 'Member',
              description: 'Can view events and comment',
              color: Colors.blue.shade400,
            ),
            _roleTile(
              context: context,
              role: SpaceRole.viewer,
              title: 'Viewer',
              description: 'Can view events only',
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleTile({
    required BuildContext context,
    required SpaceRole role,
    required String title,
    required String description,
    required Color color,
  }) {
    final bool selected = currentRole == role;
    return InkWell(
      onTap: () => Navigator.of(context).pop(role),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? color : Colors.white60,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
