// Firebase Cloud Messaging service for event notifications.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_payload.dart';
import '../providers/notification_providers.dart';

/// Cloud Function (Node.js) reference implementation:
///
/// Trigger:
/// - onDocumentCreated("spaces/{spaceId}/events/{eventId}")
///
/// Steps:
/// 1. Fetch space document.
/// 2. Collect roles.admins, roles.members, roles.viewers.
/// 3. Remove duplicate uids.
/// 4. Batch fetch users documents in groups of 10.
/// 5. Extract non-null fcmToken values.
/// 6. Send push notifications using admin.messaging().sendEachForMulticast().
///
/// Payload:
/// - title: "New Event Added"
/// - body: "${eventData.title} added to your calendar"
/// - data: { spaceId, eventId, title, body }

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background notification received');
}

class FcmService {
  final FirebaseMessaging _fcm;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final Ref _ref;

  bool _initialized = false;

  static const _channelId = 'kwan_events';
  static const _channelName = 'Event Notifications';

  FcmService(
    this._fcm,
    this._db,
    this._auth,
    this._localNotifications,
    this._ref,
  );

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      final settings = await _fcm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM permission denied');
        return;
      }
    } catch (e) {
      debugPrint('FCM initialize error (requestPermission): $e');
      return;
    }

    String? token;
    try {
      token = await _fcm.getToken();
      if (token == null) {
        debugPrint('FCM token null');
        return;
      }
    } catch (e) {
      debugPrint('FCM initialize error (getToken): $e');
      return;
    }

    await _saveToken(token);

    try {
      _fcm.onTokenRefresh.listen((newToken) async {
        await _saveToken(newToken);
      });
    } catch (e) {
      debugPrint('FCM initialize error (token refresh listener): $e');
    }

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    );

    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint('FCM initialize error (create channel): $e');
    }

    try {
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payloadString = response.payload;
          if (payloadString == null || payloadString.isEmpty) {
            return;
          }
          try {
            final decoded = jsonDecode(payloadString);
            if (decoded is! Map<String, dynamic>) {
              return;
            }
            final title = decoded['title'];
            final body = decoded['body'];
            final spaceId = decoded['spaceId'];
            final eventId = decoded['eventId'];
            if (title is! String ||
                body is! String ||
                spaceId is! String ||
                eventId is! String) {
              return;
            }
            _ref.read(notificationPayloadProvider.notifier).state =
                NotificationPayload(
              spaceId: spaceId,
              eventId: eventId,
              title: title,
              body: body,
            );
          } catch (e) {
            debugPrint('FCM local notification tap parse error: $e');
          }
        },
      );
    } catch (e) {
      debugPrint('FCM initialize error (local notifications init): $e');
    }

    try {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('FCM initialize error (foreground presentation): $e');
    }

    try {
      FirebaseMessaging.onMessage.listen((message) async {
        await handleForegroundMessage(message);
      });
    } catch (e) {
      debugPrint('FCM initialize error (foreground listener): $e');
    }

    try {
      FirebaseMessaging.onMessageOpenedApp.listen(handleNotificationTap);
    } catch (e) {
      debugPrint('FCM initialize error (tap listener): $e');
    }

    try {
      final message = await _fcm.getInitialMessage();
      if (message != null) {
        handleNotificationTap(message);
      }
    } catch (e) {
      debugPrint('FCM initialize error (initial message): $e');
    }

    _initialized = true;
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final userRef = _db.collection('users').doc(user.uid);
      final snapshot = await userRef.get();

      final currentToken = snapshot.data()?['fcmToken'];
      if (currentToken is String && currentToken == token) {
        return;
      }

      await userRef.set({'fcmToken': token}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FCM save token error: $e');
    }
  }

  Future<void> handleForegroundMessage(RemoteMessage message) async {
    final payload = NotificationPayload.fromRemoteMessage(message);
    if (payload == null) {
      debugPrint('FCM foreground payload invalid');
      return;
    }

    try {
      await _localNotifications.show(
        payload.hashCode,
        payload.title,
        payload.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(payload.toJson()),
      );
    } catch (e) {
      debugPrint('FCM foreground notification error: $e');
    }
  }

  void handleNotificationTap(RemoteMessage message) {
    final payload = NotificationPayload.fromRemoteMessage(message);
    if (payload == null) {
      debugPrint('FCM tap payload invalid');
      return;
    }
    _ref.read(notificationPayloadProvider.notifier).state = payload;
  }
}
