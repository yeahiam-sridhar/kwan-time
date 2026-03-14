// ============================================================================
// lib/features/spaces/governance/screens/space_settings_screen.dart
// ============================================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_providers.dart';
import '../../models/space_model.dart';
import '../services/space_governance_service.dart';
import '../widgets/danger_zone_card.dart';
import '../widgets/member_list_tile.dart';
import '../widgets/role_picker_sheet.dart';

final spaceDocStreamProvider =
    StreamProvider.family<DocumentSnapshot<Map<String, dynamic>>, String>(
  (ref, spaceId) {
    return FirebaseFirestore.instance
        .collection('spaces')
        .doc(spaceId)
        .snapshots();
  },
);

class SpaceSettingsScreen extends ConsumerStatefulWidget {
  const SpaceSettingsScreen({
    super.key,
    required this.space,
  });

  final SpaceModel space;

  @override
  ConsumerState<SpaceSettingsScreen> createState() => _SpaceSettingsScreenState();
}

class _SpaceSettingsScreenState extends ConsumerState<SpaceSettingsScreen> {
  static const List<String> _presetColors = <String>[
    '1565C0',
    '0288D1',
    '2E7D32',
    '43A047',
    '6A1B9A',
    'C2185B',
    'F57C00',
    '37474F',
  ];

  final SpaceGovernanceService _service = SpaceGovernanceService();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  bool _seededFromDoc = false;
  bool _isSaving = false;
  String _selectedColorHex = '1565C0';

  String? _membersCacheKey;
  Future<List<_MemberVm>>? _membersFuture;
  List<_MemberVm> _latestMembers = <_MemberVm>[];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.space.name);
    _descriptionController =
        TextEditingController(text: widget.space.description ?? '');
    _selectedColorHex = widget.space.colorHex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DocumentSnapshot<Map<String, dynamic>>> spaceAsync =
        ref.watch(spaceDocStreamProvider(widget.space.id));
    final currentUser = ref.watch(currentFirebaseUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B3E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B3E),
        title: const Text('Space Settings'),
      ),
      body: spaceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Text(
            'Failed to load space: $e',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        data: (DocumentSnapshot<Map<String, dynamic>> snap) {
          if (!snap.exists) {
            return const Center(
              child: Text(
                'Space not found',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
          final String ownerId = (data['ownerId'] ?? '').toString();
          final Map<String, dynamic> roles =
              (data['roles'] as Map<String, dynamic>?) ?? <String, dynamic>{};
          final Set<String> adminIds =
              Set<String>.from(roles['admins'] ?? <String>[]);
          final Set<String> memberIds =
              Set<String>.from(roles['members'] ?? <String>[]);
          final Set<String> viewerIds =
              Set<String>.from(roles['viewers'] ?? <String>[]);

          if (!_seededFromDoc) {
            _nameController.text = (data['name'] ?? widget.space.name).toString();
            _descriptionController.text =
                (data['description'] ?? widget.space.description ?? '').toString();
            _selectedColorHex =
                (data['colorHex'] ?? widget.space.colorHex).toString();
            _seededFromDoc = true;
          }

          final String? currentUid = currentUser?.uid;
          final bool isOwner = currentUid != null && currentUid == ownerId;
          final bool isAdmin = currentUid != null && adminIds.contains(currentUid);
          final bool canAdminister = isOwner || isAdmin;

          final Set<String> allMemberIds = <String>{
            ...adminIds,
            ...memberIds,
            ...viewerIds,
            ownerId,
          }..removeWhere((String uid) => uid.trim().isEmpty);

          _ensureMembersFuture(
            allMemberIds: allMemberIds,
            adminIds: adminIds,
            memberIds: memberIds,
            viewerIds: viewerIds,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _sectionTitle('SPACE INFORMATION'),
              const SizedBox(height: 10),
              _inputField(
                controller: _nameController,
                hint: 'Space name',
                enabled: canAdminister,
              ),
              const SizedBox(height: 10),
              _inputField(
                controller: _descriptionController,
                hint: 'Description',
                enabled: canAdminister,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presetColors.map((String hex) {
                  final bool selected = _selectedColorHex == hex;
                  return GestureDetector(
                    onTap: canAdminister
                        ? () => setState(() => _selectedColorHex = hex)
                        : null,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _hexToColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white24,
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: canAdminister && !_isSaving ? _onSave : null,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
              const SizedBox(height: 26),
              _sectionTitle('MEMBERS'),
              const SizedBox(height: 10),
              FutureBuilder<List<_MemberVm>>(
                future: _membersFuture,
                builder: (BuildContext context, AsyncSnapshot<List<_MemberVm>> s) {
                  if (!s.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final List<_MemberVm> members = s.data ?? <_MemberVm>[];
                  _latestMembers = members;
                  return Column(
                    children: members.map((m) {
                      return MemberListTile(
                        profile: m.profile,
                        role: m.role,
                        isCurrentUserAdmin: canAdminister,
                        onChangeRole: () => _onChangeRole(m),
                        onRemove: () => _onRemoveMember(m),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 26),
              _sectionTitle('YOUR SETTINGS'),
              if (!isOwner)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _onLeaveSpace,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Leave Space'),
                  ),
                ),
              const SizedBox(height: 26),
              if (canAdminister) ...<Widget>[
                _sectionTitle('DANGER ZONE'),
                const SizedBox(height: 10),
                DangerZoneCard(
                  onDeleteSpace: _onDeleteSpace,
                  onTransferOwnership: _onTransferOwnership,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _ensureMembersFuture({
    required Set<String> allMemberIds,
    required Set<String> adminIds,
    required Set<String> memberIds,
    required Set<String> viewerIds,
  }) {
    final List<String> sorted = allMemberIds.toList()..sort();
    final String key = [
      sorted.join(','),
      adminIds.toList()..sort(),
      memberIds.toList()..sort(),
      viewerIds.toList()..sort(),
    ].map((e) => e.toString()).join('|');

    if (_membersCacheKey == key && _membersFuture != null) {
      return;
    }
    _membersCacheKey = key;
    _membersFuture = _fetchMembers(
      allMemberIds: allMemberIds,
      adminIds: adminIds,
      memberIds: memberIds,
      viewerIds: viewerIds,
    );
  }

  Future<List<_MemberVm>> _fetchMembers({
    required Set<String> allMemberIds,
    required Set<String> adminIds,
    required Set<String> memberIds,
    required Set<String> viewerIds,
  }) async {
    try {
      if (allMemberIds.isEmpty) {
        return <_MemberVm>[];
      }

      final List<String> uidList = allMemberIds.toList();
      final Map<String, UserProfile> byUid = <String, UserProfile>{};

      for (int i = 0; i < uidList.length; i += 10) {
        final int end = i + 10 > uidList.length ? uidList.length : i + 10;
        final List<String> chunk = uidList.sublist(i, end);
        final QuerySnapshot<Map<String, dynamic>> query = await FirebaseFirestore
            .instance
            .collection('users')
            .where('uid', whereIn: chunk)
            .get();

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in query.docs) {
          final Map<String, dynamic> data = doc.data();
          final String uid = (data['uid'] ?? doc.id).toString();
          byUid[uid] = UserProfile(
            uid: uid,
            displayName: (data['displayName'] ?? data['name'] ?? 'Unknown').toString(),
            email: (data['email'] ?? '').toString(),
            photoUrl: data['photoUrl']?.toString(),
          );
        }
      }

      for (final String uid in uidList) {
        byUid.putIfAbsent(
          uid,
          () => UserProfile(
            uid: uid,
            displayName: 'Unknown',
            email: '',
          ),
        );
      }

      final List<_MemberVm> members = byUid.entries.map((entry) {
        final SpaceRole role = adminIds.contains(entry.key)
            ? SpaceRole.admin
            : memberIds.contains(entry.key)
                ? SpaceRole.member
                : SpaceRole.viewer;
        return _MemberVm(profile: entry.value, role: role);
      }).toList();

      members.sort(
        (a, b) => a.profile.displayName
            .toLowerCase()
            .compareTo(b.profile.displayName.toLowerCase()),
      );
      return members;
    } catch (e) {
      debugPrint('[SpaceSettingsScreen] _fetchMembers: $e');
      return <_MemberVm>[];
    }
  }

  Future<void> _onSave() async {
    setState(() => _isSaving = true);
    try {
      await _service.updateSpaceMetadata(
        widget.space.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        colorHex: _selectedColorHex,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Space updated')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _onChangeRole(_MemberVm member) async {
    final SpaceRole? selected = await RolePickerSheet.show(context);
    if (selected == null || selected == member.role) {
      return;
    }
    try {
      await _service.changeRole(widget.space.id, member.profile.uid, selected);
      setState(() {
        _membersCacheKey = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change role: $e')),
      );
    }
  }

  Future<void> _onRemoveMember(_MemberVm member) async {
    final bool confirm = await _confirm(
          title: 'Remove member?',
          message: '${member.profile.displayName} will lose access to this space.',
        ) ??
        false;
    if (!confirm) {
      return;
    }
    try {
      await _service.removeMember(widget.space.id, member.profile.uid);
      setState(() {
        _membersCacheKey = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove member: $e')),
      );
    }
  }

  Future<void> _onLeaveSpace() async {
    final bool confirm = await _confirm(
          title: 'Leave space?',
          message: 'You will lose access to this collaborative calendar.',
        ) ??
        false;
    if (!confirm) {
      return;
    }
    try {
      await _service.leaveSpace(widget.space.id);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to leave space: $e')),
      );
    }
  }

  Future<void> _onDeleteSpace() async {
    try {
      await _service.deleteSpace(widget.space.id);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete space: $e')),
      );
    }
  }

  Future<void> _onTransferOwnership() async {
    final List<_MemberVm> candidates = _latestMembers
        .where((m) => m.role == SpaceRole.admin || m.role == SpaceRole.member)
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members available for ownership transfer')),
      );
      return;
    }

    final String? selectedUid = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF12264A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: candidates.map((m) {
              return ListTile(
                title: Text(
                  m.profile.displayName,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  m.profile.email,
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                onTap: () => Navigator.of(context).pop(m.profile.uid),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selectedUid == null) {
      return;
    }
    try {
      await _service.transferOwnership(widget.space.id, selectedUid);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ownership transferred')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to transfer ownership: $e')),
      );
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.7),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required bool enabled,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        filled: true,
        fillColor: Colors.white.withOpacity(enabled ? 0.06 : 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final String normalized = hex.replaceAll('#', '').trim();
    final int value = int.tryParse('FF$normalized', radix: 16) ?? 0xFF1565C0;
    return Color(value);
  }
}

class _MemberVm {
  const _MemberVm({
    required this.profile,
    required this.role,
  });

  final UserProfile profile;
  final SpaceRole role;
}
