import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/summary_provider.dart';
import '../../../../core/theme/kwan_theme.dart';
import '../../../../shared/widgets/glass_card.dart';

class DailyCountTable extends ConsumerWidget {
  const DailyCountTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailyCountsProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Booked Count', style: KwanText.titleMedium),
          const SizedBox(height: 8),
          dailyAsync.when(
            data: (rowsByMonth) {
              final keys = rowsByMonth.keys.toList();
              final jan = rowsByMonth[keys.isNotEmpty ? keys[0] : 'Jan'] ?? const [];
              final feb = rowsByMonth[keys.length > 1 ? keys[1] : 'Feb'] ?? const [];
              final mar = rowsByMonth[keys.length > 2 ? keys[2] : 'Mar'] ?? const [];

              return SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMonthColumn('Jan', jan),
                      const SizedBox(width: 16),
                      _buildMonthColumn('Feb', feb),
                      const SizedBox(width: 16),
                      _buildMonthColumn('Mar', mar),
                    ],
                  ),
                ),
              );
            },
            loading: _buildLoading,
            error: (error, stackTrace) => _buildError(ref),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() => SizedBox(
        height: 260,
        child: ListView.separated(
          itemCount: 8,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, __) => Container(
            height: 24,
            decoration: BoxDecoration(
              color: KwanColors.bgCardHover,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );

  Widget _buildError(WidgetRef ref) => Center(
        child: TextButton.icon(
          onPressed: () => ref.invalidate(dailyCountsProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      );

  Widget _buildMonthColumn(String monthName, List<Map<String, dynamic>> rows) {
    final color = _monthColor(monthName);
    return SizedBox(
      width: 172,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              monthName,
              style: KwanText.label.copyWith(color: color),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              SizedBox(width: 84, child: Text('', style: KwanText.label)),
              SizedBox(width: 40, child: Text('O', style: KwanText.label)),
              SizedBox(width: 40, child: Text('I', style: KwanText.label)),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 240,
            child: SingleChildScrollView(
              child: Column(
                children: rows.map(_buildDayRow).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(Map<String, dynamic> row) {
    final date = (row['date'] ?? '') as String;
    final day = (row['day'] ?? '') as String;
    final online = (row['online'] as int?) ?? 0;
    final inPerson = (row['in_person'] as int?) ?? 0;
    final total = online + inPerson;
    final todayStr = _todayDateLabel();
    final isToday = date == todayStr;
    final weekend = _isWeekend(day);

    Color? bg;
    if (isToday) {
      bg = KwanColors.accent.withValues(alpha: 0.15);
    } else if (total >= 5) {
      bg = KwanColors.inPerson.withValues(alpha: 0.08);
    }

    return Container(
      height: 30,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              '$date $day',
              style: KwanText.bodySmall.copyWith(
                color: weekend ? KwanColors.textMuted : KwanColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$online',
              style: KwanText.bodySmall.copyWith(color: KwanColors.online),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$inPerson',
              style: KwanText.bodySmall.copyWith(color: KwanColors.inPerson),
            ),
          ),
        ],
      ),
    );
  }

  Color _monthColor(String month) => switch (month) {
        'Jan' => KwanColors.online,
        'Feb' => KwanColors.inPerson,
        _ => KwanColors.free,
      };

  bool _isWeekend(String day) => day == 'Sat' || day == 'Sun';

  String _todayDateLabel() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}';
  }
}
