import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'core/audio/audio_controller.dart';
import 'core/audio/audio_gatekeeper.dart';
import 'core/audio/audio_persistence.dart';
import 'core/audio/reminder_state_machine.dart';
import 'core/database/dao/event_dao.dart';
import 'core/database/db_helper.dart';
import 'core/services/notification_service.dart';
import 'features/calendar/services/festival_service.dart';
import 'features/notifications/services/fcm_service.dart';
import 'features/spaces/services/space_listener_service.dart';
import 'features/spaces/services/space_notification_service.dart';
import 'firebase_options.dart';
import 'services/app_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  tz.initializeTimeZones();
  final localTimezone = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  await SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp],
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await DbHelper.instance.database;
  await NotificationService.instance.initialize();
  await AudioController.instance.initialize();
  await AppInitializer.initialize();
  await SpaceNotificationService.instance.initialize();
  unawaited(SpaceListenerService.instance.start());
  await FestivalService.instance.load();
  unawaited(_recoverAlarms());

  final reminderRecord = await AudioPersistence.instance.loadReminderState();
  final reminderIsActive = reminderRecord?.state == ReminderState.active;
  final prefs = await AudioPersistence.instance.loadAmbientPrefs();
  if (reminderIsActive) {
    unawaited(
      AudioGatekeeper.instance.process(
        GatekeeperEvent.coldStart,
        ambientEnabled: prefs.enabled,
        profile: prefs.profile,
      ),
    );
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AudioController.instance.stopAll());
    });
  }

  runApp(
    const ProviderScope(
      child: KwanTimeApp(),
    ),
  );
}

Future<void> _recoverAlarms() async {
  try {
    final now = DateTime.now();
    final upcoming = await EventDao().getForDateRange(
      now,
      now.add(const Duration(days: 60)),
    );
    await NotificationService.instance.recoverOnLaunch(upcoming);
  } catch (e) {
    debugPrint('Alarm recovery error: $e');
  }
}
