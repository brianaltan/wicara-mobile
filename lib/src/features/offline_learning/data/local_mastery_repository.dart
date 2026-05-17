import 'package:sqflite/sqflite.dart';

import 'local_wicara_database.dart';

class LocalMasteryStateRecord {
  const LocalMasteryStateRecord({
    required this.conceptId,
    required this.status,
    required this.masteryScore,
    required this.confidenceScore,
    required this.evidenceCount,
    this.lastEvaluatedAt,
    this.nextReviewAt,
    required this.dirty,
  });

  final String conceptId;
  final String status;
  final double masteryScore;
  final double confidenceScore;
  final int evidenceCount;
  final String? lastEvaluatedAt;
  final String? nextReviewAt;
  final bool dirty;
}

class LocalMasteryRepository {
  const LocalMasteryRepository({required LocalWicaraDatabase database})
    : _database = database;

  final LocalWicaraDatabase _database;

  Future<void> upsertState(LocalMasteryStateRecord state) async {
    final db = await _database.database;
    await db.insert(
      LocalDbTables.localMasteryStates,
      {
        'concept_id': state.conceptId,
        'status': state.status,
        'mastery_score': state.masteryScore.clamp(0, 1),
        'confidence_score': state.confidenceScore.clamp(0, 1),
        'evidence_count': state.evidenceCount,
        'last_evaluated_at': state.lastEvaluatedAt,
        'next_review_at': state.nextReviewAt,
        'dirty': state.dirty ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<LocalMasteryStateRecord?> getState(String conceptId) async {
    final db = await _database.database;
    final rows = await db.query(
      LocalDbTables.localMasteryStates,
      where: 'concept_id = ?',
      whereArgs: <Object?>[conceptId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _toRecord(rows.first);
  }

  Future<List<LocalMasteryStateRecord>> listStates() async {
    final db = await _database.database;
    final rows = await db.query(
      LocalDbTables.localMasteryStates,
      orderBy: 'concept_id ASC',
    );
    return rows.map(_toRecord).toList(growable: false);
  }

  Future<List<LocalMasteryStateRecord>> listDirtyStates() async {
    final db = await _database.database;
    final rows = await db.query(
      LocalDbTables.localMasteryStates,
      where: 'dirty = 1',
      orderBy: 'last_evaluated_at DESC',
    );
    return rows.map(_toRecord).toList(growable: false);
  }

  Future<void> markSynced(String conceptId) async {
    final db = await _database.database;
    await db.update(
      LocalDbTables.localMasteryStates,
      {'dirty': 0},
      where: 'concept_id = ?',
      whereArgs: <Object?>[conceptId],
    );
  }

  LocalMasteryStateRecord _toRecord(Map<String, Object?> row) {
    return LocalMasteryStateRecord(
      conceptId: _string(row['concept_id']),
      status: _string(row['status'], fallback: 'ready'),
      masteryScore: _double(row['mastery_score']),
      confidenceScore: _double(row['confidence_score']),
      evidenceCount: _int(row['evidence_count']),
      lastEvaluatedAt: _nullableString(row['last_evaluated_at']),
      nextReviewAt: _nullableString(row['next_review_at']),
      dirty: _int(row['dirty']) == 1,
    );
  }

  static String _string(Object? value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableString(Object? value) {
    final text = _string(value);
    return text.isEmpty ? null : text;
  }

  static int _int(Object? value) => int.tryParse((value ?? '').toString()) ?? 0;

  static double _double(Object? value) {
    return switch (value) {
      final int number => number.toDouble(),
      final double number => number,
      final String text => double.tryParse(text) ?? 0,
      _ => 0,
    };
  }
}
