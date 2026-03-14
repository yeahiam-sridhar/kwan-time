import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/summary_provider.dart';
import '../../../../core/theme/kwan_theme.dart';
import '../../../../shared/widgets/count_up_text.dart';
import '../../../../shared/widgets/glass_card.dart';

class MonthlyBookedCard extends ConsumerWidget {
  const MonthlyBookedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(monthlyBookedCountProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Booked Count', style: KwanText.titleMedium),
          const SizedBox(height: 8),
          rowsAsync.when(
            data: _buildTable,
            loading: _buildLoading,
            error: (error, stackTrace) => _buildError(ref),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() => SizedBox(
        height: 200,
        child: ListView.separated(
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, __) => Container(
            height: 28,
            decoration: BoxDecoration(
              color: KwanColors.bgCardHover,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );

  Widget _buildError(WidgetRef ref) => Center(
        child: TextButton.icon(
          onPressed: () => ref.invalidate(monthlyBookedCountProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      );

  Widget _buildTable(List<Map<String, dynamic>> rows) {
    final currentMonthLabel = _currentMonthLabel();
    return Column(
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: KwanColors.bgCardHover,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Expanded(child: Text('Month', style: KwanText.label)),
              SizedBox(
                width: 58,
                child: Text(
                  'Online',
                  style: KwanText.label.copyWith(color: KwanColors.online),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  'In-Person',
                  style: KwanText.label.copyWith(color: KwanColors.inPerson),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  'Total',
                  style: KwanText.label.copyWith(
                    color: KwanColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 200,
          child: SingleChildScrollView(
            child: Column(
              children: rows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                final month = (row['month'] ?? '') as String;
                final online = (row['online'] as int?) ?? 0;
                final inPerson = (row['in_person'] as int?) ?? 0;
                final total = (row['total'] as int?) ?? (online + inPerson);
                final isCurrent = month == currentMonthLabel;
                final bg = isCurrent ? KwanColors.accentDim : (index.isOdd ? KwanColors.bgCard : Colors.transparent);
                return Container(
                  height: 36,
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          month,
                          style: KwanText.bodySmall.copyWith(
                            color: isCurrent ? KwanColors.textPrimary : KwanColors.textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 58,
                        child: CountUpText(
                          value: online,
                          style: KwanText.numberSmall.copyWith(color: KwanColors.online),
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: CountUpText(
                          value: inPerson,
                          style: KwanText.numberSmall.copyWith(color: KwanColors.inPerson),
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        child: CountUpText(
                          value: total,
                          style: KwanText.numberSmall.copyWith(
                            color: _totalColor(total),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  String _currentMonthLabel() {
    final now = DateTime.now();
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    return '$yy-$mm';
  }

  Color _totalColor(int total) {
    if (total < 20) {
      return KwanColors.free;
    }
    if (total < 50) {
      return KwanColors.inProgress;
    }
    if (total < 100) {
      return KwanColors.inPerson;
    }
    return KwanColors.cancelled;
  }
}
