import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/space_event_model.dart';
import '../services/space_event_service.dart';

final spaceEventServiceProvider = Provider<SpaceEventService>(
  (ref) => SpaceEventService(),
);

final spaceEventsStreamProvider =
    StreamProvider.family<List<SpaceEvent>, String>((ref, spaceId) {
  return ref.watch(spaceEventServiceProvider).streamEvents(spaceId);
});

final spaceEventsOnDateProvider = StreamProvider.family<List<SpaceEvent>,
    ({String spaceId, DateTime date})>((ref, args) {
  return ref
      .watch(spaceEventServiceProvider)
      .streamEventsOnDate(args.spaceId, args.date);
});

final isSpaceEventLoadingProvider = StateProvider<bool>((ref) => false);

final spaceEventErrorProvider = StateProvider<String?>((ref) => null);
