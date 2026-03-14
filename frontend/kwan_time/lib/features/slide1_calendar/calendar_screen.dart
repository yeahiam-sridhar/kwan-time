import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/event_provider.dart';
import '../../core/theme/kwan_theme.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/kwan_fab.dart';
import '../../shared/widgets/voice_sheet.dart';
import 'widgets/day_view.dart';
import 'widgets/month_view.dart';
import 'widgets/quick_add_sheet.dart';
import 'widgets/week_view.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  String _viewMode = 'month';

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildViewToggle(),
                  Expanded(child: _buildCurrentView()),
                ],
              ),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: KwanFab(
                onAdd: () => _openQuickAdd(context, null),
                onVoice: () => _openVoiceSheet(context),
              ),
            ),
          ],
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Text(
              'KWAN·TIME',
              style: KwanText.titleLarge.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            GlassPill(
              child: Text(
                DateFormat('d MMM yyyy').format(DateTime.now()),
                style: KwanText.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.mic_none_rounded,
                  color: KwanColors.textSecondary),
              onPressed: () => _openVoiceSheet(context),
            ),
            IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                color: KwanColors.textSecondary,
              ),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
      );

  Widget _buildViewToggle() {
    Widget toggleButton(String label, String mode) {
      final selected = _viewMode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () async {
            setState(() => _viewMode = mode);
            await HapticFeedback.selectionClick();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? KwanColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text(
                label,
                style: KwanText.bodyMedium.copyWith(
                  color: selected ? Colors.white : KwanColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GlassCard(
        opacity: 0.08,
        borderRadius: 999,
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            toggleButton('Month', 'month'),
            toggleButton('Week', 'week'),
            toggleButton('Day', 'day'),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView() => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        child: switch (_viewMode) {
          'month' => RepaintBoundary(
              key: const ValueKey('month'),
              child: MonthView(
                onDaySelected: (day) {
                  ref.read(selectedDayProvider.notifier).state = day;
                  setState(() => _viewMode = 'day');
                },
              ),
            ),
          'week' => RepaintBoundary(
              key: const ValueKey('week'),
              child: WeekView(
                onDaySelected: (day) {
                  ref.read(selectedDayProvider.notifier).state = day;
                  setState(() => _viewMode = 'day');
                },
              ),
            ),
          'day' => const RepaintBoundary(
              key: ValueKey('day'),
              child: DayView(),
            ),
          _ => RepaintBoundary(
              key: const ValueKey('month-fallback'),
              child: MonthView(
                onDaySelected: (day) {
                  ref.read(selectedDayProvider.notifier).state = day;
                  setState(() => _viewMode = 'day');
                },
              ),
            ),
        },
      );

  Future<void> _openQuickAdd(BuildContext context, DateTime? date) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddSheet(initialDate: date),
    );
  }

  Future<void> _openVoiceSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceSheet(),
    );
  }
}
