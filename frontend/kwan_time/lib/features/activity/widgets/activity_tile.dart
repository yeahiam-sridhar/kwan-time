// Visual tile for a single activity event in the timeline.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/activity_event.dart';

class ActivityTile extends StatelessWidget {
  final ActivityEvent event;

  const ActivityTile({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildAvatar(),
      title: _buildMessage(event),
      subtitle: Text(_timeAgo(event.createdAt)),
    );
  }

  Widget _buildAvatar() {
    if (event.actorPhotoUrl != null) {
      return CircleAvatar(
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: event.actorPhotoUrl!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _fallbackAvatarText(),
          ),
        ),
      );
    }

    return CircleAvatar(
      child: _fallbackAvatarText(),
    );
  }

  Widget _fallbackAvatarText() {
    final trimmed = event.actorName.trim();
    final firstLetter =
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
    return Text(firstLetter);
  }

  RichText _buildMessage(ActivityEvent event) {
    final actorName = event.actorName.isEmpty ? 'Unknown' : event.actorName;
    final targetName = event.targetName ?? 'item';

    String trailingText;
    switch (event.type) {
      case 'event_created':
        trailingText = ' created event $targetName';
        break;
      case 'event_updated':
        trailingText = ' updated event $targetName';
        break;
      case 'event_deleted':
        trailingText = ' deleted event $targetName';
        break;
      case 'member_joined':
        trailingText = ' joined the space';
        break;
      case 'member_removed':
        trailingText = ' was removed from the space';
        break;
      case 'comment_added':
        trailingText = ' commented on $targetName';
        break;
      default:
        trailingText = ' performed an action';
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
        ),
        children: [
          TextSpan(
            text: actorName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: trailingText),
        ],
      ),
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
