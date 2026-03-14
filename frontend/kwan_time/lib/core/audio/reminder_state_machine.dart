import 'package:flutter/foundation.dart';

enum ReminderState {
  boot,
  idle,
  scheduled,
  triggerPending,
  active,
  dismissed,
  expired,
  recovery,
}

class ReminderStateMachine {
  ReminderStateMachine._();

  static final ReminderStateMachine instance = ReminderStateMachine._();

  ReminderState _state = ReminderState.boot;
  ReminderState get state => _state;

  DateTime? _triggerTime;
  String? _activeEventId;
  bool _transitioning = false;

  static const Map<ReminderState, Set<ReminderState>> _allowed = {
    ReminderState.boot: {ReminderState.idle, ReminderState.recovery},
    ReminderState.idle: {ReminderState.scheduled},
    ReminderState.scheduled: {ReminderState.triggerPending, ReminderState.idle},
    ReminderState.triggerPending: {ReminderState.active, ReminderState.expired},
    ReminderState.active: {ReminderState.dismissed, ReminderState.expired},
    ReminderState.dismissed: {ReminderState.idle},
    ReminderState.expired: {ReminderState.idle},
    ReminderState.recovery: {ReminderState.idle, ReminderState.active},
  };

  bool transition(
    ReminderState next, {
    DateTime? triggerTime,
    String? eventId,
  }) {
    if (_transitioning) {
      debugPrint('ReminderSM: mutex blocked, rejecting ${next.name}');
      return false;
    }

    final allowed = _allowed[_state];
    if (allowed == null || !allowed.contains(next)) {
      debugPrint('ReminderSM: ILLEGAL ${_state.name} -> ${next.name} BLOCKED');
      return false;
    }

    if (next == ReminderState.active) {
      final t = triggerTime ?? _triggerTime;
      if (t == null) {
        debugPrint('ReminderSM: ACTIVE blocked — no trigger time');
        return false;
      }
      final now = DateTime.now();
      final delta = now.difference(t).abs();
      final window =
          now.isAfter(t) && now.isBefore(t.add(const Duration(minutes: 10)));
      final pending = delta.inSeconds < 30;
      if (!window && !pending) {
        debugPrint('ReminderSM: ACTIVE blocked — outside time window');
        transition(ReminderState.expired);
        return false;
      }
    }

    _transitioning = true;
    final prev = _state;
    _state = next;
    if (triggerTime != null) {
      _triggerTime = triggerTime;
    }
    if (eventId != null) {
      _activeEventId = eventId;
    }
    if (next == ReminderState.idle ||
        next == ReminderState.dismissed ||
        next == ReminderState.expired) {
      _triggerTime = null;
      _activeEventId = null;
    }
    _transitioning = false;

    debugPrint('ReminderSM: ${prev.name} -> ${_state.name}');
    return true;
  }

  bool get isAudioPermitted => _state == ReminderState.active;

  bool get isWithinTriggerWindow {
    if (_state != ReminderState.active) {
      return false;
    }
    if (_triggerTime == null) {
      return false;
    }
    final now = DateTime.now();
    return now.isAfter(_triggerTime!) &&
        now.isBefore(_triggerTime!.add(const Duration(minutes: 10)));
  }

  DateTime? get triggerTime => _triggerTime;
  String? get activeEventId => _activeEventId;
}
