import 'package:flutter/material.dart';

abstract final class KwanColors {
  static const Color surface      = Color(0xFF0D1B3E);
  static const Color surfaceCard  = Color(0xFF112247);
  static const Color primary      = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF0288D1);
  static const Color admin        = Color(0xFFF9A825);
  static const Color member       = Color(0xFF00ACC1);
  static const Color viewer       = Color(0xFF546E7A);
  static const Color success      = Color(0xFF43A047);
  static const Color error        = Color(0xFFC62828);
  static const Color warning      = Color(0xFFF57F17);

  static Color white(double opacity) => Colors.white.withOpacity(opacity);
  static Color fromHex(String hex) =>
      Color(int.parse('FF$hex', radix: 16));
}
