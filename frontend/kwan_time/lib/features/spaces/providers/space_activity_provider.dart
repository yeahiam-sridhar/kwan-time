import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/space_activity_model.dart';
import '../services/space_activity_service.dart';

final spaceActivityServiceProvider = Provider<SpaceActivityService>(
  (ref) => SpaceActivityService(),
);

final spaceActivityStreamProvider =
    StreamProvider.family<List<SpaceActivity>, String>((ref, spaceId) {
  return ref.watch(spaceActivityServiceProvider).streamActivity(spaceId);
});
