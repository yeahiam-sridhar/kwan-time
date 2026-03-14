import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/kwan_colors.dart';
import '../models/space_role.dart';

class InviteSheet extends ConsumerStatefulWidget {
  final String spaceId;
  final String spaceName;

  const InviteSheet({
    super.key,
    required this.spaceId,
    required this.spaceName,
  });

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  bool _loading = false;
  String? _errorMsg;

  String _generateInviteLink(String spaceId, String role) =>
      'https://kwantime.app/join/$spaceId?role=$role';

  Future<void> _onShareInvite(String spaceId, String role) async {
    final link = _generateInviteLink(spaceId, role);
    await Share.share(
      'Join my KWAN·TIME calendar space\n$link',
      subject: 'KWAN·TIME Invite',
    );
  }

  Future<void> _share(SpaceRole role) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      await _onShareInvite(widget.spaceId, role.name);
    } catch (e) {
      setState(() => _errorMsg = 'Failed to generate invite. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyLink(SpaceRole role) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final link = _generateInviteLink(widget.spaceId, role.name);
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard!')),
        );
      }
    } catch (e) {
      setState(() => _errorMsg = 'Failed to copy link. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KwanColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: KwanColors.white(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Invite Members',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Share this link to collaborate on this calendar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KwanColors.white(0.45),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: KwanColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMsg!,
                style: const TextStyle(
                  color: KwanColors.error,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          _RoleInviteRow(
            role: SpaceRole.admin,
            icon: Icons.admin_panel_settings_outlined,
            color: KwanColors.admin,
            description: 'Full access - create, edit, manage members',
            loading: _loading,
            onShare: () => _share(SpaceRole.admin),
            onCopy: () => _copyLink(SpaceRole.admin),
          ),
          const SizedBox(height: 12),
          _RoleInviteRow(
            role: SpaceRole.member,
            icon: Icons.edit_outlined,
            color: KwanColors.member,
            description: 'Can view events and add comments',
            loading: _loading,
            onShare: () => _share(SpaceRole.member),
            onCopy: () => _copyLink(SpaceRole.member),
          ),
          const SizedBox(height: 12),
          _RoleInviteRow(
            role: SpaceRole.viewer,
            icon: Icons.visibility_outlined,
            color: KwanColors.viewer,
            description: 'Read-only access',
            loading: _loading,
            onShare: () => _share(SpaceRole.viewer),
            onCopy: () => _copyLink(SpaceRole.viewer),
          ),
        ],
      ),
    );
  }
}

class _RoleInviteRow extends StatelessWidget {
  final SpaceRole role;
  final IconData icon;
  final Color color;
  final String description;
  final bool loading;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  const _RoleInviteRow({
    required this.role,
    required this.icon,
    required this.color,
    required this.description,
    required this.loading,
    required this.onShare,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${role.label} Link',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: KwanColors.white(0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: color,
                  strokeWidth: 2,
                ),
              )
            else ...[
              IconButton(
                tooltip: 'Copy link',
                icon: Icon(Icons.copy_outlined, color: color, size: 18),
                onPressed: onCopy,
              ),
              IconButton(
                tooltip: 'Share',
                icon: Icon(Icons.share_outlined, color: color, size: 18),
                onPressed: onShare,
              ),
            ],
          ],
        ),
      );
}
