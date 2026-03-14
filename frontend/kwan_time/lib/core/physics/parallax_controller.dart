// ═══════════════════════════════════════════════════════════════════════════
// KWAN-TIME v2.0 — Parallax Controller
// Agent 8: Physics Engine
//
// Creates depth scrolling effect by moving layers at different speeds.
// Used in calendar views, dashboard, and floating backgrounds.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Configuration for a parallax layer
class ParallaxLayer {
  const ParallaxLayer({
    required this.id,
    required this.depthFactor,
    this.opacity = 1.0,
    this.parallaxX = false,
    this.parallaxY = true,
  });

  /// Unique identifier for this layer
  final String id;

  /// Depth factor (0.0 = moves with scroll, 1.0 = stationary)
  /// Standard: 0.0 (foreground), 0.5 (mid), 0.9 (background)
  final double depthFactor;

  /// Opacity of this layer (0.0 to 1.0)
  final double opacity;

  /// Whether to horizontally parallax as well
  final bool parallaxX;

  /// Whether to vertically parallax
  final bool parallaxY;

  /// Foreground layer (moves with scroll at 100%)
  static const ParallaxLayer foreground = ParallaxLayer(
    id: 'foreground',
    depthFactor: 0,
    parallaxX: true,
    parallaxY: true,
  );

  /// Midground layer (moves at 50% scroll speed)
  static const ParallaxLayer midground = ParallaxLayer(
    id: 'midground',
    depthFactor: 0.5,
    parallaxX: false,
    parallaxY: true,
  );

  /// Background layer (barely moves)
  static const ParallaxLayer background = ParallaxLayer(
    id: 'background',
    depthFactor: 0.9,
    parallaxX: false,
    parallaxY: false,
  );

  /// Custom layer with specified depth
  ParallaxLayer withDepth(double depth) => ParallaxLayer(
        id: id,
        depthFactor: depth,
        opacity: opacity,
        parallaxX: parallaxX,
        parallaxY: parallaxY,
      );
}

/// Track position of a single parallax layer
class _LayerState {
  _LayerState(this.layer);

  /// Layer configuration
  final ParallaxLayer layer;

  /// Rendered offset (screen position)
  Offset offset = Offset.zero;
}

/// Parallax controller managing multiple depth layers
class ParallaxController {
  ParallaxController({
    this.maxOffset = 2000.0,
  }) : _totalScroll = Offset.zero;

  /// Active parallax layers
  final Map<String, _LayerState> _layers = {};

  /// Total scroll offset (in any direction)
  late Offset _totalScroll;

  /// Viewport size (for bounds calculations)
  // Reserved for future use

  /// Maximum safe parallax offset to prevent jitter
  final double maxOffset;

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  /// Add a parallax layer
  void addLayer(ParallaxLayer layer) {
    _layers[layer.id] = _LayerState(layer);
  }

  /// Add multiple layers at once
  void addLayers(List<ParallaxLayer> layers) {
    for (final layer in layers) {
      addLayer(layer);
    }
  }

  /// Remove a layer by ID
  void removeLayer(String id) {
    _layers.remove(id);
  }

  /// Get layer by ID
  ParallaxLayer? getLayer(String id) => _layers[id]?.layer;

  /// Get all layers
  List<ParallaxLayer> get layers => _layers.values.map((s) => s.layer).toList();

  /// Clear all layers
  void clear() {
    _layers.clear();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCROLL UPDATES
  // ─────────────────────────────────────────────────────────────────────────

  /// Set viewport size (needed for parallax calculations)
  void setViewportSize(Size size) {
    // _viewportSize = size;
  }

  /// Update scroll position
  /// [scrollOffset] - total scroll accumulated in page coordinates
  void updateScroll(Offset scrollOffset) {
    _totalScroll = Offset(
      scrollOffset.dx.clamp(-maxOffset, maxOffset),
      scrollOffset.dy.clamp(-maxOffset, maxOffset),
    );

    // Update all layers
    for (final entry in _layers.entries) {
      final state = entry.value;
      final layer = state.layer;

      // Calculate offset based on depth factor
      // depth 0.0 = full movement
      // depth 1.0 = no movement (stationary)
      final depthResistance = 1.0 - layer.depthFactor;

      var layerX = 0.0;
      var layerY = 0.0;

      if (layer.parallaxX) {
        layerX = _totalScroll.dx * depthResistance;
      }

      if (layer.parallaxY) {
        layerY = _totalScroll.dy * depthResistance;
      }

      state.offset = Offset(layerX, layerY);
    }
  }

  /// Update vertical scroll only (common for calendar/list)
  void updateVerticalScroll(double scrollY) {
    updateScroll(Offset(_totalScroll.dx, scrollY));
  }

  /// Update horizontal scroll only
  void updateHorizontalScroll(double scrollX) {
    updateScroll(Offset(scrollX, _totalScroll.dy));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Get offset for a specific layer
  Offset getLayerOffset(String layerId) => _layers[layerId]?.offset ?? Offset.zero;

  /// Get current total scroll
  Offset get totalScroll => _totalScroll;

  /// Get vertical scroll amount
  double get scrollY => _totalScroll.dy;

  /// Get horizontal scroll amount
  double get scrollX => _totalScroll.dx;

  // ─────────────────────────────────────────────────────────────────────────
  // EASE-IN-OUT SCROLL (for smooth transition)
  // ─────────────────────────────────────────────────────────────────────────

  /// Animate scroll to position over duration
  /// Returns animation controller for integration with Flutter animations
  AnimationController createScrollAnimation({
    required Offset fromOffset,
    required Offset toOffset,
    required Duration duration,
    required TickerProvider vsync,
    Curve curve = Curves.easeInOut,
  }) {
    final controller = AnimationController(
      duration: duration,
      vsync: vsync,
    );

    final animation = Tween<Offset>(
      begin: fromOffset,
      end: toOffset,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: curve,
    ));

    animation.addListener(() {
      updateScroll(animation.value);
    });

    return controller;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESET
  // ─────────────────────────────────────────────────────────────────────────

  /// Reset scroll to origin
  void reset() {
    updateScroll(Offset.zero);
  }

  /// Reset scroll with animation
  AnimationController resetWithAnimation({
    required Duration duration,
    required TickerProvider vsync,
  }) =>
      createScrollAnimation(
        fromOffset: _totalScroll,
        toOffset: Offset.zero,
        duration: duration,
        vsync: vsync,
        curve: Curves.easeOut,
      );
}

/// ═══════════════════════════════════════════════════════════════════════════
/// Parallax Widget Helper
///
/// Wraps a widget with parallax transformation based on scroll offset
/// ═══════════════════════════════════════════════════════════════════════════

class ParallaxWidget extends StatelessWidget {
  const ParallaxWidget({
    required this.layerId,
    required this.controller,
    required this.child,
    super.key,
    this.useTransform = true,
  });

  /// Layer ID to apply parallax to
  final String layerId;

  /// Parallax controller
  final ParallaxController controller;

  /// Child widget to transform
  final Widget child;

  /// Whether to use offset or transform
  /// Offset = applied to Transform.translate (GPU accelerated)
  /// Default: true
  final bool useTransform;

  @override
  Widget build(BuildContext context) {
    final offset = controller.getLayerOffset(layerId);
    final layer = controller.getLayer(layerId);

    if (useTransform) {
      return Transform.translate(
        offset: offset,
        child: Opacity(
          opacity: layer?.opacity ?? 1.0,
          child: child,
        ),
      );
    } else {
      // Fallback: position relative
      return Positioned(
        left: offset.dx,
        top: offset.dy,
        child: Opacity(
          opacity: layer?.opacity ?? 1.0,
          child: child,
        ),
      );
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// Usage Example:
///
/// class ParallaxCalendar extends StatefulWidget {
///   @override
///   _ParallaxCalendarState createState() => _ParallaxCalendarState();
/// }
///
/// class _ParallaxCalendarState extends State<ParallaxCalendar> {
///   late final ParallaxController parallax;
///
///   @override
///   void initState() {
///     super.initState();
///     parallax = ParallaxController();
///     parallax.addLayers([
///       ParallaxLayer.background,
///       ParallaxLayer.midground,
///       ParallaxLayer.foreground,
///     ]);
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return NotificationListener<ScrollUpdateNotification>(
///       onNotification: (notification) {
///         parallax.updateVerticalScroll(notification.metrics.pixels);
///         return false;
///       },
///       child: ListView(
///         children: [
///           ParallaxWidget(
///             layerId: 'background',
///             controller: parallax,
///             child: BackgroundGradient(),
///           ),
///           ParallaxWidget(
///             layerId: 'midground',
///             controller: parallax,
///             child: FloatingCards(),
///           ),
///           ParallaxWidget(
///             layerId: 'foreground',
///             controller: parallax,
///             child: CalendarGrid(),
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ═══════════════════════════════════════════════════════════════════════════
