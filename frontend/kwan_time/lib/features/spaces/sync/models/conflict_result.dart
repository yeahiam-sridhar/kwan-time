import 'sync_event.dart';

/// Returned by ConflictDetector when overlap is found.
class ConflictResult {
  const ConflictResult({
    required this.hasConflict,
    required this.conflictingEvents,
    this.suggestion,
  });

  final bool hasConflict;
  final List<SyncEvent> conflictingEvents;
  final String? suggestion;

  factory ConflictResult.none() {
    return const ConflictResult(
      hasConflict: false,
      conflictingEvents: <SyncEvent>[],
      suggestion: null,
    );
  }

  factory ConflictResult.conflict(
    List<SyncEvent> events, {
    String? suggestion,
  }) {
    return ConflictResult(
      hasConflict: true,
      conflictingEvents: List<SyncEvent>.unmodifiable(events),
      suggestion: suggestion,
    );
  }
}
