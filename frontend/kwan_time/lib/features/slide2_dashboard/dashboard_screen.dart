import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/event.dart';
import '../../core/providers/event_provider.dart';
import '../../theme/app_design_system.dart';
import '../export/export_modal.dart';

const Curve _curveMicro = Cubic(0.25, 0.10, 0.25, 1.0);
const Curve _curveStructural = Cubic(0.33, 1.0, 0.68, 1.0);
const Curve _curveEmphasis = Cubic(0.22, 1.0, 0.36, 1.0);

const Duration _durationMicro = Duration(milliseconds: 140);
const Duration _durationStructural = Duration(milliseconds: 230);
const Duration _durationEmphasis = Duration(milliseconds: 180);

@immutable
class _EventRow {
  const _EventRow({
    required this.day,
    required this.weekday,
    required this.title,
    required this.type,
    required this.time,
    required this.fullDate,
  });

  final int day;
  final String weekday;
  final String title;
  final String type;
  final String time;
  final DateTime fullDate;
}

@immutable
class _EventDayGroup {
  const _EventDayGroup({
    required this.day,
    required this.weekday,
    required this.events,
  });

  final int day;
  final String weekday;
  final List<_EventRow> events;
}

@immutable
class _MonthCtx {
  const _MonthCtx._({
    required this.year,
    required this.month,
    required this.label,
    required this.daysInMonth,
    required this.startWeekdayOffset,
    required this.loadByDay,
    required this.events,
    required this.dayGroups,
    required this.totalLoad,
    required this.maxDailyLoad,
    required this.loadRatio,
    required this.accentColor,
  });

  factory _MonthCtx.compute({
    required int year,
    required int month,
    required List<Event> allReminders,
    required Color accent,
  }) {
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstDay = DateTime(year, month, 1);
    final offset = (firstDay.weekday - 1) % 7;
    final label = DateFormat('MMMM').format(firstDay);

    final loadMap = <int, int>{};
    final eventRows = <_EventRow>[];

    for (final reminder in allReminders) {
      final local = reminder.startTime.toLocal();
      if (local.year != year || local.month != month) {
        continue;
      }
      loadMap[local.day] = (loadMap[local.day] ?? 0) + 1;
      eventRows.add(
        _EventRow(
          day: local.day,
          weekday: DateFormat('EEE').format(local),
          title: reminder.title,
          type: reminder.eventType,
          time: DateFormat('hh:mm a').format(local),
          fullDate: local,
        ),
      );
    }

    eventRows.sort(
      (a, b) {
        final dateCompare = a.fullDate.compareTo(b.fullDate);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.title.compareTo(b.title);
      },
    );

    final groupedEvents = <int, List<_EventRow>>{};
    for (final row in eventRows) {
      groupedEvents.putIfAbsent(row.day, () => <_EventRow>[]).add(row);
    }
    final sortedDays = groupedEvents.keys.toList()..sort();
    final dayGroups = sortedDays
        .map(
          (day) => _EventDayGroup(
            day: day,
            weekday: groupedEvents[day]!.first.weekday,
            events: List<_EventRow>.unmodifiable(groupedEvents[day]!),
          ),
        )
        .toList(growable: false);

    final total = loadMap.values.fold<int>(0, (sum, value) => sum + value);
    final maxDaily =
        loadMap.values.isEmpty ? 1 : loadMap.values.reduce(math.max);
    final ratio =
        total == 0 ? 0.0 : (total / (daysInMonth * maxDaily)).clamp(0.0, 1.0);

    return _MonthCtx._(
      year: year,
      month: month,
      label: label,
      daysInMonth: daysInMonth,
      startWeekdayOffset: offset,
      loadByDay: Map<int, int>.unmodifiable(loadMap),
      events: List<_EventRow>.unmodifiable(eventRows),
      dayGroups: List<_EventDayGroup>.unmodifiable(dayGroups),
      totalLoad: total,
      maxDailyLoad: maxDaily,
      loadRatio: ratio,
      accentColor: accent,
    );
  }

  final int year;
  final int month;
  final String label;
  final int daysInMonth;
  final int startWeekdayOffset;
  final Map<int, int> loadByDay;
  final List<_EventRow> events;
  final List<_EventDayGroup> dayGroups;
  final int totalLoad;
  final int maxDailyLoad;
  final double loadRatio;
  final Color accentColor;
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  static const LinearGradient _backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      AppDesignSystem.bg100,
      AppDesignSystem.bg200,
    ],
  );

  static final LinearGradient _gradientThisMonth = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      AppDesignSystem.accent100.withValues(alpha: 0.0),
      AppDesignSystem.accent100.withValues(alpha: 0.06),
    ],
  );

  static final LinearGradient _gradientNextMonth = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      AppDesignSystem.remind100.withValues(alpha: 0.0),
      AppDesignSystem.remind100.withValues(alpha: 0.06),
    ],
  );

  static final LinearGradient _gradientMonthAfter = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      AppDesignSystem.future100.withValues(alpha: 0.0),
      AppDesignSystem.future100.withValues(alpha: 0.06),
    ],
  );

  final ValueNotifier<int> _selectedMonthNotifier = ValueNotifier<int>(0);

  List<_MonthCtx> _months = const <_MonthCtx>[];
  int _monthsSignature = 0;
  double _refreshRateMultiplier = 1.0;

  @override
  void initState() {
    super.initState();
    _detectRefreshRate();
  }

  @override
  void dispose() {
    _selectedMonthNotifier.dispose();
    super.dispose();
  }

  Future<void> _detectRefreshRate() async {
    final displays = WidgetsBinding.instance.platformDispatcher.displays;
    if (displays.isEmpty) {
      return;
    }
    final hz = displays.first.refreshRate;
    final multiplier = hz >= 90 ? 0.85 : 1.0;
    if (!mounted) {
      _refreshRateMultiplier = multiplier;
      return;
    }
    setState(() {
      _refreshRateMultiplier = multiplier;
    });
  }

  Duration _adaptDuration(Duration base) {
    return Duration(
      milliseconds:
          math.max(1, (base.inMilliseconds * _refreshRateMultiplier).round()),
    );
  }

  void _rebuildMonthData({
    required DateTime baseMonth,
    required List<Event> source,
  }) {
    final signature = Object.hash(
      baseMonth.year,
      baseMonth.month,
      source.length,
      Object.hashAll(
        source.map(
          (event) => Object.hash(
            event.id,
            event.title,
            event.eventType,
            event.startTime.millisecondsSinceEpoch,
            event.updatedAt.millisecondsSinceEpoch,
          ),
        ),
      ),
    );

    if (signature == _monthsSignature) {
      return;
    }

    final m0 = DateTime(baseMonth.year, baseMonth.month, 1);
    final m1 = DateTime(baseMonth.year, baseMonth.month + 1, 1);
    final m2 = DateTime(baseMonth.year, baseMonth.month + 2, 1);

    _months = <_MonthCtx>[
      _MonthCtx.compute(
        year: m0.year,
        month: m0.month,
        allReminders: source,
        accent: AppDesignSystem.accent100,
      ),
      _MonthCtx.compute(
        year: m1.year,
        month: m1.month,
        allReminders: source,
        accent: AppDesignSystem.remind100,
      ),
      _MonthCtx.compute(
        year: m2.year,
        month: m2.month,
        allReminders: source,
        accent: AppDesignSystem.future100,
      ),
    ];
    _monthsSignature = signature;

    if (_selectedMonthNotifier.value > 2) {
      _selectedMonthNotifier.value = 0;
    }
  }

  void _onMonthSelected(int index) {
    if (_selectedMonthNotifier.value == index) {
      return;
    }
    HapticFeedback.lightImpact();
    _selectedMonthNotifier.value = index;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final baseMonth = DateTime(now.year, now.month, 1);
    final range = (
      from: baseMonth,
      to: DateTime(baseMonth.year, baseMonth.month + 3, 1),
    );
    final remindersAsync = ref.watch(eventsForDateRangeProvider(range));

    return remindersAsync.when(
      loading: _buildLoadingState,
      error: (Object error, StackTrace stackTrace) => _buildErrorState(error),
      data: (List<Event> reminders) {
        _rebuildMonthData(baseMonth: baseMonth, source: reminders);
        if (_months.isEmpty) {
          return _buildLoadingState();
        }
        return _buildLoadedState();
      },
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppDesignSystem.bg100,
      body: const Center(
        child: CircularProgressIndicator(
          color: AppDesignSystem.accent100,
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Scaffold(
      backgroundColor: AppDesignSystem.bg100,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load overview.\n$error',
            style: AppDesignSystem.tsBody,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadedState() {
    return Scaffold(
      backgroundColor: AppDesignSystem.bg100,
      body: Container(
        decoration: BoxDecoration(
          gradient: _backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('OVERVIEW', style: AppDesignSystem.tsLabel),
                          SizedBox(height: 4),
                          Text('3-Month Horizon', style: AppDesignSystem.tsH2),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _TotalBadge(months: _months),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const ExportModal(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[
                            Color(0xFF1565C0),
                            Color(0xFF0288D1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.analytics_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Export Report',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  flex: 52,
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      final stripHeight = constraints.maxHeight * 0.74;
                      return Column(
                        children: <Widget>[
                          SizedBox(
                            height: stripHeight,
                            child: ValueListenableBuilder<int>(
                              valueListenable: _selectedMonthNotifier,
                              builder: (BuildContext context, int selected, _) {
                                return _ThreeMonthStrip(
                                  months: _months,
                                  selectedIndex: selected,
                                  onSelect: _onMonthSelected,
                                  structuralDuration:
                                      _adaptDuration(_durationStructural),
                                  gradients: <LinearGradient>[
                                    _gradientThisMonth,
                                    _gradientNextMonth,
                                    _gradientMonthAfter,
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          ValueListenableBuilder<int>(
                            valueListenable: _selectedMonthNotifier,
                            builder: (BuildContext context, int selected, _) {
                              return _MonthSummaryBar(
                                ctx: _months[selected],
                                structuralDuration:
                                    _adaptDuration(_durationStructural),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 48,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ValueListenableBuilder<int>(
                      valueListenable: _selectedMonthNotifier,
                      builder: (BuildContext context, int selected, _) {
                        final ctx = _months[selected];
                        return RepaintBoundary(
                          key: const ValueKey<String>('event_list'),
                          child: AnimatedSwitcher(
                            duration: _adaptDuration(_durationStructural),
                            switchInCurve: _curveStructural,
                            switchOutCurve: _curveMicro,
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              final curved = CurvedAnimation(
                                parent: animation,
                                curve: _curveStructural,
                                reverseCurve: _curveMicro,
                              );
                              return AnimatedBuilder(
                                animation: curved,
                                builder: (BuildContext context,
                                    Widget? animatedChild) {
                                  final depth = (1.0 - curved.value) * -20.0;
                                  final scale = 0.96 + (curved.value * 0.04);
                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.001)
                                      ..translateByDouble(0, 0, depth, 1)
                                      ..scaleByDouble(scale, scale, 1, 1),
                                    child: FadeTransition(
                                      opacity: curved,
                                      child: animatedChild,
                                    ),
                                  );
                                },
                                child: child,
                              );
                            },
                            child: _EventList(
                              key: ValueKey<String>('${ctx.year}-${ctx.month}'),
                              ctx: ctx,
                              emphasisDuration:
                                  _adaptDuration(_durationEmphasis),
                              microDuration: _adaptDuration(_durationMicro),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _ThreeMonthStrip extends StatelessWidget {
  const _ThreeMonthStrip({
    required this.months,
    required this.selectedIndex,
    required this.onSelect,
    required this.structuralDuration,
    required this.gradients,
  });

  final List<_MonthCtx> months;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Duration structuralDuration;
  final List<LinearGradient> gradients;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const ValueKey<String>('month_strip'),
      child: Row(
        children: List<Widget>.generate(
          3,
          (int index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 6,
                  right: index == 2 ? 0 : 6,
                ),
                child: _MiniMonthCard(
                  slotIndex: index,
                  ctx: months[index],
                  gradient: gradients[index],
                  isSelected: selectedIndex == index,
                  onTap: () => onSelect(index),
                  structuralDuration: structuralDuration,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MiniMonthCard extends StatefulWidget {
  const _MiniMonthCard({
    required this.slotIndex,
    required this.ctx,
    required this.gradient,
    required this.isSelected,
    required this.onTap,
    required this.structuralDuration,
  });

  final int slotIndex;
  final _MonthCtx ctx;
  final LinearGradient gradient;
  final bool isSelected;
  final VoidCallback onTap;
  final Duration structuralDuration;

  @override
  State<_MiniMonthCard> createState() => _MiniMonthCardState();
}

class _MiniMonthCardState extends State<_MiniMonthCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selectionController;
  late final Animation<double> _borderAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _selectionController = AnimationController(
      vsync: this,
      duration: widget.structuralDuration,
    );
    _borderAnimation = Tween<double>(begin: 0.8, end: 1.6).animate(
      CurvedAnimation(
        parent: _selectionController,
        curve: _curveStructural,
      ),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _selectionController,
        curve: _curveStructural,
      ),
    );
    if (widget.isSelected) {
      _selectionController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _MiniMonthCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.structuralDuration != widget.structuralDuration) {
      _selectionController.duration = widget.structuralDuration;
    }
    if (widget.isSelected == oldWidget.isSelected) {
      return;
    }
    if (widget.isSelected) {
      _selectionController.forward();
    } else {
      _selectionController.reverse();
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: widget.onTap,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _selectionController,
          builder: (BuildContext context, Widget? child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: AppDesignSystem.bg200,
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.ctx.accentColor.withValues(
                      alpha: 0.14 + (_borderAnimation.value * 0.22),
                    ),
                    width: _borderAnimation.value,
                  ),
                  boxShadow: widget.isSelected
                      ? <BoxShadow>[
                          BoxShadow(
                            color:
                                widget.ctx.accentColor.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.ctx.label,
                        style: AppDesignSystem.tsH3.copyWith(
                          color: widget.isSelected
                              ? widget.ctx.accentColor
                              : AppDesignSystem.text200,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _LoadPill(
                      ratio: widget.ctx.loadRatio,
                      color: widget.ctx.accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RepaintBoundary(
                  key: ValueKey<String>('month_${widget.slotIndex}_grid'),
                  child: _HeatmapGrid(ctx: widget.ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({required this.ctx});

  final _MonthCtx ctx;

  @override
  Widget build(BuildContext context) {
    final totalCells = ctx.startWeekdayOffset + ctx.daysInMonth;
    final maxLoad = ctx.maxDailyLoad <= 0 ? 1 : ctx.maxDailyLoad;

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
      itemBuilder: (BuildContext context, int index) {
        if (index < ctx.startWeekdayOffset) {
          return const SizedBox.shrink();
        }
        final day = index - ctx.startWeekdayOffset + 1;
        final load = ctx.loadByDay[day] ?? 0;
        return _HeatCell(
          load: load,
          maxLoad: maxLoad,
          accentColor: ctx.accentColor,
        );
      },
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.load,
    required this.maxLoad,
    required this.accentColor,
  });

  final int load;
  final int maxLoad;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final intensity = maxLoad == 0 ? 0.0 : (load / maxLoad).clamp(0.0, 1.0);
    final cellColor = load == 0
        ? AppDesignSystem.bg300
        : Color.lerp(
            accentColor.withValues(alpha: 0.08),
            accentColor.withValues(alpha: 0.70),
            intensity,
          )!;
    final hasGlow = intensity > 0.6;

    return Container(
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(2),
        boxShadow: hasGlow
            ? <BoxShadow>[
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.20),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }
}

class _MonthSummaryBar extends StatelessWidget {
  const _MonthSummaryBar({
    required this.ctx,
    required this.structuralDuration,
  });

  final _MonthCtx ctx;
  final Duration structuralDuration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppDesignSystem.bg200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ctx.accentColor.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              ctx.label,
              style: AppDesignSystem.tsH3.copyWith(
                color: ctx.accentColor,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: ctx.loadRatio),
              duration: structuralDuration,
              curve: _curveStructural,
              builder: (BuildContext context, double value, Widget? child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: ctx.accentColor.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(ctx.accentColor),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          _LoadPill(
            ratio: ctx.loadRatio,
            color: ctx.accentColor,
          ),
        ],
      ),
    );
  }
}

class _LoadPill extends StatelessWidget {
  const _LoadPill({
    required this.ratio,
    required this.color,
  });

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = ratio == 0
        ? 'CLEAR'
        : ratio < 0.25
            ? 'LIGHT'
            : ratio < 0.50
                ? 'MOD'
                : ratio < 0.75
                    ? 'BUSY'
                    : 'FULL';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppDesignSystem.tsLabel.copyWith(
          color: color,
          fontSize: 7,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TotalBadge extends StatelessWidget {
  const _TotalBadge({required this.months});

  final List<_MonthCtx> months;

  @override
  Widget build(BuildContext context) {
    final total = months.fold<int>(
        0, (int sum, _MonthCtx month) => sum + month.totalLoad);
    final label = total == 0
        ? 'Clear ahead'
        : total < 10
            ? 'Light quarter'
            : total < 30
                ? 'Active quarter'
                : 'Dense quarter';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppDesignSystem.glass100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppDesignSystem.glassBorder,
          width: 1,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppDesignSystem.tsCaption.copyWith(
          color: AppDesignSystem.text200,
        ),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({
    super.key,
    required this.ctx,
    required this.emphasisDuration,
    required this.microDuration,
  });

  final _MonthCtx ctx;
  final Duration emphasisDuration;
  final Duration microDuration;

  @override
  Widget build(BuildContext context) {
    if (ctx.dayGroups.isEmpty) {
      return const _EventListEmpty();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
      physics: const BouncingScrollPhysics(),
      itemCount: ctx.dayGroups.length,
      itemBuilder: (BuildContext context, int index) {
        final dayGroup = ctx.dayGroups[index];
        return _DaySection(
          day: dayGroup.day,
          weekday: dayGroup.weekday,
          events: dayGroup.events,
          accent: ctx.accentColor,
          index: index,
          emphasisDuration: emphasisDuration,
          microDuration: microDuration,
        );
      },
    );
  }
}

class _EventListEmpty extends StatelessWidget {
  const _EventListEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppDesignSystem.bg200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppDesignSystem.glassBorder,
            width: 1,
          ),
        ),
        child: Text(
          'No events in this month.',
          style: AppDesignSystem.tsBody.copyWith(
            color: AppDesignSystem.text300,
          ),
        ),
      ),
    );
  }
}

class _DaySection extends StatefulWidget {
  const _DaySection({
    required this.day,
    required this.weekday,
    required this.events,
    required this.accent,
    required this.index,
    required this.emphasisDuration,
    required this.microDuration,
  });

  final int day;
  final String weekday;
  final List<_EventRow> events;
  final Color accent;
  final int index;
  final Duration emphasisDuration;
  final Duration microDuration;

  @override
  State<_DaySection> createState() => _DaySectionState();
}

class _DaySectionState extends State<_DaySection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.emphasisDuration,
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: _curveEmphasis,
      ),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: _curveEmphasis,
      ),
    );

    final delay = Duration(
      milliseconds: (widget.index * 40).clamp(0, 400),
    );
    Future<void>.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _DaySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emphasisDuration != widget.emphasisDuration) {
      _controller.duration = widget.emphasisDuration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.accent.withValues(alpha: 0.20),
                          width: 1,
                        ),
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: widget.day.toString(),
                              style: AppDesignSystem.tsH3.copyWith(
                                color: widget.accent,
                                fontSize: 14,
                              ),
                            ),
                            const TextSpan(text: '  '),
                            TextSpan(
                              text: widget.weekday.toUpperCase(),
                              style: AppDesignSystem.tsLabel.copyWith(
                                color: widget.accent.withValues(alpha: 0.70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.events.length > 1)
                      Text(
                        '${widget.events.length} events',
                        style: AppDesignSystem.tsCaption.copyWith(
                          color: AppDesignSystem.text400,
                        ),
                      ),
                  ],
                ),
              ),
              ...widget.events.map(
                (_EventRow event) => _EventCard(
                  event: event,
                  accent: widget.accent,
                  microDuration: widget.microDuration,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatefulWidget {
  const _EventCard({
    required this.event,
    required this.accent,
    required this.microDuration,
  });

  final _EventRow event;
  final Color accent;
  final Duration microDuration;

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: widget.microDuration,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: _curveMicro,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _EventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.microDuration != widget.microDuration) {
      _pressController.duration = widget.microDuration;
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typeLower = widget.event.type.toLowerCase();
    final isOnline = typeLower.contains('online');
    final isInPerson =
        typeLower.contains('in_person') || typeLower.contains('in person');

    final icon = isOnline
        ? Icons.videocam_rounded
        : isInPerson
            ? Icons.location_on_rounded
            : Icons.event_rounded;
    final iconColor = isOnline
        ? AppDesignSystem.accent100
        : isInPerson
            ? AppDesignSystem.remind100
            : AppDesignSystem.text300;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        _pressController.forward();
      },
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (BuildContext context, Widget? child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppDesignSystem.bg200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppDesignSystem.glassBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.event.time,
                  style: AppDesignSystem.tsData.copyWith(
                    color: widget.accent,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.event.title,
                  style: AppDesignSystem.tsBody.copyWith(
                    color: AppDesignSystem.text100,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                icon,
                size: 14,
                color: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
