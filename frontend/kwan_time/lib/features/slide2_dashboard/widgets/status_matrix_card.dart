import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/summary_provider.dart';
import '../../../core/theme/kwan_theme.dart';
import '../../../shared/widgets/count_up_text.dart';
import '../../../shared/widgets/glass_card.dart';

class StatusMatrixCard extends ConsumerWidget {
  const StatusMatrixCard({super.key});

  static const _rowLabels = [
    '',
    'Cancelled',
    'Completed',
    'In Progress',
    'Not Started',
  ];

  static const _statusKeys = [
    'unknown',
    'cancelled',
    'completed',
    'in_progress',
    'not_started',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrixAsync = ref.watch(statusMatrixProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Schedule Overview', style: KwanText.titleMedium),
          const SizedBox(height: 12),
          matrixAsync.when(
            data: _buildMatrix,
            loading: _buildLoading,
            error: (error, _) => _buildError(ref, error),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrix(Map<String, int> data) => Table(
        border: TableBorder.all(
          color: KwanColors.bgDivider,
          width: 0.8,
        ),
        columnWidths: const {
          0: FixedColumnWidth(94),
        },
        children: [
          _periodHeaderRow(),
          _subHeaderRow(),
          for (var i = 0; i < _rowLabels.length; i++) _dataRow(i, data),
        ],
      );

  TableRow _periodHeaderRow() {
    Widget headerCell(String text, Color bg) => Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: bg,
          alignment: Alignment.center,
          child: Text(
            text,
            style: KwanText.label.copyWith(color: Colors.white),
          ),
        );

    return TableRow(
      children: [
        const SizedBox.shrink(),
        headerCell('PAST', const Color(0x334A90E2)),
        headerCell('PAST', const Color(0x334A90E2)),
        headerCell('PAST', const Color(0x334A90E2)),
        headerCell('CURRENT', const Color(0x33E07B3C)),
        headerCell('CURRENT', const Color(0x33E07B3C)),
        headerCell('CURRENT', const Color(0x33E07B3C)),
        headerCell('FUTURE', const Color(0x334CAF50)),
        headerCell('FUTURE', const Color(0x334CAF50)),
        headerCell('FUTURE', const Color(0x334CAF50)),
      ],
    );
  }

  TableRow _subHeaderRow() {
    Widget angled(String text) => SizedBox(
          height: 34,
          child: Center(
            child: Transform.rotate(
              angle: -0.6,
              child: Text(
                text,
                style: KwanText.bodySmall.copyWith(color: KwanColors.textSecondary),
              ),
            ),
          ),
        );

    return TableRow(
      children: [
        const SizedBox(height: 34),
        angled('Online'),
        angled('In-Person'),
        angled('Total'),
        angled('Online'),
        angled('In-Person'),
        angled('Total'),
        angled('Online'),
        angled('In-Person'),
        angled('Total'),
      ],
    );
  }

  TableRow _dataRow(int row, Map<String, int> data) {
    final status = _statusKeys[row];
    final pastOnline = _get(data, 'past', 'online', status);
    final pastInPerson = _get(data, 'past', 'inperson', status);
    final currentOnline = _get(data, 'current', 'online', status);
    final currentInPerson = _get(data, 'current', 'inperson', status);
    final futureOnline = _get(data, 'future', 'online', status);
    final futureInPerson = _get(data, 'future', 'inperson', status);

    Widget valueCell(int value, {bool total = false}) => SizedBox(
          height: 34,
          child: Center(
            child: CountUpText(
              value: value,
              style: (total ? KwanText.bodyMedium : KwanText.bodySmall).copyWith(
                fontWeight: total ? FontWeight.w700 : FontWeight.w500,
                color: KwanColors.textPrimary,
              ),
            ),
          ),
        );

    return TableRow(
      children: [
        SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _rowLabels[row],
                style: KwanText.bodySmall.copyWith(color: KwanColors.textSecondary),
              ),
            ),
          ),
        ),
        valueCell(pastOnline),
        valueCell(pastInPerson),
        valueCell(pastOnline + pastInPerson, total: true),
        valueCell(currentOnline),
        valueCell(currentInPerson),
        valueCell(currentOnline + currentInPerson, total: true),
        valueCell(futureOnline),
        valueCell(futureInPerson),
        valueCell(futureOnline + futureInPerson, total: true),
      ],
    );
  }

  int _get(Map<String, int> data, String period, String type, String status) {
    final candidates = [
      '${period}_${type}_$status',
      '${period}_${type.replaceAll('inperson', 'in_person')}_$status',
    ];
    for (final key in candidates) {
      final value = data[key];
      if (value != null) {
        return value;
      }
    }
    return 0;
  }

  Widget _buildLoading() => Column(
        children: List.generate(
          6,
          (_) => Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            height: 26,
            decoration: BoxDecoration(
              color: KwanColors.bgCardHover,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );

  Widget _buildError(WidgetRef ref, Object error) => Row(
        children: [
          Expanded(
            child: Text(
              '$error',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KwanText.bodySmall.copyWith(color: KwanColors.error),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(statusMatrixProvider),
            child: const Text('Retry'),
          ),
        ],
      );
}
