// Riverpod providers for space activity timeline.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_event.dart';
import '../services/activity_service.dart';

final activityServiceProvider = Provider<ActivityService>((ref) {
  return ActivityService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});

final activityStreamProvider =
    StreamProvider.family<List<ActivityEvent>, String>(
  (ref, spaceId) {
    return ref.watch(activityServiceProvider).watchActivity(spaceId);
  },
);
