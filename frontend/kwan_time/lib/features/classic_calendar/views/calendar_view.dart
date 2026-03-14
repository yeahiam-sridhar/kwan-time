// ═══════════════════════════════════════════════════════════════════════════
// KWAN-TIME v2.0 — Calendar View (Main Container)
// Agent 6: Classic Calendar View
//
// Main calendar container with view mode selector (month/week/day).
// Coordinates state management and view rendering.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kwan_time/core/theme/kwan_theme.dart';
import '../providers/calendar_provider.dart';
import 'month_view.dart';
import 'week_view.dart';

/// Main calendar view with mode selector
class CalendarView extends ConsumerWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(calendarProvider);

    return Scaffold(
      backgroundColor: KwanTheme.darkBg,
      appBar: _buildAppBar(context, ref, calendarState),
      body: Column(
        children: [
          // View mode selector
          _buildViewModeSelector(context, ref, calendarState),

          // Content based on view mode
          Expanded(
            child: _buildContent(calendarState),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    CalendarState state,
  ) =>
      AppBar(
        title: Text(
          'Calendar',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: KwanTheme.darkCard,
        elevation: 0,
        actions: [
          // Today button
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: TextButton(
                onPressed: () {
                  ref.read(calendarProvider.notifier).goToToday();
                },
                child: Text(
                  'Today',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: KwanTheme.colorOnline,
                      ),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildViewModeSelector(
    BuildContext context,
    WidgetRef ref,
    CalendarState state,
  ) =>
      Container(
        color: KwanTheme.darkCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildViewModeButton(
              context,
              ref,
              mode: CalendarViewMode.month,
              label: 'Month',
              isSelected: state.viewMode == CalendarViewMode.month,
            ),
            const SizedBox(width: 12),
            _buildViewModeButton(
              context,
              ref,
              mode: CalendarViewMode.week,
              label: 'Week',
              isSelected: state.viewMode == CalendarViewMode.week,
            ),
            const SizedBox(width: 12),
            _buildViewModeButton(
              context,
              ref,
              mode: CalendarViewMode.day,
              label: 'Day',
              isSelected: state.viewMode == CalendarViewMode.day,
            ),
          ],
        ),
      );

  Widget _buildViewModeButton(
    BuildContext context,
    WidgetRef ref, {
    required CalendarViewMode mode,
    required String label,
    required bool isSelected,
  }) =>
      GestureDetector(
        onTap: () {
          ref.read(calendarProvider.notifier).setViewMode(mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? KwanTheme.colorOnline.withOpacity(0.2) : Colors.transparent,
            border: Border.all(
              color: isSelected ? KwanTheme.colorOnline : KwanTheme.divider,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isSelected ? KwanTheme.colorOnline : KwanTheme.textSecondary,
                ),
          ),
        ),
      );

  Widget _buildContent(CalendarState state) {
    switch (state.viewMode) {
      case CalendarViewMode.month:
        return const MonthView();
      case CalendarViewMode.week:
        return const WeekView();
      case CalendarViewMode.day:
        return _buildDayViewPlaceholder();
    }
  }

  Widget _buildDayViewPlaceholder() => Center(
        child: Text(
          'Day View — Coming Soon',
          style: Theme.of(BuildContext as dynamic).textTheme.bodyMedium,
        ),
      );
}
