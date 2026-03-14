import 'package:sqflite/sqflite.dart';

import '../database/db_helper.dart';
import 'reminder_state_machine.dart';

class ReminderStateRecord {
  const ReminderStateRecord({
    required this.state,
    this.triggerTime,
    this.eventId,
  });

  final ReminderState state;
  final DateTime? triggerTime;
  final String? eventId;
}

class AmbientPrefs {
  const AmbientPrefs({
    required this.enabled,
    required this.profile,
  });

  final bool enabled;
  final String profile;
}

class AudioPersistence {
  AudioPersistence._();

  static final AudioPersistence instance = AudioPersistence._();

  Future<void> saveReminderState(ReminderStateRecord record) async {
    final db = await DbHelper.instance.database;
    await _ensureAudioStateTable(db);
    await db.insert(
      'audio_state',
      <String, Object?>{
        'key': 'reminder_state',
        'state': record.state.name,
        'trigger_time': record.triggerTime?.toIso8601String(),
        'event_id': record.eventId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ReminderStateRecord?> loadReminderState() async {
    try {
      final db = await DbHelper.instance.database;
      await _ensureAudioStateTable(db);
      final rows = await db.query(
        'audio_state',
        where: 'key = ?',
        whereArgs: <Object?>['reminder_state'],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      final row = rows.first;
      final stateStr = row['state'] as String?;
      final state = ReminderState.values.firstWhere(
        (s) => s.name == stateStr,
        orElse: () => ReminderState.idle,
      );
      final triggerStr = row['trigger_time'] as String?;
      final trigger = triggerStr != null ? DateTime.tryParse(triggerStr) : null;
      return ReminderStateRecord(
        state: state,
        triggerTime: trigger,
        eventId: row['event_id'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearReminderState() async {
    final db = await DbHelper.instance.database;
    await _ensureAudioStateTable(db);
    await db.delete(
      'audio_state',
      where: 'key = ?',
      whereArgs: <Object?>['reminder_state'],
    );
  }

  Future<AmbientPrefs> loadAmbientPrefs() async {
    try {
      final db = await DbHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key IN (?,?)',
        whereArgs: <Object?>['ambient_enabled', 'sound_profile'],
      );
      final map = <String, String>{
        for (final row in rows)
          (row['key'] as String): (row['value']?.toString() ?? ''),
      };
      return AmbientPrefs(
        enabled: map['ambient_enabled'] != 'false',
        profile: map['sound_profile']?.isNotEmpty == true
            ? map['sound_profile']!
            : 'calm',
      );
    } catch (_) {
      return const AmbientPrefs(enabled: true, profile: 'calm');
    }
  }

  Future<void> saveAmbientPrefs(AmbientPrefs prefs) async {
    final db = await DbHelper.instance.database;
    final values = <String, String>{
      'ambient_enabled': prefs.enabled.toString(),
      'sound_profile': prefs.profile,
    };
    for (final entry in values.entries) {
      await db.insert(
        'app_settings',
        <String, Object?>{'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _ensureAudioStateTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audio_state (
        key TEXT PRIMARY KEY,
        state TEXT,
        trigger_time TEXT,
        event_id TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
  }
}
