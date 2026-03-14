import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import 'ambient_state_machine.dart';
import 'audio_controller.dart';
import 'audio_persistence.dart';
import 'reminder_state_machine.dart';

enum GatekeeperEvent {
  coldStart,
  appResumed,
  alarmFired,
  dismissPressed,
  micStart,
  micStop,
  audioInterrupt,
  audioResume,
  settingsChanged,
  navigationChanged,
  appDetached,
}

class AudioGatekeeper {
  AudioGatekeeper._();

  static final AudioGatekeeper instance = AudioGatekeeper._();

  final ReminderStateMachine _rsm = ReminderStateMachine.instance;
  final AmbientStateMachine _asm = AmbientStateMachine.instance;

  final Set<String> _processedEvents = <String>{};
  int _activeAlertSequenceId = 0;

  static const Duration _musicDuration = Duration(seconds: 3);
  static const Duration _pauseBetweenPlays = Duration(milliseconds: 800);
  static const int _vibrateDurationMs = 400;
  static const Duration _vibrationPause = Duration(milliseconds: 600);

  Future<void> process(
    GatekeeperEvent event, {
    DateTime? triggerTime,
    String? eventId,
    bool? ambientEnabled,
    String? profile,
  }) async {
    debugPrint('Gatekeeper: ${event.name}');
    switch (event) {
      case GatekeeperEvent.coldStart:
        await _onColdStart(
          ambientEnabled: ambientEnabled ?? true,
          profile: profile ?? 'calm',
        );
        break;
      case GatekeeperEvent.appResumed:
        await _onAppResumed();
        break;
      case GatekeeperEvent.alarmFired:
        if (triggerTime != null && eventId != null) {
          await _onAlarmFired(triggerTime: triggerTime, eventId: eventId);
        }
        break;
      case GatekeeperEvent.dismissPressed:
        await _onDismiss();
        break;
      case GatekeeperEvent.micStart:
        await _onMicStart();
        break;
      case GatekeeperEvent.micStop:
        await _onMicStop();
        break;
      case GatekeeperEvent.audioInterrupt:
        await _onAudioInterrupt();
        break;
      case GatekeeperEvent.audioResume:
        await _onAudioResume();
        break;
      case GatekeeperEvent.navigationChanged:
        await _onNavigationChanged();
        break;
      case GatekeeperEvent.appDetached:
        await _onDetached();
        break;
      case GatekeeperEvent.settingsChanged:
        await _onSettingsChanged(
          enabled: ambientEnabled ?? true,
          profile: profile ?? 'calm',
        );
        break;
    }
  }

  Future<void> _onColdStart({
    required bool ambientEnabled,
    required String profile,
  }) async {
    final persisted = await AudioPersistence.instance.loadReminderState();
    if (persisted != null && persisted.state == ReminderState.active) {
      _rsm.transition(ReminderState.recovery);
      final trigger = persisted.triggerTime;
      final inWindow = trigger != null &&
          DateTime.now().isBefore(trigger.add(const Duration(minutes: 10)));
      if (inWindow) {
        final ok = _rsm.transition(
          ReminderState.active,
          triggerTime: persisted.triggerTime,
          eventId: persisted.eventId,
        );
        if (ok && persisted.eventId != null) {
          await _executeReminderAlertSequence(persisted.eventId!);
          return;
        }
      } else {
        _rsm.transition(ReminderState.idle);
        _invalidateAlertSequence();
        await AudioController.instance.stopAll();
      }
    } else {
      _rsm.transition(ReminderState.idle);
    }

    final armed = _asm.armOnColdStart(
      enabled: ambientEnabled,
      profile: profile,
    );
    if (armed) {
      await AudioController.instance.startAmbient();
    }
  }

  Future<void> _onAppResumed() async {
    debugPrint('Gatekeeper.onResumed: enforcing invariants');

    if (_rsm.isAudioPermitted) {
      if (!_rsm.isWithinTriggerWindow) {
        _rsm.transition(ReminderState.expired);
        _rsm.transition(ReminderState.idle);
        _invalidateAlertSequence();
        await AudioController.instance.stopAll();
        await AudioPersistence.instance.clearReminderState();
      }
      return;
    }

    if (_asm.canPlay || _asm.isPaused) {
      return;
    }

    if (AudioController.instance.isAnyAudioPlaying) {
      debugPrint('Gatekeeper.onResumed: rogue audio detected — killing');
      await AudioController.instance.stopAll();
      _asm.forceStop();
    }
  }

  Future<void> _onAlarmFired({
    required DateTime triggerTime,
    required String eventId,
  }) async {
    final key = 'alarm:${eventId}_${triggerTime.millisecondsSinceEpoch}';
    if (_processedEvents.contains(key)) {
      debugPrint('Gatekeeper: duplicate alarm rejected ($key)');
      return;
    }
    _processedEvents.add(key);
    Future<void>.delayed(
      const Duration(minutes: 15),
      () => _processedEvents.remove(key),
    );

    if (_asm.isPlayingOrPaused) {
      await AudioController.instance.stopAmbient();
      _asm.forceStop();
    }

    final pendingOk = _rsm.transition(
      ReminderState.triggerPending,
      triggerTime: triggerTime,
      eventId: eventId,
    );
    if (!pendingOk) {
      return;
    }

    final activeOk = _rsm.transition(
      ReminderState.active,
      triggerTime: triggerTime,
      eventId: eventId,
    );
    if (!activeOk) {
      return;
    }

    await AudioPersistence.instance.saveReminderState(
      ReminderStateRecord(
        state: ReminderState.active,
        triggerTime: triggerTime,
        eventId: eventId,
      ),
    );

    await _executeReminderAlertSequence(eventId);
  }

  Future<void> _onDismiss() async {
    _invalidateAlertSequence();
    _rsm.transition(ReminderState.dismissed);
    _rsm.transition(ReminderState.idle);
    await AudioController.instance.stopReminder();
    await AudioPersistence.instance.clearReminderState();

    final prefs = await AudioPersistence.instance.loadAmbientPrefs();
    if (prefs.enabled && prefs.profile == 'calm') {
      final armed = _asm.transition(AmbientState.armed);
      if (armed) {
        await AudioController.instance.startAmbient();
      }
    }
  }

  Future<void> _onMicStart() async {
    if (_asm.canPlay) {
      _asm.transition(AmbientState.pausedMic);
      await AudioController.instance.pauseAmbient();
    }
  }

  Future<void> _onMicStop() async {
    if (_asm.state == AmbientState.pausedMic) {
      _asm.transition(AmbientState.playing);
      await AudioController.instance.resumeAmbient();
    }
  }

  Future<void> _onAudioInterrupt() async {
    if (_asm.canPlay) {
      _asm.transition(AmbientState.pausedInterrupt);
      await AudioController.instance.pauseAmbient();
    }
  }

  Future<void> _onAudioResume() async {
    if (_asm.state == AmbientState.pausedInterrupt) {
      _asm.transition(AmbientState.playing);
      await AudioController.instance.resumeAmbient();
    }
  }

  Future<void> _onNavigationChanged() async {
    await _onAppResumed();
  }

  Future<void> _onDetached() async {
    _invalidateAlertSequence();
    await AudioController.instance.stopAll();
    _asm.forceStop();
    _processedEvents.clear();
    debugPrint('Gatekeeper: detached — all audio killed');
  }

  Future<void> _onSettingsChanged({
    required bool enabled,
    required String profile,
  }) async {
    await AudioPersistence.instance.saveAmbientPrefs(
      AmbientPrefs(enabled: enabled, profile: profile),
    );

    if (!enabled || profile == 'silent' || profile == 'professional') {
      await AudioController.instance.stopAmbient();
      _asm.forceStop();
      return;
    }

    if (_asm.state == AmbientState.stopped) {
      final armed = _asm.transition(AmbientState.armed);
      if (armed) {
        await AudioController.instance.startAmbient();
      }
    }
  }

  Future<void> _executeReminderAlertSequence(String eventId) async {
    if (!_rsm.isAudioPermitted) {
      return;
    }

    final sequenceId = ++_activeAlertSequenceId;
    unawaited(_triggerVibrationSequence(sequenceId));

    try {
      for (var playCount = 1; playCount <= 3; playCount++) {
        if (!_canContinueAlertSequence(sequenceId)) {
          break;
        }

        await AudioController.instance.playReminder(eventId);
        await Future<void>.delayed(_musicDuration);
        await AudioController.instance.stopReminder();

        if (playCount < 3 && _canContinueAlertSequence(sequenceId)) {
          await Future<void>.delayed(_pauseBetweenPlays);
        }
      }
    } finally {
      await AudioController.instance.stopReminder();
    }
  }

  Future<void> _triggerVibrationSequence(int sequenceId) async {
    for (var vibrationCount = 1; vibrationCount <= 2; vibrationCount++) {
      if (!_canContinueAlertSequence(sequenceId)) {
        break;
      }
      await _vibrateOnce();
      if (vibrationCount < 2 && _canContinueAlertSequence(sequenceId)) {
        await Future<void>.delayed(_vibrationPause);
      }
    }
  }

  Future<void> _vibrateOnce() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (!hasVibrator) {
        return;
      }
      await Vibration.vibrate(duration: _vibrateDurationMs);
    } catch (e) {
      debugPrint('Gatekeeper vibration error: $e');
    }
  }

  bool _canContinueAlertSequence(int sequenceId) {
    return _rsm.isAudioPermitted && sequenceId == _activeAlertSequenceId;
  }

  void _invalidateAlertSequence() {
    _activeAlertSequenceId += 1;
  }
}
