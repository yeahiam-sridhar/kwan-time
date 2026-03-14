// ═══════════════════════════════════════════════════════════════════════════
// KWAN-TIME v2.0 — Calendar State Management (Simplified - No Freezed)
// Agent 6: Classic Calendar View
//
// Manages calendar state, event data, view modes, and selected dates.
// Note: This is a simplified version without Freezed code generation
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Calendar view modes
enum CalendarViewMode {
  month,
  week,
  day,
}

/// Calendar state (simplified implementation)
class CalendarState {
  const CalendarState({
    required this.events,
    required this.selectedDate,
    required this.viewMode,
    required this.monthStart,
    required this.isLoading,
    required this.error,
    required this.eventCountPerDay,
  });
  final List<dynamic> events;
  final DateTime selectedDate;
  final CalendarViewMode viewMode;
  final DateTime monthStart;
  final bool isLoading;
  final String? error;
  final Map<DateTime, int> eventCountPerDay;

  /// Get events for a specific day
  List<dynamic> getEventsForDay(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return events.where((e) => e is Map && e['date'] == dateOnly).toList();
  }

  /// Get events for a specific week
  List<dynamic> getEventsForWeek(DateTime weekStart) {
    // TODO: Implement week-based filtering
    return events.whereType<Map>().toList();
  }

  /// Get events for a specific month
  List<dynamic> getEventsForMonth(DateTime monthDate) => events.whereType<Map>().toList();

  DateTime getNextMonth() => DateTime(monthStart.year, monthStart.month + 1, 1);

  DateTime getPreviousMonth() => DateTime(monthStart.year, monthStart.month - 1, 1);

  /// Create a copy with updated fields
  CalendarState copyWith({
    List<dynamic>? events,
    DateTime? selectedDate,
    CalendarViewMode? viewMode,
    DateTime? monthStart,
    bool? isLoading,
    String? error,
    Map<DateTime, int>? eventCountPerDay,
  }) =>
      CalendarState(
        events: events ?? this.events,
        selectedDate: selectedDate ?? this.selectedDate,
        viewMode: viewMode ?? this.viewMode,
        monthStart: monthStart ?? this.monthStart,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        eventCountPerDay: eventCountPerDay ?? this.eventCountPerDay,
      );
}

/// Calendar provider
final calendarProvider = StateNotifierProvider<CalendarNotifier, CalendarState>((ref) => CalendarNotifier());

/// Calendar state notifier
class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier()
      : super(
          CalendarState(
            events: [],
            selectedDate: DateTime.now(),
            viewMode: CalendarViewMode.month,
            monthStart: DateTime(DateTime.now().year, DateTime.now().month, 1),
            isLoading: false,
            error: null,
            eventCountPerDay: {},
          ),
        ) {
    loadEvents();
  }

  /// Load events
  Future<void> loadEvents() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO: Implement API call to fetch events
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Add event optimistically
  void optimisticAddEvent(dynamic event) {
    final newEvents = [...state.events, event];
    state = state.copyWith(events: newEvents);
  }

  /// Update event optimistically
  void optimisticUpdateEvent(String eventId, dynamic updatedEvent) {
    final newEvents = [...state.events];
    state = state.copyWith(events: newEvents);
  }

  /// Delete event
  void optimisticDeleteEvent(String eventId) {
    final newEvents = state.events.toList();
    state = state.copyWith(events: newEvents);
  }

  /// Handle event created
  void handleEventCreated(dynamic event) {
    final newEvents = [...state.events, event];
    state = state.copyWith(events: newEvents);
  }

  /// Handle event updated
  void handleEventUpdated(dynamic updatedEvent) {
    final newEvents = [...state.events];
    state = state.copyWith(events: newEvents);
  }

  /// Handle event deleted
  void handleEventDeleted(String eventId) {
    optimisticDeleteEvent(eventId);
  }

  /// Revert optimistic update
  void revertOptimisticUpdate(dynamic originalEvent) {
    final newEvents = [...state.events];
    state = state.copyWith(events: newEvents);
  }

  /// Change view mode
  void setViewMode(CalendarViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  /// Select date
  void selectDate(DateTime date) {
    state = state.copyWith(
      selectedDate: date,
      monthStart: DateTime(date.year, date.month, 1),
    );
  }

  /// Navigate to next month
  void nextMonth() {
    final nextMonth = state.getNextMonth();
    state = state.copyWith(monthStart: nextMonth);
  }

  /// Navigate to previous month
  void previousMonth() {
    final prevMonth = state.getPreviousMonth();
    state = state.copyWith(monthStart: prevMonth);
  }

  /// Jump to today
  void goToToday() {
    final today = DateTime.now();
    state = state.copyWith(
      selectedDate: today,
      monthStart: DateTime(today.year, today.month, 1),
    );
  }
}

final monthEventsProvider = Provider<List<dynamic>>((ref) {
  final state = ref.watch(calendarProvider);
  return state.getEventsForMonth(state.monthStart);
});

final selectedDayEventsProvider = Provider<List<dynamic>>((ref) {
  final state = ref.watch(calendarProvider);
  return state.getEventsForDay(state.selectedDate);
});

final weekEventsProvider = Provider<List<dynamic>>((ref) {
  final state = ref.watch(calendarProvider);
  return state.getEventsForWeek(state.monthStart);
});
