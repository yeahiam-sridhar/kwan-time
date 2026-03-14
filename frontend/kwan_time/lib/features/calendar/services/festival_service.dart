import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FestivalService {
  FestivalService._();
  static final FestivalService instance = FestivalService._();

  Map<String, String> _festivals = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/festivals.json');
      _festivals = Map<String, String>.from(jsonDecode(raw) as Map);
      _loaded = true;
      debugPrint('[FestivalService] Loaded ${_festivals.length} festivals');
    } catch (e) {
      debugPrint('[FestivalService] Failed to load: $e');
    }
  }

  /// Returns festival name for a date, or null if no festival.
  String? festivalFor(DateTime date) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _festivals[key];
  }

  /// Returns true if the given date has a festival.
  bool hasFestival(DateTime date) => festivalFor(date) != null;

  /// Returns all festivals for a given month.
  Map<DateTime, String> festivalsForMonth(int year, int month) {
    final result = <DateTime, String>{};
    for (final entry in _festivals.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) {
        continue;
      }
      if (y == year && m == month) {
        result[DateTime(y, m, d)] = entry.value;
      }
    }
    return result;
  }
}
