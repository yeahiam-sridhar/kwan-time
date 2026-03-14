// ═══════════════════════════════════════════════════════════════════════════
// KWAN-TIME v2.0 — Spring Physics Simulation
// Agent 8: Physics Engine
//
// Implements realistic spring dynamics with damping for smooth animations.
// Follows Hooke's law (F = -kx) with velocity-based damping (F = -cv).
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Configuration for spring physics behavior
class SpringConfig {
  const SpringConfig({
    this.stiffness = 0.3,
    this.damping = 0.85,
    this.mass = 1.0,
    this.velocityThreshold = 0.001,
    this.positionThreshold = 0.001,
    this.maxVelocity = 10.0,
  });

  /// Spring stiffness constant (0.0 to infinity)
  /// Lower = slower oscillation, higher = faster oscillation
  /// Typical: 0.1 (slow), 0.3 (medium), 0.6 (bouncy)
  final double stiffness;

  /// Damping ratio (0.0 to infinity)
  /// < 1.0 = underdamped (overshoots, bounces)
  /// = 1.0 = critically damped (settles fastest without overshoot)
  /// > 1.0 = overdamped (slow, no bounce)
  /// Typical: 0.7 (smooth), 0.85 (natural), 1.0 (creepy)
  final double damping;

  /// Mass factor (affects acceleration response)
  /// Lower mass = faster response to forces
  /// Typical: 0.3 (responsive), 1.0 (normal), 2.0 (slow)
  final double mass;

  /// Velocity threshold below which motion is considered settled (px/ms)
  final double velocityThreshold;

  /// Position threshold below which motion is considered settled (px)
  final double positionThreshold;

  /// Maximum speed (px/ms) to prevent excessive velocities
  final double maxVelocity;

  /// Preset: Bouncy spring (responsive, energetic)
  static const SpringConfig bouncy = SpringConfig(
    stiffness: 0.6,
    damping: 0.6,
    mass: 0.3,
    velocityThreshold: 0.001,
    positionThreshold: 0.001,
    maxVelocity: 10,
  );

  /// Preset: Smooth spring (natural, easing)
  static const SpringConfig smooth = SpringConfig(
    stiffness: 0.3,
    damping: 0.85,
    mass: 1,
    velocityThreshold: 0.001,
    positionThreshold: 0.001,
    maxVelocity: 8,
  );

  /// Preset: Molasses spring (slow, deliberate)
  static const SpringConfig molasses = SpringConfig(
    stiffness: 0.1,
    damping: 0.95,
    mass: 2,
    velocityThreshold: 0.001,
    positionThreshold: 0.001,
    maxVelocity: 4,
  );

  /// Preset: Gentle spring (subtle, elegant)
  static const SpringConfig gentle = SpringConfig(
    stiffness: 0.15,
    damping: 0.8,
    mass: 0.8,
    velocityThreshold: 0.001,
    positionThreshold: 0.001,
    maxVelocity: 6,
  );
}

/// Single-axis spring physics simulation
/// Tracks position, velocity, and acceleration over time
class SpringAxis {
  SpringAxis({
    double initialPosition = 0.0,
    double initialTarget = 0.0,
    SpringConfig? config,
  })  : config = config ?? SpringConfig.smooth,
        _position = initialPosition,
        _target = initialTarget;

  /// Current position (pixels)
  double _position = 0;

  /// Target position (pixels)
  double _target = 0;

  /// Current velocity (pixels/ms)
  double _velocity = 0;

  /// Spring configuration
  final SpringConfig config;

  /// Whether spring has settled (velocity and displacement both below thresholds)
  bool _isSettled = true;

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Current position (px)
  double get position => _position;

  /// Current velocity (px/ms)
  double get velocity => _velocity;

  /// Target position (px)
  double get target => _target;

  /// Displacement from target (px)
  double get displacement => _position - _target;

  /// Whether spring is at rest
  bool get isSettled => _isSettled;

  // ─────────────────────────────────────────────────────────────────────────
  // SIMULATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Advance simulation by deltaTime milliseconds
  /// Uses Velocity Verlet integration for numerical stability
  ///
  /// Physics:
  /// - Spring force: F = -k * displacement
  /// - Damping force: F = -c * velocity
  /// - Acceleration: a = F / m
  /// - Integration: position += velocity * dt; velocity += acceleration * dt
  void update(double deltaTime) {
    // Check if already settled
    if (_isSettled && (target - _position).abs() < 0.01) {
      return;
    }

    // Calculate forces (in px/ms²)
    final displacement = _position - _target;
    final springForce = -config.stiffness * displacement;
    final dampingForce = -config.damping * _velocity;
    final totalForce = springForce + dampingForce;

    // Calculate acceleration (F = ma implies a = F/m)
    final acceleration = totalForce / config.mass;

    // Semi-implicit Euler integration
    // Update velocity first, then position (more stable than explicit Euler)
    _velocity += acceleration * deltaTime;

    // Clamp velocity to prevent numerical instability
    if (_velocity.abs() > config.maxVelocity) {
      _velocity = _velocity > 0 ? config.maxVelocity : -config.maxVelocity;
    }

    // Update position
    _position += _velocity * deltaTime;

    // Check settlement: both velocity and displacement must be small
    final velocitySmall = _velocity.abs() < config.velocityThreshold;
    final positionSmall = displacement.abs() < config.positionThreshold;

    _isSettled = velocitySmall && positionSmall;

    // If settled, snap to target to prevent jitter
    if (_isSettled) {
      _position = _target;
      _velocity = 0.0;
    }
  }

  /// Set target position (spring animates toward this)
  void setTarget(double target) {
    _target = target;
    _isSettled = false;
  }

  /// Instantly jump to position without animation
  void setPosition(double position) {
    _position = position;
    _velocity = 0.0;
    _isSettled = true;
  }

  /// Apply impulse (sudden velocity change) in px/ms
  void applyImpulse(double velocityDelta) {
    _velocity += velocityDelta;
    _isSettled = false;
  }

  /// Reset to target position with zero velocity
  void reset() {
    _position = _target;
    _velocity = 0.0;
    _isSettled = true;
  }
}

/// 2D spring physics (Offset-based)
/// Useful for dragging, floating animation, elasticity
class Spring2D {
  Spring2D({
    double initialX = 0.0,
    double initialY = 0.0,
    double targetX = 0.0,
    double targetY = 0.0,
    SpringConfig? config,
  }) : config = config ?? SpringConfig.smooth {
    x = SpringAxis(
      initialPosition: initialX,
      initialTarget: targetX,
      config: this.config,
    );
    y = SpringAxis(
      initialPosition: initialY,
      initialTarget: targetY,
      config: this.config,
    );
  }

  /// X-axis physics
  late final SpringAxis x;

  /// Y-axis physics
  late final SpringAxis y;

  /// Spring configuration (shared between axes)
  final SpringConfig config;

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Current position as Offset
  Offset get position => Offset(x.position, y.position);

  /// Current velocity as Offset (px/ms)
  Offset get velocity => Offset(x.velocity, y.velocity);

  /// Target position as Offset
  Offset get target => Offset(x.target, y.target);

  /// Displacement from target as Offset
  Offset get displacement => Offset(x.displacement, y.displacement);

  /// Magnitude of displacement (distance to target in px)
  double get distanceToTarget => math.sqrt(x.displacement * x.displacement + y.displacement * y.displacement);

  /// Whether both axes are settled
  bool get isSettled => x.isSettled && y.isSettled;

  // ─────────────────────────────────────────────────────────────────────────
  // SIMULATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Advance simulation by deltaTime milliseconds
  void update(double deltaTime) {
    x.update(deltaTime);
    y.update(deltaTime);
  }

  /// Set target position (both axes)
  void setTarget(Offset target) {
    x.setTarget(target.dx);
    y.setTarget(target.dy);
  }

  /// Set target position (separate X/Y)
  void setTargetXY(double targetX, double targetY) {
    x.setTarget(targetX);
    y.setTarget(targetY);
  }

  /// Instantly jump to position
  void setPosition(Offset position) {
    x.setPosition(position.dx);
    y.setPosition(position.dy);
  }

  /// Apply impulse (velocity change)
  void applyImpulse(Offset velocityDelta) {
    x.applyImpulse(velocityDelta.dx);
    y.applyImpulse(velocityDelta.dy);
  }

  /// Reset to target position
  void reset() {
    x.reset();
    y.reset();
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// Usage Example:
///
/// final spring = Spring2D(
///   initialX: 0,
///   initialY: 0,
///   config: SpringConfig.smooth,
/// );
///
/// // In animation loop:
/// spring.setTarget(Offset(100, 200));
/// while (!spring.isSettled) {
///   spring.update(16.67); // ~60 FPS
///   drawAtPosition(spring.position);
/// }
/// ═══════════════════════════════════════════════════════════════════════════
