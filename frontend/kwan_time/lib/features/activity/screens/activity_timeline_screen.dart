// Screen that renders activity timeline for a space.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/activity_providers.dart';
import '../widgets/activity_tile.dart';

class ActivityTimelineScreen extends ConsumerWidget {
  final String spaceId;

  const ActivityTimelineScreen({
    super.key,
    required this.spaceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityStreamProvider(spaceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
      ),
      body: activityAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(
              child: Text('No activity yet'),
            );
          }

          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];

              return ActivityTile(event: event);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, _) => const Center(
          child: Text('Could not load activity'),
        ),
      ),
    );
  }
}
