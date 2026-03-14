import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// KWAN-TIME v2.0 — Event Type Colors
/// SINGLE SOURCE OF TRUTH — never define colors elsewhere
/// ═══════════════════════════════════════════════════════════════════════════

class EventColors {
  EventColors._();

  static const Color online = Color(0xFF4A90E2); // Blue
  static const Color inPerson = Color(0xFFE07B3C); // Orange
  static const Color free = Color(0xFF4CAF50); // Green
  static const Color booked = Color(0xFF2E7D32); // Dark Green
  static const Color cancelled = Color(0xFFD32F2F); // Red
  static const Color notStarted = Color(0xFF9E9E9E); // Grey
  static const Color inProgress = Color(0xFFFFC107); // Amber
  static const Color completed = Color(0xFF00BCD4); // Teal

  static const Map<String, Color> byType = {
    'online': online,
    'in_person': inPerson,
    'free': free,
    'booked': booked,
    'cancelled': cancelled,
    'not_started': notStarted,
    'in_progress': inProgress,
    'completed': completed,
  };

  static Color getColor(String type) => byType[type] ?? online;
}
