import 'package:flutter/material.dart';

class KwanColors {
  KwanColors._();

  static const Color bg = Color(0xFF080D1A);
  static const Color bgCard = Color(0x1AFFFFFF);
  static const Color bgCardHover = Color(0x26FFFFFF);
  static const Color bgCardBorder = Color(0x33FFFFFF);
  static const Color bgDivider = Color(0x1AFFFFFF);

  static const Color online = Color(0xFF4A90E2);
  static const Color inPerson = Color(0xFFE07B3C);
  static const Color free = Color(0xFF4CAF50);
  static const Color booked = Color(0xFF2E7D32);
  static const Color cancelled = Color(0xFFD32F2F);
  static const Color notStarted = Color(0xFF9E9E9E);
  static const Color inProgress = Color(0xFFFFC107);
  static const Color completed = Color(0xFF00BCD4);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted = Color(0x66FFFFFF);
  static const Color textDisabled = Color(0x33FFFFFF);

  static const Color accent = Color(0xFF4A90E2);
  static const Color accentGlow = Color(0x334A90E2);
  static const Color accentDim = Color(0x1A4A90E2);

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF4A90E2);

  static Color forType(String type) => switch (type) {
        'online' => online,
        'in_person' => inPerson,
        'free' => free,
        'booked' => booked,
        'cancelled' => cancelled,
        'in_progress' => inProgress,
        'completed' => completed,
        _ => notStarted,
      };

  static Color forStatus(String status) => switch (status) {
        'completed' => completed,
        'cancelled' => cancelled,
        'in_progress' => inProgress,
        'not_started' => notStarted,
        _ => notStarted,
      };
}

class KwanGlass {
  KwanGlass._();

  static BoxDecoration card({
    double radius = 20,
    double opacity = 0.10,
    Color? borderColor,
    List<BoxShadow>? shadows,
  }) =>
      BoxDecoration(
        color: Color.fromRGBO(255, 255, 255, opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? KwanColors.bgCardBorder,
          width: 1,
        ),
        boxShadow: shadows ??
            [
              BoxShadow(
                blurRadius: 30,
                spreadRadius: -5,
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ],
      );

  static BoxDecoration accentCard({double radius = 20}) => card(
        radius: radius,
        borderColor: KwanColors.accentGlow,
        shadows: [
          const BoxShadow(
            blurRadius: 40,
            spreadRadius: -5,
            color: KwanColors.accentGlow,
          ),
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withValues(alpha: 0.4),
          ),
        ],
      );
}

class KwanGradients {
  KwanGradients._();

  static RadialGradient sunlight(int hour) {
    const frames = [
      _SunFrame(
        hour: 0,
        cx: 0,
        cy: 0,
        r: 1.2,
        c1: Color(0xFF0A0F2E),
        c2: Color(0xFF050812),
      ),
      _SunFrame(
        hour: 6,
        cx: -0.7,
        cy: -0.7,
        r: 1.5,
        c1: Color(0xFFE8834A),
        c2: Color(0xFF0D1535),
      ),
      _SunFrame(
        hour: 12,
        cx: 0,
        cy: -1,
        r: 1.8,
        c1: Color(0xFF4A90E2),
        c2: Color(0xFF0A1428),
      ),
      _SunFrame(
        hour: 18,
        cx: 0.7,
        cy: -0.6,
        r: 1.5,
        c1: Color(0xFFE07B3C),
        c2: Color(0xFF1A0A28),
      ),
      _SunFrame(
        hour: 24,
        cx: 0,
        cy: 0,
        r: 1.2,
        c1: Color(0xFF0A0F2E),
        c2: Color(0xFF050812),
      ),
    ];

    var prev = 0;
    for (var i = 0; i < frames.length - 1; i++) {
      if (hour >= frames[i].hour && hour < frames[i + 1].hour) {
        prev = i;
        break;
      }
    }

    final a = frames[prev];
    final b = frames[prev + 1];
    final t = (hour - a.hour) / (b.hour - a.hour).toDouble();

    return RadialGradient(
      center: Alignment(
        a.cx + (b.cx - a.cx) * t,
        a.cy + (b.cy - a.cy) * t,
      ),
      radius: a.r + (b.r - a.r) * t,
      colors: [
        Color.lerp(a.c1, b.c1, t)!,
        Color.lerp(a.c2, b.c2, t)!,
      ],
    );
  }
}

class _SunFrame {
  const _SunFrame({
    required this.hour,
    required this.cx,
    required this.cy,
    required this.r,
    required this.c1,
    required this.c2,
  });

  final int hour;
  final double cx;
  final double cy;
  final double r;
  final Color c1;
  final Color c2;
}

class KwanText {
  KwanText._();

  static const TextStyle displayLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: KwanColors.textPrimary,
    letterSpacing: -0.5,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: KwanColors.textPrimary,
    letterSpacing: -0.3,
  );
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: KwanColors.textPrimary,
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: KwanColors.textPrimary,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: KwanColors.textPrimary,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: KwanColors.textSecondary,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: KwanColors.textMuted,
  );
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: KwanColors.textMuted,
    letterSpacing: 0.8,
  );
  static const TextStyle number = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: KwanColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle numberSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: KwanColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

class KwanTheme {
  KwanTheme._();

  static const Color darkBg = KwanColors.bg;
  static const Color darkCard = KwanColors.bgCard;
  static const Color textPrimary = KwanColors.textPrimary;
  static const Color textSecondary = KwanColors.textSecondary;
  static const Color divider = KwanColors.bgDivider;

  static const Color colorOnline = KwanColors.online;
  static const Color colorInPerson = KwanColors.inPerson;
  static const Color colorFree = KwanColors.free;
  static const Color colorBooked = KwanColors.booked;
  static const Color colorCancelled = KwanColors.cancelled;
  static const Color colorNotStarted = KwanColors.notStarted;
  static const Color colorInProgress = KwanColors.inProgress;
  static const Color colorCompleted = KwanColors.completed;

  static const Color neonBlue = KwanColors.accent;
  static const Color neonGreen = KwanColors.success;
  static const Color accentPurple = Color(0xFF7C4DFF);
  static const Color neonOrange = KwanColors.inPerson;

  static const Color glassText = KwanColors.textSecondary;
  static const Color darkGlass = Color(0x1A000000);
  static const Color glassStroke = KwanColors.bgCardBorder;
  static const Color glassBorder = KwanColors.bgCardBorder;

  static BoxDecoration glassCardDecoration({
    Color? color,
    BorderRadius? borderRadius,
  }) =>
      BoxDecoration(
        color: color ?? KwanColors.bgCard,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(
          color: KwanColors.bgCardBorder,
          width: 1,
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: KwanColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: KwanColors.accent,
          secondary: KwanColors.inPerson,
          surface: KwanColors.bgCard,
          error: KwanColors.error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: KwanColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: KwanColors.textPrimary),
          titleTextStyle: KwanText.titleLarge,
        ),
        cardTheme: CardThemeData(
          color: KwanColors.bgCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: KwanColors.bgCardBorder),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: KwanColors.accent,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            textStyle: KwanText.titleMedium,
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: KwanColors.accent),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: KwanColors.bgCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: KwanColors.bgCardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: KwanColors.bgCardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: KwanColors.accent, width: 1.5),
          ),
          hintStyle: KwanText.bodyMedium,
          labelStyle: KwanText.bodySmall,
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: KwanColors.bgCard,
          selectedColor: KwanColors.accentDim,
          side: BorderSide(color: KwanColors.bgCardBorder),
          labelStyle: KwanText.bodySmall,
          shape: StadiumBorder(),
        ),
        dividerTheme: const DividerThemeData(
          color: KwanColors.bgDivider,
          thickness: 1,
          space: 1,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF10172A),
          modalBackgroundColor: Color(0xFF10172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          elevation: 0,
        ),
      );

  static ThemeData get darkTheme => dark();
}
