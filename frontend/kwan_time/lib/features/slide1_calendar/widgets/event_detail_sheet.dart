import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/event.dart';
import '../../../core/providers/event_provider.dart';
import '../../../core/theme/kwan_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import 'quick_add_sheet.dart';

class EventDetailSheet extends ConsumerStatefulWidget {
  const EventDetailSheet({
    required this.event,
    super.key,
  });

  final Event event;

  @override
  ConsumerState<EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends ConsumerState<EventDetailSheet> {
  late Event _event;
  String _selectedStatus = 'not_started';

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _selectedStatus = widget.event.status;
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF10172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: KwanColors.textDisabled,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleRow(),
                      const SizedBox(height: 12),
                      _buildTimeRow(),
                      const SizedBox(height: 12),
                      _buildStatusSelector(),
                      const SizedBox(height: 12),
                      _buildTypeAndLocation(),
                      if ((_event.notes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildNotes(),
                      ],
                      if (_event.reminderList.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildReminders(),
                      ],
                      const SizedBox(height: 20),
                      _buildActions(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildTitleRow() => Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: _event.typeColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _event.title,
              style: KwanText.titleLarge,
            ),
          ),
          IconButton(
            onPressed: () => _openEdit(context),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      );

  Widget _buildTimeRow() {
    final label =
        '${DateFormat('EEE d MMM').format(_event.startTime)} · ${_event.timeRangeLabel}';
    return Row(
      children: [
        const Icon(Icons.access_time_rounded,
            size: 18, color: KwanColors.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: KwanText.bodyMedium),
      ],
    );
  }

  Widget _buildStatusSelector() {
    const statuses = ['not_started', 'in_progress', 'completed', 'cancelled'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((status) {
        final selected = _selectedStatus == status;
        return AnimatedScale(
          duration: const Duration(milliseconds: 220),
          scale: selected ? 1.08 : 1,
          child: ChoiceChip(
            label: Text(status.replaceAll('_', ' ')),
            selected: selected,
            selectedColor: KwanColors.forStatus(status).withValues(alpha: 0.22),
            side: BorderSide(
              color: selected
                  ? KwanColors.forStatus(status)
                  : KwanColors.bgCardBorder,
            ),
            onSelected: (_) => _updateStatus(status),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypeAndLocation() => Row(
        children: [
          StatusBadge(
            label: _event.eventType.replaceAll('_', ' '),
            color: _event.typeColor,
          ),
          if (_event.isInPerson &&
              (_event.location?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: _openMaps,
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: KwanColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _event.location!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KwanText.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );

  Widget _buildNotes() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notes_rounded,
              size: 18, color: KwanColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _event.notes!,
              style: KwanText.bodyMedium,
            ),
          ),
        ],
      );

  Widget _buildReminders() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_none_rounded,
              size: 18, color: KwanColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _event.reminderList
                  .map((m) => GlassPill(
                        child: Text(m >= 60 ? '${m ~/ 60}hr' : '${m}m'),
                      ))
                  .toList(),
            ),
          ),
        ],
      );

  Widget _buildActions(BuildContext context) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openEdit(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _duplicate,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Duplicate'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _delete,
              style: ElevatedButton.styleFrom(
                backgroundColor: KwanColors.cancelled,
                foregroundColor: KwanColors.textPrimary,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
            ),
          ),
        ],
      );

  Future<void> _updateStatus(String status) async {
    setState(() => _selectedStatus = status);
    await ref
        .read(eventsNotifierProvider.notifier)
        .updateStatus(_event.id, status);
    setState(() => _event = _event.copyWith(status: status));
  }

  Future<void> _openMaps() async {
    final q = Uri.encodeComponent(_event.location ?? '');
    final uri = Uri.parse('https://maps.google.com/?q=$q');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openEdit(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddSheet(initialEvent: _event),
    );
  }

  Future<void> _duplicate() async {
    final start = _event.startTime.add(const Duration(days: 1));
    final end = _event.endTime.add(const Duration(days: 1));
    await ref.read(eventsNotifierProvider.notifier).createEvent(
          title: _event.title,
          startTime: start,
          endTime: end,
          eventType: _event.eventType,
          status: _event.status,
          location: _event.location,
          notes: _event.notes,
          reminderMinutes: _event.reminderList,
          isRecurring: _event.isRecurring,
          recurrenceRule: _event.recurrenceRule,
        );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Duplicated to tomorrow')),
    );
  }

  Future<void> _delete() async {
    final notifier = ref.read(eventsNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final eventId = _event.id;

    Navigator.of(context).pop();

    try {
      await notifier.deleteEvent(eventId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Event deleted')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: KwanColors.cancelled,
        ),
      );
    }
  }
}
