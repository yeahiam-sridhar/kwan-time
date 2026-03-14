import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwan_time/core/providers/event_provider.dart';
import 'package:kwan_time/core/theme/kwan_theme.dart';
import 'package:kwan_time/features/slide1_calendar/calendar_screen.dart';
import 'package:kwan_time/features/slide1_calendar/widgets/week_view.dart';
import 'package:kwan_time/shared/widgets/kwan_fab.dart';

void main() {
  Widget buildTestApp() => ProviderScope(
        overrides: [
          eventsForMonthProvider.overrideWith((ref, month) async => const []),
          eventsForDayProvider.overrideWith((ref, day) async => const []),
          eventsForDateRangeProvider.overrideWith((ref, range) async => const []),
        ],
        child: MaterialApp(
          theme: KwanTheme.dark(),
          home: const CalendarScreen(),
        ),
      );

  testWidgets('CalendarScreen renders without crash', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('KWAN'), findsOneWidget);
  });

  testWidgets('View toggle shows Month/Week/Day', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
  });

  testWidgets('Tapping Week toggle switches to WeekView', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Week'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(WeekView), findsOneWidget);
  });

  testWidgets('FAB is visible on calendar screen', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(KwanFab), findsOneWidget);
  });

  testWidgets('QuickAddSheet opens on FAB tap', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byType(KwanFab), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('New Event'), findsOneWidget);
  });
}
