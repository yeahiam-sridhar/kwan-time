import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/space_activity_model.dart';
import '../providers/space_activity_provider.dart';

class ActivityTimeline extends ConsumerWidget {
  const ActivityTimeline({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(spaceActivityStreamProvider(spaceId));
    return activityAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1565C0)),
      ),
      error: (e, _) => Center(
        child: Text(
          'Failed to load activity: $e',
          style: const TextStyle(color: Color(0xFFEF9A9A)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No activity yet.',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final activity = items[index];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActivityAvatar(activity: activity),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.type
                            .label(activity.actorName, activity.targetName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeAgo(activity.createdAt),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
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

class _ActivityAvatar extends StatelessWidget {
  const _ActivityAvatar({required this.activity});

  final SpaceActivity activity;

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor(activity.type);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withOpacity(0.12),
          backgroundImage: activity.actorPhotoUrl != null
              ? NetworkImage(activity.actorPhotoUrl!)
              : null,
          child: activity.actorPhotoUrl == null
              ? Text(
                  _initials(activity.actorName),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                )
              : null,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0D1B3E), width: 2),
            ),
            child: Icon(activity.type.icon, size: 11, color: Colors.white),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _badgeColor(ActivityType type) => switch (type) {
        ActivityType.eventCreated => const Color(0xFF2E7D32),
        ActivityType.eventUpdated => const Color(0xFF1565C0),
        ActivityType.eventDeleted => const Color(0xFFC62828),
        ActivityType.memberJoined => const Color(0xFF00ACC1),
        ActivityType.memberRemoved => const Color(0xFFE65100),
        ActivityType.commentAdded => const Color(0xFF6A1B9A),
      };
}
