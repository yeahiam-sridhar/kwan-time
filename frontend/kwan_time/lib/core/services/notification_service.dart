import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;

import '../database/db_helper.dart';
import '../models/event.dart';

// WHY(VECTOR 2, VECTOR 5): Background tap handlers run in a background isolate
// in release mode, so this must remain a top-level entry point.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  NotificationService.instance.handleBackgroundTap(notificationResponse);
}

enum NotificationFailureVector {
  vector2EntryPoint,
  vector3ExactAlarmPermission,
  vector4ChannelCorruption,
  vector5BackgroundIsolate,
  vector6BatteryOptimization,
  vector8TimezoneDrift,
  vector9CallbackRegistration,
  vector10R8Shrinking,
  unknown,
}

class NotificationFailure implements Exception {
  const NotificationFailure({
    required this.vector,
    required this.reason,
    this.cause,
  });

  final NotificationFailureVector vector;
  final String reason;
  final Object? cause;

  @override
  String toString() => 'NotificationFailure(vector: $vector, reason: $reason, '
      'cause: $cause)';
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  // WHY(VECTOR 3, VECTOR 6): Native channel is used for exact-alarm settings
  // routing and OEM battery settings that cannot be opened directly from Dart.
  static const MethodChannel _diagnosticsChannel =
      MethodChannel('kwan_time/notification_diagnostics');

  static const String _channelId = 'kwan_reminders_v2';
  static const String _channelName = 'KWAN-TIME Reminders';
  static const String _channelDescription =
      'Calendar reminders and event start alarms';
  static const int _channelSchemaVersion = 2;

  static const String _settingChannelSchemaVersion =
      'notification_channel_schema_version';
  static const String _settingExactAlarmPrompted =
      'notification_exact_alarm_prompted_v1';
  static const String _settingBatteryPrompted =
      'notification_battery_prompted_v1';
  static const String _settingPostNotificationPrompted =
      'notification_post_permission_prompted_v1';
  static const String _settingLastFailure = 'notification_last_failure';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? _androidPlugin;
  Future<void>? _initializationFuture;

  NotificationFailure? _lastFailure;
  NotificationFailure? get lastFailure => _lastFailure;

  Future<void> initialize() {
    _initializationFuture ??= _initializeInternal();
    return _initializationFuture!;
  }

  Future<void> _initializeInternal() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const settings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onForegroundTap,
        // WHY(VECTOR 2, VECTOR 5, VECTOR 9): Passing the background callback
        // here registers callback handles for release/AOT background isolates.
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      _androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // WHY(VECTOR 8): Re-validate timezone at runtime in release too, because
      // AOT edge cases can leave tz.local at UTC.
      await _validateAndRepairTimezone();

      // WHY(VECTOR 4): Rebuild or heal channel state before scheduling.
      await _ensureChannelIsHealthy();

      // WHY(VECTOR 3): Ensure runtime permissions for posting notifications and
      // exact alarms are checked early.
      await _ensureRuntimePermissions(promptIfMissing: true);

      // WHY(VECTOR 6): Detect aggressive OEM battery rules and deep-link users
      // once to relevant Samsung/system settings.
      await _checkBatteryOptimizations(promptIfRestricted: true);
    } on Object catch (e) {
      await _recordFailure(
        NotificationFailure(
          vector: NotificationFailureVector.unknown,
          reason: 'Notification initialize failed',
          cause: e,
        ),
      );
    }
  }

  Future<void> scheduleEventReminder(Event event, int minutesBefore) async {
    if (minutesBefore <= 0) {
      return;
    }

    final fireAt = event.startTime.subtract(Duration(minutes: minutesBefore));
    if (!fireAt.isAfter(DateTime.now())) {
      return;
    }

    final id = _buildStableNotificationId(
      eventId: event.id,
      type: _NotificationType.reminder,
      reminderMinutes: minutesBefore,
    );

    final body = minutesBefore == 1
        ? '${event.title} starts in 1 minute.'
        : '${event.title} starts in $minutesBefore minutes.';

    await _scheduleWithFallback(
      id: id,
      title: 'Upcoming Event',
      body: body,
      event: event,
      fireAt: fireAt,
      type: _NotificationType.reminder,
      reminderMinutes: minutesBefore,
    );
  }

  Future<void> scheduleEventStart(Event event) async {
    if (!event.startTime.isAfter(DateTime.now())) {
      return;
    }

    final id = _buildStableNotificationId(
      eventId: event.id,
      type: _NotificationType.start,
    );

    await _scheduleWithFallback(
      id: id,
      title: 'Event Started',
      body: event.title,
      event: event,
      fireAt: event.startTime,
      type: _NotificationType.start,
    );
  }

  Future<void> cancelEventReminders(String eventId) async {
    await initialize();

    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'notification_log',
      columns: <String>['notification_id'],
      where: 'event_id = ? AND status IN (?, ?, ?)',
      whereArgs: <Object?>[eventId, 'pending', 'fallback', 'failed'],
    );

    for (final row in rows) {
      final id = row['notification_id'] as int?;
      if (id == null) {
        continue;
      }
      await _plugin.cancel(id);
    }

    await db.update(
      'notification_log',
      <String, Object?>{'status': 'cancelled'},
      where: 'event_id = ?',
      whereArgs: <Object?>[eventId],
    );
  }

  Future<void> recoverOnLaunch(List<Event> upcomingEvents) async {
    await initialize();

    final now = DateTime.now();
    for (final event in upcomingEvents) {
      if (!event.startTime.isAfter(now)) {
        continue;
      }
      for (final minutes in event.reminderList.where((m) => m > 0)) {
        try {
          await scheduleEventReminder(event, minutes);
        } on Object catch (_) {
          // WHY(VECTOR 3, VECTOR 6): Recovery should continue for other events
          // even if one schedule fails due device-level restrictions.
        }
      }
      try {
        await scheduleEventStart(event);
      } on Object catch (_) {}
    }
  }

  // WHY(VECTOR 2, VECTOR 5): This function is called from background isolate.
  @pragma('vm:entry-point')
  void handleBackgroundTap(NotificationResponse notificationResponse) {
    unawaited(_persistBackgroundTap(notificationResponse));
  }

  Future<void> _persistBackgroundTap(NotificationResponse response) async {
    final payload = response.payload ?? '';
    final db = await DbHelper.instance.database;
    await db.insert(
      'notification_log',
      <String, Object?>{
        'notification_id': response.id ?? -1,
        'title': 'tap',
        'type': 'tap_background',
        'fire_at': DateTime.now().toIso8601String(),
        'event_id': payload,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'handled',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  void _onForegroundTap(NotificationResponse notificationResponse) {
    unawaited(_persistBackgroundTap(notificationResponse));
  }

  Future<void> _scheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required Event event,
    required DateTime fireAt,
    required _NotificationType type,
    int? reminderMinutes,
  }) async {
    await initialize();
    await _validateAndRepairTimezone();

    final canNotify = await _ensurePostNotificationsPermission(
      promptIfMissing: false,
    );
    if (!canNotify) {
      await _recordFailure(
        const NotificationFailure(
          vector: NotificationFailureVector.vector3ExactAlarmPermission,
          reason: 'POST_NOTIFICATIONS not granted',
        ),
      );
      return;
    }

    final now = DateTime.now();
    if (!fireAt.isAfter(now)) {
      return;
    }

    final details = _buildNotificationDetails();
    final scheduledDate = tz.TZDateTime.from(fireAt, tz.local);
    final payload = jsonEncode(<String, Object?>{
      'eventId': event.id,
      'type': type.name,
      'minutes': reminderMinutes,
      'scheduledFor': fireAt.toIso8601String(),
    });

    Object? exactError;
    final exactAllowed =
        await _ensureExactAlarmCapability(promptIfMissing: false);

    if (exactAllowed) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );

        await _upsertNotificationLog(
          id: id,
          title: title,
          type: type,
          eventId: event.id,
          fireAt: fireAt,
          status: 'pending',
        );
        return;
      } on Object catch (e) {
        exactError = e;
      }
    }

    // WHY(VECTOR 3): Fallback to inexact mode when exact alarms are blocked by
    // user/device policy on Android 12+.
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );

      await _upsertNotificationLog(
        id: id,
        title: title,
        type: type,
        eventId: event.id,
        fireAt: fireAt,
        status: 'fallback',
      );
      return;
    } catch (fallbackError) {
      await _recordFailure(
        NotificationFailure(
          vector: NotificationFailureVector.vector3ExactAlarmPermission,
          reason:
              'Exact and inexact scheduling failed '
              '(exact: $exactError, fallback: $fallbackError)',
          cause: fallbackError,
        ),
      );

      await _upsertNotificationLog(
        id: id,
        title: title,
        type: type,
        eventId: event.id,
        fireAt: fireAt,
        status: 'failed',
      );
      rethrow;
    }
  }

  NotificationDetails _buildNotificationDetails() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('reminder_chime'),
      ticker: 'KWAN-TIME reminder',
    );
    return const NotificationDetails(android: android);
  }

  Future<void> _ensureRuntimePermissions({
    required bool promptIfMissing,
  }) async {
    await _ensurePostNotificationsPermission(promptIfMissing: promptIfMissing);
    await _ensureExactAlarmCapability(promptIfMissing: promptIfMissing);
  }

  Future<bool> _ensurePostNotificationsPermission({
    required bool promptIfMissing,
  }) async {
    final android = _androidPlugin;
    if (android == null) {
      return true;
    }

    final enabled = await android.areNotificationsEnabled() ?? true;
    if (enabled) {
      return true;
    }

    if (!promptIfMissing) {
      return false;
    }

    final requested = await android.requestNotificationsPermission() ?? false;
    if (requested) {
      return true;
    }

    final prompted = await _isPrompted(_settingPostNotificationPrompted);
    if (!prompted) {
      await _setPrompted(_settingPostNotificationPrompted);
      await openAppSettings();
    }
    return false;
  }

  Future<bool> _ensureExactAlarmCapability({
    required bool promptIfMissing,
  }) async {
    final android = _androidPlugin;
    if (android == null) {
      return true;
    }

    final canScheduleExact = await android.canScheduleExactNotifications();
    if (canScheduleExact ?? true) {
      return true;
    }

    if (!promptIfMissing) {
      return false;
    }

    final granted = await android.requestExactAlarmsPermission() ?? false;
    if (granted) {
      final recheck = await android.canScheduleExactNotifications() ?? false;
      if (recheck) {
        return true;
      }
    }

    final prompted = await _isPrompted(_settingExactAlarmPrompted);
    if (!prompted) {
      await _setPrompted(_settingExactAlarmPrompted);
      await _invokeNativeBool('openExactAlarmSettings');
    }
    return false;
  }

  Future<void> _checkBatteryOptimizations({
    required bool promptIfRestricted,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final isSamsung = await _invokeNativeBool('isSamsungDevice') ?? false;
    final ignoring = await _invokeNativeBool('isIgnoringBatteryOptimizations');

    if (ignoring ?? true) {
      return;
    }

    await _recordFailure(
      const NotificationFailure(
        vector: NotificationFailureVector.vector6BatteryOptimization,
        reason: 'Battery optimization is active for app process',
      ),
    );

    if (!promptIfRestricted) {
      return;
    }

    final prompted = await _isPrompted(_settingBatteryPrompted);
    if (prompted) {
      return;
    }
    await _setPrompted(_settingBatteryPrompted);

    // WHY(VECTOR 6): Samsung Device Care/App Power Monitor can suppress alarms
    // even when standard AOSP flow is followed.
    if (isSamsung) {
      await _invokeNativeBool('openSamsungBatterySettings');
    }
    await _invokeNativeBool('openBatteryOptimizationSettings');
  }

  Future<void> _ensureChannelIsHealthy() async {
    final android = _androidPlugin;
    if (android == null) {
      return;
    }

    final savedVersion = await _readSetting(_settingChannelSchemaVersion);
    final shouldForceRecreate =
        savedVersion != _channelSchemaVersion.toString();

    final channels = await android.getNotificationChannels() ??
        <AndroidNotificationChannel>[];
    AndroidNotificationChannel? existing;
    for (final channel in channels) {
      if (channel.id == _channelId) {
        existing = channel;
        break;
      }
    }

    final hasLowImportance = existing != null &&
        existing.importance.value < Importance.high.value;

    if (!shouldForceRecreate && existing != null && !hasLowImportance) {
      return;
    }

    // WHY(VECTOR 4): Recreate channel on schema upgrades or corrupted
    // importance state that can persist across reinstalls.
    try {
      await android.deleteNotificationChannel(_channelId);
    } on Object catch (_) {
      // Channel may not exist yet.
    }

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('reminder_chime'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    await android.createNotificationChannel(channel);
    await _writeSetting(
      _settingChannelSchemaVersion,
      _channelSchemaVersion.toString(),
    );
  }

  Future<void> _validateAndRepairTimezone() async {
    try {
      // WHY(VECTOR 8): Refresh tz.local from platform timezone each launch to
      // avoid silent UTC fallback in AOT/release.
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final zoneId = timezoneInfo.identifier;
      if (zoneId.isNotEmpty && zoneId != tz.local.name) {
        tz.setLocalLocation(tz.getLocation(zoneId));
      }

      final now = DateTime.now();
      final zonedNow = tz.TZDateTime.from(now, tz.local);
      final drift =
          (zonedNow.millisecondsSinceEpoch - now.millisecondsSinceEpoch).abs();
      if (drift > const Duration(hours: 14).inMilliseconds) {
        throw const NotificationFailure(
          vector: NotificationFailureVector.vector8TimezoneDrift,
          reason: 'Timezone drift exceeded safe bound',
        );
      }
    } on Object catch (e) {
      await _recordFailure(
        NotificationFailure(
          vector: NotificationFailureVector.vector8TimezoneDrift,
          reason: 'Timezone validation failed',
          cause: e,
        ),
      );
    }
  }

  Future<bool?> _invokeNativeBool(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      return await _diagnosticsChannel.invokeMethod<bool>(method);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on Object {
      return null;
    }
  }

  Future<void> _upsertNotificationLog({
    required int id,
    required String title,
    required _NotificationType type,
    required String eventId,
    required DateTime fireAt,
    required String status,
  }) async {
    final db = await DbHelper.instance.database;
    await db.insert(
      'notification_log',
      <String, Object?>{
        'notification_id': id,
        'title': title,
        'type': type.name,
        'fire_at': fireAt.toIso8601String(),
        'event_id': eventId,
        'created_at': DateTime.now().toIso8601String(),
        'status': status,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  int _buildStableNotificationId({
    required String eventId,
    required _NotificationType type,
    int? reminderMinutes,
  }) {
    final seed = '$eventId|${type.name}|${reminderMinutes ?? 0}';
    var hash = 0x811C9DC5;
    for (final rune in seed.runes) {
      hash ^= rune;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  Future<void> _recordFailure(NotificationFailure failure) async {
    _lastFailure = failure;
    try {
      await _writeSetting(
        _settingLastFailure,
        jsonEncode(<String, String>{
          'vector': failure.vector.name,
          'reason': failure.reason,
          'time': DateTime.now().toIso8601String(),
        }),
      );
    } on Object {
      // WHY(VECTOR 3, VECTOR 6): Failure logging must never crash scheduling.
    }
  }

  Future<bool> _isPrompted(String key) async {
    final value = await _readSetting(key);
    return value == '1';
  }

  Future<void> _setPrompted(String key) => _writeSetting(key, '1');

  Future<String?> _readSetting(String key) async {
    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'app_settings',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> _writeSetting(String key, String value) async {
    final db = await DbHelper.instance.database;
    await db.insert(
      'app_settings',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

enum _NotificationType {
  reminder,
  start,
}
