import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/event_provider.dart';
import '../../theme/app_design_system.dart';
import 'export_service.dart';

enum ExportFormat { styledExcel, executivePdf, rawCsv }

class ExportModal extends ConsumerStatefulWidget {
  const ExportModal({super.key});

  @override
  ConsumerState<ExportModal> createState() => _ExportModalState();
}

class _ExportModalState extends ConsumerState<ExportModal> {
  late final List<DateTime> _monthOptions;
  late final FixedExtentScrollController _monthWheelController;

  late DateTime _selectedMonth;
  ExportFormat _format = ExportFormat.styledExcel;
  int _selectedMonthIndex = 11;
  int _eventCount = 0;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final startMonth = DateTime(currentMonth.year, currentMonth.month - 11, 1);

    _monthOptions = List<DateTime>.generate(
      15,
      (index) => DateTime(startMonth.year, startMonth.month + index, 1),
      growable: false,
    );
    _selectedMonth = currentMonth;
    _monthWheelController = FixedExtentScrollController(
      initialItem: _selectedMonthIndex,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEventCount();
    });
  }

  @override
  void dispose() {
    _monthWheelController.dispose();
    super.dispose();
  }

  ({DateTime from, DateTime to}) get _selectedRange {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(start.year, start.month + 1, 1);
    return (from: start, to: end);
  }

  Future<void> _loadEventCount() async {
    final events = await ref.read(eventsForDateRangeProvider(_selectedRange).future);
    if (!mounted) {
      return;
    }
    setState(() {
      _eventCount = events.length;
    });
  }

  Future<void> _generate() async {
    if (_isGenerating || _eventCount == 0) {
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final events =
          await ref.read(eventsForDateRangeProvider(_selectedRange).future);
      switch (_format) {
        case ExportFormat.styledExcel:
          await ExportService.instance.exportExcel(events, _selectedMonth);
          break;
        case ExportFormat.executivePdf:
          await ExportService.instance.exportPdf(events, _selectedMonth);
          break;
        case ExportFormat.rawCsv:
          await ExportService.instance.exportCsv(events, _selectedMonth);
          break;
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsForDateRangeProvider(_selectedRange));
    final resolvedCount = eventsAsync.maybeWhen(
      data: (events) => events.length,
      orElse: () => _eventCount,
    );
    if (resolvedCount != _eventCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _eventCount != resolvedCount) {
          setState(() {
            _eventCount = resolvedCount;
          });
        }
      });
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.55,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppDesignSystem.accent100.withValues(alpha: 0.30),
                AppDesignSystem.future100.withValues(alpha: 0.24),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Container(
              decoration: BoxDecoration(
                color: AppDesignSystem.bg200.withValues(alpha: 0.96),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(27)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Export Report',
                      style: AppDesignSystem.tsH2.copyWith(
                        color: AppDesignSystem.text100,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select month and format',
                      style: AppDesignSystem.tsCaption.copyWith(
                        color: AppDesignSystem.text300,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 184,
                      child: ListWheelScrollView.useDelegate(
                        controller: _monthWheelController,
                        itemExtent: 52,
                        diameterRatio: 1.4,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedMonthIndex = index;
                            _selectedMonth = _monthOptions[index];
                          });
                          _loadEventCount();
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _monthOptions.length,
                          builder: (context, index) {
                            final month = _monthOptions[index];
                            final selected = index == _selectedMonthIndex;
                            return Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                style: AppDesignSystem.tsBody.copyWith(
                                  fontSize: selected ? 16 : 14,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? AppDesignSystem.accent100
                                      : AppDesignSystem.text300,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(DateFormat('MMMM').format(month)),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('yyyy').format(month),
                                      style: TextStyle(
                                        color: selected
                                            ? AppDesignSystem.accent200
                                            : AppDesignSystem.text400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        final offset = Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: offset, child: child),
                        );
                      },
                      child: Container(
                        key: ValueKey<int>(resolvedCount),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: resolvedCount == 0
                                ? <Color>[
                                    AppDesignSystem.danger100
                                        .withValues(alpha: 0.14),
                                    AppDesignSystem.bg300
                                        .withValues(alpha: 0.55),
                                  ]
                                : <Color>[
                                    AppDesignSystem.accent100
                                        .withValues(alpha: 0.20),
                                    AppDesignSystem.future100
                                        .withValues(alpha: 0.16),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: resolvedCount == 0
                                ? AppDesignSystem.danger100
                                    .withValues(alpha: 0.35)
                                : AppDesignSystem.glassBorder,
                          ),
                        ),
                        child: Text(
                          resolvedCount == 0
                              ? 'No events this month'
                              : '$resolvedCount events found',
                          style: AppDesignSystem.tsBody.copyWith(
                            color: resolvedCount == 0
                                ? AppDesignSystem.danger200
                                : AppDesignSystem.text100,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _FormatCard(
                            icon: Icons.table_chart_outlined,
                            title: 'Styled Excel',
                            subtitle: 'Overview + details',
                            selected: _format == ExportFormat.styledExcel,
                            onTap: () => setState(() {
                              _format = ExportFormat.styledExcel;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _FormatCard(
                            icon: Icons.picture_as_pdf_outlined,
                            title: 'Executive PDF',
                            subtitle: 'Share-ready brief',
                            selected: _format == ExportFormat.executivePdf,
                            onTap: () => setState(() {
                              _format = ExportFormat.executivePdf;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _FormatCard(
                            icon: Icons.data_object_rounded,
                            title: 'Raw CSV',
                            subtitle: 'Portable dataset',
                            selected: _format == ExportFormat.rawCsv,
                            onTap: () => setState(() {
                              _format = ExportFormat.rawCsv;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: resolvedCount == 0 || _isGenerating
                            ? null
                            : _generate,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppDesignSystem.accent100,
                          foregroundColor: AppDesignSystem.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isGenerating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppDesignSystem.white,
                                  ),
                                ),
                              )
                            : const Text('Generate Report ->'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppDesignSystem.accent100 : AppDesignSystem.text300;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: AppDesignSystem.bg300.withValues(alpha: selected ? 0.8 : 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppDesignSystem.accent100.withValues(alpha: 0.85)
                  : AppDesignSystem.glassBorder.withValues(alpha: 0.30),
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppDesignSystem.accent100.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: accent),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppDesignSystem.tsLabel.copyWith(
                  color: selected
                      ? AppDesignSystem.accent200
                      : AppDesignSystem.text300,
                  letterSpacing: 0.2,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppDesignSystem.tsCaption.copyWith(
                  color: AppDesignSystem.text400,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
