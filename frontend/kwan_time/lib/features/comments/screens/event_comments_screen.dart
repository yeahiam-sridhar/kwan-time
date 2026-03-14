// Screen for browsing and posting event comments.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/comment_providers.dart';
import '../widgets/comment_input_bar.dart';
import '../widgets/comment_tile.dart';

class EventCommentsScreen extends ConsumerWidget {
  final String spaceId;
  final String eventId;

  const EventCommentsScreen({
    super.key,
    required this.spaceId,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(
      commentsStreamProvider(CommentQuery(spaceId, eventId)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: commentsAsync.when(
              data: (comments) {
                if (comments.isEmpty) {
                  return const Center(
                    child: Text('No comments yet'),
                  );
                }

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];

                    return CommentTile(
                      comment: comment,
                      onDelete: null,
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => const Center(
                child: Text('Could not load comments'),
              ),
            ),
          ),
          CommentInputBar(
            spaceId: spaceId,
            eventId: eventId,
          ),
        ],
      ),
    );
  }
}
