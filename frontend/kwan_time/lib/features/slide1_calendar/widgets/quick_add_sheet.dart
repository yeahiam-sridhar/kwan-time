import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/event.dart';
import '../../../core/providers/event_provider.dart';
import '../../../core/theme/kwan_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    this.initialDate,
    this.initialTime,
    this.initialEvent,
  });

  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final Event? initialEvent;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  String _eventType = 'in_person';
  String _status = 'not_started';
  String _repeat = 'None';
  List<int> _reminders = <int>[];
  bool _isSaving = false;
  bool _titleError = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _locationController = TextEditingController();
    _notesController = TextEditingController();

    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    _selectedDate =
        widget.initialDate ?? DateTime(now.year, now.month, now.day);
    _startTime =
        widget.initialTime ?? TimeOfDay(hour: nextHour.hour, minute: 0);
    _endTime = _addDuration(_startTime, const Duration(hours: 1));

    final initial = widget.initialEvent;
    if (initial != null) {
      _titleController.text = initial.title;
      _selectedDate = DateTime(
        initial.startTime.year,
        initial.startTime.month,
        initial.startTime.day,
      );
      _startTime = TimeOfDay(
        hour: initial.startTime.hour,
        minute: initial.startTime.minute,
      );
      _endTime = TimeOfDay(
        hour: initial.endTime.hour,
        minute: initial.endTime.minute,
      );
      _eventType = initial.eventType;
      _status = initial.status;
      _repeat = initial.recurrenceRule == null
          ? 'None'
          : '${initial.recurrenceRule![0].toUpperCase()}${initial.recurrenceRule!.substring(1)}';
      _locationController.text = initial.location ?? '';
      _notesController.text = initial.notes ?? '';
      _reminders = [...initial.reminderList];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.62,
      maxChildSize: 0.96,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF10172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: KwanColors.textDisabled,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildTitleField(),
                  const SizedBox(height: 16),
                  _buildDateTimeRow(context),
                  const SizedBox(height: 14),
                  _buildDurationChips(),
                  const SizedBox(height: 14),
                  _buildTypeToggle(),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    alignment: Alignment.topCenter,
                    child: _eventType == 'in_person'
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: TextField(
                              controller: _locationController,
                              style: KwanText.bodyLarge,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.location_on_outlined),
                                hintText: 'Location',
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                  _buildRepeatDropdown(),
                  const SizedBox(height: 14),
                  _buildReminderChips(),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesController,
                    style: KwanText.bodyMedium,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Notes (optional)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveEvent,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.initialEvent == null
                                  ? 'Save Event'
                                  : 'Update Event',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Row(
        children: [
          Text(
            widget.initialEvent == null ? 'New Event' : 'Edit Event',
            style: KwanText.titleLarge,
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      );

  Widget _buildTitleField() => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _titleError ? KwanColors.error : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: TextField(
          controller: _titleController,
          autofocus: true,
          style: KwanText.titleLarge,
          onChanged: (_) {
            if (_titleError) {
              setState(() => _titleError = false);
            }
          },
          decoration: const InputDecoration(
            hintText: "What's happening?",
            border: InputBorder.none,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: KwanColors.bgCardBorder),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: KwanColors.accent),
            ),
          ),
        ),
      );

  Widget _buildDateTimeRow(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          GlassPill(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14),
                const SizedBox(width: 6),
                Text(DateFormat('d MMM yyyy').format(_selectedDate)),
              ],
            ),
          ),
          GlassPill(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _startTime,
              );
              if (picked != null) {
                setState(() => _startTime = picked);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_rounded, size: 14),
                const SizedBox(width: 6),
                Text(_startTime.format(context)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(Icons.arrow_right_alt_rounded),
          ),
          GlassPill(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _endTime,
              );
              if (picked != null) {
                setState(() => _endTime = picked);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_rounded, size: 14),
                const SizedBox(width: 6),
                Text(_endTime.format(context)),
              ],
            ),
          ),
        ],
      );

  Widget _buildDurationChips() {
    final options = <String, Duration>{
      '15m': const Duration(minutes: 15),
      '30m': const Duration(minutes: 30),
      '1hr': const Duration(hours: 1),
      '2hr': const Duration(hours: 2),
    };
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.key),
            selected: false,
            onSelected: (_) => setState(
                () => _endTime = _addDuration(_startTime, entry.value)),
          ),
        ChoiceChip(
          label: const Text('Custom'),
          selected: false,
          onSelected: (_) {},
        ),
      ],
    );
  }

  Widget _buildTypeToggle() => Row(
        children: [
          Expanded(
            child: _typeButton(
              type: 'online',
              emoji: '🔵',
              label: 'Online',
              activeColor: KwanColors.online,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _typeButton(
              type: 'in_person',
              emoji: '🟠',
              label: 'In-Person',
              activeColor: KwanColors.inPerson,
            ),
          ),
        ],
      );

  Widget _typeButton({
    required String type,
    required String emoji,
    required String label,
    required Color activeColor,
  }) {
    final selected = _eventType == type;
    return GestureDetector(
      onTap: () => setState(() => _eventType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected ? activeColor.withValues(alpha: 0.2) : KwanColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? activeColor : KwanColors.bgCardBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji),
            const SizedBox(width: 6),
            Text(label, style: KwanText.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatDropdown() {
    const options = ['None', 'Daily', 'Weekly', 'Monthly'];
    return DropdownButtonFormField<String>(
      initialValue: _repeat,
      decoration: const InputDecoration(
        labelText: 'Repeat',
      ),
      items: options
          .map((e) => DropdownMenuItem<String>(
                value: e,
                child: Text(e),
              ))
          .toList(),
      onChanged: (v) {
        if (v == null) {
          return;
        }
        setState(() => _repeat = v);
      },
    );
  }

  Widget _buildReminderChips() {
    final reminderValues = <int>[5, 15, 30, 60, 120];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: reminderValues.map((value) {
        final selected = _reminders.contains(value);
        final label = value >= 60 ? '${value ~/ 60}hr' : '${value}m';
        return FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (isSelected) {
            setState(() {
              if (isSelected) {
                _reminders.add(value);
              } else {
                _reminders.remove(value);
              }
              _reminders.sort();
            });
          },
        );
      }).toList(),
    );
  }

  TimeOfDay _addDuration(TimeOfDay base, Duration delta) {
    final totalMinutes = base.hour * 60 + base.minute + delta.inMinutes;
    return TimeOfDay(
      hour: (totalMinutes ~/ 60) % 24,
      minute: totalMinutes % 60,
    );
  }

  Future<void> _saveEvent() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      await HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _isSaving = true);

    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final end = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    try {
      final normalizedEnd =
          end.isAfter(start) ? end : start.add(const Duration(minutes: 30));
      final notifier = ref.read(eventsNotifierProvider.notifier);
      final editingEvent = widget.initialEvent;

      if (editingEvent == null) {
        await notifier.createEvent(
          title: title,
          startTime: start,
          endTime: normalizedEnd,
          eventType: _eventType,
          status: _status,
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          reminderMinutes: _reminders,
          isRecurring: _repeat != 'None',
          recurrenceRule: _repeat == 'None' ? null : _repeat.toLowerCase(),
        );
      } else {
        await notifier.updateEvent(
          editingEvent.copyWith(
            title: title,
            startTime: start,
            endTime: normalizedEnd,
            eventType: _eventType,
            status: _status,
            location: _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            reminderMinutes: jsonEncode(_reminders),
            isRecurring: _repeat != 'None',
            recurrenceRule: _repeat == 'None' ? null : _repeat.toLowerCase(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      await HapticFeedback.lightImpact();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('QuickAdd save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
