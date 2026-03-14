// ═══════════════════════════════════════════════════════════════════════════
// KWAN-TIME v2.0 — Week View
// Agent 6: Classic Calendar View
//
// Displays 7-day week with hourly time slots and drag-and-drop events.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Week view widget — 7-day grid with hourly slots
class WeekView extends ConsumerStatefulWidget {
  const WeekView({super.key});

  @override
  ConsumerState<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<WeekView> {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Week View'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Week View',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Coming soon!',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
}
