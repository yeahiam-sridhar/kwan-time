import 'package:flutter/material.dart';

class AppDesignSystem {
  AppDesignSystem._();

  static const Color bg100 = Color(0xFF0A0E1A);
  static const Color bg200 = Color(0xFF0F1525);
  static const Color bg300 = Color(0xFF161D30);
  static const Color bg400 = Color(0xFF1E2740);

  static const Color glass100 = Color(0x0DFFFFFF);
  static const Color glass200 = Color(0x1AFFFFFF);
  static const Color glass300 = Color(0x26FFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);

  static const Color accent100 = Color(0xFF3B82F6);
  static const Color accent200 = Color(0xFF60A5FA);
  static const Color accent300 = Color(0xFF1D4ED8);

  static const Color remind100 = Color(0xFF10B981);
  static const Color remind200 = Color(0xFF34D399);
  static const Color remind300 = Color(0xFF065F46);

  static const Color fest100 = Color(0xFFF59E0B);
  static const Color fest200 = Color(0xFFFBBF24);
  static const Color fest300 = Color(0xFF78350F);

  static const Color future100 = Color(0xFF8B5CF6);
  static const Color future200 = Color(0xFFA78BFA);

  static const Color danger100 = Color(0xFFF43F5E);
  static const Color danger200 = Color(0xFFFDA4AF);

  static const Color sunday100 = Color(0xFFFC8181);
  static const Color sunday200 = Color(0xFFFCA5A5);

  static const Color text100 = Color(0xFFF8FAFC);
  static const Color text200 = Color(0xFFCBD5E1);
  static const Color text300 = Color(0xFF64748B);
  static const Color text400 = Color(0xFF334155);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  static const Curve springStandard = Curves.easeOutCubic;
  static const Curve springBounce = Curves.elasticOut;
  static const Curve decelerate = Curves.decelerate;
  static const Curve anticipate = Curves.easeIn;

  static const Duration micro = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration emphasis = Duration(milliseconds: 350);
  static const Duration pulse = Duration(milliseconds: 1200);

  static const TextStyle tsHero = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: text100,
    letterSpacing: -2,
    height: 1,
  );

  static const TextStyle tsH1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: text100,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static const TextStyle tsH2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: text100,
    letterSpacing: -0.4,
    height: 1.3,
  );

  static const TextStyle tsH3 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: text200,
    letterSpacing: -0.2,
    height: 1.4,
  );

  static const TextStyle tsBody = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: text200,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const TextStyle tsLabel = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    color: text300,
    letterSpacing: 2,
    height: 1,
  );

  static const TextStyle tsData = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: accent200,
    letterSpacing: 0.2,
    height: 1,
  );

  static const TextStyle tsCaption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: text300,
    letterSpacing: 0.3,
    height: 1.4,
  );

  static BoxDecoration elevation(int level, {Color? tint}) {
    switch (level) {
      case 1:
        return BoxDecoration(
          color: tint ?? bg200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: glassBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );
      case 2:
        return BoxDecoration(
          color: tint ?? bg300,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: glass200, width: 1),
          boxShadow: [
            BoxShadow(
              color: black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: accent100.withValues(alpha: 0.04),
              blurRadius: 40,
              offset: const Offset(0, 0),
            ),
          ],
        );
      case 3:
        return BoxDecoration(
          color: tint ?? bg400,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: glass300, width: 1),
          boxShadow: [
            BoxShadow(
              color: black.withValues(alpha: 0.4),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: accent100.withValues(alpha: 0.08),
              blurRadius: 60,
              spreadRadius: -10,
              offset: const Offset(0, 0),
            ),
          ],
        );
      default:
        return BoxDecoration(color: tint ?? bg100);
    }
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.elevationLevel = 2,
    this.padding,
    this.tint,
    this.onTap,
  });

  final Widget child;
  final int elevationLevel;
  final EdgeInsets? padding;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: AppDesignSystem.elevation(elevationLevel, tint: tint),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: content,
    );
  }
}
