import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/audio/audio_controller.dart';
import '../../core/audio/audio_gatekeeper.dart';
import '../../core/constants/sound_keys.dart';
import '../../core/database/db_helper.dart';
import '../../core/navigation/logout_button.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/kwan_theme.dart';
import '../../shared/widgets/glass_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _memberNameController = TextEditingController();
  String _soundProfile = 'calm';
  double _volume = 1.0;
  double _ambientVolume = 0.3;
  bool _dailySummaryEnabled = true;
  TimeOfDay _dailySummaryTime = const TimeOfDay(hour: 8, minute: 0);
  Set<int> _defaultReminders = {15, 30};
  bool _weekStartsMonday = true;
  String? _customMusicPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _memberNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: _buildProfileSection(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: _buildSoundSection(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: _buildMusicLibrarySection(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: _buildNotificationSection(context),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: _buildCalendarSection(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: _buildDataSection(context),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
        ),
      );

  Widget _buildMusicLibrarySection() => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Custom Music', style: KwanText.titleMedium),
            const SizedBox(height: 8),
            Text(
              _customMusicPath == null
                  ? 'No custom track selected. Default ambient will play.'
                  : _customMusicPath!.split(RegExp(r'[\\/]')).last,
              style: KwanText.bodySmall.copyWith(color: KwanColors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Pick Custom Music'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KwanColors.accent.withValues(alpha: 0.2),
                  foregroundColor: KwanColors.accent,
                  elevation: 0,
                  side: const BorderSide(color: KwanColors.accent),
                ),
                onPressed: _pickMusic,
              ),
            ),
          ],
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
            const SizedBox(width: 4),
            const Text('Settings', style: KwanText.titleLarge),
          ],
        ),
      );

  Widget _buildProfileSection() => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profile', style: KwanText.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _memberNameController,
              decoration: const InputDecoration(labelText: 'Member Name'),
              onSubmitted: (value) => _saveSetting('member_name', value.trim()),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _saveSetting(
                  'member_name',
                  _memberNameController.text.trim(),
                ),
                child: const Text('Save Name'),
              ),
            ),
            const SizedBox(height: 12),
            const LogoutButton(
              style: LogoutButtonStyle.outlinedButton,
            ),
          ],
        ),
      );

  Widget _buildSoundSection() => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sound Settings', style: KwanText.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _profileChip('professional'),
                _profileChip('calm'),
                _profileChip('silent'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Sound Volume', style: KwanText.bodySmall),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    activeColor: KwanColors.accent,
                    onChanged: (value) {
                      setState(() => _volume = value);
                      SoundService.instance.setVolume(value);
                    },
                    onChangeEnd: (value) {
                      SoundService.instance.play(SoundKeys.eventCreate);
                    },
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${(_volume * 100).round()}%',
                    style: KwanText.bodySmall,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildNotificationSection(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notification Settings', style: KwanText.titleMedium),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily Summary', style: KwanText.bodyMedium),
              value: _dailySummaryEnabled,
              onChanged: (value) async {
                setState(() => _dailySummaryEnabled = value);
                await _saveSetting(
                  'daily_summary_enabled',
                  value ? 'true' : 'false',
                );
              },
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Time', style: KwanText.bodySmall),
                const SizedBox(width: 10),
                GlassPill(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _dailySummaryTime,
                    );
                    if (picked == null) {
                      return;
                    }
                    setState(() => _dailySummaryTime = picked);
                    await _saveSetting(
                      'daily_summary_time',
                      '${picked.hour.toString().padLeft(2, '0')}:'
                          '${picked.minute.toString().padLeft(2, '0')}',
                    );
                  },
                  child: Text(_dailySummaryTime.format(context)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Default Reminders', style: KwanText.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [5, 15, 30, 60].map((minutes) {
                final selected = _defaultReminders.contains(minutes);
                final label =
                    minutes >= 60 ? '${minutes ~/ 60}hr' : '${minutes}m';
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (value) async {
                    setState(() {
                      if (value) {
                        _defaultReminders.add(minutes);
                      } else {
                        _defaultReminders.remove(minutes);
                      }
                    });
                    final list = _defaultReminders.toList()..sort();
                    await _saveSetting('default_reminders', jsonEncode(list));
                  },
                );
              }).toList(),
            ),
          ],
        ),
      );

  Widget _buildCalendarSection() => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calendar Settings', style: KwanText.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Week starts', style: KwanText.bodySmall),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Monday'),
                  selected: _weekStartsMonday,
                  onSelected: (_) async {
                    setState(() => _weekStartsMonday = true);
                    await _saveSetting('week_starts_monday', 'true');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Sunday'),
                  selected: !_weekStartsMonday,
                  onSelected: (_) async {
                    setState(() => _weekStartsMonday = false);
                    await _saveSetting('week_starts_monday', 'false');
                  },
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildDataSection(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Data', style: KwanText.titleMedium),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _exportEventsCsv,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Export Events (CSV)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _clearAllData(context),
              icon: const Icon(Icons.delete_forever_rounded,
                  color: KwanColors.error),
              label: const Text(
                'Clear All Data',
                style: TextStyle(color: KwanColors.error),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'KWAN-TIME v1.0.0',
              style: KwanText.bodySmall.copyWith(color: KwanColors.textMuted),
            ),
          ],
        ),
      );

  Widget _profileChip(String profile) {
    final selected = _soundProfile == profile;
    return ChoiceChip(
      selected: selected,
      label: Text(
        profile[0].toUpperCase() + profile.substring(1),
      ),
      onSelected: (_) async {
        setState(() => _soundProfile = profile);
        await _saveSetting('sound_profile', profile);
        await _applyAmbient();
      },
    );
  }

  Future<void> _loadSettings() async {
    final db = await DbHelper.instance.database;
    final rows = await db.query('app_settings');
    final map = <String, String>{
      for (final row in rows)
        (row['key']! as String): (row['value']?.toString() ?? ''),
    };

    _memberNameController.text = map['member_name']?.trim().isNotEmpty == true
        ? map['member_name']!
        : 'Karthiganesh Durai';
    _soundProfile = map['sound_profile']?.isNotEmpty == true
        ? map['sound_profile']!
        : 'calm';
    _volume = double.tryParse(map['sound_volume'] ?? '') ?? 1.0;
    _ambientVolume = double.tryParse(map['ambient_volume'] ?? '') ?? 0.3;
    _dailySummaryEnabled = (map['daily_summary_enabled'] ?? 'true') == 'true';
    _customMusicPath = map['custom_music_path']?.trim().isNotEmpty == true
        ? map['custom_music_path']
        : null;

    final summaryTime = map['daily_summary_time'] ?? '08:00';
    final parts = summaryTime.split(':');
    if (parts.length == 2) {
      _dailySummaryTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }

    final reminderJson = map['default_reminders'] ?? '[15,30]';
    final decoded = jsonDecode(reminderJson);
    if (decoded is List) {
      _defaultReminders = decoded
          .map((value) => int.tryParse('$value') ?? 0)
          .where((value) => value > 0)
          .toSet();
    }
    _weekStartsMonday = (map['week_starts_monday'] ?? 'true') == 'true';

    if (mounted) {
      setState(() => _loading = false);
    }
    await _applyAmbient();
  }

  Future<void> _pickMusic() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result == null) {
        return;
      }
      final pickedPath = result.files.first.path;
      if (pickedPath == null || pickedPath.trim().isEmpty) {
        return;
      }

      await SoundService.instance.setCustomMusicPath(pickedPath);
      await AudioController.instance.setCustomMusicPath(pickedPath);
      await _saveSetting('custom_music_path', pickedPath);

      if (mounted) {
        setState(() => _customMusicPath = pickedPath);
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom music updated')),
      );
    } catch (e) {
      debugPrint('Music pick error: $e');
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    final db = await DbHelper.instance.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _applyAmbient() async {
    await AudioController.instance.setAmbientVolume(_ambientVolume);
    await AudioGatekeeper.instance.process(
      GatekeeperEvent.settingsChanged,
      ambientEnabled: true,
      profile: _soundProfile,
    );
  }

  Future<void> _exportEventsCsv() async {
    final db = await DbHelper.instance.database;
    final rows = await db.query('events', orderBy: 'start_time ASC');
    final buffer = StringBuffer();
    buffer.writeln(
      'id,title,event_type,status,location,notes,start_time,end_time,is_recurring',
    );
    for (final row in rows) {
      buffer.writeln([
        _csv(row['id']),
        _csv(row['title']),
        _csv(row['event_type']),
        _csv(row['status']),
        _csv(row['location']),
        _csv(row['notes']),
        _csv(row['start_time']),
        _csv(row['end_time']),
        _csv(row['is_recurring']),
      ].join(','));
    }
    await Share.share(buffer.toString(), subject: 'KWAN-TIME Events CSV');
  }

  String _csv(Object? value) {
    final text = (value ?? '').toString().replaceAll('"', '""');
    return '"$text"';
  }

  Future<void> _clearAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text('This deletes all events and cached summaries.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final db = await DbHelper.instance.database;
    await db.delete('events');
    await db.delete('monthly_cache');
    await db.delete('app_settings');
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All local data cleared')),
    );
    await _loadSettings();
  }
}
