import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../audio/audio_gatekeeper.dart';
import 'voice_input_service.dart';

class VoiceService {
  VoiceService._();

  static final VoiceService instance = VoiceService._();

  final SpeechToText _speech = SpeechToText();
  bool _available = false;
  bool _initialized = false;
  bool _initializing = false;
  bool _captureInProgress = false;
  String _lastWords = '';

  void Function(String partial)? onPartialResult;
  void Function(double amplitude)? onAmplitude;
  void Function(String finalResult)? onFinalResult;
  void Function(String error)? onError;

  Future<bool> initialize() async {
    if (_initialized) {
      return _available;
    }
    if (_initializing) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return _available;
    }
    _initializing = true;
    _available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('STT Status: $status');
        if ((status == 'done' || status == 'notListening') && _lastWords.isNotEmpty) {
          onFinalResult?.call(_lastWords);
        }
      },
      onError: (error) {
        debugPrint('STT Error: ${error.errorMsg}');
        onError?.call(error.errorMsg);
      },
      debugLogging: true,
      finalTimeout: const Duration(seconds: 5),
    );
    _initialized = true;
    _initializing = false;
    return _available;
  }

  Future<bool> startListening() async {
    await AudioGatekeeper.instance.process(GatekeeperEvent.micStart);
    _captureInProgress = true;
    _lastWords = '';
    onAmplitude?.call(0.6);
    unawaited(() async {
      try {
        final transcript = await VoiceInputService.capture();
        if (transcript.isEmpty) {
          onError?.call('empty_transcript');
          return;
        }
        _lastWords = transcript;
        onPartialResult?.call(_lastWords);
        onFinalResult?.call(_lastWords);
      } finally {
        _captureInProgress = false;
        onAmplitude?.call(0.0);
        unawaited(AudioGatekeeper.instance.process(GatekeeperEvent.micStop));
      }
    }());
    return true;
  }

  void stopListening() {
    _captureInProgress = false;
    unawaited(VoiceInputService.stopCapture());
    unawaited(AudioGatekeeper.instance.process(GatekeeperEvent.micStop));
  }

  void cancelListening() {
    _captureInProgress = false;
    unawaited(VoiceInputService.cancelCapture());
    unawaited(AudioGatekeeper.instance.process(GatekeeperEvent.micStop));
  }

  bool get isListening => _captureInProgress;

  bool get isAvailable => _available;
}

class EventDraft {
  const EventDraft({
    required this.date,
    required this.time,
    required this.durationMinutes,
    required this.location,
    required this.title,
    required this.eventType,
    required this.recurrenceRule,
    required this.confidence,
    required this.rawTranscript,
  });

  final DateTime? date;
  final TimeOfDay? time;
  final int durationMinutes;
  final String? location;
  final String title;
  final String eventType;
  final String? recurrenceRule;
  final ParseConfidence confidence;
  final String rawTranscript;
}

enum ParseConfidence { high, medium, low }

class VoiceNLPParser {
  static EventDraft parse(String transcript) {
    final raw = transcript.toLowerCase().trim();
    return EventDraft(
      date: _extractDate(raw),
      time: _extractTime(raw),
      durationMinutes: _extractDuration(raw),
      location: _extractLocation(transcript),
      title: _extractTitle(raw),
      eventType: _extractType(raw),
      recurrenceRule: _extractRecurrence(raw),
      confidence: _computeConfidence(raw),
      rawTranscript: transcript.trim(),
    );
  }

  static DateTime? _extractDate(String s) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (s.contains('day after tomorrow')) {
      return today.add(const Duration(days: 2));
    }
    if (s.contains('today') || s.contains('tonight')) {
      return today;
    }
    if (s.contains('tomorrow')) {
      return today.add(const Duration(days: 1));
    }

    final weekdays = <String>[
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    for (var i = 0; i < weekdays.length; i++) {
      if (s.contains('next ${weekdays[i]}') || s.contains('this ${weekdays[i]}')) {
        final targetWeekday = i + 1;
        var daysAhead = targetWeekday - now.weekday;
        if (daysAhead <= 0) {
          daysAhead += 7;
        }
        return today.add(Duration(days: daysAhead));
      }
    }

    final months = <String, int>{
      'january': 1,
      'jan': 1,
      'february': 2,
      'feb': 2,
      'march': 3,
      'mar': 3,
      'april': 4,
      'apr': 4,
      'may': 5,
      'june': 6,
      'jun': 6,
      'july': 7,
      'jul': 7,
      'august': 8,
      'aug': 8,
      'september': 9,
      'sep': 9,
      'october': 10,
      'oct': 10,
      'november': 11,
      'nov': 11,
      'december': 12,
      'dec': 12,
    };

    for (final month in months.entries) {
      final patternDayMonth = RegExp(r'\b(\d{1,2})\s+' + month.key + r'(?:\s+(\d{4}))?\b');
      final dayMonth = patternDayMonth.firstMatch(s);
      if (dayMonth != null) {
        final day = int.parse(dayMonth.group(1)!);
        var year = int.tryParse(dayMonth.group(2) ?? '') ?? now.year;
        var candidate = DateTime(year, month.value, day);
        if (dayMonth.group(2) == null && candidate.isBefore(today)) {
          year += 1;
          candidate = DateTime(year, month.value, day);
        }
        return candidate;
      }

      final patternMonthDay = RegExp(r'\b' + month.key + r'\s+(\d{1,2})(?:\s+(\d{4}))?\b');
      final monthDay = patternMonthDay.firstMatch(s);
      if (monthDay != null) {
        final day = int.parse(monthDay.group(1)!);
        var year = int.tryParse(monthDay.group(2) ?? '') ?? now.year;
        var candidate = DateTime(year, month.value, day);
        if (monthDay.group(2) == null && candidate.isBefore(today)) {
          year += 1;
          candidate = DateTime(year, month.value, day);
        }
        return candidate;
      }
    }

    final dayMonthNumeric = RegExp(r'\b(\d{1,2})[\/\-](\d{1,2})\b').firstMatch(s);
    if (dayMonthNumeric != null) {
      final day = int.parse(dayMonthNumeric.group(1)!);
      final month = int.parse(dayMonthNumeric.group(2)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        var year = now.year;
        var candidate = DateTime(year, month, day);
        if (candidate.isBefore(today)) {
          year += 1;
          candidate = DateTime(year, month, day);
        }
        return candidate;
      }
    }

    return null;
  }

  static TimeOfDay? _extractTime(String s) {
    if (s.contains('noon')) {
      return const TimeOfDay(hour: 12, minute: 0);
    }
    if (s.contains('midnight')) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
    if (s.contains('morning') && !RegExp(r'\d').hasMatch(s)) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    if (s.contains('afternoon') && !RegExp(r'\d').hasMatch(s)) {
      return const TimeOfDay(hour: 14, minute: 0);
    }
    if (s.contains('evening') && !RegExp(r'\d').hasMatch(s)) {
      return const TimeOfDay(hour: 18, minute: 0);
    }

    final halfPast = RegExp(r'\bhalf past (\d{1,2})\b').firstMatch(s);
    if (halfPast != null) {
      var hour = int.parse(halfPast.group(1)!);
      final assumePm = s.contains('pm') || (hour >= 1 && hour <= 6);
      if (assumePm && hour < 12) {
        hour += 12;
      }
      return TimeOfDay(hour: hour % 24, minute: 30);
    }

    final quarterTo = RegExp(r'\bquarter to (\d{1,2})\b').firstMatch(s);
    if (quarterTo != null) {
      var hour = int.parse(quarterTo.group(1)!) - 1;
      if (hour < 0) {
        hour = 23;
      }
      final assumePm = s.contains('pm') || (hour >= 1 && hour <= 6);
      if (assumePm && hour < 12) {
        hour += 12;
      }
      return TimeOfDay(hour: hour % 24, minute: 45);
    }

    final quarterPast = RegExp(r'\bquarter past (\d{1,2})\b').firstMatch(s);
    if (quarterPast != null) {
      var hour = int.parse(quarterPast.group(1)!);
      final assumePm = s.contains('pm') || (hour >= 1 && hour <= 6);
      if (assumePm && hour < 12) {
        hour += 12;
      }
      return TimeOfDay(hour: hour % 24, minute: 15);
    }

    final oClock = RegExp(r"\b(\d{1,2})\s*o'?clock\b").firstMatch(s);
    if (oClock != null) {
      var hour = int.parse(oClock.group(1)!);
      if (s.contains('pm') || (hour < 7 && !s.contains('am'))) {
        hour += 12;
      }
      if (s.contains('am') && hour == 12) {
        hour = 0;
      }
      return TimeOfDay(hour: hour % 24, minute: 0);
    }

    final amPm = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b').firstMatch(s);
    if (amPm != null) {
      var hour = int.parse(amPm.group(1)!);
      final minute = int.tryParse(amPm.group(2) ?? '0') ?? 0;
      final meridiem = amPm.group(3);
      if (meridiem == 'pm' && hour < 12) {
        hour += 12;
      }
      if (meridiem == 'am' && hour == 12) {
        hour = 0;
      }
      return TimeOfDay(hour: hour % 24, minute: minute.clamp(0, 59));
    }

    final twentyFour = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b').firstMatch(s);
    if (twentyFour != null) {
      final hour = int.parse(twentyFour.group(1)!);
      final minute = int.parse(twentyFour.group(2)!);
      return TimeOfDay(hour: hour, minute: minute);
    }

    final plainHour = RegExp(r'\b(?:at|by|around)?\s*(\d{1,2})\b').firstMatch(s);
    if (plainHour != null) {
      var hour = int.parse(plainHour.group(1)!);
      if (hour <= 23) {
        if (hour < 7) {
          hour += 12;
        }
        return TimeOfDay(hour: hour % 24, minute: 0);
      }
    }

    return null;
  }

  static int _extractDuration(String s) {
    final hours = RegExp(r'\b(\d+)\s*h(?:our)?s?\b').firstMatch(s);
    if (hours != null) {
      return int.parse(hours.group(1)!) * 60;
    }

    final minutes = RegExp(r'\b(\d+)\s*m(?:in(?:ute)?s?)?\b').firstMatch(s);
    if (minutes != null) {
      final value = int.parse(minutes.group(1)!);
      if (value <= 300) {
        return value;
      }
    }

    return 60;
  }

  static String? _extractLocation(String original) {
    final atMatch = RegExp(
      r'\bat\s+([A-Za-z][A-Za-z\s]{1,30}?)(?=(?:\s+(?:at|on|for|by)\b|\s+\d|$))',
      caseSensitive: false,
    ).firstMatch(original);
    if (atMatch != null) {
      final location = atMatch.group(1)?.trim();
      if (location != null && location.isNotEmpty) {
        final low = location.toLowerCase();
        const blocked = <String>{
          'the',
          'a',
          'an',
          'noon',
          'midnight',
          'morning',
          'afternoon',
          'evening',
        };
        if (!blocked.contains(low)) {
          return location;
        }
      }
    }

    final inMatch = RegExp(
      r'\bin\s+([A-Za-z][A-Za-z\s]{1,30}?)(?=(?:\s+(?:at|on|for|by)\b|\s+\d|$))',
      caseSensitive: false,
    ).firstMatch(original);
    if (inMatch != null) {
      return inMatch.group(1)?.trim();
    }
    return null;
  }

  static String _extractType(String s) {
    if (s.contains('online') ||
        s.contains('video') ||
        s.contains('zoom') ||
        s.contains('teams') ||
        s.contains('call') ||
        s.contains('virtual') ||
        s.contains('meet') ||
        s.contains('webinar')) {
      return 'online';
    }
    return 'in_person';
  }

  static String? _extractRecurrence(String s) {
    if (s.contains('every day') || s.contains('daily')) {
      return 'daily';
    }
    if (s.contains('every week') || s.contains('weekly')) {
      return 'weekly';
    }
    if (s.contains('every month') || s.contains('monthly')) {
      return 'monthly';
    }
    if (RegExp(
      r'\bevery (monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    ).hasMatch(s)) {
      return 'weekly';
    }
    return null;
  }

  static String _extractTitle(String lower) {
    var working = lower;
    const patterns = <String>[
      r'\b(book|schedule|add|create|set up|setup|remind me|remind)\b',
      r'\b(today|tomorrow|tonight|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
      r'\b(january|february|march|april|may|june|july|august|september|october|november|december)\b',
      r'\b(jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\b',
      r"\b\d{1,2}(?::\d{2})?\s*(am|pm|o'?clock)?\b",
      r'\b(at|in|for|on|next|this|the|a|an|by|around)\b',
      r'\b\d{1,2}[\/\-]\d{1,2}\b',
      r'\b(half past|quarter to|quarter past|noon|midnight)\b',
      r'\b(online|video|zoom|teams|call|in person|visit|virtual|webinar)\b',
      r'\b(every|daily|weekly|monthly)\b',
    ];
    for (final pattern in patterns) {
      working = working.replaceAll(RegExp(pattern), ' ');
    }
    working = working.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (working.isEmpty || working.length < 3) {
      return 'New Event';
    }

    return working
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .map(
          (word) => word.length == 1 ? word.toUpperCase() : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  static ParseConfidence _computeConfidence(String s) {
    final hasDate = _extractDate(s) != null;
    final hasTime = _extractTime(s) != null;
    if (hasDate && hasTime) {
      return ParseConfidence.high;
    }
    if (hasDate || hasTime) {
      return ParseConfidence.medium;
    }
    return ParseConfidence.low;
  }
}
