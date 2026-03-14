import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/space_activity_model.dart';
import '../models/space_event_model.dart';
import '../models/space_model.dart';
import '../providers/space_activity_provider.dart';
import '../providers/space_providers.dart';
import '../services/role_permission_service.dart';
import '../services/space_comment_service.dart';
import 'comment_list.dart';
import 'space_event_form.dart';

class SpaceEventDetailSheet extends ConsumerStatefulWidget {
  const SpaceEventDetailSheet({
    super.key,
    required this.event,
    required this.space,
  });

  final SpaceEvent event;
  final SpaceModel space;

  @override
  ConsumerState<SpaceEventDetailSheet> createState() =>
      _SpaceEventDetailSheetState();
}

class _SpaceEventDetailSheetState extends ConsumerState<SpaceEventDetailSheet> {
  late SpaceEvent _event;
  final _commentCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final role =
        uid.isEmpty ? SpaceRole.none : ref.watch(spaceRoleProvider(widget.space.id));
    final perm = ref.read(rolePermissionServiceProvider);
    final canEdit = perm.canEditEvent(role, _event.createdBy, uid);
    final canDelete = perm.canDeleteEvent(role);
    final canComment = role == SpaceRole.admin || role == SpaceRole.member;
    final commentsAsync = ref.watch(
      spaceCommentsProvider((spaceId: widget.space.id, eventId: _event.id)),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1B3E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              _buildHeader(canEdit: canEdit, canDelete: canDelete),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 10),
              Text(
                'Comments (${commentsAsync.valueOrNull?.length ?? _event.commentCount})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              CommentList(spaceId: widget.space.id, eventId: _event.id),
              if (canComment) ...[
                const SizedBox(height: 12),
                _buildCommentInput(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader({required bool canEdit, required bool canDelete}) {
    final color = _parseColor(_event.colorHex);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16,
          height: 110,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _event.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatTimeRange(context, _event),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
              if (_event.location != null &&
                  _event.location!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.place_rounded,
                      color: Colors.white.withOpacity(0.5),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _event.location!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (canEdit || canDelete) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (canEdit)
                      OutlinedButton(
                        onPressed: _onEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side:
                              BorderSide(color: Colors.white.withOpacity(0.4)),
                        ),
                        child: const Text('Edit'),
                      ),
                    if (canEdit && canDelete) const SizedBox(width: 10),
                    if (canDelete)
                      OutlinedButton(
                        onPressed: _onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF9A9A),
                          side: const BorderSide(color: Color(0xFFEF9A9A)),
                        ),
                        child: const Text('Delete'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    final userName = ref.watch(displayNameProvider);
    final initials = _initials(userName);
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withOpacity(0.12),
          child: Text(
            initials,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _commentCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a comment...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1565C0)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        IconButton(
          onPressed: _isSending ? null : _sendComment,
          icon: Icon(
            Icons.send_rounded,
            color: _isSending ? Colors.white38 : const Color(0xFF1565C0),
          ),
        ),
      ],
    );
  }

  Future<void> _onEdit() async {
    final updated = await showModalBottomSheet<SpaceEvent?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpaceEventForm(
        space: widget.space,
        existingEvent: _event,
      ),
    );
    if (updated != null && mounted) {
      setState(() => _event = updated);
    }
  }

  Future<void> _onDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162347),
        title: const Text(
          'Delete Event?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will remove the event and its comments.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    final svc = ref.read(eventServiceProvider);
    await svc.deleteEvent(widget.space.id, _event.id);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userName = ref.read(displayNameProvider);
    await ref.read(spaceActivityServiceProvider).log(
          spaceId: widget.space.id,
          type: ActivityType.eventDeleted,
          actorId: uid,
          actorName: userName,
          targetId: _event.id,
          targetName: _event.title,
        );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final userName = ref.read(displayNameProvider);
      await SpaceCommentService().addComment(
        spaceId: widget.space.id,
        eventId: _event.id,
        text: text,
        authorId: user.uid,
        authorName: userName,
        authorPhotoUrl: user.photoURL,
      );
      await ref.read(spaceActivityServiceProvider).log(
            spaceId: widget.space.id,
            type: ActivityType.commentAdded,
            actorId: user.uid,
            actorName: userName,
            targetId: _event.id,
            targetName: _event.title,
          );
      _commentCtrl.clear();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _formatTimeRange(BuildContext context, SpaceEvent event) {
    if (event.isAllDay) {
      return 'All Day';
    }
    final localizations = MaterialLocalizations.of(context);
    final start = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(event.startTime),
      alwaysUse24HourFormat: false,
    );
    final end = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(event.endTime),
      alwaysUse24HourFormat: false,
    );
    return '$start - $end';
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) {
      return const Color(0xFF1565C0);
    }
    final value = hex.replaceFirst('#', '');
    if (value.length == 6) {
      return Color(int.parse('0xFF$value'));
    }
    if (value.length == 8) {
      return Color(int.parse('0x$value'));
    }
    return const Color(0xFF1565C0);
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
