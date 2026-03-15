import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/kwan_colors.dart';
import '../providers/space_calendar_provider.dart';

/// Premium month-view calendar for a Calendar Space.
/// Visual feature parity with the personal calendar:
///   • Sunday highlighted red
///   • Event dots under dates
///   • Festival indicators
///   • Today highlighted
///   • Selected date ring
///   • Smooth month page transitions
class SpaceCalendarView extends ConsumerStatefulWidget {
  final String spaceId;
  const SpaceCalendarView({super.key, required this.spaceId});

  @override
  ConsumerState<SpaceCalendarView> createState() => _SpaceCalendarViewState();
}

class _SpaceCalendarViewState extends ConsumerState<SpaceCalendarView>
    with SingleTickerProviderStateMixin {
  late final PageController _pageCtrl;
  late final DateTime _baseMonth;
  late DateTime _currentMonth;
  late final AnimationController _fadeCtrl;

  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    _baseMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _currentMonth = _baseMonth;
    _pageCtrl = PageController(initialPage: 600);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) {
    final diff = page - 600;
    return DateTime(_baseMonth.year, _baseMonth.month + diff);
  }

  void _onPageChanged(int page) {
    _fadeCtrl.reset();
    setState(() => _currentMonth = _monthForPage(page));
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(spaceSelectedDateProvider);

    return Column(
      children: [
        // ── Month header ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: () => _pageCtrl.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
              ),
              FadeTransition(
                opacity: _fadeCtrl,
                child: Text(
                  _monthLabel(_currentMonth),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: () => _pageCtrl.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
              ),
            ],
          ),
        ),

        // ── Weekday labels ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              7,
              (i) => SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    _weekdays[i],
                    style: TextStyle(
                      color: i == 0
                          ? const Color(0xFFEF5350)
                          : KwanColors.white(0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Month grid ───────────────────────────────────────────────
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (_, page) {
              final month = _monthForPage(page);
              return _MonthGrid(
                spaceId: widget.spaceId,
                month: month,
                selected: selected,
                onDateTap: (date) {
                  ref.read(spaceSelectedDateProvider.notifier).state = date;
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

// ── Month grid ────────────────────────────────────────────────────────────

class _MonthGrid extends ConsumerWidget {
  final String spaceId;
  final DateTime month;
  final DateTime selected;
  final void Function(DateTime) onDateTap;

  const _MonthGrid({
    required this.spaceId,
    required this.month,
    required this.selected,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datesWithEvents = ref.watch(spaceDatesWithEventsProvider(spaceId));
    final festivals = ref.watch(
      monthFestivalsProvider((year: month.year, month: month.month)),
    );
    final today = DateTime.now();

    final firstDay = DateTime(month.year, month.month, 1);
    final startOffset = firstDay.weekday % 7; // Sunday = 0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          rows,
          (row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (col) {
                final cell = row * 7 + col;
                final dayNum = cell - startOffset + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox(width: 40, height: 40);
                }
                final date = DateTime(month.year, month.month, dayNum);
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final isSelected = date.year == selected.year &&
                    date.month == selected.month &&
                    date.day == selected.day;
                final isSunday = col == 0;
                final hasEvent = datesWithEvents.contains(date);
                final festival = festivals[date];

                return _DayCell(
                  day: dayNum,
                  isToday: isToday,
                  isSelected: isSelected,
                  isSunday: isSunday,
                  hasEvent: hasEvent,
                  festival: festival,
                  onTap: () => onDateTap(date),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Individual day cell ────────────────────────────────────────────────────

class _DayCell extends StatefulWidget {
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool isSunday;
  final bool hasEvent;
  final String? festival;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isSunday,
    required this.hasEvent,
    this.festival,
    required this.onTap,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> with SingleTickerProviderStateMixin {
  late final AnimationController _tap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    lowerBound: 0.88,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color? bgColor;
    Border? border;

    if (widget.isSelected) {
      bgColor = KwanColors.primary;
      textColor = Colors.white;
    } else if (widget.isToday) {
      border = Border.all(color: KwanColors.primary, width: 1.5);
      textColor = KwanColors.primary;
    } else if (widget.isSunday) {
      textColor = const Color(0xFFEF5350);
    } else {
      textColor = Colors.white;
    }

    return GestureDetector(
      onTapDown: (_) => _tap.reverse(),
      onTapUp: (_) {
        _tap.forward();
        widget.onTap();
      },
      onTapCancel: () => _tap.forward(),
      child: AnimatedBuilder(
        animation: _tap,
        builder: (_, child) => Transform.scale(scale: _tap.value, child: child),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              if (bgColor != null || border != null)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: border,
                    shape: BoxShape.circle,
                  ),
                ),

              // Day number
              Text(
                '${widget.day}',
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: widget.isToday || widget.isSelected
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
              ),

              // Event dot
              if (widget.hasEvent && !widget.isSelected)
                Positioned(
                  bottom: 3,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.isSunday
                          ? const Color(0xFFEF5350)
                          : KwanColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

              // Festival dot (amber, shifted when event dot exists)
              if (widget.festival != null && !widget.isSelected)
                Positioned(
                  bottom: 3,
                  right: widget.hasEvent ? 5 : null,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: KwanColors.admin,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
