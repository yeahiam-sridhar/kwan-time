import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/monthly_summary.dart';
import '../../../core/providers/event_provider.dart';
import '../../../core/providers/summary_provider.dart';
import '../../../core/theme/kwan_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class AvailableDatesPanel extends ConsumerWidget {
  const AvailableDatesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(threeMonthSummaryProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Free Dates', style: KwanText.titleMedium),
          const SizedBox(height: 12),
          summaryAsync.when(
            data: (summaries) => Column(
              children: [
                for (var i = 0; i < summaries.length; i++) _buildMonthSection(ref, summaries[i], i),
              ],
            ),
            loading: () => const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('$e', style: KwanText.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSection(WidgetRef ref, MonthlySummary summary, int index) {
    final monthColor = _monthColor(index);
    final dates = summary.availableDateList;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMM').format(DateTime.parse('${summary.month}-01')),
          style: KwanText.label.copyWith(color: monthColor),
        ),
        const SizedBox(height: 6),
        if (dates.isEmpty)
          Text(
            'Fully booked 🔥',
            style: KwanText.bodySmall.copyWith(color: KwanColors.warning),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: dates.asMap().entries.map((entry) {
                final i = entry.key;
                final date = entry.value;
                return _buildDatePill(ref, date)
                    .animate(delay: (i * 60).ms)
                    .slideX(begin: 0.3, end: 0, duration: 300.ms)
                    .fadeIn(duration: 300.ms);
              }).toList(),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDatePill(WidgetRef ref, AvailableDate date) {
    final color = date.isWeekend ? KwanColors.inPerson : KwanColors.accent;
    return GestureDetector(
      onTap: () {
        ref.read(selectedDayProvider.notifier).state = date.date;
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
          color: color.withValues(alpha: 0.08),
        ),
        child: Text(
          date.display,
          style: KwanText.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _monthColor(int i) => switch (i) {
        0 => KwanColors.online,
        1 => KwanColors.inPerson,
        2 => KwanColors.success,
        _ => KwanColors.textSecondary,
      };
}
