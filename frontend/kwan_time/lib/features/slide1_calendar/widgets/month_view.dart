import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/event.dart';
import '../../../core/providers/event_provider.dart';
import '../../../models/system_event_model.dart';
import '../../../services/system_event_service.dart';
import '../../../theme/app_design_system.dart';
import 'quick_add_sheet.dart';

class MonthView extends ConsumerStatefulWidget {
  const MonthView({
    super.key,
    this.onDaySelected,
  });

  final ValueChanged<DateTime>? onDaySelected;

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  late int _viewYear;
  late int _viewMonth;
  late final ValueNotifier<DateTime> _selectedDateNotifier;

  Timer? _monthNavDebounce;
  _MonthCache? _monthCache;
  String _cacheToken = '';

  @override
  void initState() {
    super.initState();
    final initialMonth = ref.read(selectedMonthProvider);
    final today = DateTime.now();
    _viewYear = initialMonth.year;
    _viewMonth = initialMonth.month;
    _selectedDateNotifier = ValueNotifier<DateTime>(
      DateTime(today.year, today.month, today.day),
    );
  }

  @override
  void dispose() {
    _monthNavDebounce?.cancel();
    _selectedDateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime buildNow = DateTime.now();
    final DateTime monthKey = DateTime(_viewYear, _viewMonth, 1);
    final monthEventsAsync = ref.watch(eventsForMonthProvider(monthKey));

    return monthEventsAsync.when(
      loading: _CalendarLoadingState.new,
      error: (error, _) => _CalendarErrorState(
        message: error.toString(),
        onRetry: () {
          setState(() {
            _cacheToken = '';
          });
        },
      ),
      data: (events) {
        final systemEvents =
            SystemEventService().eventsForMonth(_viewYear, _viewMonth);
        final cache = _ensureCache(
          reminders: events,
          festivals: systemEvents,
        );

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: RepaintBoundary(
                key: const ValueKey('month_header'),
                child: _MonthHeader(
                  monthDate: DateTime(_viewYear, _viewMonth, 1),
                  onPrev: () {
                    HapticFeedback.lightImpact();
                    _navigateMonth(-1);
                  },
                  onNext: () {
                    HapticFeedback.lightImpact();
                    _navigateMonth(1);
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _WeekdayHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: RepaintBoundary(
                key: const ValueKey('calendar_grid'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity < -300) {
                        HapticFeedback.lightImpact();
                        _navigateMonth(1);
                      } else if (velocity > 300) {
                        HapticFeedback.lightImpact();
                        _navigateMonth(-1);
                      }
                    },
                    child: _MonthGrid(
                      cache: cache,
                      now: buildNow,
                      selectedDateListenable: _selectedDateNotifier,
                      onDayTap: _onDaySelected,
                      onDayLongPress: widget.onDaySelected,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: RepaintBoundary(
                key: const ValueKey('events_list'),
                child: ValueListenableBuilder<DateTime>(
                  valueListenable: _selectedDateNotifier,
                  builder: (context, selectedDate, _) {
                    final dayReminders =
                        cache.remindersByDay[selectedDate.day] ??
                            const <Event>[];
                    final dayFestivals =
                        cache.festivalsByDay[selectedDate.day] ??
                            const <SystemEventModel>[];

                    return _SelectedDayEventsPanel(
                      selectedDate: selectedDate,
                      reminders: dayReminders,
                      festivals: dayFestivals,
                      onReminderTap: (event) =>
                          _showReminderActions(context, event),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 96),
            ),
          ],
        );
      },
    );
  }

  void _onDaySelected(DateTime date) {
    _selectedDateNotifier.value = date;
    ref.read(selectedDayProvider.notifier).state = date;
  }

  void _navigateMonth(int direction) {
    _monthNavDebounce?.cancel();
    _monthNavDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) {
        return;
      }
      final nextMonth = DateTime(_viewYear, _viewMonth + direction, 1);
      final selected = _selectedDateNotifier.value;
      final maxDay = DateUtils.getDaysInMonth(nextMonth.year, nextMonth.month);
      final clampedDay = math.min(selected.day, maxDay);

      setState(() {
        _viewYear = nextMonth.year;
        _viewMonth = nextMonth.month;
        _cacheToken = '';
      });

      _selectedDateNotifier.value =
          DateTime(nextMonth.year, nextMonth.month, clampedDay);
      ref.read(selectedMonthProvider.notifier).state = nextMonth;
    });
  }

  _MonthCache _ensureCache({
    required List<Event> reminders,
    required List<SystemEventModel> festivals,
  }) {
    final token = _buildCacheToken(
      year: _viewYear,
      month: _viewMonth,
      reminders: reminders,
      festivals: festivals,
    );

    if (_monthCache == null || token != _cacheToken) {
      _monthCache = _MonthCache.compute(
        year: _viewYear,
        month: _viewMonth,
        allReminders: reminders,
        allSystemEvents: festivals,
      );
      _cacheToken = token;
      _syncSelectedDateToMonth();
    }
    return _monthCache!;
  }

  String _buildCacheToken({
    required int year,
    required int month,
    required List<Event> reminders,
    required List<SystemEventModel> festivals,
  }) {
    var reminderHash = 0;
    for (final event in reminders) {
      reminderHash = reminderHash ^
          event.id.hashCode ^
          event.startTime.millisecondsSinceEpoch ^
          event.updatedAt.millisecondsSinceEpoch;
    }

    var festivalHash = 0;
    for (final event in festivals) {
      festivalHash =
          festivalHash ^ event.id.hashCode ^ event.date.millisecondsSinceEpoch;
    }

    return '$year-$month-${reminders.length}-$reminderHash-${festivals.length}-$festivalHash';
  }

  void _syncSelectedDateToMonth() {
    final selected = _selectedDateNotifier.value;
    if (selected.year == _viewYear && selected.month == _viewMonth) {
      return;
    }
    final maxDay = DateUtils.getDaysInMonth(_viewYear, _viewMonth);
    final nextDay = math.min(selected.day, maxDay);
    _selectedDateNotifier.value = DateTime(_viewYear, _viewMonth, nextDay);
  }

  Future<void> _showReminderActions(
      BuildContext context, Event reminder) async {
    await HapticFeedback.mediumImpact();
    if (!context.mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReminderActionSheet(
        reminder: reminder,
        onEdit: () => _openEditFlow(context, reminder),
        onDelete: () => _confirmDelete(context, reminder),
      ),
    );
  }

  Future<void> _openEditFlow(BuildContext context, Event reminder) async {
    Navigator.of(context).pop();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddSheet(initialEvent: reminder),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Event reminder) async {
    Navigator.of(context).pop();
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierColor: AppDesignSystem.black.withValues(alpha: 0.55),
      builder: (_) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.82, end: 1),
        duration: AppDesignSystem.emphasis,
        curve: AppDesignSystem.springBounce,
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          child: child,
        ),
        child: AlertDialog(
          backgroundColor: AppDesignSystem.bg300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Reminder',
            style: AppDesignSystem.tsH3,
          ),
          content: Text(
            'Remove "${reminder.title}"?\nThis cannot be undone.',
            style: AppDesignSystem.tsCaption,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Keep',
                style: AppDesignSystem.tsBody.copyWith(
                  color: AppDesignSystem.text300,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: AppDesignSystem.tsBody.copyWith(
                  color: AppDesignSystem.danger100,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (shouldDelete == true) {
      await _deleteReminder(context, reminder);
    }
  }

  Future<void> _deleteReminder(BuildContext context, Event reminder) async {
    await ref.read(eventsNotifierProvider.notifier).deleteEvent(reminder.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder deleted')),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.monthDate,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime monthDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            _NavButton(
              icon: Icons.chevron_left_rounded,
              onTap: onPrev,
            ),
            const Spacer(),
            Column(
              children: [
                MonthTitleText(month: monthDate),
                Text(
                  DateFormat('yyyy').format(monthDate),
                  style: AppDesignSystem.tsLabel.copyWith(
                    color: AppDesignSystem.text300,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _NavButton(
              icon: Icons.chevron_right_rounded,
              onTap: onNext,
            ),
          ],
        ),
      );
}

class MonthTitleText extends StatefulWidget {
  const MonthTitleText({
    super.key,
    required this.month,
  });

  final DateTime month;

  @override
  State<MonthTitleText> createState() => _MonthTitleTextState();
}

class _MonthTitleTextState extends State<MonthTitleText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Alignment> _beginAlign;
  late final Animation<Alignment> _endAlign;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _beginAlign = AlignmentTween(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _endAlign = AlignmentTween(
      begin: Alignment.centerRight,
      end: Alignment.bottomLeft,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant MonthTitleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthText = DateFormat('MMMM').format(widget.month);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: _beginAlign.value,
            end: _endAlign.value,
            colors: const <Color>[
              Color(0xFFFFFFFF),
              Color(0xFF90CAF9),
              Color(0xFFFFFFFF),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
      child: Text(
        monthText,
        key: ValueKey<String>(monthText),
        style: AppDesignSystem.tsH2.copyWith(
          color: AppDesignSystem.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppDesignSystem.glass100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppDesignSystem.glassBorder),
          ),
          child: Icon(
            icon,
            color: AppDesignSystem.text200,
          ),
        ),
      );
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const List<String> _weekdayHeaders = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S'
  ];

  Widget _buildWeekdayLabel(String label, int weekdayIndex) {
    final isSunday = weekdayIndex == 6;
    final isSaturday = weekdayIndex == 5;
    final color = isSunday
        ? const Color(0xFFB71C1C)
        : isSaturday
            ? const Color(0xFF78909C)
            : AppDesignSystem.text300;

    return Text(
      label,
      textAlign: TextAlign.center,
      style: AppDesignSystem.tsLabel.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: color,
        shadows: isSunday
            ? <Shadow>[
                Shadow(
                  color: color.withValues(alpha: 0.40),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
        children: List<Widget>.generate(
          7,
          (index) => Expanded(
            child: Center(
              child: _buildWeekdayLabel(_weekdayHeaders[index], index),
            ),
          ),
        ),
      );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.cache,
    required this.now,
    required this.selectedDateListenable,
    required this.onDayTap,
    required this.onDayLongPress,
  });

  final _MonthCache cache;
  final DateTime now;
  final ValueListenable<DateTime> selectedDateListenable;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime>? onDayLongPress;

  @override
  Widget build(BuildContext context) {
    final totalCells = cache.firstWeekdayOffset + cache.daysInMonth;
    return ValueListenableBuilder<DateTime>(
      valueListenable: selectedDateListenable,
      builder: (context, selectedDate, _) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < cache.firstWeekdayOffset) {
              return const SizedBox.shrink();
            }

            final day = index - cache.firstWeekdayOffset + 1;
            final cellDate = cache.dayDates[day - 1];
            final isToday = _isSameDay(cellDate, now);
            final isSelected = _isSameDay(cellDate, selectedDate);

            return _AnimatedDayCell(
              day: day,
              isToday: isToday,
              isSelected: isSelected,
              isSunday: cache.sundayDays.contains(day),
              hasReminder: cache.daysWithReminders.contains(day),
              hasFestival: cache.daysWithFestivals.contains(day),
              isCurrentMonth: true,
              onPointerDown: () => onDayTap(cellDate),
              onLongPress: onDayLongPress == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onDayLongPress?.call(cellDate);
                    },
            );
          },
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _AnimatedDayCell extends StatefulWidget {
  const _AnimatedDayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isSunday,
    required this.hasReminder,
    required this.hasFestival,
    required this.isCurrentMonth,
    this.onPointerDown,
    this.onLongPress,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final bool isSunday;
  final bool hasReminder;
  final bool hasFestival;
  final bool isCurrentMonth;
  final VoidCallback? onPointerDown;
  final VoidCallback? onLongPress;

  @override
  State<_AnimatedDayCell> createState() => _AnimatedDayCellState();
}

class _AnimatedDayCellState extends State<_AnimatedDayCell> {
  bool _isPressed = false;

  void _onPointerDown(PointerDownEvent _) {
    HapticFeedback.selectionClick();
    if (!_isPressed) {
      setState(() => _isPressed = true);
    }
    widget.onPointerDown?.call();
  }

  void _onPointerUp(PointerUpEvent _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _onPointerCancel(PointerCancelEvent _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 60),
            curve: Curves.easeOut,
            child: _buildCellContent(),
          ),
        ),
      );

  Widget _buildCellContent() {
    final Color numberColor = widget.isSelected
        ? AppDesignSystem.white
        : !widget.isCurrentMonth
            ? AppDesignSystem.text400
            : widget.isToday
                ? AppDesignSystem.accent100
                : widget.isSunday
                    ? AppDesignSystem.sunday100
                    : AppDesignSystem.text200;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.isToday && !widget.isSelected) const _TodayPulseRing(),
        if (widget.isSelected)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF1565C0), Color(0xFF0288D1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        if (widget.isToday && !widget.isSelected)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppDesignSystem.accent100,
                width: 1.8,
              ),
            ),
          ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.day}',
              style: AppDesignSystem.tsBody.copyWith(
                color: numberColor,
                fontSize: 14,
                fontWeight: widget.isToday || widget.isSelected
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 3),
            _IndicatorStrip(
              hasReminder: widget.hasReminder,
              hasFestival: widget.hasFestival,
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayPulseRing extends StatefulWidget {
  const _TodayPulseRing();

  @override
  State<_TodayPulseRing> createState() => _TodayPulseRingState();
}

class _TodayPulseRingState extends State<_TodayPulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.32, end: 0.04).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    AppDesignSystem.accent100.withValues(alpha: _opacity.value),
                width: 1.5,
              ),
            ),
          ),
        ),
      );
}

class _IndicatorStrip extends StatelessWidget {
  const _IndicatorStrip({
    required this.hasReminder,
    required this.hasFestival,
  });

  final bool hasReminder;
  final bool hasFestival;

  @override
  Widget build(BuildContext context) {
    if (!hasReminder && !hasFestival) {
      return const SizedBox(height: 5);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasReminder) const _Dot(color: AppDesignSystem.remind100),
        if (hasReminder && hasFestival) const SizedBox(width: 3),
        if (hasFestival) const _Dot(color: AppDesignSystem.fest100),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 4,
            ),
          ],
        ),
      );
}

class _SelectedDayEventsPanel extends StatelessWidget {
  const _SelectedDayEventsPanel({
    required this.selectedDate,
    required this.reminders,
    required this.festivals,
    required this.onReminderTap,
  });

  final DateTime selectedDate;
  final List<Event> reminders;
  final List<SystemEventModel> festivals;
  final ValueChanged<Event> onReminderTap;

  @override
  Widget build(BuildContext context) {
    final totalEvents = reminders.length + festivals.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('MMM dd, yyyy').format(selectedDate),
                style: AppDesignSystem.tsH3,
              ),
              const Spacer(),
              if (totalEvents > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.accent100.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalEvents events',
                    style: AppDesignSystem.tsLabel.copyWith(
                      color: AppDesignSystem.accent100,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (totalEvents == 0)
            const _DayEmptyState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: festivals.length + reminders.length,
              itemBuilder: (context, index) {
                if (index < festivals.length) {
                  return _FestivalEventTile(event: festivals[index]);
                }
                final reminder = reminders[index - festivals.length];
                return _ReminderEventTile(
                  reminder: reminder,
                  onTap: () => onReminderTap(reminder),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FestivalEventTile extends StatelessWidget {
  const _FestivalEventTile({required this.event});

  final SystemEventModel event;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.category) {
      'national_holiday' => AppDesignSystem.remind100,
      'indian_festival' => AppDesignSystem.fest100,
      _ => AppDesignSystem.accent100,
    };

    final categoryLabel = event.category == 'national_holiday'
        ? 'Holiday'
        : event.regionCode == 'IN'
            ? 'Festival'
            : 'Global';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignSystem.bg300.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(
        children: [
          Text(
            event.emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: AppDesignSystem.tsH3,
                ),
                const SizedBox(height: 2),
                Text(
                  categoryLabel,
                  style: AppDesignSystem.tsCaption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              event.regionCode,
              style: AppDesignSystem.tsLabel.copyWith(
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderEventTile extends StatelessWidget {
  const _ReminderEventTile({
    required this.reminder,
    required this.onTap,
  });

  final Event reminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOnline = reminder.eventType == 'online';
    final color =
        isOnline ? AppDesignSystem.accent100 : AppDesignSystem.remind100;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppDesignSystem.bg200.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppDesignSystem.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isOnline ? Icons.wifi_rounded : Icons.location_on_rounded,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppDesignSystem.tsBody.copyWith(
                      color: AppDesignSystem.text100,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('hh:mm a').format(reminder.startTime.toLocal()),
                    style: AppDesignSystem.tsCaption,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppDesignSystem.text300,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderActionSheet extends StatelessWidget {
  const _ReminderActionSheet({
    required this.reminder,
    required this.onEdit,
    required this.onDelete,
  });

  final Event reminder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('MMM dd · hh:mm a').format(reminder.startTime.toLocal());
    final isOnline = reminder.eventType == 'online';
    final leadingColor =
        isOnline ? AppDesignSystem.accent100 : AppDesignSystem.remind100;

    return Container(
      decoration: AppDesignSystem.elevation(3),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppDesignSystem.glass300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AppCard(
            elevationLevel: 1,
            child: Row(
              children: [
                Icon(
                  isOnline ? Icons.wifi_rounded : Icons.alarm_rounded,
                  size: 18,
                  color: leadingColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reminder.title, style: AppDesignSystem.tsH3),
                      const SizedBox(height: 2),
                      Text(dateLabel, style: AppDesignSystem.tsCaption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ActionButton(
            icon: Icons.edit_rounded,
            label: 'Edit Reminder',
            color: AppDesignSystem.accent100,
            onTap: onEdit,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: AppDesignSystem.danger100,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppDesignSystem.tsBody.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

class _CalendarLoadingState extends StatelessWidget {
  const _CalendarLoadingState();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(),
      );
}

class _CalendarErrorState extends StatelessWidget {
  const _CalendarErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unable to load calendar',
                style: AppDesignSystem.tsH3,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppDesignSystem.tsCaption,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

class _DayEmptyState extends StatelessWidget {
  const _DayEmptyState();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: AppDesignSystem.bg300.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppDesignSystem.glassBorder),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.event_available_rounded,
              color: AppDesignSystem.text300,
            ),
            const SizedBox(height: 6),
            Text(
              'No reminders or festivals for this day.',
              style: AppDesignSystem.tsCaption,
            ),
          ],
        ),
      );
}

class _MonthCache {
  const _MonthCache({
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.firstWeekdayOffset,
    required this.remindersByDay,
    required this.festivalsByDay,
    required this.daysWithReminders,
    required this.daysWithFestivals,
    required this.sundayDays,
    required this.dayDates,
  });

  final int year;
  final int month;
  final int daysInMonth;
  final int firstWeekdayOffset;
  final Map<int, List<Event>> remindersByDay;
  final Map<int, List<SystemEventModel>> festivalsByDay;
  final Set<int> daysWithReminders;
  final Set<int> daysWithFestivals;
  final Set<int> sundayDays;
  final List<DateTime> dayDates;

  factory _MonthCache.compute({
    required int year,
    required int month,
    required List<Event> allReminders,
    required List<SystemEventModel> allSystemEvents,
  }) {
    final dim = DateUtils.getDaysInMonth(year, month);
    final firstDay = DateTime(year, month, 1);
    final offset = (firstDay.weekday - 1) % 7;

    final rMap = <int, List<Event>>{};
    for (final reminder in allReminders) {
      final local = reminder.startTime.toLocal();
      if (local.year != year || local.month != month) {
        continue;
      }
      rMap.putIfAbsent(local.day, () => <Event>[]).add(reminder);
    }
    for (final reminders in rMap.values) {
      reminders.sort(
          (a, b) => a.startTime.toLocal().compareTo(b.startTime.toLocal()));
    }

    final fMap = <int, List<SystemEventModel>>{};
    for (final festival in allSystemEvents) {
      final local = festival.date.toLocal();
      if (local.year != year || local.month != month) {
        continue;
      }
      fMap.putIfAbsent(local.day, () => <SystemEventModel>[]).add(festival);
    }
    for (final festivals in fMap.values) {
      festivals.sort((a, b) => a.date.compareTo(b.date));
    }

    final sundays = <int>{};
    final dayDates = <DateTime>[];
    for (var day = 1; day <= dim; day++) {
      final date = DateTime(year, month, day);
      dayDates.add(date);
      if (date.weekday == DateTime.sunday) {
        sundays.add(day);
      }
    }

    return _MonthCache(
      year: year,
      month: month,
      daysInMonth: dim,
      firstWeekdayOffset: offset,
      remindersByDay: Map<int, List<Event>>.unmodifiable(
        rMap.map((key, value) =>
            MapEntry<int, List<Event>>(key, List<Event>.unmodifiable(value))),
      ),
      festivalsByDay: Map<int, List<SystemEventModel>>.unmodifiable(
        fMap.map(
          (key, value) => MapEntry<int, List<SystemEventModel>>(
            key,
            List<SystemEventModel>.unmodifiable(value),
          ),
        ),
      ),
      daysWithReminders: Set<int>.unmodifiable(rMap.keys.toSet()),
      daysWithFestivals: Set<int>.unmodifiable(fMap.keys.toSet()),
      sundayDays: Set<int>.unmodifiable(sundays),
      dayDates: List<DateTime>.unmodifiable(dayDates),
    );
  }
}
