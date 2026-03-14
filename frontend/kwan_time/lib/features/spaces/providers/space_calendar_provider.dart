import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/services/festival_service.dart';
import '../models/space_event_model.dart';

// ── Selected space provider ───────────────────────────────────────────────
final selectedSpaceIdProvider = StateProvider<String?>((ref) => null);

// ── Selected date in space calendar ──────────────────────────────────────
final spaceSelectedDateProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

// ── Space events stream for selected space ────────────────────────────────
final spaceCalendarEventsProvider =
    StreamProvider.autoDispose.family<List<SpaceEvent>, String>(
  (ref, spaceId) {
    if (spaceId.isEmpty) {
      return Stream<List<SpaceEvent>>.value(const []);
    }
    return FirebaseFirestore.instance
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .orderBy('startTime')
        .snapshots()
        .map((snap) => snap.docs.map(SpaceEvent.fromFirestore).toList());
  },
);

// ── Events for a specific date in a space ────────────────────────────────
final spaceEventsForDateProvider = Provider.autoDispose
    .family<List<SpaceEvent>, ({String spaceId, DateTime date})>((ref, args) {
  final eventsAsync = ref.watch(spaceCalendarEventsProvider(args.spaceId));
  return eventsAsync.valueOrNull
          ?.where(
            (e) =>
                e.startTime.year == args.date.year &&
                e.startTime.month == args.date.month &&
                e.startTime.day == args.date.day,
          )
          .toList() ??
      [];
});

// ── Dates that have events (for dot markers) ──────────────────────────────
final spaceDatesWithEventsProvider =
    Provider.autoDispose.family<Set<DateTime>, String>((ref, spaceId) {
  final eventsAsync = ref.watch(spaceCalendarEventsProvider(spaceId));
  return eventsAsync.valueOrNull
          ?.map(
            (e) => DateTime(e.startTime.year, e.startTime.month, e.startTime.day),
          )
          .toSet() ??
      {};
});

// ── Festival provider ─────────────────────────────────────────────────────
final festivalProvider = Provider.family<String?, DateTime>((ref, date) {
  return FestivalService.instance.festivalFor(date);
});

// ── Month festivals map ───────────────────────────────────────────────────
final monthFestivalsProvider =
    Provider.family<Map<DateTime, String>, ({int year, int month})>(
  (ref, args) {
    return FestivalService.instance.festivalsForMonth(args.year, args.month);
  },
);
