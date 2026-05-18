import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDbTables {
  static const localMeta = 'local_meta';
  static const localConcepts = 'local_concepts';
  static const localConceptEdges = 'local_concept_edges';
  static const localMasteryStates = 'local_mastery_states';
  static const localLearningSessions = 'local_learning_sessions';
  static const localInputEvents = 'local_input_events';
  static const localSyncOutbox = 'local_sync_outbox';
}

class LocalWicaraDatabase {
  LocalWicaraDatabase({
    DatabaseFactory? databaseFactoryOverride,
    Future<String> Function()? databasePathProvider,
    this.databaseName = _defaultDatabaseName,
    this.enforcePlatformSupport = true,
  }) : _databaseFactory = databaseFactoryOverride ?? databaseFactory,
       _databasePathProvider = databasePathProvider;

  static const _defaultDatabaseName = 'wicara_offline.db';

  final DatabaseFactory _databaseFactory;
  final Future<String> Function()? _databasePathProvider;
  final String databaseName;
  final bool enforcePlatformSupport;

  Database? _database;

  bool get isPlatformSupported {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    if (enforcePlatformSupport && !isPlatformSupported) {
      throw UnsupportedError(
        'Offline local database is not supported on this platform.',
      );
    }

    final resolvedPath = await _resolveDatabasePath();
    _database = await _databaseFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS ${LocalDbTables.localMeta} (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
          }
        },
      ),
    );
    return _database!;
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) {
      await db.close();
    }
  }

  Future<void> deleteDatabaseFile() async {
    await close();
    final resolvedPath = await _resolveDatabasePath();
    await _databaseFactory.deleteDatabase(resolvedPath);
  }

  Future<String> _resolveDatabasePath() async {
    final basePath =
        await (_databasePathProvider?.call() ?? getDatabasesPath());
    return p.join(basePath, databaseName);
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS ${LocalDbTables.localMeta} (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS ${LocalDbTables.localConcepts} (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL,
  title TEXT NOT NULL,
  subject_code TEXT NOT NULL,
  description TEXT,
  grade_band TEXT,
  metadata_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS ${LocalDbTables.localConceptEdges} (
  id TEXT PRIMARY KEY,
  from_concept_id TEXT NOT NULL,
  to_concept_id TEXT NOT NULL,
  edge_type TEXT NOT NULL,
  weight REAL NOT NULL,
  metadata_json TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS ${LocalDbTables.localMasteryStates} (
  concept_id TEXT PRIMARY KEY,
  status TEXT NOT NULL,
  mastery_score REAL NOT NULL,
  confidence_score REAL NOT NULL,
  evidence_count INTEGER NOT NULL,
  last_evaluated_at TEXT,
  next_review_at TEXT,
  dirty INTEGER NOT NULL DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS ${LocalDbTables.localLearningSessions} (
  id TEXT PRIMARY KEY,
  target_concept_id TEXT,
  session_type TEXT NOT NULL,
  status TEXT NOT NULL,
  current_stage TEXT,
  metadata_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  dirty INTEGER NOT NULL DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS ${LocalDbTables.localInputEvents} (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  concept_id TEXT,
  event_type TEXT NOT NULL,
  actor_type TEXT NOT NULL,
  text_payload TEXT NOT NULL,
  selected_option_id TEXT,
  canvas_snapshot_json TEXT,
  ai_audit_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  dirty INTEGER NOT NULL DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS ${LocalDbTables.localSyncOutbox} (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  status TEXT NOT NULL,
  attempts INTEGER NOT NULL,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_local_concepts_subject
ON ${LocalDbTables.localConcepts}(subject_code)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_local_edges_from_to
ON ${LocalDbTables.localConceptEdges}(from_concept_id, to_concept_id)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_local_events_session
ON ${LocalDbTables.localInputEvents}(session_id, created_at)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_local_outbox_status
ON ${LocalDbTables.localSyncOutbox}(status, updated_at)
''');
  }
}
