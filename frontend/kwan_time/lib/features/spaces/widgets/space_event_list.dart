import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/kwan_colors.dart';
import '../models/space_event_model.dart';
import '../providers/space_calendar_provider.dart';
import '../services/role_permission_service.dart';

class SpaceEventList extends ConsumerWidget {
  final String spaceId;
  final SpaceRole? userRole;
  final void Function(SpaceEvent)? onEventTap;
  final void Function(SpaceEvent)? onDeleteTap;

  const SpaceEventList({
    super.key,
    required this.spaceId,
    this.userRole,
    this.onEventTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(spaceSelectedDateProvider);
    final events = ref.watch(
      spaceEventsForDateProvider((spaceId: spaceId, date: selected)),
    );

    final festival = ref.watch(festivalProvider(selected));
    final canDelete = userRole != null &&
        ref.read(rolePermissionServiceProvider).canDeleteEvent(userRole!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateLabel(selected),
                    style: TextStyle(
                      color: KwanColors.white(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (festival != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.celebration_outlined,
                            color: KwanColors.admin,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            festival,
                            style: const TextStyle(
                              color: KwanColors.admin,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'No events',
              style: TextStyle(
                color: KwanColors.white(0.25),
                fontSize: 14,
              ),
            ),
          )
        else
          ...events.map(
            (e) => _EventTile(
              event: e,
              canDelete: canDelete,
              onTap: () => onEventTap?.call(e),
              onDelete: () => onDeleteTap?.call(e),
            ),
          ),
      ],
    );
  }

  String _dateLabel(DateTime d) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return '${days[d.weekday - 1]}  ${months[d.month - 1]} ${d.day}';
  }
}

class _EventTile extends StatefulWidget {
  final SpaceEvent event;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EventTile({
    required this.event,
    required this.canDelete,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_EventTile> createState() => _EventTileState();
}

class _EventTileState extends State<_EventTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.97,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return GestureDetector(
      onTapDown: (_) => _scale.reverse(),
      onTapUp: (_) {
        _scale.forward();
        widget.onTap();
      },
      onTapCancel: () => _scale.forward(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: KwanColors.white(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KwanColors.white(0.07)),
            boxShadow: [
              BoxShadow(
                color: KwanColors.white(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: KwanColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${e.startTime.hour.toString().padLeft(2, '0')}'
                      ':${e.startTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: KwanColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (e.location != null && e.location!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: KwanColors.white(0.35),
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              e.location!,
                              style: TextStyle(
                                color: KwanColors.white(0.4),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.canDelete)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: KwanColors.white(0.25),
                    size: 18,
                  ),
                  onPressed: widget.onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
