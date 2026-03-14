// Notification payload model for event push messages.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@immutable
class NotificationPayload {
  final String spaceId;
  final String eventId;
  final String title;
  final String body;

  const NotificationPayload({
    required this.spaceId,
    required this.eventId,
    required this.title,
    required this.body,
  });

  /// Parse from RemoteMessage.data.
  ///
  /// Required keys:
  /// - spaceId
  /// - eventId
  /// - title
  /// - body
  ///
  /// Returns null if keys are missing or empty.
  static NotificationPayload? fromRemoteMessage(RemoteMessage message) {
    try {
      final data = message.data;

      const requiredKeys = <String>['spaceId', 'eventId', 'title', 'body'];
      for (final key in requiredKeys) {
        final value = data[key];
        if (value == null) {
          return null;
        }
        if (value is! String || value.trim().isEmpty) {
          return null;
        }
      }

      return NotificationPayload(
        spaceId: data['spaceId']!.trim(),
        eventId: data['eventId']!.trim(),
        title: data['title']!.trim(),
        body: data['body']!.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'spaceId': spaceId,
      'eventId': eventId,
      'title': title,
      'body': body,
    };
  }
}
