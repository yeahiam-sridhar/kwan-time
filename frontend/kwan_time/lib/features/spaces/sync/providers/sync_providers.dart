import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/event_sync_service.dart';
import '../services/pending_sync_queue.dart';

final eventSyncServiceProvider = Provider<EventSyncService>((Ref ref) {
  return EventSyncService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

final pendingSyncCountProvider = StreamProvider<int>((Ref ref) {
  final StreamController<int> controller = StreamController<int>();
  Timer? timer;

  Future<void> emitCount() async {
    try {
      final int count = await PendingSyncQueue.instance.getPendingCount();
      if (!controller.isClosed) {
        controller.add(count);
      }
    } catch (_) {
      if (!controller.isClosed) {
        controller.add(0);
      }
    }
  }

  unawaited(emitCount());
  timer = Timer.periodic(const Duration(seconds: 30), (_) {
    unawaited(emitCount());
  });

  ref.onDispose(() {
    timer?.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

final isSyncingProvider = StateProvider<bool>((Ref ref) => false);

final lastSyncTimeProvider = StateProvider<DateTime?>((Ref ref) => null);

final connectivityProvider = Provider<Connectivity>((Ref ref) {
  return Connectivity();
});

final isOnlineProvider = StreamProvider<bool>((Ref ref) {
  final Connectivity connectivity = ref.watch(connectivityProvider);
  final StreamController<bool> controller = StreamController<bool>();

  Future<void> emitCurrent() async {
    try {
      final Object result = await connectivity.checkConnectivity();
      if (!controller.isClosed) {
        controller.add(_isConnected(result));
      }
    } catch (_) {
      if (!controller.isClosed) {
        controller.add(false);
      }
    }
  }

  unawaited(emitCurrent());
  final StreamSubscription<Object> sub =
      connectivity.onConnectivityChanged.listen((Object result) {
    if (!controller.isClosed) {
      controller.add(_isConnected(result));
    }
  });

  ref.onDispose(() {
    unawaited(sub.cancel());
    unawaited(controller.close());
  });

  return controller.stream.distinct();
});

final syncStatusLabelProvider = Provider<String>((Ref ref) {
  final bool isSyncing = ref.watch(isSyncingProvider);
  final bool isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
  final int pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
  final DateTime? lastSync = ref.watch(lastSyncTimeProvider);

  if (!isOnline) {
    return 'Offline';
  }
  if (isSyncing) {
    return 'Syncing...';
  }
  if (pending > 0) {
    return '$pending pending';
  }
  if (lastSync == null) {
    return 'Synced';
  }
  return 'Synced - ${_timeAgo(lastSync)}';
});

bool _isConnected(Object result) {
  if (result is ConnectivityResult) {
    return result != ConnectivityResult.none;
  }
  if (result is List<ConnectivityResult>) {
    return result
        .any((ConnectivityResult item) => item != ConnectivityResult.none);
  }
  return true;
}

String _timeAgo(DateTime time) {
  final Duration diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) {
    return 'just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} min ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} hr ago';
  }
  return '${diff.inDays} d ago';
}
