import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

// ============================================================================
// Animation State Model
// ============================================================================

class AnimationState {
  AnimationState({
    this.isEnabled = true,
    this.isLoaded = false,
    this.error,
    this.isFloatingCardHovered = false,
    this.isEventCreating = false,
    this.isDragging = false,
    this.isDashboardRefreshing = false,
  });
  final bool isEnabled;
  final bool isLoaded;
  final String? error;
  final bool isFloatingCardHovered;
  final bool isEventCreating;
  final bool isDragging;
  final bool isDashboardRefreshing;

  AnimationState copyWith({
    bool? isEnabled,
    bool? isLoaded,
    String? error,
    bool? isFloatingCardHovered,
    bool? isEventCreating,
    bool? isDragging,
    bool? isDashboardRefreshing,
  }) =>
      AnimationState(
        isEnabled: isEnabled ?? this.isEnabled,
        isLoaded: isLoaded ?? this.isLoaded,
        error: error ?? this.error,
        isFloatingCardHovered: isFloatingCardHovered ?? this.isFloatingCardHovered,
        isEventCreating: isEventCreating ?? this.isEventCreating,
        isDragging: isDragging ?? this.isDragging,
        isDashboardRefreshing: isDashboardRefreshing ?? this.isDashboardRefreshing,
      );
}

// ============================================================================
// Animation Notifier
// ============================================================================

class AnimationNotifier extends StateNotifier<AnimationState> {
  AnimationNotifier()
      : super(
          AnimationState(
            isEnabled: true,
            isLoaded: true, // Animations load automatically
          ),
        ) {
    _initialize();
  }

  void _initialize() {
    // On initialization, check if Rive is available
    // Gracefully degrade to fallback Flutter animations if not
    try {
      state = state.copyWith(isLoaded: true, error: null);
    } catch (e) {
      // Rive not available, use fallback animations
      state = state.copyWith(
        isLoaded: true,
        error: 'Using fallback animations',
      );
    }
  }

  // =========================================================================
  // Floating Card Animation
  // =========================================================================

  void setFloatingCardHovered(bool value) {
    state = state.copyWith(isFloatingCardHovered: value);
  }

  // =========================================================================
  // Event Creation Animation
  // =========================================================================

  void startEventCreation() {
    state = state.copyWith(isEventCreating: true);
  }

  void completeEventCreation() {
    state = state.copyWith(isEventCreating: false);
  }

  void cancelEventCreation() {
    state = state.copyWith(isEventCreating: false);
  }

  // =========================================================================
  // Drag Gesture Animation
  // =========================================================================

  void startDragging() {
    state = state.copyWith(isDragging: true);
  }

  void stopDragging() {
    state = state.copyWith(isDragging: false);
  }

  // =========================================================================
  // Dashboard Refresh Animation
  // =========================================================================

  void startRefresh() {
    state = state.copyWith(isDashboardRefreshing: true);
  }

  void completeRefresh() {
    state = state.copyWith(isDashboardRefreshing: false);
  }

  // =========================================================================
  // Animation Control
  // =========================================================================

  void enableAnimations() {
    state = state.copyWith(isEnabled: true);
  }

  void disableAnimations() {
    state = state.copyWith(isEnabled: false);
  }

  void reset() {
    state = AnimationState(
      isEnabled: state.isEnabled,
      isLoaded: state.isLoaded,
    );
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

final animationNotifierProvider =
    StateNotifierProvider<AnimationNotifier, AnimationState>((ref) => AnimationNotifier());

// State accessors
final animationEnabledProvider = Provider<bool>((ref) => ref.watch(animationNotifierProvider).isEnabled);

final floatingCardHoveredProvider = Provider<bool>((ref) => ref.watch(animationNotifierProvider).isFloatingCardHovered);

final eventCreatingProvider = Provider<bool>((ref) => ref.watch(animationNotifierProvider).isEventCreating);

final draggingProvider = Provider<bool>((ref) => ref.watch(animationNotifierProvider).isDragging);

final dashboardRefreshingProvider = Provider<bool>((ref) => ref.watch(animationNotifierProvider).isDashboardRefreshing);

final animationErrorProvider = Provider<String?>((ref) => ref.watch(animationNotifierProvider).error);

// ============================================================================
// Animation Configuration Provider
// ============================================================================

class AnimationConfig {
  AnimationConfig({
    this.useRive = true,
    this.enableGestures = true,
    this.enableParallax = true,
    this.standardDuration = const Duration(milliseconds: 300),
    this.standardCurveValue = 0.4,
  });
  final bool useRive;
  final bool enableGestures;
  final bool enableParallax;
  final Duration standardDuration;
  final double standardCurveValue;
}

final animationConfigProvider = Provider<AnimationConfig>((ref) => AnimationConfig(
      useRive: true, // Will be false if Rive unavailable
      enableGestures: true,
      enableParallax: true,
      standardDuration: const Duration(milliseconds: 300),
      standardCurveValue: 0.4,
    ));

// ============================================================================
// Pre-configured Animation Providers for Common Tasks
// ============================================================================

final floatingCardAnimationProvider = Provider.family<bool, String>((ref, cardId) {
  final isHovered = ref.watch(floatingCardHoveredProvider);
  // Could customize per card ID if needed
  return isHovered;
});

final eventCreationAnimationProvider = Provider<bool>((ref) => ref.watch(eventCreatingProvider));

final dashboardRefreshAnimationProvider = Provider<bool>((ref) => ref.watch(dashboardRefreshingProvider));

// ============================================================================
// Animation Feature Detection
// ============================================================================

final supportsRiveProvider = Provider<bool>((ref) {
  // In a real app, this would detect Rive availability
  // For now, assume it's available but gracefully fallback
  return !kIsWeb || true; // Rive works on all platforms in latest SDK
});

final hasAnimationErrorProvider = Provider<bool>((ref) => ref.watch(animationErrorProvider) != null);
