import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/space_event_model.dart';
import 'space_notification_service.dart';

class SpaceEventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<SpaceEvent>> streamEvents(String spaceId) {
    return _db
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .orderBy('startTime')
        .snapshots()
        .map((snap) => snap.docs.map(SpaceEvent.fromFirestore).toList());
  }

  Stream<List<SpaceEvent>> streamEventsOnDate(String spaceId, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _db
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('startTime')
        .snapshots()
        .map((snap) => snap.docs.map(SpaceEvent.fromFirestore).toList());
  }

  Future<SpaceEvent> createEvent(String spaceId, SpaceEvent event) async {
    final conflicts = await _detectConflicts(spaceId, event);
    if (conflicts.isNotEmpty) {
      throw SpaceEventConflictException(conflicts);
    }

    final ref =
        _db.collection('spaces').doc(spaceId).collection('events').doc();
    final uid = _auth.currentUser?.uid;
    final toSave = event.copyWith(
      id: ref.id,
      createdBy: event.createdBy.isNotEmpty ? event.createdBy : (uid ?? ''),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    debugPrint(
        '[EventService] writing startTime=${Timestamp.fromDate(toSave.startTime)}');
    debugPrint(
        '[EventService] writing endTime=${Timestamp.fromDate(toSave.endTime)}');
    await ref.set(toSave.toFirestore());

    await _db.collection('spaces').doc(spaceId).update({
      'meta.eventCount': FieldValue.increment(1),
      'meta.lastActivityAt': FieldValue.serverTimestamp(),
    });

    unawaited(
      SpaceNotificationService.instance.scheduleFromData(
        toSave.id,
        {
          'title': toSave.title,
          'startTime': Timestamp.fromDate(toSave.startTime),
          'reminderMinutes': toSave.reminderMinutes,
        },
      ),
    );

    return toSave;
  }

  Future<void> updateEvent(String spaceId, SpaceEvent event) async {
    final conflicts =
        await _detectConflicts(spaceId, event, excludeId: event.id);
    if (conflicts.isNotEmpty) {
      throw SpaceEventConflictException(conflicts);
    }

    await _db
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .doc(event.id)
        .update({
      ...event.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEvent(String spaceId, String eventId) async {
    final batch = _db.batch();

    final comments = await _db
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .doc(eventId)
        .collection('comments')
        .get();
    for (final doc in comments.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_db
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .doc(eventId));

    batch.update(_db.collection('spaces').doc(spaceId), {
      'meta.eventCount': FieldValue.increment(-1),
    });

    await batch.commit();

    unawaited(SpaceNotificationService.instance.cancelEvent(eventId));
  }

  Future<List<SpaceEvent>> _detectConflicts(
    String spaceId,
    SpaceEvent event, {
    String? excludeId,
  }) async {
    final snap = await _db
        .collection('spaces')
        .doc(spaceId)
        .collection('events')
        .where('startTime', isLessThan: Timestamp.fromDate(event.endTime))
        .where('endTime', isGreaterThan: Timestamp.fromDate(event.startTime))
        .get();

    return snap.docs
        .map(SpaceEvent.fromFirestore)
        .where((e) => e.id != excludeId)
        .toList();
  }
}

class SpaceEventConflictException implements Exception {
  const SpaceEventConflictException(this.conflicts);

  final List<SpaceEvent> conflicts;

  @override
  String toString() =>
      'Schedule conflict with ${conflicts.length} existing event(s).';
}
