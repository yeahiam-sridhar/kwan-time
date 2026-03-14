import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_event.dart';
import 'sync_providers.dart';

final eventStreamProvider =
    StreamProvider.family<List<SyncEvent>, String>((Ref ref, String spaceId) {
  final svc = ref.read(eventSyncServiceProvider);
  final FirebaseFirestore db = FirebaseFirestore.instance;

  return db
      .collection('spaces')
      .doc(spaceId)
      .collection('events')
      .where('isDeleted', isEqualTo: false)
      .orderBy('startTime')
      .snapshots()
      .asyncMap((QuerySnapshot<Map<String, dynamic>> snapshot) async {
    for (final DocumentChange<Map<String, dynamic>> change
        in snapshot.docChanges) {
      switch (change.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          await svc.reconcileSingleEvent(SyncEvent.fromFirestore(change.doc));
          break;
        case DocumentChangeType.removed:
          await svc.handleRemoteDelete(change.doc.id);
          break;
      }
    }

    return svc.loadCachedEventsForSpace(spaceId);
  });
});

final eventsOnDateProvider =
    Provider.family<List<SyncEvent>, ({String spaceId, DateTime date})>(
  (Ref ref, ({String spaceId, DateTime date}) args) {
    final AsyncValue<List<SyncEvent>> events = ref.watch(
      eventStreamProvider(args.spaceId),
    );
    return events.valueOrNull?.where((SyncEvent e) {
          return e.startTime.year == args.date.year &&
              e.startTime.month == args.date.month &&
              e.startTime.day == args.date.day &&
              !e.isDeleted;
        }).toList() ??
        <SyncEvent>[];
  },
);

final eventsInRangeProvider = Provider.family<List<SyncEvent>,
    ({String spaceId, DateTime from, DateTime to})>(
  (Ref ref, ({String spaceId, DateTime from, DateTime to}) args) {
    final AsyncValue<List<SyncEvent>> events = ref.watch(
      eventStreamProvider(args.spaceId),
    );
    return events.valueOrNull?.where((SyncEvent e) {
          return e.startTime
                  .isAfter(args.from.subtract(const Duration(seconds: 1))) &&
              e.startTime.isBefore(args.to.add(const Duration(seconds: 1))) &&
              !e.isDeleted;
        }).toList() ??
        <SyncEvent>[];
  },
);
