// ═══════════════════════════════════════════════════════════════════════════
// KWAN-TIME v2.0 — Gooey Dragger Physics
// Agent 8: Physics Engine
//
// Creates elastic blob morphing effect when dragging elements.
// Stretches between original position and drag position with curve continuity.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'spring_physics.dart';

/// Gooey dragger configuration
class GooeyConfig {
  const GooeyConfig({
    this.maxStretchDistance = 150.0,
    this.elasticity = 0.8,
    this.baseDiameter = 60.0,
    SpringConfig? springConfig,
  }) : springConfig = springConfig ?? SpringConfig.smooth;

  /// Maximum stretch distance before blob separates (px)
  /// Larger = stickier blob that follows further
  final double maxStretchDistance;

  /// Elasticity factor (0.0 to 1.0)
  /// Affects how quickly blob returns to roundness
  final double elasticity;

  /// Base diameter of blob (px)
  final double baseDiameter;

  /// Spring config for returning to rest position
  final SpringConfig springConfig;

  /// Preset: Stretchy blob (sticky, responsive)
  static const GooeyConfig stretchy = GooeyConfig(
    maxStretchDistance: 200,
    elasticity: 0.7,
    baseDiameter: 60,
  );

  /// Preset: Firm blob (less deformation)
  static const GooeyConfig firm = GooeyConfig(
    maxStretchDistance: 100,
    elasticity: 0.9,
    baseDiameter: 60,
  );

  /// Preset: Jiggly blob (loose, bouncy)
  static const GooeyConfig jiggly = GooeyConfig(
    maxStretchDistance: 250,
    elasticity: 0.5,
    baseDiameter: 60,
  );
}

/// Represents a blob control point for bezier curve rendering
class BlobPoint {
  BlobPoint({
    required this.anchor,
    required this.control1,
    required this.control2,
  });

  /// Anchor point position (on the blob outline)
  final Offset anchor;

  /// Control point 1 (for cubic bezier curve)
  final Offset control1;

  /// Control point 2 (for cubic bezier curve)
  final Offset control2;
}

/// Gooey dragger with elastic blob morphing
class GooeyDragger {
  GooeyDragger({
    Offset initialPosition = const Offset(0, 0),
    GooeyConfig? config,
  }) : config = config ?? const GooeyConfig() {
    _origin = Spring2D(
      initialX: initialPosition.dx,
      initialY: initialPosition.dy,
      targetX: initialPosition.dx,
      targetY: initialPosition.dy,
      config: this.config.springConfig,
    );
    _dragPosition = initialPosition;
    // _restPosition = initialPosition;
  }

  /// Origin point (where dragging started)
  late final Spring2D _origin;

  /// Current drag position
  late Offset _dragPosition;

  /// Target rest position after drag release
  // Reserved for future use

  /// Configuration
  final GooeyConfig config;

  /// Whether currently being dragged
  bool _isDragging = false;

  /// Blob is separated (too far from origin)
  bool _isSeparated = false;

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Current rest position (where blob settles)
  Offset get position => _origin.position;

  /// Position being dragged to
  Offset get dragPosition => _dragPosition;

  /// Whether blob is currently being dragged
  bool get isDragging => _isDragging;

  /// Whether blob has separated into two parts
  bool get isSeparated => _isSeparated;

  /// Distance from origin to drag position (px)
  double get stretchDistance => (position - _dragPosition).distance;

  /// Stretch ratio (0.0 to 1.0, where 1.0 = max stretch)
  double get stretchRatio => (stretchDistance / config.maxStretchDistance).clamp(0.0, 1.0);

  /// Displacement vector from origin to current drag position
  Offset get displacement => _dragPosition - position;

  // ─────────────────────────────────────────────────────────────────────────
  // DRAGGING
  // ─────────────────────────────────────────────────────────────────────────

  /// Start dragging from current position
  void startDrag(Offset startPosition) {
    _isDragging = true;
    _dragPosition = startPosition;
    _isSeparated = false;
  }

  /// Update drag position
  void updateDrag(Offset newPosition) {
    _dragPosition = newPosition;

    // Check if stretched beyond separation distance
    _isSeparated = stretchDistance > config.maxStretchDistance;
  }

  /// Release drag and animate back to position
  void releaseDrag(Offset releasePosition) {
    _isDragging = false;
    _dragPosition = releasePosition;
    _origin.setTarget(releasePosition);
  }

  /// Cancel drag and return to original position
  void cancelDrag() {
    _isDragging = false;
    _origin.reset();
    _dragPosition = _origin.position;
    _isSeparated = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PHYSICS SIMULATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Update physics simulation (call in animation loop)
  void update(double deltaTime) {
    if (!_isDragging) {
      _origin.update(deltaTime);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BLOB MORPHING GEOMETRY
  // ─────────────────────────────────────────────────────────────────────────

  /// Calculate blob radius at angle (from origin)
  /// Squashes toward drag direction, bulges perpendicular
  double getBlobRadiusAtAngle(double angleRadians) {
    if (_isSeparated) {
      return config.baseDiameter / 2; // Circle if separated
    }

    // Vector from origin to drag position (stretch direction)
    final stretchVector = _dragPosition - position;
    final stretchLength = stretchVector.distance;

    if (stretchLength == 0) {
      return config.baseDiameter / 2; // Perfect circle at rest
    }

    // Normalize stretch vector
    final stretchAngle = math.atan2(stretchVector.dy, stretchVector.dx);
    final relativeAngle = angleRadians - stretchAngle;

    // Deformation factor increases with stretch
    final deformation = stretchRatio * config.elasticity;

    // Squash (compress) along stretch direction
    final squashAmount = config.baseDiameter / 2 * (1.0 - deformation * 0.3);

    // Bulge (expand) perpendicular to stretch
    final bulgeAmount = config.baseDiameter / 2 * (1.0 + deformation * 0.4);

    // Use cos² for smooth transitions
    final cosSquared = math.cos(relativeAngle) * math.cos(relativeAngle);
    final radius = squashAmount * cosSquared + bulgeAmount * (1.0 - cosSquared);

    return radius;
  }

  /// Calculate blob outline points for path drawing
  /// Returns list of anchor points with control points for bezier curves
  List<BlobPoint> getBlobOutline({int pointCount = 32}) {
    final points = <BlobPoint>[];
    final angleStep = (2 * math.pi) / pointCount;

    for (var i = 0; i < pointCount; i++) {
      final angle = i * angleStep;
      final radius = getBlobRadiusAtAngle(angle);

      // Anchor point on blob outline
      final anchor = position +
          Offset(
            radius * math.cos(angle),
            radius * math.sin(angle),
          );

      // Control points for smooth bezier curve (1/3 of radius along tangent)
      final controlDist = radius * 0.33;
      final nextAngle = (i + 1) * angleStep;
      final prevAngle = (i - 1) * angleStep;

      final control1 = position +
          Offset(
            controlDist * math.cos(nextAngle),
            controlDist * math.sin(nextAngle),
          );

      final control2 = position +
          Offset(
            controlDist * math.cos(prevAngle),
            controlDist * math.sin(prevAngle),
          );

      points.add(BlobPoint(
        anchor: anchor,
        control1: control1,
        control2: control2,
      ));
    }

    return points;
  }

  /// Get drag handle position (circle at drag endpoint)
  Offset getDragHandlePosition() {
    if (_isSeparated) {
      return _dragPosition;
    }

    // Extrapolate along stretch vector
    final stretchVector = _dragPosition - position;
    final radius = config.baseDiameter / 2;
    final handlePos = stretchVector.distance > 0 ? (stretchVector / stretchVector.distance) * radius : Offset.zero;

    return position + handlePos;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESET
  // ─────────────────────────────────────────────────────────────────────────

  /// Reset to position with zero drag
  void reset(Offset position) {
    _origin.setPosition(position);
    _dragPosition = position;
    _isDragging = false;
    _isSeparated = false;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// Usage Example:
///
/// final gooey = GooeyDragger(
///   initialPosition: Offset(100, 100),
///   config: GooeyConfig.stretchy,
/// );
///
/// // During drag:
/// gooey.startDrag(Offset(100, 100));
///
/// // On pointer move:
/// gooey.updateDrag(Offset(150, 180));
///
/// // On release:
/// gooey.releaseDrag(Offset(150, 180));
///
/// // In animation loop:
/// gooey.update(deltaTime);
/// final outline = gooey.getBlobOutline();
/// // Render blob using outline points with bezier curves
/// ═══════════════════════════════════════════════════════════════════════════
