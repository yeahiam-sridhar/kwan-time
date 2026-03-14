import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/space_event_model.dart';
import '../models/space_model.dart';
import '../services/event_service.dart';
import '../services/invite_service.dart';
import '../services/role_permission_service.dart';
import '../services/space_service.dart';

// Services
final spaceServiceProvider = Provider((ref) => SpaceService());
final eventServiceProvider = Provider((ref) => EventService());
final inviteServiceProvider = Provider((ref) => InviteService());

// Currently selected space
final selectedSpaceProvider = StateProvider<SpaceModel?>((ref) => null);

// Stream of current user's spaces
final spaceListProvider = StreamProvider<List<SpaceModel>>((ref) {
  return ref.watch(spaceServiceProvider).streamUserSpaces();
});

// Current user's role in a given space
final spaceRoleProvider = Provider.family<SpaceRole, String>((ref, spaceId) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return SpaceRole.none;
  final spaces = ref.watch(spaceListProvider).valueOrNull ?? [];
  final space =
      spaces.firstWhere((s) => s.id == spaceId, orElse: SpaceModel.empty);
  return space.roleOfOrNone(uid);
});

// Events for a given space (real-time stream)
final spaceEventsProvider =
    StreamProvider.family<List<SpaceEvent>, String>((ref, spaceId) {
  return ref.watch(eventServiceProvider).streamEvents(spaceId);
});

// Events on a specific date within a space
final eventsOnDateProvider =
    Provider.family<List<SpaceEvent>, ({String spaceId, DateTime date})>(
  (ref, args) {
    final events = ref.watch(spaceEventsProvider(args.spaceId)).valueOrNull ?? [];
    return events
        .where((e) =>
            e.startTime.year == args.date.year &&
            e.startTime.month == args.date.month &&
            e.startTime.day == args.date.day)
        .toList();
  },
);
