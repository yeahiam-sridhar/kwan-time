import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwan_time/core/services/voice_service.dart';

void main() {
  group('VoiceNLPParser - Date Extraction', () {
    test('extracts "21 december 2025"', () {
      final draft = VoiceNLPParser.parse('book 21 december 2025 at Chennai 11 oclock');
      expect(draft.date, isNotNull);
      expect(draft.date!.day, equals(21));
      expect(draft.date!.month, equals(12));
      expect(draft.date!.year, equals(2025));
    });

    test('extracts "tomorrow"', () {
      final draft = VoiceNLPParser.parse('meeting tomorrow at 3pm');
      expect(draft.date, isNotNull);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(draft.date!.year, equals(tomorrow.year));
      expect(draft.date!.month, equals(tomorrow.month));
      expect(draft.date!.day, equals(tomorrow.day));
    });

    test('extracts "next monday"', () {
      final draft = VoiceNLPParser.parse('call next monday at 10am');
      expect(draft.date, isNotNull);
      expect(draft.date!.weekday, equals(DateTime.monday));
    });

    test('extracts "today"', () {
      final draft = VoiceNLPParser.parse('add meeting today at noon');
      expect(draft.date, isNotNull);
      final now = DateTime.now();
      expect(draft.date!.year, equals(now.year));
      expect(draft.date!.month, equals(now.month));
      expect(draft.date!.day, equals(now.day));
    });
  });

  group('VoiceNLPParser - Time Extraction', () {
    test('extracts "11 oclock"', () {
      final draft = VoiceNLPParser.parse('book Chennai 21 dec at 11 oclock');
      expect(draft.time, isNotNull);
      expect(draft.time!.hour, equals(11));
      expect(draft.time!.minute, equals(0));
    });

    test('extracts "3pm"', () {
      final draft = VoiceNLPParser.parse('meeting tomorrow at 3pm');
      expect(draft.time, isNotNull);
      expect(draft.time!.hour, equals(15));
      expect(draft.time!.minute, equals(0));
    });

    test('extracts "half past 3"', () {
      final draft = VoiceNLPParser.parse('call half past 3');
      expect(draft.time, isNotNull);
      expect(draft.time!.minute, equals(30));
    });

    test('extracts "noon"', () {
      final draft = VoiceNLPParser.parse('lunch meeting at noon');
      expect(draft.time, isNotNull);
      expect(draft.time, equals(const TimeOfDay(hour: 12, minute: 0)));
    });

    test('extracts "quarter to 5"', () {
      final draft = VoiceNLPParser.parse('call quarter to 5');
      expect(draft.time, isNotNull);
      expect(draft.time!.minute, equals(45));
    });
  });

  group('VoiceNLPParser - Event Type', () {
    test('detects online from "zoom call"', () {
      final draft = VoiceNLPParser.parse('zoom call tomorrow at 2pm');
      expect(draft.eventType, equals('online'));
    });

    test('detects online from "video meeting"', () {
      final draft = VoiceNLPParser.parse('video meeting with client at 10am');
      expect(draft.eventType, equals('online'));
    });

    test('defaults to in_person when not clearly online', () {
      final draft = VoiceNLPParser.parse('visit Chennai office tomorrow');
      expect(draft.eventType, equals('in_person'));
    });
  });

  group('VoiceNLPParser - Location', () {
    test('extracts "at Chennai"', () {
      final draft = VoiceNLPParser.parse('book 21 december at Chennai 11 oclock');
      expect(draft.location, isNotNull);
      expect(draft.location!.toLowerCase(), contains('chennai'));
    });

    test('extracts "in Mumbai"', () {
      final draft = VoiceNLPParser.parse('meeting in Mumbai next Monday');
      expect(draft.location, isNotNull);
      expect(draft.location!.toLowerCase(), contains('mumbai'));
    });
  });

  group('VoiceNLPParser - Duration', () {
    test('extracts "2 hours"', () {
      final draft = VoiceNLPParser.parse('meeting for 2 hours tomorrow');
      expect(draft.durationMinutes, equals(120));
    });

    test('extracts "30 minutes"', () {
      final draft = VoiceNLPParser.parse('call for 30 minutes');
      expect(draft.durationMinutes, equals(30));
    });

    test('defaults to 60 if no duration', () {
      final draft = VoiceNLPParser.parse('meeting tomorrow');
      expect(draft.durationMinutes, equals(60));
    });
  });

  group('VoiceNLPParser - Confidence', () {
    test('HIGH when date + time both found', () {
      final draft = VoiceNLPParser.parse('meeting tomorrow at 3pm');
      expect(draft.confidence, equals(ParseConfidence.high));
    });

    test('MEDIUM when only date found', () {
      final draft = VoiceNLPParser.parse('meeting tomorrow');
      expect(draft.confidence, equals(ParseConfidence.medium));
    });

    test('LOW when neither found', () {
      final draft = VoiceNLPParser.parse('book something');
      expect(draft.confidence, equals(ParseConfidence.low));
    });
  });

  group('VoiceNLPParser - Recurrence', () {
    test('detects daily', () {
      final draft = VoiceNLPParser.parse('standup every day at 9am');
      expect(draft.recurrenceRule, equals('daily'));
    });

    test('detects weekly', () {
      final draft = VoiceNLPParser.parse('team meeting every monday');
      expect(draft.recurrenceRule, equals('weekly'));
    });
  });
}
