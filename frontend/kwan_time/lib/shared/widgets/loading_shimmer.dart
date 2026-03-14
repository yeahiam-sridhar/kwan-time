import 'package:flutter/material.dart';

import 'glass_card.dart';

class LoadingShimmer extends StatefulWidget {
  const LoadingShimmer({
    required this.width,
    required this.height,
    super.key,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (_controller.value * 2), 0),
              end: Alignment(1.0 + (_controller.value * 2), 0),
              colors: const [
                Color(0x1AFFFFFF),
                Color(0x33FFFFFF),
                Color(0x1AFFFFFF),
              ],
            ),
          ),
        ),
      );
}

class LoadingShimmerCard extends StatelessWidget {
  const LoadingShimmerCard({
    super.key,
    this.rows = 6,
  });

  final int rows;

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LoadingShimmer(width: 140, height: 18, radius: 6),
            const SizedBox(height: 12),
            for (var i = 0; i < rows; i++) ...[
              const LoadingShimmerRow(),
              if (i != rows - 1) const SizedBox(height: 6),
            ],
          ],
        ),
      );
}

class LoadingShimmerRow extends StatelessWidget {
  const LoadingShimmerRow({
    super.key,
    this.height = 28,
  });

  final double height;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          LoadingShimmer(
            width: 64,
            height: height,
            radius: 6,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LoadingShimmer(
              width: double.infinity,
              height: height,
              radius: 6,
            ),
          ),
        ],
      );
}
