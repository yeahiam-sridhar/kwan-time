import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kwan_time/core/theme/kwan_theme.dart';

// ============================================================================
// Animated Widgets - Agent 7 Future Enhancement
// Simplified version - full implementation coming in future agents
// ============================================================================

class AnimatedMetricCard extends ConsumerWidget {
  const AnimatedMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    super.key,
    this.onTap,
  });
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                KwanTheme.colorOnline.withOpacity(0.1),
                KwanTheme.colorFree.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: KwanTheme.glassBorder,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelSmall),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

class AnimatedDashboardRefreshButton extends ConsumerWidget {
  const AnimatedDashboardRefreshButton({
    required this.onPressed,
    required this.isRefreshing,
    super.key,
  });
  final VoidCallback onPressed;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
        onTap: isRefreshing ? null : onPressed,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: KwanTheme.colorOnline.withOpacity(0.1),
            border: Border.all(
              color: KwanTheme.glassBorder.withOpacity(0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isRefreshing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                )
              : Icon(
                  Icons.refresh_rounded,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  size: 20,
                ),
        ),
      );
}

class AnimatedEventCard extends ConsumerWidget {
  const AnimatedEventCard({
    required this.eventTitle,
    required this.timeRange,
    required this.eventColor,
    super.key,
    this.onTap,
    this.onDragStart,
    this.onDragEnd,
  });
  final String eventTitle;
  final String timeRange;
  final Color eventColor;
  final VoidCallback? onTap;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
        onTap: onTap,
        onLongPressStart: (_) => onDragStart?.call(),
        onLongPressEnd: (_) => onDragEnd?.call(),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: eventColor.withOpacity(0.15),
            border: Border.all(
              color: eventColor.withOpacity(0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eventTitle,
                style: Theme.of(context).textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                timeRange,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      );
}

class AnimatedActionButton extends ConsumerWidget {
  const AnimatedActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
    this.backgroundColor,
    this.textColor,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor ?? Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: textColor ?? Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor ?? Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

class AnimatedLoadingSkeleton extends ConsumerWidget {
  const AnimatedLoadingSkeleton({
    required this.width,
    required this.height,
    super.key,
    this.lineCount = 3,
    this.spacing = 8,
  });
  final double width;
  final double height;
  final int lineCount;
  final double spacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        children: List.generate(lineCount, (index) {
          final isLast = index == lineCount - 1;
          final lineWidth = isLast ? width * 0.7 : width;

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
            child: Container(
              width: lineWidth,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          );
        }),
      );
}

class AnimatedEmptyState extends ConsumerWidget {
  const AnimatedEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
    this.onActionPressed,
    this.actionLabel,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onActionPressed != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              AnimatedActionButton(
                label: actionLabel!,
                icon: Icons.add_rounded,
                onPressed: onActionPressed!,
              ),
            ],
          ],
        ),
      );
}
