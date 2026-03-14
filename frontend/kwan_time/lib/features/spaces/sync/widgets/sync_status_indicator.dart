import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_providers.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String label = ref.watch(syncStatusLabelProvider);
    final bool isSyncing = ref.watch(isSyncingProvider);
    final bool isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final _StatusVisual visual = _statusVisual(
      label: label,
      isOnline: isOnline,
      isSyncing: isSyncing,
    );

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isSyncing)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            )
          else
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: visual.dotColor,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: visual.textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  _StatusVisual _statusVisual({
    required String label,
    required bool isOnline,
    required bool isSyncing,
  }) {
    if (!isOnline || label == 'Offline') {
      return const _StatusVisual(
        dotColor: Color(0xFF90A4AE),
        textColor: Color(0xFFB0BEC5),
      );
    }
    if (isSyncing || label == 'Syncing...') {
      return const _StatusVisual(
        dotColor: Color(0xFFFFFFFF),
        textColor: Color(0xFFE3F2FD),
      );
    }
    if (label.toLowerCase().contains('error')) {
      return const _StatusVisual(
        dotColor: Color(0xFFE53935),
        textColor: Color(0xFFFFCDD2),
      );
    }
    if (label.toLowerCase().contains('pending')) {
      return const _StatusVisual(
        dotColor: Color(0xFFF9A825),
        textColor: Color(0xFFFFE082),
      );
    }
    return const _StatusVisual(
      dotColor: Color(0xFF43A047),
      textColor: Color(0xFFC8E6C9),
    );
  }
}

class _StatusVisual {
  const _StatusVisual({
    required this.dotColor,
    required this.textColor,
  });

  final Color dotColor;
  final Color textColor;
}
