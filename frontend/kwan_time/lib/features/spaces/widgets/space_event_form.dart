import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/space_activity_model.dart';
import '../models/space_event_model.dart';
import '../models/space_model.dart';
import '../providers/space_activity_provider.dart';
import '../providers/space_providers.dart';

class SpaceEventForm extends ConsumerStatefulWidget {
  const SpaceEventForm({
    super.key,
    required this.space,
    this.existingEvent,
    this.initialDate,
  });

  final SpaceModel space;
  final SpaceEvent? existingEvent;
  final DateTime? initialDate;

  @override
  ConsumerState<SpaceEventForm> createState() => _SpaceEventFormState();
}

class _SpaceEventFormState extends ConsumerState<SpaceEventForm> {
  static const _colors = [
    '#1565C0',
    '#00ACC1',
    '#2E7D32',
    '#F9A825',
    '#E65100',
    '#AD1457',
    '#6A1B9A',
    '#546E7A',
  ];

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locCtrl = TextEditingController();

  late DateTime _startTime;
  late DateTime _endTime;
  String _selectedColor = _colors.first;
  int? _reminder;        // null = at event start time (0 min before)
  bool _useCustom = false;
  int _customDays = 0;
  int _customHours = 0;
  int _customMins = 5;
  bool _isSaving = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEvent;
    if (existing != null) {
      _titleCtrl.text = existing.title;
      _descCtrl.text = existing.description ?? '';
      _locCtrl.text = existing.location ?? '';
      _startTime = existing.startTime;
      _endTime = existing.endTime;
      final color = existing.colorHex ?? _colors.first;
      _selectedColor = color.startsWith('#') ? color : '#$color';
      _reminder =
          existing.reminderMinutes.isNotEmpty ? existing.reminderMinutes.first : null;
    } else {
      final now = DateTime.now();
      final base = widget.initialDate ?? now;
      final start = DateTime(base.year, base.month, base.day, now.hour, 0);
      _startTime = start;
      _endTime = start.add(const Duration(hours: 1));
      _selectedColor = _colors.first;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B3E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingEvent == null ? 'Add Event' : 'Edit Event',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMsg != null) ...[
                Text(
                  _errorMsg!,
                  style: const TextStyle(
                    color: Color(0xFFEF9A9A),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _titleCtrl,
                maxLength: 200,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Description'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Location'),
              ),
              const SizedBox(height: 16),
              _buildDateRow(context),
              const SizedBox(height: 12),
              _buildTimeRow(context),
              const SizedBox(height: 16),
              Text(
                'Color',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _colors.map((hex) {
                  final isSelected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _parseColor(hex),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _ReminderPicker(
                selectedMinutes: _reminder,
                onChanged: (minutes) => setState(() => _reminder = minutes),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Event',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      counterStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1565C0)),
      ),
    );
  }

  Widget _buildDateRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionField(
            label: 'Date',
            value: _formatDate(context, _startTime),
            onTap: _pickDate,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionField(
            label: 'Start',
            value: _formatTime(context, _startTime),
            onTap: _pickStartTime,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionField(
            label: 'End',
            value: _formatTime(context, _endTime),
            onTap: _pickEndTime,
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _startTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _startTime.hour,
        _startTime.minute,
      );
      _endTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _endTime.hour,
        _endTime.minute,
      );
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _startTime = DateTime(
        _startTime.year,
        _startTime.month,
        _startTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _endTime = DateTime(
        _endTime.year,
        _endTime.month,
        _endTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  String _formatDate(BuildContext context, DateTime date) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatMediumDate(date);
  }

  String _formatTime(BuildContext context, DateTime date) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date));
  }

  bool _validate() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMsg = 'Title is required.');
      return false;
    }
    if (!_endTime.isAfter(_startTime)) {
      setState(() => _errorMsg = 'End time must be after start time.');
      return false;
    }
    setState(() => _errorMsg = null);
    return true;
  }

  Future<void> _onSave() async {
    if (!_validate()) {
      return;
    }
    setState(() => _isSaving = true);

    try {
      final svc = ref.read(eventServiceProvider);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userName = ref.read(displayNameProvider);

      final event = SpaceEvent(
        id: widget.existingEvent?.id ?? '',
        spaceId: widget.space.id,
        title: _titleCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        location: _locCtrl.text.trim().isEmpty ? null : _locCtrl.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        createdBy: uid,
        createdByName: userName,
        createdAt: widget.existingEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        // null _reminder means "at event time" = 0 minutes before
        reminderMinutes: _reminder == null ? [0] : [_reminder!],
        colorHex: _selectedColor,
        commentCount: widget.existingEvent?.commentCount ?? 0,
      );

      SpaceEvent saved;
      if (widget.existingEvent == null) {
        saved = await svc.createEvent(widget.space.id, event);
        await ref.read(spaceActivityServiceProvider).log(
              spaceId: widget.space.id,
              type: ActivityType.eventCreated,
              actorId: uid,
              actorName: userName,
              targetId: saved.id,
              targetName: saved.title,
            );
      } else {
        await svc.updateEvent(widget.space.id, event);
        saved = event;
        await ref.read(spaceActivityServiceProvider).log(
              spaceId: widget.space.id,
              type: ActivityType.eventUpdated,
              actorId: uid,
              actorName: userName,
              targetId: saved.id,
              targetName: saved.title,
            );
      }

      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Color _parseColor(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.parse('0xFF$value'));
  }
}

class _ActionField extends StatelessWidget {
  const _ActionField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Preset + custom reminder picker for space events.
class _ReminderPicker extends StatefulWidget {
  final int? selectedMinutes;
  final void Function(int?) onChanged;
  const _ReminderPicker({
    required this.selectedMinutes,
    required this.onChanged,
  });

  @override
  State<_ReminderPicker> createState() => _ReminderPickerState();
}

class _ReminderPickerState extends State<_ReminderPicker> {
  // -1 = custom sentinel
  static const _presets = <int?>[null, 1, 5, 10, 30, 60, 1440, -1];

  static String _label(int? v) => switch (v) {
        null => 'At event time',
        1 => '1 min before',
        5 => '5 min before',
        10 => '10 min before',
        30 => '30 min before',
        60 => '1 hour before',
        1440 => '1 day before',
        _ => 'Custom',
      };

  int? get _dropdownValue {
    final m = widget.selectedMinutes;
    if (m == null) return null;
    if (_presets.contains(m)) return m;
    return -1; // custom
  }

  void _openCustomPicker() {
    int days = 0, hours = 0, mins = 5;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF162347),
          title: const Text(
            'Custom reminder',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _StepRow(
              label: 'Days',
              value: days,
              onInc: () => setDlg(() => days++),
              onDec: () => setDlg(() {
                if (days > 0) days--;
              }),
            ),
            const SizedBox(height: 12),
            _StepRow(
              label: 'Hours',
              value: hours,
              onInc: () => setDlg(() {
                if (hours < 23) hours++;
              }),
              onDec: () => setDlg(() {
                if (hours > 0) hours--;
              }),
            ),
            const SizedBox(height: 12),
            _StepRow(
              label: 'Minutes',
              value: mins,
              onInc: () => setDlg(() {
                if (mins < 59) mins++;
              }),
              onDec: () => setDlg(() {
                if (mins > 0) mins--;
              }),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
              ),
              onPressed: () {
                final total = days * 1440 + hours * 60 + mins;
                // Clamp to 0 (fire at event time)
                widget.onChanged(total <= 0 ? null : total);
                Navigator.pop(ctx);
              },
              child: const Text('Set'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      value: _dropdownValue,
      dropdownColor: const Color(0xFF162347),
      decoration: InputDecoration(
        labelText: 'Reminder',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0)),
        ),
      ),
      items: _presets
          .map(
            (v) => DropdownMenuItem<int?>(
              value: v,
              child: Text(
                _label(v),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v == -1) {
          _openCustomPicker();
        } else {
          widget.onChanged(v);
        }
      },
      style: const TextStyle(color: Colors.white),
      iconEnabledColor: Colors.white70,
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onInc;
  final VoidCallback onDec;
  const _StepRow({
    required this.label,
    required this.value,
    required this.onInc,
    required this.onDec,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 70,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
      IconButton(
        icon: const Icon(
          Icons.remove_circle_outline,
          color: Colors.white70,
          size: 22,
        ),
        onPressed: onDec,
      ),
      SizedBox(
        width: 32,
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      IconButton(
        icon: const Icon(
          Icons.add_circle_outline,
          color: Colors.white70,
          size: 22,
        ),
        onPressed: onInc,
      ),
    ]);
  }
}
