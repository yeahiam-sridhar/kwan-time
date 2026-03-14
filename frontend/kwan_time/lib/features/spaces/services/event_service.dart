import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/space_event_model.dart';
import 'space_service.dart';
import 'space_notification_service.dart';

class EventService {
  final FirebaseFirestore _db;

  EventService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<SpaceEvent>> streamEvents(String spaceId) {
    return _db
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .orderBy('startTime')
        .snapshots()
        .map((snap) => snap.docs.map(SpaceEvent.fromFirestore).toList());
  }

  Future<SpaceEvent> createEvent(String spaceId, SpaceEvent event) async {
    try {
      final eventsRef =
          _db.collection('spaces').doc(spaceId).collection('events');
      final docRef = event.id.trim().isEmpty ? eventsRef.doc() : eventsRef.doc(event.id);

      final saved = event.copyWith(
        id: docRef.id,
        spaceId: spaceId,
        createdAt: event.createdAt,
        updatedAt: DateTime.now(),
      );

      final batch = _db.batch();
      batch.set(docRef, {
        ...saved.toFirestore(),
        // Ensure Timestamp types even if a caller bypassed the model helper.
        'startTime': Timestamp.fromDate(saved.startTime),
        'endTime': Timestamp.fromDate(saved.endTime),
      });
      batch.update(_db.collection('spaces').doc(spaceId), {
        'meta.eventCount': FieldValue.increment(1),
        'meta.lastActivityAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      unawaited(
        SpaceNotificationService.instance.scheduleFromData(
          saved.id,
          {
            'title': saved.title,
            'startTime': Timestamp.fromDate(saved.startTime),
            'reminderMinutes': saved.reminderMinutes,
          },
        ),
      );

      return saved;
    } on FirebaseException catch (e, s) {
      debugPrint('[EventService] createEvent error: ${e.code}\n$s');
      throw SpaceException('Failed to create event', cause: e);
    } catch (e, s) {
      debugPrint('[EventService] createEvent error: $e\n$s');
      throw SpaceException('Failed to create event', cause: e);
    }
  }

  Future<void> updateEvent(String spaceId, SpaceEvent event) async {
    try {
      await _db
          .collection('spaces')
          .doc(spaceId)
          .collection('events')
          .doc(event.id)
          .update({
        ...event.toFirestore(),
        'startTime': Timestamp.fromDate(event.startTime),
        'endTime': Timestamp.fromDate(event.endTime),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e, s) {
      debugPrint('[EventService] updateEvent error: ${e.code}\n$s');
      throw SpaceException('Failed to update event', cause: e);
    } catch (e, s) {
      debugPrint('[EventService] updateEvent error: $e\n$s');
      throw SpaceException('Failed to update event', cause: e);
    }
  }

  Future<void> deleteEvent(String spaceId, String eventId) async {
    try {
      final batch = _db.batch();
      batch.delete(_db
          .collection('spaces')
          .doc(spaceId)
          .collection('events')
          .doc(eventId));
      batch.update(_db.collection('spaces').doc(spaceId), {
        'meta.eventCount': FieldValue.increment(-1),
        'meta.lastActivityAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      unawaited(SpaceNotificationService.instance.cancelEvent(eventId));
    } on FirebaseException catch (e, s) {
      debugPrint('[EventService] deleteEvent error: ${e.code}\n$s');
      throw SpaceException('Failed to delete event', cause: e);
    } catch (e, s) {
      debugPrint('[EventService] deleteEvent error: $e\n$s');
      throw SpaceException('Failed to delete event', cause: e);
    }
  }
}
