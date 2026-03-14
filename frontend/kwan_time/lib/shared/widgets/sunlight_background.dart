import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/kwan_theme.dart';

class SunlightBackground extends StatefulWidget {
  const SunlightBackground({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<SunlightBackground> createState() => _SunlightBackgroundState();
}

class _SunlightBackgroundState extends State<SunlightBackground> {
  late int _fromHour;
  late int _toHour;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fromHour = DateTime.now().hour;
    _toHour = _fromHour;
    _timer = Timer.periodic(const Duration(minutes: 10), (_) {
      final nowHour = DateTime.now().hour;
      if (nowHour != _toHour && mounted) {
        setState(() {
          _fromHour = _toHour;
          _toHour = nowHour;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = KwanGradients.sunlight(_fromHour);
    final to = KwanGradients.sunlight(_toHour);

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('$_fromHour-$_toHour'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(seconds: 3),
      curve: Curves.easeInOut,
      builder: (context, t, child) {
        final gradient = Gradient.lerp(from, to, t) ?? to;
        return DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
