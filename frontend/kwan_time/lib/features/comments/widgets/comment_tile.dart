// UI tile for rendering a single event comment.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/event_comment.dart';

class CommentTile extends StatelessWidget {
  final EventComment comment;
  final VoidCallback? onDelete;

  const CommentTile({
    super.key,
    required this.comment,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildAvatar(),
      title: Text(
        comment.authorName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 2),
          Text(comment.text),
          const SizedBox(height: 4),
          Text(
            _timeAgo(comment.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: onDelete != null
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            )
          : null,
    );
  }

  Widget _buildAvatar() {
    if (comment.authorPhotoUrl != null) {
      return CircleAvatar(
        backgroundImage: CachedNetworkImageProvider(comment.authorPhotoUrl!),
      );
    }

    final name = comment.authorName.trim();
    final firstLetter = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return CircleAvatar(
      child: Text(firstLetter),
    );
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
