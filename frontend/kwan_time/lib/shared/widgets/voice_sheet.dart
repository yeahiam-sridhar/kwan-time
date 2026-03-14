import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/sound_keys.dart';
import '../../core/database/dao/event_dao.dart';
import '../../core/models/event.dart';
import '../../core/providers/event_provider.dart';
import '../../core/services/haptic_engine.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/kwan_theme.dart';
import '../../features/slide1_calendar/widgets/quick_add_sheet.dart';
import 'glass_card.dart';

enum VoiceState { idle, listening, processing, preview, confirmed, error }

class VoiceSheet extends ConsumerStatefulWidget {
  const VoiceSheet({super.key});

  @override
  ConsumerState<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends ConsumerState<VoiceSheet> with SingleTickerProviderStateMixin {
  VoiceState _state = VoiceState.idle;
  String _transcript = '';
  double _amplitude = 0;
  EventDraft? _draft;
  bool _hasConflict = false;
  List<Event> _conflictingEvents = const [];
  late final AnimationController _waveController;
  bool _handlingFinal = false;
  String _confirmationSummary = '';

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    VoiceService.instance.stopListening();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF10172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: _buildBody(context),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildHandle() => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: KwanColors.textDisabled,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case VoiceState.idle:
        return _buildIdle();
      case VoiceState.listening:
        return _buildListening();
      case VoiceState.processing:
        return _buildProcessing();
      case VoiceState.preview:
        return _buildPreview(context);
      case VoiceState.confirmed:
        return _buildConfirmed();
      case VoiceState.error:
        return _buildError();
    }
  }

  Widget _buildIdle() => Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.mic_rounded, size: 72, color: KwanColors.accent),
              const SizedBox(height: 20),
              const Text('Tap to speak', style: KwanText.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Try: "Book Chennai 21 Dec at 11"',
                style: KwanText.bodySmall.copyWith(color: KwanColors.textSecondary),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _startListening,
                icon: const Icon(Icons.mic),
                label: const Text('Start Listening'),
              ),
            ],
          ),
        ),
      );

  Widget _buildListening() => GestureDetector(
        onTap: _stopListening,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, _buildWaveBar),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: KwanGlass.card(),
                  child: Text(
                    _transcript.isEmpty ? 'Listening...' : _transcript,
                    style: KwanText.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Tap anywhere to stop', style: KwanText.bodySmall),
                const SizedBox(height: 16),
                TextButton(onPressed: _stopListening, child: const Text('Done')),
              ],
            ),
          ),
        ),
      );

  Widget _buildWaveBar(int index) => AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          final centerDistance = (index - 2).abs();
          final wave = 0.3 + (_waveController.value * 0.4 * (1 - centerDistance * 0.2));
          final heightFactor = index == 2 ? _amplitude : wave.clamp(0.2, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 6,
            height: 8 + (heightFactor * 40),
            decoration: BoxDecoration(
              color: KwanColors.accent.withValues(
                alpha: (0.6 + heightFactor * 0.4).clamp(0.0, 1.0),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        },
      );

  Widget _buildProcessing() => const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: KwanColors.accent),
              SizedBox(height: 16),
              Text('Understanding...', style: KwanText.titleMedium),
            ],
          ),
        ),
      );

  Widget _buildPreview(BuildContext context) {
    final draft = _draft;
    if (draft == null) {
      return const SizedBox.shrink();
    }

    final confidenceColor = _confidenceColor(draft.confidence);
    final confidenceLabel = _confidenceLabel(draft.confidence);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: KwanGlass.card(opacity: 0.05),
          child: Row(
            children: [
              const Icon(Icons.record_voice_over, size: 16, color: KwanColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '"${draft.rawTranscript}"',
                  style: KwanText.bodySmall.copyWith(fontStyle: FontStyle.italic, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            children: [
              _buildDraftRow(
                icon: Icons.title,
                label: 'Event',
                value: draft.title,
              ),
              _divider(),
              _buildDraftRow(
                icon: Icons.calendar_today,
                label: 'Date',
                value: draft.date != null ? DateFormat('EEE, d MMMM yyyy').format(draft.date!) : null,
                confidence: draft.date != null ? ParseConfidence.high : ParseConfidence.low,
              ),
              _divider(),
              _buildDraftRow(
                icon: Icons.access_time,
                label: 'Time',
                value: draft.time?.format(context),
                confidence: draft.time != null ? ParseConfidence.high : ParseConfidence.low,
              ),
              if (draft.location != null) ...[
                _divider(),
                _buildDraftRow(
                  icon: Icons.location_on,
                  label: 'Location',
                  value: draft.location,
                ),
              ],
              _divider(),
              _buildDraftRow(
                icon: Icons.access_time_filled,
                label: 'Duration',
                value: '${draft.durationMinutes} min',
              ),
              _divider(),
              _buildDraftRow(
                icon: draft.eventType == 'online' ? Icons.videocam : Icons.people,
                label: 'Type',
                value: draft.eventType == 'online' ? 'Online' : 'In-Person',
                color: draft.eventType == 'online' ? KwanColors.online : KwanColors.inPerson,
              ),
            ],
          ),
        ),
        if (_hasConflict && _conflictingEvents.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KwanColors.cancelled.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: KwanColors.cancelled.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: KwanColors.cancelled,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Overlaps with "${_conflictingEvents.first.title}"',
                    style: KwanText.bodySmall.copyWith(
                      color: KwanColors.cancelled,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: confidenceColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$confidenceLabel confidence',
              style: KwanText.bodySmall.copyWith(color: confidenceColor),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetToIdle,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openEditSheet,
                icon: const Icon(Icons.edit, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KwanColors.inProgress,
                  side: BorderSide(
                    color: KwanColors.inProgress.withValues(alpha: 0.5),
                  ),
                ),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _confirmBooking,
                icon: const Icon(Icons.check, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KwanColors.free,
                ),
                label: const Text('Book It'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmed() => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.check_circle_rounded, size: 80, color: KwanColors.free).animate().scale(
                    begin: const Offset(0, 0),
                    end: const Offset(1, 1),
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(height: 16),
              const Text('Booked!', style: KwanText.displayMedium),
              const SizedBox(height: 8),
              Text(
                _confirmationSummary,
                style: KwanText.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );

  Widget _buildError() => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.mic_off, size: 64, color: KwanColors.cancelled),
              const SizedBox(height: 12),
              const Text('Microphone unavailable', style: KwanText.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Check microphone permission in\nSettings -> Apps -> KWAN-TIME -> Permissions',
                style: KwanText.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: openAppSettings,
                child: const Text('Open Settings'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _resetToIdle,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );

  Widget _buildDraftRow({
    required IconData icon,
    required String label,
    required String? value,
    ParseConfidence? confidence,
    Color? color,
  }) {
    final displayColor = color ?? (confidence == null ? KwanColors.textPrimary : _confidenceColor(confidence));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: KwanColors.textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label, style: KwanText.bodySmall),
          ),
          Expanded(
            child: value == null
                ? Text(
                    'Tap to set',
                    style: KwanText.bodySmall.copyWith(
                      color: KwanColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Text(
                    value,
                    style: KwanText.bodyMedium.copyWith(
                      color: displayColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: KwanColors.bgDivider);

  Future<void> _startListening() async {
    await SoundService.instance.play(SoundKeys.voiceStart);
    await HapticEngine.voiceStart();

    final service = VoiceService.instance;
    final ok = await service.initialize();
    if (!ok) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone unavailable')),
      );
      setState(() => _state = VoiceState.error);
      return;
    }

    service.onPartialResult = (text) {
      if (!mounted) {
        return;
      }
      setState(() => _transcript = text);
    };
    service.onAmplitude = (amplitude) {
      if (!mounted) {
        return;
      }
      setState(() => _amplitude = amplitude);
    };
    service.onFinalResult = _onFinalResult;
    service.onError = (message) {
      if (!mounted) {
        return;
      }
      setState(() => _state = VoiceState.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice error: $message'),
          backgroundColor: KwanColors.cancelled,
        ),
      );
    };

    final started = await service.startListening();
    if (!mounted) {
      return;
    }
    if (!started) {
      setState(() => _state = VoiceState.error);
      return;
    }
    setState(() => _state = VoiceState.listening);
  }

  Future<void> _stopListening() async {
    VoiceService.instance.stopListening();
    await HapticEngine.selection();
  }

  Future<void> _onFinalResult(String transcript) async {
    if (_handlingFinal) {
      return;
    }
    _handlingFinal = true;
    try {
      final cleaned = transcript.trim();
      if (cleaned.isEmpty) {
        if (!mounted) {
          return;
        }
        _resetToIdle();
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _state = VoiceState.processing;
        _transcript = cleaned;
      });

      await Future<void>.delayed(const Duration(milliseconds: 400));

      final draft = VoiceNLPParser.parse(cleaned);
      var hasConflict = false;
      var conflicts = <Event>[];
      if (draft.date != null && draft.time != null) {
        final start = DateTime(
          draft.date!.year,
          draft.date!.month,
          draft.date!.day,
          draft.time!.hour,
          draft.time!.minute,
        );
        final end = start.add(Duration(minutes: draft.durationMinutes));
        final dao = EventDao();
        hasConflict = await dao.hasConflict(start, end);
        if (hasConflict) {
          final dayEvents = await dao.getForDay(draft.date!);
          conflicts =
              dayEvents.where((event) => event.startTime.isBefore(end) && event.endTime.isAfter(start)).toList();
          await HapticEngine.conflictDetected();
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _draft = draft;
        _hasConflict = hasConflict;
        _conflictingEvents = conflicts;
        _state = VoiceState.preview;
      });
    } finally {
      _handlingFinal = false;
    }
  }

  Future<void> _confirmBooking() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }

    final now = DateTime.now();
    final date = draft.date ?? DateTime(now.year, now.month, now.day);
    final time = draft.time ?? TimeOfDay(hour: now.hour, minute: now.minute);
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final end = start.add(Duration(minutes: draft.durationMinutes));

    await ref.read(eventsNotifierProvider.notifier).createEvent(
          title: draft.title,
          startTime: start,
          endTime: end,
          eventType: draft.eventType,
          location: draft.location,
          recurrenceRule: draft.recurrenceRule,
          isRecurring: draft.recurrenceRule != null,
        );

    await SoundService.instance.play(SoundKeys.bookingConfirmed);
    await HapticEngine.bookingConfirmed();

    if (!mounted) {
      return;
    }
    setState(() {
      _confirmationSummary = '${DateFormat('EEE d MMM').format(start)} · ${DateFormat('HH:mm').format(start)}';
      _state = VoiceState.confirmed;
    });

    Future<void>.delayed(2500.ms, () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _openEditSheet() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }

    final now = DateTime.now();
    final date = draft.date ?? DateTime(now.year, now.month, now.day);
    final time = draft.time ?? TimeOfDay(hour: now.hour, minute: now.minute);
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final end = start.add(Duration(minutes: draft.durationMinutes));
    final event = Event(
      id: 'voice-preview',
      title: draft.title,
      eventType: draft.eventType,
      status: 'not_started',
      location: draft.location,
      notes: null,
      startTime: start,
      endTime: end,
      isRecurring: draft.recurrenceRule != null,
      recurrenceRule: draft.recurrenceRule,
      reminderMinutes: '[]',
      soundKey: SoundKeys.reminderChime,
      colorOverride: null,
      createdAt: now,
      updatedAt: now,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddSheet(initialEvent: event),
    );
  }

  void _resetToIdle() {
    VoiceService.instance.cancelListening();
    setState(() {
      _state = VoiceState.idle;
      _transcript = '';
      _amplitude = 0;
      _draft = null;
      _hasConflict = false;
      _conflictingEvents = const [];
      _handlingFinal = false;
    });
  }

  Color _confidenceColor(ParseConfidence confidence) {
    switch (confidence) {
      case ParseConfidence.high:
        return KwanColors.textPrimary;
      case ParseConfidence.medium:
        return KwanColors.inProgress;
      case ParseConfidence.low:
        return KwanColors.textMuted;
    }
  }

  String _confidenceLabel(ParseConfidence confidence) {
    switch (confidence) {
      case ParseConfidence.high:
        return 'High';
      case ParseConfidence.medium:
        return 'Medium';
      case ParseConfidence.low:
        return 'Low';
    }
  }
}
