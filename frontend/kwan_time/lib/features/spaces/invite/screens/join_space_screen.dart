import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// This screen supported an older /join/{spaceId} deep-link format.
// Canonical invites now use:
//   https://kwantime.app/invite?spaceId=...&role=...&token=...
class JoinSpaceScreen extends ConsumerWidget {
  const JoinSpaceScreen({
    super.key,
    required this.spaceId,
    required this.role,
  });

  final String spaceId;
  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Space Invitation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This invitation link format is no longer supported.\n\n'
            'Ask the space admin for a new invite link.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
        ),
      ),
    );
  }
}
