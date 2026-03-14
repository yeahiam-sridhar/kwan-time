import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../constants/sound_keys.dart';
import '../database/dao/event_dao.dart';
import '../database/dao/summary_dao.dart';
import '../models/event.dart';
import '../models/monthly_summary.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';

final eventDaoProvider = Provider<EventDao>((ref) => EventDao());
final summaryDaoProvider = Provider<SummaryDao>((ref) => SummaryDao());

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

final eventsForMonthProvider =
    FutureProvider.family<List<Event>, DateTime>((ref, month) async {
  final dao = ref.watch(eventDaoProvider);
  return dao.getForMonth(month);
});

final eventsForDayProvider =
    FutureProvider.family<List<Event>, DateTime>((ref, day) async {
  final dao = ref.watch(eventDaoProvider);
  return dao.getForDay(day);
});

final eventsForDateRangeProvider =
    FutureProvider.family<List<Event>, ({DateTime from, DateTime to})>(
  (ref, range) async {
    final dao = ref.watch(eventDaoProvider);
    return dao.getForDateRange(range.from, range.to);
  },
);

class EventsNotifier extends StateNotifier<AsyncValue<List<Event>>> {
  EventsNotifier(this._ref) : super(const AsyncValue.loading());

  final Ref _ref;
  final Uuid _uuid = const Uuid();

  EventDao get _eventDao => _ref.read(eventDaoProvider);
  SummaryDao get _summaryDao => _ref.read(summaryDaoProvider);

  Future<void> loadForMonth(DateTime month) async {
    state = const AsyncValue.loading();
    try {
      final events = await _eventDao.getForMonth(month);
      state = AsyncValue.data(events);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Event> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String eventType = 'in_person',
    String status = 'not_started',
    String? location,
    String? notes,
    List<int> reminderMinutes = const [],
    String? soundKey,
    bool isRecurring = false,
    String? recurrenceRule,
  }) async {
    final now = DateTime.now();
    final event = Event(
      id: _uuid.v4(),
      title: title,
      eventType: eventType,
      status: status,
      location: location,
      notes: notes,
      startTime: startTime,
      endTime: endTime,
      isRecurring: isRecurring,
      recurrenceRule: recurrenceRule,
      reminderMinutes: jsonEncode(reminderMinutes),
      soundKey: soundKey ?? SoundKeys.reminderChime,
      colorOverride: null,
      createdAt: now,
      updatedAt: now,
    );

    await _eventDao.insert(event).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception('DB timeout'),
        );

    _ref.invalidate(eventsForMonthProvider);
    _ref.invalidate(eventsForDayProvider);
    _ref.invalidate(eventsForDateRangeProvider);
    unawaited(_scheduleNotifications(event, reminderMinutes));
    unawaited(SoundService.instance.play(SoundKeys.eventCreate));
    unawaited(_invalidateSummaryCache(startTime));

    return event;
  }

  Future<void> _scheduleNotifications(Event event, List<int> minutes) async {
    try {
      for (final mins in minutes) {
        await NotificationService.instance.scheduleEventReminder(event, mins);
      }
      await NotificationService.instance.scheduleEventStart(event);
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
    }
  }

  Future<void> _invalidateSummaryCache(DateTime month) async {
    try {
      await _summaryDao.invalidate(_monthKey(month));
    } catch (e) {
      debugPrint('Cache invalidation failed: $e');
    }
  }

  Future<void> updateEvent(Event event) async {
    final previous = await _eventDao.getById(event.id);
    final updated = event.copyWith(updatedAt: DateTime.now());
    final current = state.valueOrNull ?? <Event>[];

    state = AsyncValue.data(
      <Event>[
        for (final existing in current)
          if (existing.id == updated.id) updated else existing,
      ],
    );

    try {
      final updatedCount = await _eventDao.update(updated);
      debugPrint(
          '[EventProvider] update result: $updatedCount for id: ${updated.id}');
      if (updatedCount == 0) {
        throw StateError('No rows updated for id=${updated.id}');
      }

      try {
        await NotificationService.instance.cancelEventReminders(updated.id);
        for (final mins in updated.reminderList) {
          await NotificationService.instance
              .scheduleEventReminder(updated, mins);
        }
        await NotificationService.instance.scheduleEventStart(updated);
      } catch (_) {}

      await _summaryDao.invalidate(_monthKey(updated.startTime));
      if (previous != null) {
        await _summaryDao.invalidate(_monthKey(previous.startTime));
      }

      _ref.invalidate(eventsForMonthProvider);
      _ref.invalidate(eventsForDayProvider);
      _ref.invalidate(eventsForDateRangeProvider);
    } catch (e) {
      debugPrint('[EventProvider] UPDATE FAILED: $e');
      await loadForMonth(_ref.read(selectedMonthProvider));
      rethrow;
    }
  }

  Future<void> deleteEvent(String id) async {
    final existing = await _eventDao.getById(id);
    final current = state.valueOrNull ?? <Event>[];
    state = AsyncValue.data(
      current.where((event) => event.id != id).toList(growable: false),
    );

    try {
      final deletedCount = await _eventDao.delete(id);
      debugPrint('[EventProvider] delete result: $deletedCount for id: $id');
      if (deletedCount == 0) {
        throw StateError('No rows deleted for id=$id');
      }

      await NotificationService.instance.cancelEventReminders(id);
      if (existing != null) {
        await _summaryDao.invalidate(_monthKey(existing.startTime));
      }

      _ref.invalidate(eventsForMonthProvider);
      _ref.invalidate(eventsForDayProvider);
      _ref.invalidate(eventsForDateRangeProvider);
    } catch (e) {
      debugPrint('[EventProvider] DELETE FAILED: $e');
      await loadForMonth(_ref.read(selectedMonthProvider));
      rethrow;
    }
  }

  Future<void> updateStatus(String id, String status) async {
    final existing = await _eventDao.getById(id);
    if (existing == null) {
      return;
    }
    await updateEvent(existing.copyWith(status: status));
  }

  String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
}

final eventsNotifierProvider =
    StateNotifierProvider<EventsNotifier, AsyncValue<List<Event>>>(
  (ref) {
    final notifier = EventsNotifier(ref);
    notifier.loadForMonth(ref.read(selectedMonthProvider));
    return notifier;
  },
);

final summaryProvider =
    FutureProvider.family<List<MonthlySummary>, DateTime>((ref, start) async {
  final summaryDao = ref.watch(summaryDaoProvider);
  final monthKey =
      '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}';
  return summaryDao.getThreeMonths(monthKey);
});
