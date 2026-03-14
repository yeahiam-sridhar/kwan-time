import 'package:flutter/material.dart';

import '../../core/theme/kwan_theme.dart';

class CountUpText extends StatefulWidget {
  const CountUpText({
    required this.value,
    super.key,
    this.duration = const Duration(milliseconds: 700),
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  final int value;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    )..addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.value <= 0) {
        return;
      }
      _buildAnimation(begin: 0, end: widget.value.toDouble());
      _controller.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(covariant CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      if (widget.value <= 0) {
        _buildAnimation(begin: 0, end: 0);
        _controller.reset();
        return;
      }
      _buildAnimation(
        begin: oldWidget.value.toDouble(),
        end: widget.value.toDouble(),
      );
      _controller.forward(from: 0);
    }
  }

  void _buildAnimation({required double begin, required double end}) {
    _animation = Tween<double>(
      begin: begin,
      end: end,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        '${widget.prefix}${_animation.value.round()}${widget.suffix}',
        style: widget.style ?? KwanText.number,
      );
}
