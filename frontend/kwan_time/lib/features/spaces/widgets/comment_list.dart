import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/space_comment_model.dart';
import '../models/space_role.dart';
import '../providers/space_providers.dart';
import '../services/space_comment_service.dart';

final spaceCommentsProvider = StreamProvider.family<List<SpaceComment>,
    ({String spaceId, String eventId})>((ref, args) {
  return SpaceCommentService().streamComments(args.spaceId, args.eventId);
});

class CommentList extends ConsumerWidget {
  const CommentList({
    super.key,
    required this.spaceId,
    required this.eventId,
  });

  final String spaceId;
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync =
        ref.watch(spaceCommentsProvider((spaceId: spaceId, eventId: eventId)));
    return commentsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Loading comments...',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Failed to load comments: $e',
          style: const TextStyle(color: Color(0xFFEF9A9A)),
        ),
      ),
      data: (comments) {
        if (comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No comments yet.',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final comment = comments[index];
            final canDelete = _canDelete(ref, comment);
            return GestureDetector(
              onLongPress: canDelete
                  ? () => _showDeleteOption(context, ref, comment)
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(comment),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              comment.authorName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _timeAgo(comment.createdAt),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment.text,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar(SpaceComment comment) {
    if (comment.authorPhotoUrl != null &&
        comment.authorPhotoUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: CachedNetworkImageProvider(comment.authorPhotoUrl!),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white.withOpacity(0.12),
      child: Text(
        comment.initials,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  bool _canDelete(WidgetRef ref, SpaceComment comment) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return false;
    }
    final role = ref.watch(spaceRoleProvider(spaceId));
    return comment.authorId == uid || role == SpaceRole.admin;
  }

  Future<void> _showDeleteOption(
    BuildContext context,
    WidgetRef ref,
    SpaceComment comment,
  ) async {
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF162347),
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline, color: Color(0xFFEF9A9A)),
          title: const Text(
            'Delete comment',
            style: TextStyle(color: Color(0xFFEF9A9A)),
          ),
          onTap: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (shouldDelete == true) {
      await SpaceCommentService().deleteComment(
        spaceId: spaceId,
        eventId: eventId,
        commentId: comment.id,
      );
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }
}
