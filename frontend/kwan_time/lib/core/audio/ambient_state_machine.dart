import 'package:flutter/foundation.dart';

enum AmbientState {
  boot,
  armed,
  playing,
  pausedMic,
  pausedInterrupt,
  stopped,
}

class AmbientStateMachine {
  AmbientStateMachine._();

  static final AmbientStateMachine instance = AmbientStateMachine._();

  AmbientState _state = AmbientState.boot;
  AmbientState get state => _state;

  final int _processId = DateTime.now().millisecondsSinceEpoch;
  bool _bootSequenceExecuted = false;
  bool _lock = false;

  static const Map<AmbientState, Set<AmbientState>> _allowed = {
    AmbientState.boot: {AmbientState.armed, AmbientState.stopped},
    AmbientState.armed: {AmbientState.playing, AmbientState.stopped},
    AmbientState.playing: {
      AmbientState.pausedMic,
      AmbientState.pausedInterrupt,
      AmbientState.stopped,
    },
    AmbientState.pausedMic: {AmbientState.playing, AmbientState.stopped},
    AmbientState.pausedInterrupt: {AmbientState.playing, AmbientState.stopped},
    AmbientState.stopped: {AmbientState.armed},
  };

  bool transition(AmbientState next) {
    if (_lock) {
      return false;
    }
    if (!(_allowed[_state]?.contains(next) ?? false)) {
      debugPrint('AmbientSM: ILLEGAL ${_state.name} -> ${next.name} BLOCKED');
      return false;
    }
    _lock = true;
    final prev = _state;
    _state = next;
    _lock = false;
    debugPrint('AmbientSM: ${prev.name} -> ${_state.name}');
    return true;
  }

  bool armOnColdStart({required bool enabled, required String profile}) {
    if (_bootSequenceExecuted) {
      debugPrint('AmbientSM.arm: already executed this process — REJECTED');
      return false;
    }
    _bootSequenceExecuted = true;

    if (!enabled || profile == 'silent' || profile == 'professional') {
      transition(AmbientState.stopped);
      return false;
    }

    return transition(AmbientState.armed);
  }

  void forceStop() {
    _lock = false;
    _state = AmbientState.stopped;
    debugPrint('AmbientSM: force-stopped');
  }

  bool get canPlay => _state == AmbientState.playing;
  bool get canStart => _state == AmbientState.armed;

  bool get isPaused =>
      _state == AmbientState.pausedMic ||
      _state == AmbientState.pausedInterrupt;

  bool get isPlayingOrPaused => canPlay || isPaused;
  int get processId => _processId;
}
