import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/kwan_colors.dart';
import '../models/space_model.dart';
import '../models/space_role.dart';
import '../providers/auth_provider.dart';
import '../screens/space_calendar_screen.dart';
import 'space_type_tile.dart';
import 'space_management_menu.dart';

class SpaceCard extends ConsumerStatefulWidget {
  const SpaceCard({
    super.key,
    required this.space,
    required this.onTap,
  });

  final SpaceModel space;
  final VoidCallback onTap;

  @override
  ConsumerState<SpaceCard> createState() => _SpaceCardState();
}

class _SpaceCardState extends ConsumerState<SpaceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.96,
  ).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = kSpaceTypes.firstWhere(
      (c) => c.type == widget.space.type,
      orElse: () => kSpaceTypes.last,
    );
    final user = ref.watch(currentUserProvider);
    final role = user != null ? widget.space.roleOf(user.uid) : null;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SpaceCalendarScreen(space: widget.space),
          ),
        );
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                KwanColors.fromHex(config.gradientStart).withOpacity(0.85),
                KwanColors.fromHex(config.gradientEnd).withOpacity(0.65),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: KwanColors.fromHex(config.gradientEnd).withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: KwanColors.fromHex(
                  config.gradientStart,
                ).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [KwanColors.white(0.08), KwanColors.white(0.02)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: KwanColors.white(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      kSpaceIconMap[config.icon] ?? Icons.calendar_today,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.space.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (role != null) _RoleBadge(role),
                            const SizedBox(width: 4),
                            if (widget.space.storageType ==
                                SpaceStorageType.shared)
                              _Badge('SHARED', KwanColors.white(0.2)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.space.description ?? config.description,
                          style: TextStyle(
                            color: KwanColors.white(0.7),
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: KwanColors.white(0.5),
                    size: 22,
                  ),
                  const SizedBox(width: 2),
                  SpaceManagementMenu(space: widget.space),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge(this.role);

  final SpaceRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      SpaceRole.admin => KwanColors.admin,
      SpaceRole.member => KwanColors.member,
      SpaceRole.viewer => KwanColors.viewer,
      SpaceRole.none => KwanColors.viewer,
    };
    return _Badge(
      role.label.toUpperCase(),
      color.withOpacity(0.25),
      textColor: color,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(
    this.text,
    this.bg, {
    this.textColor = Colors.white,
  });

  final String text;
  final Color bg;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
