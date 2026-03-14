import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/space_model.dart';
import '../providers/space_providers.dart';
import '../services/role_permission_service.dart';
import '../services/space_service.dart';
import '../screens/space_calendar_screen.dart';
import '../screens/space_members_screen.dart';
import 'space_edit_sheet.dart';

// Three-dot PopupMenuButton shown on each SpaceCard.
// Menu items are role-dependent.
class SpaceManagementMenu extends ConsumerWidget {
  const SpaceManagementMenu({super.key, required this.space});

  final SpaceModel space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final role = uid.isEmpty ? SpaceRole.none : space.roleOfOrNone(uid);
    final svc = ref.read(rolePermissionServiceProvider);

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: Colors.white.withOpacity(0.6),
        size: 20,
      ),
      color: const Color(0xFF162347),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) => _onSelected(context, ref, value, role),
      itemBuilder: (_) => [
        // ALL roles
        _item('open', Icons.open_in_new_rounded, 'Open space', Colors.white),

        // ADMIN only
        if (svc.canEditSpace(role))
          _item('edit', Icons.edit_rounded, 'Edit space', Colors.white),
        if (svc.canInviteMembers(role))
          _item('invite', Icons.person_add_rounded, 'Invite members', Colors.white),
        if (svc.canInviteMembers(role))
          _item('members', Icons.group_rounded, 'Manage members', Colors.white),
        if (svc.canDeleteSpace(role))
          _item(
            'delete',
            Icons.delete_forever_rounded,
            'Delete space',
            const Color(0xFFEF9A9A),
          ),

        // MEMBER / VIEWER
        if (svc.canLeaveSpace(role))
          _item(
            'leave',
            Icons.exit_to_app_rounded,
            'Leave space',
            const Color(0xFFF9A825),
          ),
      ],
    );
  }

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    String value,
    SpaceRole role,
  ) async {
    switch (value) {
      case 'open':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SpaceCalendarScreen(space: space)),
        );
        return;

      case 'edit':
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => SpaceEditSheet(space: space),
        );
        return;

      case 'invite':
        final svc = ref.read(inviteServiceProvider);
        final link = await svc.generateInviteLink(space.id, SpaceRole.member);
        await Share.share(
          'Join my KWAN\u00B7TIME space: ${space.name}\n$link',
          subject: 'KWAN\u00B7TIME Invite',
        );
        return;

      case 'members':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SpaceMembersScreen(space: space)),
        );
        return;

      case 'delete':
        final confirmed = await _confirmDelete(context);
        if (!confirmed || !context.mounted) return;
        try {
          await ref.read(spaceServiceProvider).deleteSpace(space.id);
          ref.invalidate(spaceListProvider);
          await Navigator.of(context).maybePop();
        } on SpaceException catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
        return;

      case 'leave':
        final confirmed = await _confirmLeave(context);
        if (!confirmed || !context.mounted) return;
        try {
          final uid = FirebaseAuth.instance.currentUser!.uid;
          await ref.read(spaceServiceProvider).removeMember(space.id, uid);
          ref.invalidate(spaceListProvider);
          await Navigator.of(context).maybePop();
        } on SpaceException catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
        return;
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF162347),
            title: const Text(
              'Delete Space',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            content: Text(
              'This permanently deletes "${space.name}", all events, and member data.',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.white60)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Color(0xFFEF9A9A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF162347),
            title: const Text(
              'Leave Space',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            content: Text(
              'Leave "${space.name}"?',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.white60)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Leave',
                  style: TextStyle(
                    color: Color(0xFFF9A825),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}
