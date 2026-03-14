import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class SpaceNotificationService {
  SpaceNotificationService._();
  static final SpaceNotificationService instance =
      SpaceNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'space_reminders';
  static const _channelName = 'Space Event Reminders';

  Future<void> initialize() async {
    if (_initialized) return;

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Reminders for Calendar Space events',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[SpaceNotif] ✅ Initialized');
  }

  /// Schedules from raw Firestore document data.
  /// Field names must match exactly: title, startTime,
  /// reminderMinutes (int or List<int>)
  Future<void> scheduleFromData(
    String eventId,
    Map<String, dynamic> data,
  ) async {
    if (!_initialized) await initialize();

    try {
      final title = (data['title'] as String?)?.trim() ?? 'Event';

      // Parse startTime
      DateTime? startTime;
      final raw = data['startTime'];
      if (raw == null) return;
      try {
        startTime = (raw as dynamic).toDate() as DateTime;
      } catch (_) {
        if (raw is String) startTime = DateTime.tryParse(raw);
      }
      if (startTime == null) {
        debugPrint('[SpaceNotif] ⚠️ Bad startTime for $eventId');
        return;
      }

      // Parse reminderMinutes — int OR List
      List<int> reminders;
      final rm = data['reminderMinutes'];
      if (rm is List) {
        reminders = List<int>.from(rm);
      } else if (rm is int) {
        reminders = [rm];
      } else if (rm is double) {
        reminders = [rm.toInt()];
      } else {
        reminders = [15];
      }

      debugPrint('[SpaceNotif] 📅 "$title" start=$startTime '
          'reminders=$reminders');

      await cancelEvent(eventId); // prevent duplicates

      for (final minutes in reminders) {
        final notifyAt = startTime.subtract(Duration(minutes: minutes));
        if (notifyAt.isBefore(DateTime.now())) {
          debugPrint('[SpaceNotif] ⏭️ Past — skip $minutes min');
          continue;
        }

        final notifId = _id(eventId, minutes);
        final tzNotifyAt = tz.TZDateTime.from(notifyAt, tz.local);

        await _plugin.zonedSchedule(
          notifId,
          '📅 $title',
          minutes == 0
              ? 'Starting now'
              : 'In $minutes minute${minutes == 1 ? '' : 's'}',
          tzNotifyAt,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );

        debugPrint('[SpaceNotif] ✅ Scheduled id=$notifId '
            '"$title" at $tzNotifyAt');
      }
    } catch (e, st) {
      debugPrint('[SpaceNotif] ❌ Error: $e\n$st');
    }
  }

  Future<void> cancelEvent(String eventId) async {
    for (final m in [0, 1, 5, 10, 15, 20, 30, 45, 60, 90, 120]) {
      await _plugin.cancel(_id(eventId, m));
    }
  }

  /// Instant test — tap a button to verify notifications work
  Future<void> sendTestNotification() async {
    if (!_initialized) await initialize();
    await _plugin.show(
      99999,
      '🧪 KWAN·TIME Space Test',
      'Notifications are working!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
    debugPrint('[SpaceNotif] 🧪 Test notification sent');
  }

  int _id(String eventId, int minutes) {
    var h = 0;
    for (final c in '$eventId:$minutes'.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    return h;
  }
}
