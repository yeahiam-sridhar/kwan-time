import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/db_helper.dart';
import 'system_event_service.dart';

class AppInitializer {
  static const String _festivalSeedKey = 'system_events_seeded_v1';
  static const String _demoCleanupKey = 'legacy_demo_cleanup_v1';

  static Future<void> initialize() async {
    final db = await DbHelper.instance.database;
    await _removeLegacyDemoData(db);
    await _initializeSystemEvents(db);
  }

  static Future<void> _removeLegacyDemoData(Database db) async {
    final alreadyCleaned = await _readSetting(db, _demoCleanupKey) == 'true';
    if (alreadyCleaned) {
      return;
    }

    try {
      final removed = await db.delete(
        'events',
        where: "id LIKE ? OR LOWER(COALESCE(notes, '')) LIKE ?",
        whereArgs: <Object?>['seed-%', '%auto-seeded sample event for dashboard analytics%'],
      );

      if (removed > 0) {
        await db.delete('monthly_cache');
        debugPrint('AppInitializer: Removed $removed legacy seed event(s).');
      }
    } catch (e) {
      debugPrint('AppInitializer: Legacy demo cleanup skipped: $e');
    } finally {
      await _writeSetting(db, _demoCleanupKey, 'true');
    }
  }

  static Future<void> _initializeSystemEvents(Database db) async {
    final year = DateTime.now().year;
    await SystemEventService().initialize(year);

    final seeded = await _readSetting(db, _festivalSeedKey) == 'true';
    if (!seeded) {
      await _writeSetting(db, _festivalSeedKey, 'true');
    }
  }

  static Future<String?> _readSetting(Database db, String key) async {
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value']?.toString();
  }

  static Future<void> _writeSetting(Database db, String key, String value) async {
    await db.insert(
      'app_settings',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
