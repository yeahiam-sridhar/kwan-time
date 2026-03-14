/// ═══════════════════════════════════════════════════════════════════════════
/// KWAN-TIME v2.0 — Interface Contracts
/// Frozen contracts that downstream agents (6, 7, 10, 11, 12) implement
/// These define the bridge between Agent 4 (UI Shell) and feature engineers
/// ═══════════════════════════════════════════════════════════════════════════
library;

// ─────────────────────────────────────────────────────────────────────────
// Models shared across all contracts
// ─────────────────────────────────────────────────────────────────────────

class Event {
  Event({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.startTime,
    required this.endTime,
    this.location,
    this.reminderMinutes,
    this.soundTrigger,
  });
  final String id;
  final String title;
  final String type; // online, in_person, free, booked, cancelled
  final String status; // not_started, in_progress, completed, cancelled
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final List<int>? reminderMinutes;
  final String? soundTrigger;
}

class ThreeMonthOverview {
  ThreeMonthOverview({required this.months});
  final List<MonthSummary> months;
}

class MonthSummary {
  MonthSummary({
    required this.month,
    required this.label,
    required this.isCurrent,
    required this.totalOnline,
    required this.totalInPerson,
    required this.totalFree,
    required this.totalBooked,
    required this.totalCancelled,
    required this.totalNotStarted,
    required this.totalInProgress,
    required this.totalCompleted,
    required this.freeTimeMinutes,
    required this.availableDays,
    required this.availableSaturdays,
    required this.availableSundays,
    required this.availableDates,
  });
  final DateTime month;
  final String label;
  final bool isCurrent;
  final int totalOnline;
  final int totalInPerson;
  final int totalFree;
  final int totalBooked;
  final int totalCancelled;
  final int totalNotStarted;
  final int totalInProgress;
  final int totalCompleted;
  final int freeTimeMinutes;
  final int availableDays;
  final int availableSaturdays;
  final int availableSundays;
  final List<String> availableDates;
}

// ═══════════════════════════════════════════════════════════════════════════
// AGENT 6 — CLASSIC CALENDAR VIEW CONTRACT
// ═══════════════════════════════════════════════════════════════════════════

abstract class ICalendarViewModel {
  /// Stream of events for a given month
  Stream<List<Event>> eventsForMonth(DateTime month);

  /// Stream of events for a given week
  Stream<List<Event>> eventsForWeek(DateTime weekStart);

  /// Stream of events for a given day
  Stream<List<Event>> eventsForDay(DateTime day);

  /// Move an event to a new start time (drag & drop)
  /// Returns optimistic ID for sync reconciliation
  Future<String> moveEvent(String eventId, DateTime newStart);

  /// Create a new event
  /// Returns optimistic ID for sync reconciliation
  Future<String> createEvent({
    required String title,
    required String type,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
  });

  /// Delete an event
  /// Returns optimistic ID for sync reconciliation
  Future<String> deleteEvent(String eventId);

  /// Refresh events from server
  Future<void> refresh();
}

// ═══════════════════════════════════════════════════════════════════════════
// AGENT 7 — BI DASHBOARD VIEW CONTRACT
// ═══════════════════════════════════════════════════════════════════════════

abstract class IDashboardViewModel {
  /// Stream of 3-month overview (month, next month, next+1 month)
  /// Used by BI Dashboard tab
  Stream<ThreeMonthOverview> threeMonthOverview();

  /// Manually refresh dashboard data from server
  Future<void> refresh();

  /// Calculate percentage of free time for availability pulse
  double calculateAvailabilityPercent();
}

// ═══════════════════════════════════════════════════════════════════════════
// AGENT 10 — PUSH NOTIFICATION VIEW MODEL CONTRACT
// ═══════════════════════════════════════════════════════════════════════════

class NotificationPrefs {
  NotificationPrefs({
    required this.reminderMinutes,
    this.dailySummaryTime,
    this.reminderEnabled = true,
    this.bookingConfirmedEnabled = true,
    this.eventStartEnabled = true,
    this.dailySummaryEnabled = true,
    this.weeklySummaryEnabled = true,
  });
  final List<int> reminderMinutes; // [60, 15, 5]
  final String? dailySummaryTime; // "08:00"
  final bool reminderEnabled;
  final bool bookingConfirmedEnabled;
  final bool eventStartEnabled;
  final bool dailySummaryEnabled;
  final bool weeklySummaryEnabled;
}

class InAppNotification {
  InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.soundKey,
  });
  final String id;
  final String title;
  final String body;
  final String? soundKey;
  final DateTime createdAt;
}

abstract class INotificationViewModel {
  /// Register device for push notifications
  Future<void> registerDevice(String fcmToken, String platform);

  /// Get current notification preferences
  Future<NotificationPrefs> getPreferences();

  /// Update notification preferences
  Future<void> updatePreferences(NotificationPrefs prefs);

  /// Stream of in-app notifications (shown when app is open)
  Stream<InAppNotification> inAppNotifications();

  /// Dismiss an in-app notification
  Future<void> dismissNotification(String id);
}

// ═══════════════════════════════════════════════════════════════════════════
// AGENT 11 — SOUND & MUSIC ENGINE CONTRACT
// ═══════════════════════════════════════════════════════════════════════════

class SoundProfile {
  SoundProfile({
    required this.key,
    required this.label,
    required this.enableMicroSounds,
    required this.enableAmbientMusic,
    required this.ambientVolume,
  });
  final String key; // 'professional', 'calm', 'silent', 'celebration'
  final String label;
  final bool enableMicroSounds;
  final bool enableAmbientMusic;
  final double ambientVolume;
}

abstract class ISoundViewModel {
  /// Play a micro-sound instantly
  Future<void> playSound(String soundKey);

  /// Play sound with haptic feedback simultaneously
  Future<void> playSoundWithHaptic(String soundKey);

  /// Set user's sound profile
  Future<void> setSoundProfile(String profileKey);

  /// Get current sound profile
  Future<SoundProfile> getCurrentProfile();

  /// Stream of sound profile changes
  Stream<SoundProfile> soundProfileStream();

  /// Enable/disable ambient music
  Future<void> setAmbientMusicEnabled(bool enabled);

  /// Set ambient music volume (0.0 - 1.0)
  Future<void> setAmbientVolume(double volume);

  /// Stop ambient music
  Future<void> stopAmbient();

  /// Start ambient music (auto-selects based on time of day)
  Future<void> startAmbient();
}

// ═══════════════════════════════════════════════════════════════════════════
// AGENT 12 — PUBLIC BOOKING VIEW MODEL CONTRACT
// ═══════════════════════════════════════════════════════════════════════════

class AvailableSlot {
  // "10:00 AM · 1hr"

  AvailableSlot({
    required this.startTime,
    required this.endTime,
    required this.displayText,
  });
  final DateTime startTime;
  final DateTime endTime;
  final String displayText;
}

class BookingPage {
  BookingPage({
    required this.slug,
    required this.title,
    required this.durationMinutes,
    required this.bufferMinutes,
    required this.isActive,
    required this.maxAdvanceDays,
    required this.shareUrl,
  });
  final String slug;
  final String title;
  final int durationMinutes;
  final int bufferMinutes;
  final bool isActive;
  final int maxAdvanceDays;
  final String shareUrl;
}

class BookingRequest {
  BookingRequest({
    required this.date,
    required this.time,
    required this.clientName,
    required this.clientEmail,
    this.notes,
  });
  final String date; // "2026-01-16"
  final String time; // "10:00"
  final String clientName;
  final String clientEmail;
  final String? notes;
}

abstract class IBookingViewModel {
  /// Get my booking page configuration
  Future<BookingPage> getMyBookingPage();

  /// Get available slots for a specific date
  Future<List<AvailableSlot>> getAvailableSlots(DateTime date);

  /// Generate shareable booking link
  Future<String> generateShareLink();

  /// Submit a booking (client-side)
  Future<void> submitBooking(String slug, BookingRequest request);

  /// Stream of incoming bookings (for owner's dashboard)
  Stream<Event> incomingBookings();

  /// Toggle booking page active/inactive
  Future<void> setBookingPageActive(bool active);

  /// Update booking page settings
  Future<void> updateBookingPageSettings({
    String? title,
    int? durationMinutes,
    int? bufferMinutes,
    int? maxAdvanceDays,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// STATE MANAGEMENT RULES
// All view models follow these patterns:
// ═══════════════════════════════════════════════════════════════════════════

/// 1. ASYNC NOTIFIER PROVIDER
///    Use `AsyncNotifierProvider` for ALL async data
///    Stream local state first (Hive), then API hydration
///
/// 2. LOCAL-FIRST CACHING
///    Hive stores latest data locally
///    App renders cache immediately
///    API updates in background
///
/// 3. OPTIMISTIC UPDATES
///    Local state changes first (instant UI response)
///    API call sent with X-Optimistic-ID header
///    Go handlers return 202 Accepted
///    WebSocket broadcasts SYNC_CONFIRM or SYNC_REVERT
///    Riverpod provider reconciles based on server response
///
/// 4. WEBSOCKET SYNCHRONIZATION
///    When data mutates server-side (other devices), WS broadcasts
///    Message includes: type, payload, optimistic_id (if from same device)
///    Provider invalidates if optimistic_id doesn't match (different device)
///    UI re-renders with new data
///
/// 5. ERROR HANDLING
///    On SYNC_REVERT: rollback local state
///    Show error toast with HapticEngine.errorShake()
///    Log to error tracking queue
///    User can retry
///
/// 6. CACHING INVALIDATION
///    On user action: local state + invalidate provider
///    WebSocket DASHBOARD_STALE: invalidate dashboard provider
///    EVENT_CREATED/UPDATED/DELETED: invalidate calendar provider
///    Cascading invalida tions handled by Riverpod
