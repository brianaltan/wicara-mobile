import 'dart:convert';

import 'local_wicara_database.dart';

class LocalLearningSessionRecord {
  const LocalLearningSessionRecord({
    required this.id,
    this.targetConceptId,
    required this.sessionType,
    required this.status,
    this.currentStage,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    required this.dirty,
  });

  final String id;
  final String? targetConceptId;
  final String sessionType;
  final String status;
  final String? currentStage;
  final Map<String, dynamic> metadata;
  final String createdAt;
  final String updatedAt;
  final bool dirty;
}

class LocalInputEventRecord {
  const LocalInputEventRecord({
    required this.id,
    required this.sessionId,
    this.conceptId,
    required this.eventType,
    required this.actorType,
    required this.textPayload,
    this.selectedOptionId,
    this.canvasSnapshot,
    required this.aiAudit,
    required this.createdAt,
    required this.dirty,
  });

  final String id;
  final String sessionId;
  final String? conceptId;
  final String eventType;
  final String actorType;
  final String textPayload;
  final String? selectedOptionId;
  final Map<String, dynamic>? canvasSnapshot;
  final Map<String, dynamic> aiAudit;
  final String createdAt;
  final bool dirty;
}

class LocalSessionRepository {
  const LocalSessionRepository({required LocalWicaraDatabase database})
    : _database = database;

  final LocalWicaraDatabase _database;

  Future<LocalLearningSessionRecord> createLearningSession({
    String? id,
    String? targetConceptId,
    String sessionType = 'pilot_chat',
    String status = 'active',
    String? currentStage,
    Map<String, dynamic> metadata = const {},
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final sessionId = id ?? _newId(prefix: 'session');
    final record = LocalLearningSessionRecord(
      id: sessionId,
      targetConceptId: targetConceptId,
      sessionType: sessionType,
      status: status,
      currentStage: currentStage,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
      dirty: true,
    );
    final db = await _database.database;
    await db.insert(LocalDbTables.localLearningSessions, _sessionToRow(record));
    return record;
  }

  Future<LocalLearningSessionRecord?> getSessionById(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      LocalDbTables.localLearningSessions,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _sessionFromRow(rows.first);
  }

  Future<List<LocalLearningSessionRecord>> listSessions() async {
    final db = await _database.database;
    final rows = await db.query(
      LocalDbTables.localLearningSessions,
      orderBy: 'updated_at DESC',
    );
    return rows.map(_sessionFromRow).toList(growable: false);
  }

  Future<void> updateSession({
    required String sessionId,
    String? status,
    String? currentStage,
    Map<String, dynamic>? metadata,
    bool? dirty,
  }) async {
    final db = await _database.database;
    final row = <String, Object?>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (status != null) {
      row['status'] = status;
    }
    if (currentStage != null) {
      row['current_stage'] = currentStage;
    }
    if (metadata != null) {
      row['metadata_json'] = jsonEncode(metadata);
    }
    if (dirty != null) {
      row['dirty'] = dirty ? 1 : 0;
    }
    await db.update(
      LocalDbTables.localLearningSessions,
      row,
      where: 'id = ?',
      whereArgs: <Object?>[sessionId],
    );
  }

  Future<LocalInputEventRecord> appendInputEvent({
    String? id,
    required String sessionId,
    String? conceptId,
    required String eventType,
    String actorType = 'learner',
    String textPayload = '',
    String? selectedOptionId,
    Map<String, dynamic>? canvasSnapshot,
    Map<String, dynamic> aiAudit = const {},
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final eventId = id ?? _newId(prefix: 'event');
    final event = LocalInputEventRecord(
      id: eventId,
      sessionId: sessionId,
      conceptId: conceptId,
      eventType: eventType,
      actorType: actorType,
      textPayload: textPayload,
      selectedOptionId: selectedOptionId,
      canvasSnapshot: canvasSnapshot,
      aiAudit: aiAudit,
      createdAt: now,
      dirty: true,
    );
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert(LocalDbTables.localInputEvents, _eventToRow(event));
      await txn.update(
        LocalDbTables.localLearningSessions,
        {'updated_at': now, 'dirty': 1},
        where: 'id = ?',
        whereArgs: <Object?>[sessionId],
      );
    });
    return event;
  }

  Future<List<LocalInputEventRecord>> listEvents(String sessionId) async {
    final db = await _database.database;
    final rows = await db.query(
      LocalDbTables.localInputEvents,
      where: 'session_id = ?',
      whereArgs: <Object?>[sessionId],
      orderBy: 'created_at ASC',
    );
    return rows.map(_eventFromRow).toList(growable: false);
  }

  Map<String, Object?> _sessionToRow(LocalLearningSessionRecord value) {
    return {
      'id': value.id,
      'target_concept_id': value.targetConceptId,
      'session_type': value.sessionType,
      'status': value.status,
      'current_stage': value.currentStage,
      'metadata_json': jsonEncode(value.metadata),
      'created_at': value.createdAt,
      'updated_at': value.updatedAt,
      'dirty': value.dirty ? 1 : 0,
    };
  }

  LocalLearningSessionRecord _sessionFromRow(Map<String, Object?> row) {
    return LocalLearningSessionRecord(
      id: _string(row['id']),
      targetConceptId: _nullableString(row['target_concept_id']),
      sessionType: _string(row['session_type']),
      status: _string(row['status']),
      currentStage: _nullableString(row['current_stage']),
      metadata: _decodeObject(row['metadata_json']),
      createdAt: _string(row['created_at']),
      updatedAt: _string(row['updated_at']),
      dirty: _int(row['dirty']) == 1,
    );
  }

  Map<String, Object?> _eventToRow(LocalInputEventRecord value) {
    return {
      'id': value.id,
      'session_id': value.sessionId,
      'concept_id': value.conceptId,
      'event_type': value.eventType,
      'actor_type': value.actorType,
      'text_payload': value.textPayload,
      'selected_option_id': value.selectedOptionId,
      'canvas_snapshot_json': value.canvasSnapshot == null
          ? null
          : jsonEncode(value.canvasSnapshot),
      'ai_audit_json': jsonEncode(value.aiAudit),
      'created_at': value.createdAt,
      'dirty': value.dirty ? 1 : 0,
    };
  }

  LocalInputEventRecord _eventFromRow(Map<String, Object?> row) {
    return LocalInputEventRecord(
      id: _string(row['id']),
      sessionId: _string(row['session_id']),
      conceptId: _nullableString(row['concept_id']),
      eventType: _string(row['event_type']),
      actorType: _string(row['actor_type']),
      textPayload: _string(row['text_payload']),
      selectedOptionId: _nullableString(row['selected_option_id']),
      canvasSnapshot: _decodeNullableObject(row['canvas_snapshot_json']),
      aiAudit: _decodeObject(row['ai_audit_json']),
      createdAt: _string(row['created_at']),
      dirty: _int(row['dirty']) == 1,
    );
  }

  static String _newId({required String prefix}) {
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return '$prefix-$micros';
  }

  static Map<String, dynamic> _decodeObject(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }
    return const {};
  }

  static Map<String, dynamic>? _decodeNullableObject(Object? value) {
    if (value == null) {
      return null;
    }
    final decoded = _decodeObject(value);
    return decoded.isEmpty ? null : decoded;
  }

  static String _string(Object? value) => (value ?? '').toString().trim();

  static String? _nullableString(Object? value) {
    final text = _string(value);
    return text.isEmpty ? null : text;
  }

  static int _int(Object? value) => int.tryParse((value ?? '').toString()) ?? 0;
}
