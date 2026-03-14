import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/kwan_theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 20.0,
    this.opacity = 0.10,
    this.blur = 20.0,
    this.borderColor,
    this.onTap,
    this.isAccent = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final double opacity;
  final double blur;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      decoration: isAccent
          ? KwanGlass.accentCard(radius: borderRadius)
          : KwanGlass.card(
              radius: borderRadius,
              opacity: opacity,
              borderColor: borderColor,
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

class GlassPill extends StatelessWidget {
  const GlassPill({
    required this.child,
    super.key,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: ShapeDecoration(
            color: color ?? KwanColors.bgCard,
            shape: StadiumBorder(
              side: BorderSide(color: borderColor ?? KwanColors.bgCardBorder),
            ),
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.color,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => GlassPill(
        color: color.withValues(alpha: 0.18),
        borderColor: color.withValues(alpha: 0.55),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: KwanColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      );
}
