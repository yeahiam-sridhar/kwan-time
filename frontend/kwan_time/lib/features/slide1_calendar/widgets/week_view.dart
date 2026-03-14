import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/event.dart';
import '../../../core/providers/event_provider.dart';
import '../../../core/theme/kwan_theme.dart';
import 'event_card.dart';
import 'event_detail_sheet.dart';

class WeekView extends ConsumerStatefulWidget {
  const WeekView({
    super.key,
    this.onDaySelected,
  });

  final ValueChanged<DateTime>? onDaySelected;

  @override
  ConsumerState<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<WeekView> {
  final ScrollController _scrollController = ScrollController();
  DateTime? _weekStart;
  Timer? _clockTimer;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    final selected = DateTime.now();
    _weekStart = _mondayOf(selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(8 * 60);
      }
    });
    _clockTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final selectedWeek = _mondayOf(selectedDay);
    _weekStart ??= selectedWeek;
    if (!_isSameDay(_weekStart!, selectedWeek)) {
      _weekStart = selectedWeek;
    }

    final start = _weekStart!;
    final end = start.add(const Duration(days: 7));
    final weekEventsAsync = ref.watch(
      eventsForDateRangeProvider((from: start, to: end)),
    );

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 300) {
          _changeWeek(-1);
        } else if (velocity < -300) {
          _changeWeek(1);
        }
      },
      child: AnimatedSwitcher(
        duration: 280.ms,
        transitionBuilder: (child, animation) {
          final begin = Offset(_direction > 0 ? 1 : -1, 0);
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInOutQuint),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Column(
          key: ValueKey('${start.year}-${start.month}-${start.day}'),
          children: [
            _buildWeekHeader(selectedDay),
            Expanded(
              child: weekEventsAsync.when(
                data: _buildGrid,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('$error', style: KwanText.bodySmall),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekHeader(DateTime selectedDay) {
    final days = List.generate(
      7,
      (index) => _weekStart!.add(Duration(days: index)),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Row(
        children: [
          const SizedBox(width: 50),
          ...days.map((day) {
            final isToday = _isSameDay(day, DateTime.now());
            return Expanded(
              child: InkWell(
                onTap: () {
                  ref.read(selectedDayProvider.notifier).state = day;
                  widget.onDaySelected?.call(day);
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('EEE').format(day),
                        style: KwanText.label.copyWith(
                          color: isToday ? KwanColors.accent : KwanColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.day}',
                        style: KwanText.bodyMedium.copyWith(
                          color: isToday ? KwanColors.accent : KwanColors.textPrimary,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (isToday)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 18,
                          height: 2,
                          decoration: BoxDecoration(
                            color: KwanColors.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Event> events) => SingleChildScrollView(
        controller: _scrollController,
        child: SizedBox(
          height: 24 * 60.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimeColumn(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final dayWidth = width / 7;
                    return Stack(
                      children: [
                        _buildHourGrid(dayWidth),
                        _buildWorkingHoursHighlight(),
                        _buildCurrentTimeLine(dayWidth),
                        ..._buildEventBlocks(context, events, dayWidth),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildTimeColumn() => SizedBox(
        width: 50,
        child: Column(
          children: List.generate(
              24,
              (hour) => SizedBox(
                    height: 60,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, right: 6),
                      child: Text(
                        hour.toString().padLeft(2, '0'),
                        textAlign: TextAlign.right,
                        style: KwanText.label,
                      ),
                    ),
                  )),
        ),
      );

  Widget _buildHourGrid(double dayWidth) => Stack(
        children: [
          Column(
            children: List.generate(
                24,
                (_) => Container(
                      height: 60,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: KwanColors.bgDivider, width: 1),
                        ),
                      ),
                    )),
          ),
          ...List.generate(
              6,
              (index) => Positioned(
                    top: 0,
                    bottom: 0,
                    left: dayWidth * (index + 1),
                    child: Container(width: 1, color: KwanColors.bgDivider),
                  )),
        ],
      );

  Widget _buildWorkingHoursHighlight() => Positioned(
        top: 9 * 60,
        left: 0,
        right: 0,
        height: 9 * 60,
        child: Container(
          color: Colors.white.withValues(alpha: 0.02),
        ),
      );

  Widget _buildCurrentTimeLine(double dayWidth) {
    final now = DateTime.now();
    if (now.isBefore(_weekStart!) || !now.isBefore(_weekStart!.add(const Duration(days: 7)))) {
      return const SizedBox.shrink();
    }

    final top = (now.hour * 60 + now.minute).toDouble();
    final dayIndex = now.weekday - 1;
    final left = dayIndex * dayWidth;

    return Positioned(
      top: top,
      left: left,
      width: dayWidth,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 1.5,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEventBlocks(
    BuildContext context,
    List<Event> events,
    double dayWidth,
  ) {
    final byDay = <int, List<Event>>{};
    for (final event in events) {
      byDay.putIfAbsent(event.startTime.weekday - 1, () => <Event>[]).add(event);
    }

    final widgets = <Widget>[];
    for (final entry in byDay.entries) {
      final dayIndex = entry.key;
      final placed = _placeOverlaps(entry.value);
      for (final item in placed) {
        final top = _minutesOf(item.event.startTime).toDouble();
        final height = max(item.event.duration.inMinutes.toDouble(), 30);
        final leftBase = dayIndex * dayWidth;
        final blockWidth = dayWidth / item.columns;
        final left = leftBase + (item.column * blockWidth) + 2;
        final width = max(blockWidth - 4, 28);

        widgets.add(
          Positioned(
            top: top,
            left: left,
            width: width.toDouble(),
            height: height.toDouble(),
            child: LongPressDraggable<Event>(
              data: item.event,
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: width.toDouble(),
                  height: height.toDouble(),
                  child: Transform.rotate(
                    angle: 0.02,
                    child: Opacity(
                      opacity: 0.85,
                      child: EventCard(event: item.event, compact: true),
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.25,
                child: EventCard(
                  event: item.event,
                  compact: true,
                  onTap: () => _openEventDetail(context, item.event),
                ),
              ),
              child: EventCard(
                event: item.event,
                compact: true,
                onTap: () => _openEventDetail(context, item.event),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  List<_PlacedEvent> _placeOverlaps(List<Event> input) {
    final events = [...input]..sort((a, b) => a.startTime.compareTo(b.startTime));
    final active = <_PlacedEvent>[];
    final placed = <_PlacedEvent>[];

    for (final event in events) {
      active.removeWhere((item) => !item.event.endTime.isAfter(event.startTime));

      final usedColumns = active.map((e) => e.column).toSet();
      var col = 0;
      while (usedColumns.contains(col)) {
        col++;
      }

      final currentColumns = max(col + 1, active.length + 1);
      final placedEvent = _PlacedEvent(
        event: event,
        column: col,
        columns: currentColumns,
      );
      active.add(placedEvent);
      placed.add(placedEvent);

      for (var i = 0; i < placed.length; i++) {
        final item = placed[i];
        final overlaps = item.event.startTime.isBefore(event.endTime) && item.event.endTime.isAfter(event.startTime);
        if (overlaps) {
          placed[i] = item.copyWith(columns: max(item.columns, currentColumns));
        }
      }
    }
    return placed;
  }

  int _minutesOf(DateTime dt) => dt.hour * 60 + dt.minute;

  DateTime _mondayOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _changeWeek(int deltaWeeks) {
    final current = _weekStart!;
    final next = current.add(Duration(days: 7 * deltaWeeks));
    _direction = deltaWeeks > 0 ? 1 : -1;
    setState(() => _weekStart = next);
    ref.read(selectedDayProvider.notifier).state = next;
  }

  Future<void> _openEventDetail(BuildContext context, Event event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDetailSheet(event: event),
    );
  }
}

class _PlacedEvent {
  const _PlacedEvent({
    required this.event,
    required this.column,
    required this.columns,
  });

  final Event event;
  final int column;
  final int columns;

  _PlacedEvent copyWith({
    Event? event,
    int? column,
    int? columns,
  }) =>
      _PlacedEvent(
        event: event ?? this.event,
        column: column ?? this.column,
        columns: columns ?? this.columns,
      );
}
