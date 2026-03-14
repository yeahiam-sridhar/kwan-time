import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kwan_time/core/models/event.dart';

// ============================================================================
// Model Classes
// ============================================================================

/// Daily occupancy metrics
class DailyOccupancy {
  DailyOccupancy({
    required this.date,
    required this.dayLabel,
    required this.occupancy,
    required this.eventCount,
    required this.totalDuration,
  });
  final DateTime date;
  final String dayLabel;
  final double occupancy;
  final int eventCount;
  final Duration totalDuration;

  DailyOccupancy copyWith({
    DateTime? date,
    String? dayLabel,
    double? occupancy,
    int? eventCount,
    Duration? totalDuration,
  }) =>
      DailyOccupancy(
        date: date ?? this.date,
        dayLabel: dayLabel ?? this.dayLabel,
        occupancy: occupancy ?? this.occupancy,
        eventCount: eventCount ?? this.eventCount,
        totalDuration: totalDuration ?? this.totalDuration,
      );
}

/// Available time slot
class TimeSlotAvailability {
  TimeSlotAvailability({
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.slot,
  });
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final int slot;

  TimeSlotAvailability copyWith({
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    int? slot,
  }) =>
      TimeSlotAvailability(
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        duration: duration ?? this.duration,
        slot: slot ?? this.slot,
      );
}

/// Dashboard metrics
class DashboardMetrics {
  DashboardMetrics({
    required this.totalEvents,
    required this.eventsThisWeek,
    required this.eventsDayAfterTomorrow,
    required this.avgEventsPerDay,
    required this.avgEventDuration,
    required this.occupancyRate,
    required this.weeklyOccupancy,
    required this.availableSlots,
  });
  final int totalEvents;
  final int eventsThisWeek;
  final int eventsDayAfterTomorrow;
  final double avgEventsPerDay;
  final Duration avgEventDuration;
  final double occupancyRate;
  final List<DailyOccupancy> weeklyOccupancy;
  final List<TimeSlotAvailability> availableSlots;

  DashboardMetrics copyWith({
    int? totalEvents,
    int? eventsThisWeek,
    int? eventsDayAfterTomorrow,
    double? avgEventsPerDay,
    Duration? avgEventDuration,
    double? occupancyRate,
    List<DailyOccupancy>? weeklyOccupancy,
    List<TimeSlotAvailability>? availableSlots,
  }) =>
      DashboardMetrics(
        totalEvents: totalEvents ?? this.totalEvents,
        eventsThisWeek: eventsThisWeek ?? this.eventsThisWeek,
        eventsDayAfterTomorrow: eventsDayAfterTomorrow ?? this.eventsDayAfterTomorrow,
        avgEventsPerDay: avgEventsPerDay ?? this.avgEventsPerDay,
        avgEventDuration: avgEventDuration ?? this.avgEventDuration,
        occupancyRate: occupancyRate ?? this.occupancyRate,
        weeklyOccupancy: weeklyOccupancy ?? this.weeklyOccupancy,
        availableSlots: availableSlots ?? this.availableSlots,
      );
}

/// Dashboard state
class DashboardState {
  DashboardState({
    required this.metrics,
    required this.isLoading,
    required this.startDate,
    required this.endDate,
    this.error,
  });
  final DashboardMetrics metrics;
  final bool isLoading;
  final String? error;
  final DateTime startDate;
  final DateTime endDate;

  DashboardState copyWith({
    DashboardMetrics? metrics,
    bool? isLoading,
    String? error,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      DashboardState(
        metrics: metrics ?? this.metrics,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
      );
}

// ============================================================================
// Dashboard Notifier
// ============================================================================

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier()
      : super(
          DashboardState(
            metrics: DashboardMetrics(
              totalEvents: 0,
              eventsThisWeek: 0,
              eventsDayAfterTomorrow: 0,
              avgEventsPerDay: 0,
              avgEventDuration: Duration.zero,
              occupancyRate: 0,
              weeklyOccupancy: [],
              availableSlots: [],
            ),
            isLoading: true,
            error: null,
            startDate: DateTime.now(),
            endDate: DateTime.now().add(const Duration(days: 30)),
          ),
        ) {
    _initialize();
  }

  void _initialize() {
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // TODO: Get calendar data
      // For now, use empty events list
      final events = <Event>[];

      final metrics = _calculateMetrics(
        events: events,
        startDate: state.startDate,
        endDate: state.endDate,
      );

      state = state.copyWith(
        metrics: metrics,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  DashboardMetrics _calculateMetrics({
    required List<Event> events,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final dayAfterTomorrow = now.add(const Duration(days: 2));

    final totalEvents = events.length;

    final eventsThisWeek = events.where((e) => e.startTime.isAfter(weekStart) && e.startTime.isBefore(weekEnd)).length;

    final eventsDayAfterTomorrow = events.where((e) {
      final eDate = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      final targetDate = DateTime(dayAfterTomorrow.year, dayAfterTomorrow.month, dayAfterTomorrow.day);
      return eDate == targetDate;
    }).length;

    final daysCount = endDate.difference(startDate).inDays.toDouble();
    final avgEventsPerDay = totalEvents / (daysCount > 0 ? daysCount : 1);

    var totalDuration = Duration.zero;
    for (final event in events) {
      totalDuration += event.endTime.difference(event.startTime);
    }
    final avgEventDuration = totalEvents > 0
        ? Duration(
            minutes: (totalDuration.inMinutes / totalEvents).round(),
          )
        : Duration.zero;

    final weeklyOccupancy = _calculateWeeklyOccupancy(events, now);

    final avgOccupancy = weeklyOccupancy.isEmpty
        ? 0.0
        : weeklyOccupancy.fold<double>(
              0,
              (sum, day) => sum + day.occupancy,
            ) /
            weeklyOccupancy.length;

    final availableSlots = _findAvailableSlots(events, now);

    return DashboardMetrics(
      totalEvents: totalEvents,
      eventsThisWeek: eventsThisWeek,
      eventsDayAfterTomorrow: eventsDayAfterTomorrow,
      avgEventsPerDay: avgEventsPerDay,
      avgEventDuration: avgEventDuration,
      occupancyRate: avgOccupancy,
      weeklyOccupancy: weeklyOccupancy,
      availableSlots: availableSlots,
    );
  }

  List<DailyOccupancy> _calculateWeeklyOccupancy(List<Event> events, DateTime now) {
    final result = <DailyOccupancy>[];
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (var i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);

      final dayEvents = events.where((e) {
        final eDate = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
        return eDate == dateOnly;
      }).toList();

      var totalDuration = Duration.zero;
      for (final event in dayEvents) {
        totalDuration += event.endTime.difference(event.startTime);
      }

      const wakingHours = 16;
      const wakingMinutes = wakingHours * 60;
      final occupancy = (totalDuration.inMinutes / wakingMinutes).clamp(0.0, 1.0);

      result.add(
        DailyOccupancy(
          date: dateOnly,
          dayLabel: dayLabels[i % 7],
          occupancy: occupancy,
          eventCount: dayEvents.length,
          totalDuration: totalDuration,
        ),
      );
    }

    return result;
  }

  List<TimeSlotAvailability> _findAvailableSlots(List<Event> events, DateTime now) {
    final availableSlots = <TimeSlotAvailability>[];

    for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
      final dayStart = DateTime(
        now.year,
        now.month,
        now.day,
        8,
      ).add(Duration(days: dayOffset));

      final dayEnd = dayStart.add(const Duration(hours: 16));

      final dayEvents = events.where((e) {
        final eDate = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
        final searchDate = DateTime(dayStart.year, dayStart.month, dayStart.day);
        return eDate == searchDate;
      }).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      var currentTime = dayStart;
      var slotIndex = 0;

      while (currentTime.isBefore(dayEnd)) {
        final slotEnd = currentTime.add(const Duration(minutes: 30));

        final isOccupied =
            dayEvents.any((event) => event.startTime.isBefore(slotEnd) && event.endTime.isAfter(currentTime));

        if (!isOccupied && currentTime.isAfter(now.subtract(const Duration(minutes: 15)))) {
          availableSlots.add(
            TimeSlotAvailability(
              startTime: currentTime,
              endTime: slotEnd,
              duration: const Duration(minutes: 30),
              slot: slotIndex,
            ),
          );
        }

        currentTime = slotEnd;
        slotIndex++;
      }
    }

    return availableSlots.take(10).toList();
  }

  void setDateRange(DateTime startDate, DateTime endDate) {
    state = state.copyWith(startDate: startDate, endDate: endDate);
    _loadMetrics();
  }

  void nextWeek() {
    final newStart = state.startDate.add(const Duration(days: 7));
    final newEnd = state.endDate.add(const Duration(days: 7));
    setDateRange(newStart, newEnd);
  }

  void previousWeek() {
    final newStart = state.startDate.subtract(const Duration(days: 7));
    final newEnd = state.endDate.subtract(const Duration(days: 7));
    setDateRange(newStart, newEnd);
  }

  void goToToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 30));
    setDateRange(start, end);
  }

  Future<void> refresh() async {
    await _loadMetrics();
  }
}

// ============================================================================
// Providers
// ============================================================================

final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) => DashboardNotifier());

final metricsProvider = Provider<DashboardMetrics>((ref) => ref.watch(dashboardNotifierProvider).metrics);

final weeklyOccupancyProvider = Provider<List<DailyOccupancy>>((ref) => ref.watch(metricsProvider).weeklyOccupancy);

final availableSlotsProvider = Provider<List<TimeSlotAvailability>>((ref) => ref.watch(metricsProvider).availableSlots);

final dashboardLoadingProvider = Provider<bool>((ref) => ref.watch(dashboardNotifierProvider).isLoading);

final dashboardErrorProvider = Provider<String?>((ref) => ref.watch(dashboardNotifierProvider).error);
