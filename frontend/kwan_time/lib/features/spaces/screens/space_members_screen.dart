import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/kwan_colors.dart';
import '../models/space_model.dart';
import '../providers/space_providers.dart';
import '../services/role_permission_service.dart';

class SpaceMembersScreen extends ConsumerWidget {
  const SpaceMembersScreen({super.key, required this.space});

  final SpaceModel space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final role = uid.isEmpty ? SpaceRole.none : space.roleOfOrNone(uid);
    final svc = ref.read(rolePermissionServiceProvider);

    final spaces = ref.watch(spaceListProvider).valueOrNull ?? const [];
    final liveSpace = spaces
        .firstWhere((s) => s.id == space.id, orElse: () => space);

    final entries = liveSpace.members.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B3E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B3E),
        elevation: 0,
        title: const Text(
          'Members',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                'No members found',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final memberUid = entry.key;
                final memberRole = SpaceRoleX.fromString(entry.value);
                final canManage = svc.canRemoveMember(role);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: ListTile(
                    title: Text(
                      memberUid,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      memberRole.label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    trailing: canManage
                        ? PopupMenuButton<String>(
                            color: const Color(0xFF162347),
                            onSelected: (value) async {
                              if (value.startsWith('role:')) {
                                final next = value.split(':')[1];
                                final newRole = SpaceRoleX.fromString(next);
                                await ref
                                    .read(spaceServiceProvider)
                                    .changeMemberRole(
                                      liveSpace.id,
                                      memberUid,
                                      newRole,
                                    );
                              } else if (value == 'remove') {
                                final confirmed =
                                    await _confirmRemove(context, memberUid);
                                if (confirmed != true) return;

                                final isLastAdmin =
                                    memberRole == SpaceRole.admin &&
                                        liveSpace.adminIds.length <= 1;
                                if (isLastAdmin) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'You must keep at least one admin',
                                        ),
                                        backgroundColor: KwanColors.error,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                await ref
                                    .read(spaceServiceProvider)
                                    .removeMember(liveSpace.id, memberUid);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'role:admin',
                                child: Text('Make admin'),
                              ),
                              const PopupMenuItem(
                                value: 'role:member',
                                child: Text('Make member'),
                              ),
                              const PopupMenuItem(
                                value: 'role:viewer',
                                child: Text('Make viewer'),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text(
                                  'Remove',
                                  style: TextStyle(color: KwanColors.error),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }

  Future<bool?> _confirmRemove(BuildContext context, String memberUid) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162347),
        title: const Text(
          'Remove Member',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Remove $memberUid from this space?',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFEF9A9A), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
