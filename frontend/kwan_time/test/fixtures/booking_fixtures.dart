import 'package:kwan_time/core/providers/interfaces.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TESTING FIXTURES — Booking Models
/// Provides reusable test data for unit & integration tests
/// ═══════════════════════════════════════════════════════════════════════════

/// Sample booking page configuration for testing
BookingPage createMockBookingPage({
  String slug = 'test-booking',
  String title = 'Test Booking',
  int durationMinutes = 60,
  int bufferMinutes = 15,
  bool isActive = true,
  int maxAdvanceDays = 90,
  String shareUrl = 'https://kwan.time/u/example/book',
}) =>
    BookingPage(
      slug: slug,
      title: title,
      durationMinutes: durationMinutes,
      bufferMinutes: bufferMinutes,
      isActive: isActive,
      maxAdvanceDays: maxAdvanceDays,
      shareUrl: shareUrl,
    );

/// Sample available time slot for testing
AvailableSlot createMockAvailableSlot({
  DateTime? startTime,
  DateTime? endTime,
  String displayText = '10:00 AM · 1hr',
}) {
  final now = DateTime.now();
  final start = startTime ?? DateTime(now.year, now.month, now.day, 10, 0);
  final end = endTime ?? DateTime(now.year, now.month, now.day, 11, 0);

  return AvailableSlot(
    startTime: start,
    endTime: end,
    displayText: displayText,
  );
}

/// Generate mock available slots for a date
List<AvailableSlot> createMockAvailableSlots(DateTime date, {int count = 6}) {
  final slots = <AvailableSlot>[];
  for (var i = 0; i < count; i++) {
    final hour = 9 + (i ~/ 2); // 9, 9, 10, 10, 11, 11
    final minute = (i % 2) == 0 ? 0 : 30; // 00, 30, 00, 30, etc
    final start = DateTime(date.year, date.month, date.day, hour, minute);
    final end = start.add(const Duration(hours: 1));

    slots.add(AvailableSlot(
      startTime: start,
      endTime: end,
      displayText:
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} · 1hr',
    ));
  }
  return slots;
}

/// Sample booking request for testing
BookingRequest createMockBookingRequest({
  String date = '2026-02-25',
  String time = '10:00',
  String clientName = 'John Doe',
  String clientEmail = 'john.doe@example.com',
  String? notes,
}) =>
    BookingRequest(
      date: date,
      time: time,
      clientName: clientName,
      clientEmail: clientEmail,
      notes: notes,
    );

/// Batch create multiple booking requests with variations
List<BookingRequest> createMultipleBookingRequests({int count = 3}) => [
      for (int i = 0; i < count; i++)
        BookingRequest(
          date: '2026-02-${25 + i}',
          time: '${9 + i}:00',
          clientName: 'Client $i',
          clientEmail: 'client$i@example.com',
          notes: i % 2 == 0 ? null : 'Note for client $i',
        ),
    ];

/// Common test dates for consistent testing
class TestDates {
  static DateTime get today => DateTime.now();
  static DateTime get tomorrow => today.add(const Duration(days: 1));
  static DateTime get in7Days => today.add(const Duration(days: 7));
  static DateTime get in30Days => today.add(const Duration(days: 30));
  static DateTime get in90Days => today.add(const Duration(days: 90));

  /// Generate a date string in YYYY-MM-DD format
  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Generate a time string in HH:MM format
  static String formatTime(DateTime dateTime) =>
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

/// Test validation cases for email addresses
class EmailValidationCases {
  static const List<String> validEmails = [
    'test@example.com',
    'user+tag@domain.co.uk',
    'contact.name@my-company.org',
    'user.name+filters@example.com',
  ];

  static const List<String> invalidEmails = [
    'invalid',
    'invalid@',
    '@invalid.com',
    'invalid@.com',
    'invalid @example.com',
    'invalid..name@example.com',
  ];
}

/// Test validation cases for names
class NameValidationCases {
  static const List<String> validNames = [
    'John Doe',
    'Jane',
    'José García',
    'O\'Brien',
    'Jean-Pierre',
  ];

  static const List<String> invalidNames = [
    '',
    '   ',
    '123',
    '@invalid',
  ];
}
