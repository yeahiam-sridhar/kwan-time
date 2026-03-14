import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/monthly_summary.dart';
import '../../../core/providers/summary_provider.dart';
import '../../../core/theme/kwan_theme.dart';
import '../../../shared/widgets/count_up_text.dart';
import '../../../shared/widgets/glass_card.dart';

class AvailableDaysPanel extends ConsumerWidget {
  const AvailableDaysPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(threeMonthSummaryProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available Days', style: KwanText.titleMedium),
          const SizedBox(height: 8),
          summaryAsync.when(
            data: _buildTable,
            loading: _buildLoading,
            error: (e, _) => Text('$e', style: KwanText.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<MonthlySummary> summaries) {
    final data = summaries.take(3).toList();

    Widget header(String text, Color color) => Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: KwanText.label.copyWith(color: color),
          ),
        );

    Widget numberCell(int value, {Color? color}) => SizedBox(
          height: 32,
          child: Center(
            child: CountUpText(
              value: value,
              style: KwanText.bodySmall.copyWith(color: color ?? KwanColors.textPrimary),
            ),
          ),
        );

    return Table(
      border: TableBorder.all(color: KwanColors.bgDivider, width: 0.8),
      children: [
        TableRow(
          children: [
            const SizedBox(height: 30),
            header('Available', KwanColors.success),
            header('Online', KwanColors.online),
            header('In-Person', KwanColors.inPerson),
            header('Sat', KwanColors.textMuted),
            header('Sun', KwanColors.textMuted),
          ],
        ),
        for (var i = 0; i < data.length; i++)
          TableRow(
            children: [
              SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    DateFormat('MMM').format(DateTime.parse('${data[i].month}-01')),
                    style: KwanText.bodySmall.copyWith(
                      color: _monthColor(i),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              numberCell(
                data[i].availableDays,
                color: _availableColor(data[i].availableDays),
              ),
              numberCell(data[i].totalOnline, color: KwanColors.online),
              numberCell(data[i].totalInPerson, color: KwanColors.inPerson),
              numberCell(data[i].availableSaturdays),
              numberCell(data[i].availableSundays),
            ],
          ),
      ],
    );
  }

  Color _availableColor(int value) {
    if (value == 0) {
      return KwanColors.textMuted;
    }
    if (value <= 2) {
      return KwanColors.warning;
    }
    return KwanColors.success;
  }

  Color _monthColor(int index) => switch (index) {
        0 => KwanColors.online,
        1 => KwanColors.inPerson,
        2 => KwanColors.success,
        _ => KwanColors.textSecondary,
      };

  Widget _buildLoading() => Column(
        children: List.generate(
          3,
          (_) => Container(
            height: 30,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: KwanColors.bgCardHover,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
}
