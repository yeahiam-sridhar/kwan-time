import 'package:flutter/material.dart';
import 'package:kwan_time/core/theme/kwan_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// DATE SELECTOR WIDGET — Shows calendar for date selection
/// ═══════════════════════════════════════════════════════════════════════════

class DateSelectorWidget extends StatefulWidget {
  const DateSelectorWidget({
    required this.maxAdvanceDays,
    required this.onDateSelected,
    super.key,
  });
  final int maxAdvanceDays;
  final Function(DateTime) onDateSelected;

  @override
  State<DateSelectorWidget> createState() => _DateSelectorWidgetState();
}

class _DateSelectorWidgetState extends State<DateSelectorWidget> {
  late DateTime _selectedDate;
  late DateTime _focusDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _focusDate = _selectedDate;
  }

  DateTime? _getStartOfWeek(DateTime date) {
    final diff = date.weekday - DateTime.monday;
    return date.subtract(Duration(days: diff));
  }

  List<DateTime> _getWeekDays(DateTime weekStart) => List.generate(7, (index) => weekStart.add(Duration(days: index)));

  String _formatMonthYear(DateTime date) {
    const months = <String>[
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
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDayOfWeek(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  bool _isDateAvailable(DateTime date) {
    final now = DateTime.now();
    final maxDate = now.add(Duration(days: widget.maxAdvanceDays));
    return date.isAfter(now) && date.isBefore(maxDate.add(const Duration(days: 1)));
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _previousWeek() {
    setState(() {
      _focusDate = _focusDate.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _focusDate = _focusDate.add(const Duration(days: 7));
    });
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = _getStartOfWeek(_focusDate) ?? DateTime.now();
    final weekDays = _getWeekDays(weekStart);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month/Year header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _formatMonthYear(_focusDate),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        // Week navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _previousWeek,
              icon: const Icon(Icons.chevron_left),
              color: KwanTheme.neonBlue,
              splashRadius: 20,
            ),
            Text(
              '${weekStart.day} - ${weekStart.add(const Duration(days: 6)).day} ${_formatMonthYear(weekStart)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KwanTheme.glassText,
                  ),
            ),
            IconButton(
              onPressed: _nextWeek,
              icon: const Icon(Icons.chevron_right),
              color: KwanTheme.neonBlue,
              splashRadius: 20,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Week grid
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: weekDays.map((date) {
            final isSelected = _isSameDay(date, _selectedDate);
            final isAvailable = _isDateAvailable(date);
            final isToday = _isSameDay(date, DateTime.now());

            return _buildDateButton(
              context,
              date,
              isSelected,
              isAvailable,
              isToday,
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        // Calendar grid
        _buildMonthCalendar(context),
      ],
    );
  }

  Widget _buildDateButton(
    BuildContext context,
    DateTime date,
    bool isSelected,
    bool isAvailable,
    bool isToday,
  ) =>
      GestureDetector(
        onTap: isAvailable
            ? () {
                setState(() => _selectedDate = date);
                widget.onDateSelected(date);
              }
            : null,
        child: Column(
          children: [
            Text(
              _formatDayOfWeek(date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isAvailable ? KwanTheme.glassText : KwanTheme.glassText.withOpacity(0.5),
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected
                    ? KwanTheme.neonBlue
                    : isToday
                        ? KwanTheme.neonGreen.withOpacity(0.2)
                        : KwanTheme.darkGlass.withOpacity(0.3),
                border: Border.all(
                  color: isSelected
                      ? KwanTheme.neonBlue
                      : isToday
                          ? KwanTheme.neonGreen
                          : KwanTheme.glassStroke,
                  width: isToday ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  date.day.toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? Colors.white
                            : isAvailable
                                ? Colors.white
                                : KwanTheme.glassText.withOpacity(0.5),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildMonthCalendar(BuildContext context) {
    final now = DateTime.now();
    // final maxDate = now.add(Duration(days: widget.maxAdvanceDays));

    // Get first day of focused month
    final firstDay = DateTime(_focusDate.year, _focusDate.month, 1);
    // Get last day of focused month
    final lastDay = DateTime(_focusDate.year, _focusDate.month + 1, 0);

    // Get start of first week (may include days from previous month)
    final weekStart = _getStartOfWeek(firstDay) ?? DateTime.now();

    final totalDays = lastDay.difference(weekStart).inDays + 1;
    final weeks = (totalDays / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Full Month View',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: KwanTheme.glassText,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        // Day headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((day) => SizedBox(
                    width: 40,
                    child: Center(
                      child: Text(
                        day,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: KwanTheme.glassText,
                            ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        ...List.generate(
            weeks,
            (weekIndex) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (dayIndex) {
                      final date = weekStart.add(Duration(days: weekIndex * 7 + dayIndex));
                      final isThisMonth = date.month == _focusDate.month;
                      final isSelected = _isSameDay(date, _selectedDate);
                      final isAvailable = _isDateAvailable(date);
                      final isToday = _isSameDay(date, now);

                      if (!isThisMonth) {
                        return const SizedBox(width: 40, height: 40);
                      }

                      return GestureDetector(
                        onTap: isAvailable
                            ? () {
                                setState(() => _selectedDate = date);
                                widget.onDateSelected(date);
                              }
                            : null,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isSelected
                                ? KwanTheme.neonBlue
                                : isToday
                                    ? KwanTheme.neonGreen.withOpacity(0.2)
                                    : KwanTheme.darkGlass.withOpacity(0.2),
                            border: Border.all(
                              color: isSelected
                                  ? KwanTheme.neonBlue
                                  : isToday
                                      ? KwanTheme.neonGreen
                                      : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              date.day.toString(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? Colors.white
                                        : isAvailable
                                            ? Colors.white
                                            : KwanTheme.glassText.withOpacity(0.4),
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                )),
      ],
    );
  }
}
