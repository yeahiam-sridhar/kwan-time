import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/summary_provider.dart';
import '../../../../core/theme/kwan_theme.dart';
import '../../../../shared/widgets/count_up_text.dart';

class FreeTimeGauge extends ConsumerStatefulWidget {
  const FreeTimeGauge({super.key});

  @override
  ConsumerState<FreeTimeGauge> createState() => _FreeTimeGaugeState();
}

class _FreeTimeGaugeState extends ConsumerState<FreeTimeGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  double _targetSweep = 0;
  int _freeHours = 0;
  Color _gaugeColor = KwanColors.free;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(threeMonthSummaryProvider);
    return summaryAsync.when(
      data: (summaries) {
        if (summaries.isEmpty) {
          return const SizedBox.shrink();
        }

        final current = summaries.first;
        final monthDate = DateTime.parse('${current.month}-01');
        final totalMinutes = DateTime(monthDate.year, monthDate.month + 1, 1).difference(monthDate).inMinutes;
        final percent = totalMinutes == 0 ? 0.0 : (current.freeTimeMinutes / totalMinutes).clamp(0.0, 1.0);

        _targetSweep = (240 * math.pi / 180) * percent;
        _freeHours = current.freeTimeHours.round();
        _gaugeColor = _colorForPercent(percent);
        if (!_controller.isAnimating && _controller.value == 0) {
          _controller.forward();
        }

        return SizedBox(
          width: 150,
          height: 150,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => CustomPaint(
              painter: _GaugePainter(
                sweepAngle: _targetSweep * _animation.value,
                gaugeColor: _gaugeColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CountUpText(
                      value: _freeHours,
                      suffix: 'h',
                      style: KwanText.number,
                    ),
                    const Text('free time', style: KwanText.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        width: 150,
        height: 150,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Color _colorForPercent(double percent) {
    if (percent > 0.5) {
      return KwanColors.free;
    }
    if (percent >= 0.2) {
      return KwanColors.inProgress;
    }
    return KwanColors.cancelled;
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.sweepAngle,
    required this.gaugeColor,
  });

  final double sweepAngle;
  final Color gaugeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = 150 * math.pi / 180;
    const maxSweep = 240 * math.pi / 180;

    canvas.drawArc(
      rect,
      startAngle,
      maxSweep,
      false,
      Paint()
        ..color = KwanColors.bgCardBorder
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (sweepAngle <= 0) {
      return;
    }

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = gaugeColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.sweepAngle != sweepAngle || oldDelegate.gaugeColor != gaugeColor;
}
