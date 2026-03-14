import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/summary_provider.dart';
import '../../../../core/theme/kwan_theme.dart';

class SmartInsightBanner extends ConsumerWidget {
  const SmartInsightBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(smartInsightsProvider);
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: insights.asMap().entries.map((entry) {
          final i = entry.key;
          final insight = entry.value;
          return _buildChip(insight)
              .animate(delay: (i * 80).ms)
              .slideX(begin: 0.4, duration: 350.ms, curve: Curves.easeOut)
              .fadeIn(duration: 350.ms);
        }).toList(),
      ),
    );
  }

  Widget _buildChip(InsightMessage insight) => Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: insight.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: insight.color.withValues(alpha: 0.4)),
        ),
        child: Text(
          '${insight.emoji}  ${insight.text}',
          style: KwanText.bodySmall.copyWith(
            color: insight.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
