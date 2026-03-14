import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {
  DbHelper._();

  static final DbHelper instance = DbHelper._();

  static const String _databaseName = 'kwan_time.db';
  static const int _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<void> close() async {
    final db = _database;
    if (db == null) {
      return;
    }

    await db.close();
    _database = null;
  }

  Future<Database> _openDatabase() async {
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, _databaseName);

    return openDatabase(
      dbPath,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createSchemaV1(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var nextVersion = oldVersion + 1; nextVersion <= newVersion; nextVersion++) {
      switch (nextVersion) {
        case 1:
          await _createSchemaV1(db);
          break;
      }
    }
  }

  Future<void> _createSchemaV1(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        event_type TEXT,
        status TEXT,
        location TEXT,
        notes TEXT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        is_recurring INTEGER DEFAULT 0,
        recurrence_rule TEXT,
        reminder_minutes TEXT,
        sound_key TEXT,
        color_override TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_cache (
        id TEXT PRIMARY KEY,
        month TEXT NOT NULL,
        total_online INTEGER DEFAULT 0,
        total_in_person INTEGER DEFAULT 0,
        total_booked INTEGER DEFAULT 0,
        total_cancelled INTEGER DEFAULT 0,
        total_completed INTEGER DEFAULT 0,
        total_not_started INTEGER DEFAULT 0,
        total_in_progress INTEGER DEFAULT 0,
        available_days INTEGER DEFAULT 0,
        available_saturdays INTEGER DEFAULT 0,
        available_sundays INTEGER DEFAULT 0,
        available_dates TEXT,
        free_time_minutes INTEGER DEFAULT 0,
        UNIQUE(month)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS audio_state (
        key TEXT PRIMARY KEY,
        state TEXT,
        trigger_time TEXT,
        event_id TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notification_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        notification_id INTEGER UNIQUE,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        fire_at TEXT NOT NULL,
        event_id TEXT,
        created_at TEXT NOT NULL,
        status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_start ON events(start_time);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);',
    );
  }
}
