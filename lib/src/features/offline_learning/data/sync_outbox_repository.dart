import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'local_wicara_database.dart';

class LocalSyncOutboxRecord {
  const LocalSyncOutboxRecord({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.status,
    required this.attempts,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final String status;
  final int attempts;
  final String? lastError;
  final String createdAt;
  final String updatedAt;
}

class SyncOutboxRepository {
  const SyncOutboxRepository({required LocalWicaraDatabase database})
    : _database = database;

  final LocalWicaraDatabase _database;

  Future<LocalSyncOutboxRecord> enqueue({
    String? id,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final outboxId = id ?? _newId();
    final record = LocalSyncOutboxRecord(
      id: outboxId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      status: 'pending',
      attempts: 0,
      lastError: null,
      createdAt: now,
      updatedAt: now,
    );
    final db = await _database.database;
    await db.insert(
      LocalDbTables.localSyncOutbox,
      _toRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record;
  }

  Future<List<LocalSyncOutboxRecord>> listPending({int limit = 100}) async {
    final db = await _database.database;
    final rows = await db.query(
      LocalDbTables.localSyncOutbox,
      where: 'status IN (?, ?)',
      whereArgs: <Object?>['pending', 'failed'],
      orderBy: 'updated_at ASC',
      limit: limit,
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> markInFlight(String id) async {
    await _setStatus(id: id, status: 'in_flight');
  }

  Future<void> markSynced(String id) async {
    await _setStatus(id: id, status: 'synced', lastError: null);
  }

  Future<void> markFailed(String id, {String? lastError}) async {
    final db = await _database.database;
    await db.rawUpdate(
      '''
UPDATE ${LocalDbTables.localSyncOutbox}
SET status = ?, attempts = attempts + 1, last_error = ?, updated_at = ?
WHERE id = ?
''',
      <Object?>[
        'failed',
        lastError,
        DateTime.now().toUtc().toIso8601String(),
        id,
      ],
    );
  }

  Future<void> _setStatus({
    required String id,
    required String status,
    String? lastError,
  }) async {
    final db = await _database.database;
    await db.update(
      LocalDbTables.localSyncOutbox,
      <String, Object?>{
        'status': status,
        'last_error': lastError,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Map<String, Object?> _toRow(LocalSyncOutboxRecord value) {
    return <String, Object?>{
      'id': value.id,
      'entity_type': value.entityType,
      'entity_id': value.entityId,
      'operation': value.operation,
      'payload_json': jsonEncode(value.payload),
      'status': value.status,
      'attempts': value.attempts,
      'last_error': value.lastError,
      'created_at': value.createdAt,
      'updated_at': value.updatedAt,
    };
  }

  LocalSyncOutboxRecord _fromRow(Map<String, Object?> row) {
    return LocalSyncOutboxRecord(
      id: _string(row['id']),
      entityType: _string(row['entity_type']),
      entityId: _string(row['entity_id']),
      operation: _string(row['operation']),
      payload: _decodeObject(row['payload_json']),
      status: _string(row['status']),
      attempts: _int(row['attempts']),
      lastError: _nullableString(row['last_error']),
      createdAt: _string(row['created_at']),
      updatedAt: _string(row['updated_at']),
    );
  }

  static String _newId() {
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'outbox-$micros';
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

  static String _string(Object? value) => (value ?? '').toString().trim();

  static String? _nullableString(Object? value) {
    final text = _string(value);
    return text.isEmpty ? null : text;
  }

  static int _int(Object? value) => int.tryParse((value ?? '').toString()) ?? 0;
}
