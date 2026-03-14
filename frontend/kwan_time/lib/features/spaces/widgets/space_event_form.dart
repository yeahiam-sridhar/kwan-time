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
  int? _reminder;
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
              DropdownButtonFormField<int?>(
                value: _reminder,
                dropdownColor: const Color(0xFF162347),
                decoration: _inputDecoration('Reminder'),
                items: const [
                  DropdownMenuItem<int?>(value: null, child: Text('None')),
                  DropdownMenuItem<int?>(value: 5, child: Text('5 min')),
                  DropdownMenuItem<int?>(value: 10, child: Text('10 min')),
                  DropdownMenuItem<int?>(value: 30, child: Text('30 min')),
                  DropdownMenuItem<int?>(value: 60, child: Text('1 hour')),
                ],
                onChanged: (value) => setState(() => _reminder = value),
                style: const TextStyle(color: Colors.white),
                iconEnabledColor: Colors.white70,
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
        reminderMinutes: _reminder == null ? [] : [_reminder!],
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
