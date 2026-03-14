import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

// ============================================================================
// Animation Constants & Configuration
// ============================================================================

class RiveAnimations {
  // Asset paths for Rive animation files
  static const String floatingCardRiv = 'assets/rive/floating_card.riv';
  static const String eventCreationRiv = 'assets/rive/event_creation.riv';
  static const String dragGestureRiv = 'assets/rive/drag_gesture.riv';
  static const String dashboardRefreshRiv = 'assets/rive/dashboard_refresh.riv';
  static const String timePickerRiv = 'assets/rive/time_picker.riv';
  static const String bookingConfirmRiv = 'assets/rive/booking_confirm.riv';
  static const String errorStateRiv = 'assets/rive/error_state.riv';

  // State machine names within .riv files
  static const String floatingCardMachine = 'floating_card_states';
  static const String eventCreationMachine = 'event_creation_states';
  static const String dragGestureMachine = 'drag_gesture_states';
  static const String dashboardRefreshMachine = 'refresh_states';
  static const String timePickerMachine = 'picker_states';
  static const String bookingConfirmMachine = 'confirm_states';
  static const String errorStateMachine = 'error_states';

  // Input names for controlling state machines
  static const String stateInput = 'state';
  static const String progressInput = 'progress';
  static const String triggerInput = 'trigger';
  static const String intensityInput = 'intensity';
}

// ============================================================================
// Rive Animation Controller Wrapper
// ============================================================================

class RiveAnimationController {
  RiveAnimationController({
    required this.assetPath,
    required this.stateMachineName,
  });
  // Reserved for future use
  final String assetPath;
  final String stateMachineName;
  final ValueNotifier<bool> isLoaded = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);

  Future<void> initialize() async {
    try {
      // Load Rive file and initialize state machine
      final riveFile = await RiveFile.asset(assetPath);
      if (riveFile.artboards.isEmpty) {
        error.value = 'No artboards found in $assetPath';
        return;
      }

      isLoaded.value = true;
      error.value = null;
    } catch (e) {
      error.value = 'Failed to load animation: $e';
      isLoaded.value = false;
    }
  }

  // Control state machine inputs
  void setInput(String inputName, dynamic value) {
    // Implementation would set SMI input value
    // Requires access to StateMachineController
  }

  void triggerEvent(String eventName) {
    // Fire a trigger event in the state machine
  }

  void setProgress(double progress) {
    // Set animation progress (0.0 to 1.0)
  }

  void dispose() {
    isLoaded.dispose();
    error.dispose();
  }
}

// ============================================================================
// Floating Card Animation Controller
// ============================================================================

class FloatingCardAnimationController {
  FloatingCardAnimationController(Artboard artboard) {
    _controller = StateMachineController.fromArtboard(
      artboard,
      RiveAnimations.floatingCardMachine,
    )!;

    artboard.addController(_controller);

    // Get input references from state machine
    _isHovered = _controller.findInput<bool>('is_hovered') as SMIBool?;
    _isPressed = _controller.findInput<bool>('is_pressed') as SMIBool?;
    _floatIntensity = _controller.findInput<double>('float_intensity') as SMINumber?;
  }
  late StateMachineController _controller;
  late SMIBool? _isHovered;
  late SMIBool? _isPressed;
  late SMINumber? _floatIntensity;

  void setHovered(bool value) {
    _isHovered?.value = value;
  }

  void setPressed(bool value) {
    _isPressed?.value = value;
  }

  void setFloatIntensity(double value) {
    _floatIntensity?.value = value.clamp(0.0, 1.0);
  }

  void dispose() {
    _controller.dispose();
  }
}

// ============================================================================
// Event Creation Animation Controller
// ============================================================================

class EventCreationAnimationController {
  EventCreationAnimationController(Artboard artboard) {
    _controller = StateMachineController.fromArtboard(
      artboard,
      RiveAnimations.eventCreationMachine,
    )!;

    artboard.addController(_controller);

    _createTrigger = _controller.findInput<bool>('create_trigger') as SMITrigger?;
    _cancelTrigger = _controller.findInput<bool>('cancel_trigger') as SMITrigger?;
    _completionProgress = _controller.findInput<double>('progress') as SMINumber?;
  }
  late StateMachineController _controller;
  late SMITrigger? _createTrigger;
  late SMITrigger? _cancelTrigger;
  late SMINumber? _completionProgress;

  void triggerCreate() {
    _createTrigger?.fire();
  }

  void triggerCancel() {
    _cancelTrigger?.fire();
  }

  void setProgress(double value) {
    _completionProgress?.value = value.clamp(0.0, 1.0);
  }

  void dispose() {
    _controller.dispose();
  }
}

// ============================================================================
// Drag Gesture Animation Controller
// ============================================================================

class DragGestureAnimationController {
  DragGestureAnimationController(Artboard artboard) {
    _controller = StateMachineController.fromArtboard(
      artboard,
      RiveAnimations.dragGestureMachine,
    )!;

    artboard.addController(_controller);

    _isDragging = _controller.findInput<bool>('is_dragging') as SMIBool?;
    _dragDistance = _controller.findInput<double>('drag_distance') as SMINumber?;
    _dragVelocity = _controller.findInput<double>('drag_velocity') as SMINumber?;
  }
  late StateMachineController _controller;
  late SMIBool? _isDragging;
  late SMINumber? _dragDistance;
  late SMINumber? _dragVelocity;

  void setDragging(bool value) {
    _isDragging?.value = value;
  }

  void setDragDistance(double distance) {
    _dragDistance?.value = distance.clamp(-1.0, 1.0);
  }

  void setDragVelocity(double velocity) {
    _dragVelocity?.value = velocity.clamp(-1.0, 1.0);
  }

  void dispose() {
    _controller.dispose();
  }
}

// ============================================================================
// Dashboard Refresh Animation Controller
// ============================================================================

class DashboardRefreshAnimationController {
  DashboardRefreshAnimationController(Artboard artboard) {
    _controller = StateMachineController.fromArtboard(
      artboard,
      RiveAnimations.dashboardRefreshMachine,
    )!;

    artboard.addController(_controller);

    _startTrigger = _controller.findInput<bool>('start_refresh') as SMITrigger?;
    _completeTrigger = _controller.findInput<bool>('complete_refresh') as SMITrigger?;
    _rotationProgress = _controller.findInput<double>('rotation') as SMINumber?;
  }
  late StateMachineController _controller;
  late SMITrigger? _startTrigger;
  late SMITrigger? _completeTrigger;
  late SMINumber? _rotationProgress;

  void startRefresh() {
    _startTrigger?.fire();
  }

  void completeRefresh() {
    _completeTrigger?.fire();
  }

  void setProgress(double value) {
    _rotationProgress?.value = value.clamp(0.0, 1.0);
  }

  void dispose() {
    _controller.dispose();
  }
}

// ============================================================================
// Time Picker Animation Controller
// ============================================================================

class TimePickerAnimationController {
  TimePickerAnimationController(Artboard artboard) {
    _controller = StateMachineController.fromArtboard(
      artboard,
      RiveAnimations.timePickerMachine,
    )!;

    artboard.addController(_controller);

    _scrollPosition = _controller.findInput<double>('scroll_position') as SMINumber?;
    _selectTrigger = _controller.findInput<bool>('select') as SMITrigger?;
  }
  late StateMachineController _controller;
  late SMINumber? _scrollPosition;
  late SMITrigger? _selectTrigger;

  void setScrollPosition(double position) {
    _scrollPosition?.value = position.clamp(-1.0, 1.0);
  }

  void selectTime() {
    _selectTrigger?.fire();
  }

  void dispose() {
    _controller.dispose();
  }
}

// ============================================================================
// Booking Confirmation Animation Controller
// ============================================================================

class BookingConfirmationAnimationController {
  BookingConfirmationAnimationController(Artboard artboard) {
    _controller = StateMachineController.fromArtboard(
      artboard,
      RiveAnimations.bookingConfirmMachine,
    )!;

    artboard.addController(_controller);

    _confirmTrigger = _controller.findInput<bool>('confirm') as SMITrigger?;
    _celebrationIntensity = _controller.findInput<double>('intensity') as SMINumber?;
  }
  late StateMachineController _controller;
  late SMITrigger? _confirmTrigger;
  late SMINumber? _celebrationIntensity;

  void triggerConfirmation() {
    _confirmTrigger?.fire();
  }

  void setCelebrationIntensity(double value) {
    _celebrationIntensity?.value = value.clamp(0.0, 1.0);
  }

  void dispose() {
    _controller.dispose();
  }
}

// ============================================================================
// Error State Animation Controller
// ============================================================================

class ErrorStateAnimationController {
  ErrorStateAnimationController(Artboard artboard) {
    _controller = StateMachineController.fromArtboard(
      artboard,
      RiveAnimations.errorStateMachine,
    )!;

    artboard.addController(_controller);

    _errorTrigger = _controller.findInput<bool>('trigger_error') as SMITrigger?;
    _dismissTrigger = _controller.findInput<bool>('dismiss') as SMITrigger?;
    _shakeIntensity = _controller.findInput<double>('shake_intensity') as SMINumber?;
  }
  late StateMachineController _controller;
  late SMITrigger? _errorTrigger;
  late SMITrigger? _dismissTrigger;
  late SMINumber? _shakeIntensity;

  void triggerError() {
    _errorTrigger?.fire();
  }

  void dismiss() {
    _dismissTrigger?.fire();
  }

  void setShakeIntensity(double value) {
    _shakeIntensity?.value = value.clamp(0.0, 1.0);
  }

  void dispose() {
    _controller.dispose();
  }
}
