import 'package:flutter/material.dart';

import '../../../core/theme/kwan_colors.dart';
import '../models/space_model.dart';

const Map<String, IconData> kSpaceIconMap = {
  'home': Icons.home,
  'person': Icons.person,
  'favorite': Icons.favorite,
  'work': Icons.work,
  'group': Icons.group,
  'schedule': Icons.schedule,
  'menu_book': Icons.menu_book,
  'school': Icons.school,
  'groups': Icons.groups,
  'palette': Icons.palette,
  'add_circle': Icons.add_circle,
  'calendar_today': Icons.calendar_today,
};

class SpaceTypeTile extends StatefulWidget {
  const SpaceTypeTile({
    super.key,
    required this.config,
    required this.isSelected,
    required this.onTap,
  });

  final SpaceTypeConfig config;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<SpaceTypeTile> createState() => _SpaceTypeTileState();
}

class _SpaceTypeTileState extends State<SpaceTypeTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.94,
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
    final s = widget.isSelected;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: s
                  ? [
                      KwanColors.fromHex(widget.config.gradientStart),
                      KwanColors.fromHex(widget.config.gradientEnd),
                    ]
                  : [KwanColors.white(0.06), KwanColors.white(0.03)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: s
                  ? KwanColors.fromHex(
                      widget.config.gradientEnd,
                    ).withOpacity(0.7)
                  : KwanColors.white(0.08),
              width: s ? 2 : 1,
            ),
            boxShadow: s
                ? [
                    BoxShadow(
                      color: KwanColors.fromHex(
                        widget.config.gradientStart,
                      ).withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                kSpaceIconMap[widget.config.icon] ?? Icons.calendar_today,
                color: Colors.white,
                size: 28,
              ),
              const Spacer(),
              Text(
                widget.config.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.config.description,
                style: TextStyle(
                  color: KwanColors.white(0.55),
                  fontSize: 10,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
