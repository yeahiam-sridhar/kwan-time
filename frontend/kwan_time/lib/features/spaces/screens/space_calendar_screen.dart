import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/space_model.dart';
import 'space_detail_screen.dart';

// Legacy route target: keep this screen as a thin wrapper so existing
// navigation continues to work while Spaces use the new calendar UI.
class SpaceCalendarScreen extends ConsumerWidget {
  const SpaceCalendarScreen({super.key, required this.space});

  final SpaceModel space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SpaceDetailScreen(space: space);
  }
}
