import 'package:flutter/material.dart';

import '../../../core/models/event.dart';
import '../../../core/theme/kwan_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    required this.event,
    super.key,
    this.compact = false,
    this.onTap,
    this.onLongPress,
  });

  final Event event;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 12,
            vertical: compact ? 1 : 3,
          ),
          decoration: BoxDecoration(
            color: event.typeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  color: event.typeColor,
                ),
                Expanded(
                  child: GlassCard(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 8 : 10,
                    ),
                    borderRadius: 0,
                    opacity: 0.04,
                    blur: 0,
                    borderColor: Colors.transparent,
                    child: _Content(
                      event: event,
                      compact: compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Content extends StatelessWidget {
  const _Content({
    required this.event,
    required this.compact,
  });

  final Event event;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: compact ? KwanText.bodyMedium.copyWith(color: KwanColors.textPrimary) : KwanText.titleMedium,
                ),
              ),
              const SizedBox(width: 6),
              StatusDot(color: event.statusColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            event.timeRangeLabel,
            style: KwanText.bodySmall,
          ),
          if (!compact && event.isInPerson && (event.location?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 12,
                  color: KwanColors.textMuted,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    event.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KwanText.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
}

class StatusDot extends StatelessWidget {
  const StatusDot({
    required this.color,
    super.key,
  });

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
}
