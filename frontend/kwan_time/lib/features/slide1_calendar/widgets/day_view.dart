import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/event.dart';
import '../../../core/providers/event_provider.dart';
import '../../../core/theme/kwan_theme.dart';
import 'event_card.dart';
import 'event_detail_sheet.dart';
import 'quick_add_sheet.dart';

class DayView extends ConsumerStatefulWidget {
  const DayView({super.key});

  @override
  ConsumerState<DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<DayView> {
  static const _hourHeight = 80.0;
  static const _timelineHeight = 24 * _hourHeight;

  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final dayEventsAsync = ref.watch(eventsForDayProvider(selectedDay));
    final eventCount = dayEventsAsync.valueOrNull?.length ?? 0;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 300) {
          ref.read(selectedDayProvider.notifier).state = selectedDay.subtract(const Duration(days: 1));
        } else if (velocity < -300) {
          ref.read(selectedDayProvider.notifier).state = selectedDay.add(const Duration(days: 1));
        }
      },
      child: Column(
        children: [
          _buildHeader(selectedDay, eventCount),
          Expanded(
            child: dayEventsAsync.when(
              data: (events) => _buildTimeline(context, selectedDay, events),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  '$error',
                  style: KwanText.bodyMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(DateTime selectedDay, int eventCount) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                ref.read(selectedDayProvider.notifier).state = selectedDay.subtract(const Duration(days: 1));
              },
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                DateFormat('EEEE, d MMMM').format(selectedDay),
                style: KwanText.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            GlassChipCount(value: eventCount),
            IconButton(
              onPressed: () {
                ref.read(selectedDayProvider.notifier).state = selectedDay.add(const Duration(days: 1));
              },
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );

  Widget _buildTimeline(BuildContext context, DateTime day, List<Event> events) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final localY = details.localPosition.dy + _scrollController.offset;
          final minutes = max(0, min((localY / _hourHeight * 60).round(), 1439));
          final initialTime = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
          _openQuickAdd(context, day, initialTime);
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          child: SizedBox(
            height: _timelineHeight,
            child: Stack(
              children: [
                _buildWorkingHoursTint(),
                _buildTimeGrid(),
                _buildCurrentTimeLine(day),
                ..._buildEventBlocks(context, events),
              ],
            ),
          ),
        ),
      );

  Widget _buildWorkingHoursTint() {
    const top = 9 * _hourHeight;
    const height = 9 * _hourHeight;
    return Positioned(
      top: top,
      left: 50,
      right: 0,
      height: height,
      child: Container(
        color: Colors.white.withValues(alpha: 0.03),
      ),
    );
  }

  Widget _buildTimeGrid() => Column(
        children: List.generate(
            24,
            (hour) => SizedBox(
                  height: _hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 50,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2, right: 6),
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            textAlign: TextAlign.right,
                            style: KwanText.label,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(
                          color: KwanColors.bgDivider,
                          height: _hourHeight,
                        ),
                      ),
                    ],
                  ),
                )),
      );

  Widget _buildCurrentTimeLine(DateTime day) {
    if (!DateUtils.isSameDay(day, DateTime.now())) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    final top = (minutes / 60) * _hourHeight;

    return Positioned(
      top: top,
      left: 50,
      right: 8,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 1.5,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              DateFormat('HH:mm').format(now),
              style: KwanText.bodySmall.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEventBlocks(BuildContext context, List<Event> events) => events.map((event) {
        final top = _minutesFromMidnight(event.startTime) / 60 * _hourHeight;
        final height = max(event.duration.inMinutes / 60 * _hourHeight, 40);
        return Positioned(
          top: top,
          left: 58,
          right: 8,
          height: height.toDouble(),
          child: EventCard(
            event: event,
            onTap: () => _openEventDetail(context, event),
          ),
        );
      }).toList();

  int _minutesFromMidnight(DateTime dateTime) => dateTime.hour * 60 + dateTime.minute;

  void _scrollToNow() {
    if (!mounted) {
      return;
    }
    final now = DateTime.now();
    final target = max<double>(0.0, (now.hour - 2) * _hourHeight);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _openQuickAdd(BuildContext context, DateTime day, TimeOfDay time) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickAddSheet(
        initialDate: day,
        initialTime: time,
      ),
    );
  }

  Future<void> _openEventDetail(BuildContext context, Event event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventDetailSheet(event: event),
    );
  }
}

class GlassChipCount extends StatelessWidget {
  const GlassChipCount({required this.value, super.key});

  final int value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: KwanColors.bgCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: KwanColors.bgCardBorder),
        ),
        child: Text(
          '$value',
          style: KwanText.bodySmall,
        ),
      );
}
