import 'package:flutter/material.dart';

// ============================================================================
// Floating Card Animation Widget
// ============================================================================

class FloatingCardAnimation extends StatefulWidget {
  const FloatingCardAnimation({
    required this.child,
    super.key,
    this.enablePhysics = true,
    this.floatHeight = 8.0,
    this.animationDuration = const Duration(milliseconds: 600),
    this.onHover,
    this.onTap,
  });
  final Widget child;
  final bool enablePhysics;
  final double floatHeight;
  final Duration animationDuration;
  final VoidCallback? onHover;
  final VoidCallback? onTap;

  @override
  State<FloatingCardAnimation> createState() => _FloatingCardAnimationState();
}

class _FloatingCardAnimationState extends State<FloatingCardAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _floatAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _floatAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(0, -widget.floatHeight / MediaQuery.of(context).size.height),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter(PointerEvent event) {
    if (!_isHovered) {
      _isHovered = true;
      _controller.forward();
      widget.onHover?.call();
    }
  }

  void _onExit(PointerEvent event) {
    if (_isHovered) {
      _isHovered = false;
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: _onEnter,
        onExit: _onExit,
        child: GestureDetector(
          onTap: widget.onTap,
          child: SlideTransition(
            position: _floatAnimation,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      0.08 + (_controller.value * 0.12),
                    ),
                    blurRadius: 8 + (_controller.value * 16),
                    offset: Offset(0, 4 + (_controller.value * 4)),
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        ),
      );
}

// ============================================================================
// Event Creation Animation Widget
// ============================================================================

class EventCreationAnimation extends StatefulWidget {
  const EventCreationAnimation({
    super.key,
    this.duration = const Duration(milliseconds: 800),
    this.onComplete,
    this.showAnimation = true,
  });
  final Duration duration;
  final VoidCallback? onComplete;
  final bool showAnimation;

  @override
  State<EventCreationAnimation> createState() => _EventCreationAnimationState();
}

class _EventCreationAnimationState extends State<EventCreationAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    if (widget.showAnimation) {
      _controller.forward().then((_) {
        widget.onComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(),
        ),
      );
}

// ============================================================================
// Drag Gesture Animation Widget
// ============================================================================

class DragGestureAnimation extends StatefulWidget {
  const DragGestureAnimation({
    required this.child,
    super.key,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.enableAnimation = true,
  });
  final Widget child;
  final VoidCallback? onDragStart;
  final Function(Offset)? onDragUpdate;
  final VoidCallback? onDragEnd;
  final bool enableAnimation;

  @override
  State<DragGestureAnimation> createState() => _DragGestureAnimationState();
}

class _DragGestureAnimationState extends State<DragGestureAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _dragOffset = Offset.zero;
  // Reserved for future use

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setupReturnAnimation() {
    // TODO: Implement return animation in future
    // _returnAnimation = Tween<Offset>(
    //   begin: _dragOffset,
    //   end: Offset.zero,
    // ).animate(
    //   CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    // );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onPanStart: (_) {
          widget.onDragStart?.call();
        },
        onPanUpdate: (details) {
          setState(() {
            _dragOffset = details.delta;
          });
          widget.onDragUpdate?.call(details.delta);
        },
        onPanEnd: (details) {
          _setupReturnAnimation();
          _controller.forward(from: 0).then((_) {
            setState(() {
              _dragOffset = Offset.zero;
            });
            widget.onDragEnd?.call();
          });
        },
        child: Transform.translate(
          offset: _dragOffset,
          child: widget.child,
        ),
      );
}

// ============================================================================
// Dashboard Refresh Animation Widget
// ============================================================================

class DashboardRefreshAnimation extends StatefulWidget {
  const DashboardRefreshAnimation({
    required this.isRefreshing,
    super.key,
    this.duration = const Duration(milliseconds: 2000),
    this.size = 24.0,
  });
  final bool isRefreshing;
  final Duration duration;
  final double size;

  @override
  State<DashboardRefreshAnimation> createState() => _DashboardRefreshAnimationState();
}

class _DashboardRefreshAnimationState extends State<DashboardRefreshAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    if (widget.isRefreshing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(DashboardRefreshAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRefreshing && !oldWidget.isRefreshing) {
      _controller.repeat();
    } else if (!widget.isRefreshing && oldWidget.isRefreshing) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _controller,
        child: Icon(
          Icons.refresh_rounded,
          size: widget.size,
        ),
      );
}

// ============================================================================
// Bounce Animation Widget (for buttons)
// ============================================================================

class BounceAnimation extends StatefulWidget {
  const BounceAnimation({
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 200),
    this.onTap,
  });
  final Widget child;
  final Duration duration;
  final VoidCallback? onTap;

  @override
  State<BounceAnimation> createState() => _BounceAnimationState();
}

class _BounceAnimationState extends State<BounceAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.bounceInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) {
      _controller.reverse();
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _handleTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      );
}

// ============================================================================
// Shimmer Loading Animation
// ============================================================================

class ShimmerAnimation extends StatefulWidget {
  const ShimmerAnimation({
    required this.width,
    required this.height,
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });
  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<ShimmerAnimation> createState() => _ShimmerAnimationState();
}

class _ShimmerAnimationState extends State<ShimmerAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: Colors.grey.withOpacity(0.1),
        ),
        child: Stack(
          children: [
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  (_shimmerAnimation.value * widget.width) - widget.width,
                  0,
                ),
                child: Container(
                  width: widget.width / 3,
                  height: widget.height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0),
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
