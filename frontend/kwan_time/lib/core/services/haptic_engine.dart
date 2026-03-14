import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticEngine {
  HapticEngine._();

  static Future<void> light() async {
    if (await Vibration.hasVibrator()) {
      await HapticFeedback.lightImpact();
    }
  }

  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  static Future<void> eventCreated() async {
    await light();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await light();
  }

  static Future<void> error() async {
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.selectionClick();
      if (i < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }
  }

  static Future<void> reminderFired() async {
    await medium();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await medium();
  }

  static Future<void> bookingConfirmed() async {
    await heavy();
  }

  static Future<void> voiceStart() async {
    await light();
  }

  static Future<void> conflictDetected() async {
    await heavy();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await heavy();
  }
}
