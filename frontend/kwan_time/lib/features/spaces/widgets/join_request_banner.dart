import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Join-requests were part of an earlier invite flow.
// With tokenised invites, this banner is intentionally a no-op.
class JoinRequestBanner extends ConsumerWidget {
  const JoinRequestBanner({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}
