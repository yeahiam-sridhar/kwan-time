import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:kwan_time/core/models/event.dart';
import 'package:kwan_time/core/providers/event_provider.dart';
import 'package:kwan_time/core/theme/kwan_theme.dart';
import 'package:kwan_time/features/slide2_dashboard/dashboard_screen.dart';

void main() {
  final now = DateTime.now();
  final selectedMonth = DateTime(now.year, now.month, 1);
  final nextMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
  final futureMonth = DateTime(selectedMonth.year, selectedMonth.month + 2, 1);

  Event buildEvent({
    required String id,
    required String title,
    required DateTime start,
    required String eventType,
    required String status,
  }) {
    final end = start.add(const Duration(hours: 1));
    return Event(
      id: id,
      title: title,
      eventType: eventType,
      status: status,
      startTime: start,
      endTime: end,
      createdAt: start.subtract(const Duration(days: 2)),
      updatedAt: start.subtract(const Duration(days: 1)),
    );
  }

  final allEvents = <Event>[
    buildEvent(
      id: 'cur-1',
      title: 'Board Strategy Sync',
      start: DateTime(selectedMonth.year, selectedMonth.month, 3, 9),
      eventType: 'online',
      status: 'in_progress',
    ),
    buildEvent(
      id: 'cur-2',
      title: 'Partner Workshop',
      start: DateTime(selectedMonth.year, selectedMonth.month, 12, 11),
      eventType: 'in_person',
      status: 'not_started',
    ),
    buildEvent(
      id: 'cur-3',
      title: 'Monthly Close Review',
      start: DateTime(selectedMonth.year, selectedMonth.month, 23, 16),
      eventType: 'online',
      status: 'not_started',
    ),
    buildEvent(
      id: 'next-1',
      title: 'Capacity Planning',
      start: DateTime(nextMonth.year, nextMonth.month, 8, 10),
      eventType: 'in_person',
      status: 'not_started',
    ),
    buildEvent(
      id: 'next-2',
      title: 'Quarter Kickoff',
      start: DateTime(nextMonth.year, nextMonth.month, 16, 13),
      eventType: 'online',
      status: 'not_started',
    ),
    buildEvent(
      id: 'future-1',
      title: 'Future Growth Session',
      start: DateTime(futureMonth.year, futureMonth.month, 10, 15),
      eventType: 'online',
      status: 'not_started',
    ),
  ];

  Widget buildTestApp() => ProviderScope(
        overrides: [
          eventsForDateRangeProvider.overrideWith(
            (ref, range) async {
              return allEvents.where((event) {
                final start = event.startTime;
                return !start.isBefore(range.from) && start.isBefore(range.to);
              }).toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));
            },
          ),
        ],
        child: MaterialApp(
          theme: KwanTheme.dark(),
          home: const DashboardScreen(),
        ),
      );

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(buildTestApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('Dashboard screen renders 3-month command center shell', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.text('OVERVIEW'), findsOneWidget);
    expect(find.text('3-Month Horizon'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(GridView), findsNWidgets(3));

    await cleanup(tester);
  });

  testWidgets('Dashboard uses reminder dataset in event intelligence list', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.text('Board Strategy Sync'), findsOneWidget);
    expect(find.text('Partner Workshop'), findsOneWidget);

    await cleanup(tester);
  });

  testWidgets('Month selection switches list to next month events', (
    tester,
  ) async {
    await pumpDashboard(tester);

    final nextMonthLabel = DateFormat('MMMM').format(nextMonth);

    await tester.tap(find.text(nextMonthLabel).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Capacity Planning'), findsOneWidget);
    expect(find.text('Quarter Kickoff'), findsOneWidget);
    await cleanup(tester);
  });
}
