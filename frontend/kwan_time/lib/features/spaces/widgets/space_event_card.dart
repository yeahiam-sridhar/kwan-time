import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/space_event_model.dart';
import '../models/space_model.dart';
import 'space_event_detail_sheet.dart';

class SpaceEventCard extends ConsumerWidget {
  const SpaceEventCard({
    super.key,
    required this.event,
    required this.space,
  });

  final SpaceEvent event;
  final SpaceModel space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _parseColor(event.colorHex);
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SpaceEventDetailSheet(event: event, space: space),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: Colors.white.withOpacity(0.4),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _formatTimeRange(context, event),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (event.location != null &&
                          event.location!.trim().isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.place_rounded,
                          color: Colors.white.withOpacity(0.4),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            event.location!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (event.commentCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.comment_rounded,
                          color: Colors.white.withOpacity(0.3),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${event.commentCount} comment(s)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (event.isPast)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Past',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimeRange(BuildContext context, SpaceEvent event) {
    if (event.isAllDay) {
      return 'All Day';
    }
    final localizations = MaterialLocalizations.of(context);
    final start = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(event.startTime),
      alwaysUse24HourFormat: false,
    );
    final end = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(event.endTime),
      alwaysUse24HourFormat: false,
    );
    return '$start - $end';
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) {
      return const Color(0xFF1565C0);
    }
    final value = hex.replaceFirst('#', '');
    if (value.length == 6) {
      return Color(int.parse('0xFF$value'));
    }
    if (value.length == 8) {
      return Color(int.parse('0x$value'));
    }
    return const Color(0xFF1565C0);
  }
}
