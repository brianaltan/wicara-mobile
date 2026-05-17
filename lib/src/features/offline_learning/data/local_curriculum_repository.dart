import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'local_wicara_database.dart';

class LocalConceptRecord {
  const LocalConceptRecord({
    required this.id,
    required this.code,
    required this.title,
    required this.subjectCode,
    required this.description,
    required this.gradeBand,
    required this.metadata,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final String title;
  final String subjectCode;
  final String? description;
  final String? gradeBand;
  final Map<String, dynamic> metadata;
  final String updatedAt;
}

class LocalConceptEdgeRecord {
  const LocalConceptEdgeRecord({
    required this.id,
    required this.fromConceptId,
    required this.toConceptId,
    required this.edgeType,
    required this.weight,
    required this.metadata,
  });

  final String id;
  final String fromConceptId;
  final String toConceptId;
  final String edgeType;
  final double weight;
  final Map<String, dynamic> metadata;
}

class LocalCurriculumSeedResult {
  const LocalCurriculumSeedResult({
    required this.seeded,
    required this.assetPath,
    required this.conceptsCount,
    required this.edgesCount,
  });

  final bool seeded;
  final String assetPath;
  final int conceptsCount;
  final int edgesCount;
}

class LocalCurriculumRepository {
  LocalCurriculumRepository({
    required LocalWicaraDatabase database,
    Future<String> Function(String path)? assetLoader,
  }) : _database = database,
       _assetLoader = assetLoader ?? rootBundle.loadString;

  static const defaultPilotGraphAssetPath =
      'assets/offline_graph/math_derivatives_pilot.json';

  final LocalWicaraDatabase _database;
  final Future<String> Function(String path) _assetLoader;

  Future<LocalCurriculumSeedResult> ensurePilotSliceSeeded({
    String assetPath = defaultPilotGraphAssetPath,
    bool forceReload = false,
  }) async {
    final db = await _database.database;
    final existingCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(1) FROM ${LocalDbTables.localConcepts}',
          ),
        ) ??
        0;
    if (existingCount > 0 && !forceReload) {
      final existingEdges =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(1) FROM ${LocalDbTables.localConceptEdges}',
            ),
          ) ??
          0;
      return LocalCurriculumSeedResult(
        seeded: false,
        assetPath: assetPath,
        conceptsCount: existingCount,
        edgesCount: existingEdges,
      );
    }

    return loadPilotSlice(assetPath: assetPath, clearExisting: true);
  }

  Future<LocalCurriculumSeedResult> loadPilotSlice({
    String assetPath = defaultPilotGraphAssetPath,
    bool clearExisting = false,
  }) async {
    final raw = await _assetLoader(assetPath);
    final parsed = jsonDecode(raw);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException(
        'Offline curriculum asset must be JSON object.',
      );
    }
    final nodes = _jsonObjectList(parsed['nodes']);
    final edges = _jsonObjectList(parsed['edges']);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final db = await _database.database;
    await db.transaction((txn) async {
      if (clearExisting) {
        await txn.delete(LocalDbTables.localConceptEdges);
        await txn.delete(LocalDbTables.localConcepts);
      }

      for (final node in nodes) {
        final id = _string(node['id']);
        if (id.isEmpty) {
          continue;
        }
        final title = _string(
          node['label_id'],
          fallback: _string(node['label_en']),
        );
        final description = _nullableString(node['description_id']);
        final gradeBand = _gradeBandFromNode(node);
        await txn.insert(
          LocalDbTables.localConcepts,
          {
            'id': id,
            'code': id,
            'title': title.isEmpty ? id : title,
            'subject_code': _string(node['subject'], fallback: 'matematika'),
            'description': description,
            'grade_band': gradeBand,
            'metadata_json': jsonEncode(node),
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final edge in edges) {
        final fromConceptId = _string(edge['from_node_id']);
        final toConceptId = _string(edge['to_node_id']);
        if (fromConceptId.isEmpty || toConceptId.isEmpty) {
          continue;
        }
        final edgeType = _string(edge['edge_type'], fallback: 'prerequisite');
        final edgeId = _string(
          edge['id'],
          fallback: '$fromConceptId->$toConceptId:$edgeType',
        );
        final weight = _double(
          edge['weight'],
          fallback: _double(edge['strength'], fallback: 1),
        );
        await txn.insert(
          LocalDbTables.localConceptEdges,
          {
            'id': edgeId,
            'from_concept_id': fromConceptId,
            'to_concept_id': toConceptId,
            'edge_type': edgeType,
            'weight': weight,
            'metadata_json': jsonEncode(edge),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    return LocalCurriculumSeedResult(
      seeded: true,
      assetPath: assetPath,
      conceptsCount: nodes.length,
      edgesCount: edges.length,
    );
  }

  Future<List<LocalConceptRecord>> listConcepts({String? subjectCode}) async {
    final db = await _database.database;
    final rows = await db.query(
      LocalDbTables.localConcepts,
      where: subjectCode == null ? null : 'subject_code = ?',
      whereArgs: subjectCode == null ? null : <Object?>[subjectCode],
      orderBy: 'title ASC',
    );
    return rows.map(_toConceptRecord).toList(growable: false);
  }

  Future<List<LocalConceptEdgeRecord>> listEdges() async {
    final db = await _database.database;
    final rows = await db.query(
      LocalDbTables.localConceptEdges,
      orderBy: 'from_concept_id ASC, to_concept_id ASC',
    );
    return rows.map(_toEdgeRecord).toList(growable: false);
  }

  LocalConceptRecord _toConceptRecord(Map<String, Object?> row) {
    return LocalConceptRecord(
      id: _string(row['id']),
      code: _string(row['code']),
      title: _string(row['title']),
      subjectCode: _string(row['subject_code']),
      description: _nullableString(row['description']),
      gradeBand: _nullableString(row['grade_band']),
      metadata: _decodeObject(row['metadata_json']),
      updatedAt: _string(row['updated_at']),
    );
  }

  LocalConceptEdgeRecord _toEdgeRecord(Map<String, Object?> row) {
    return LocalConceptEdgeRecord(
      id: _string(row['id']),
      fromConceptId: _string(row['from_concept_id']),
      toConceptId: _string(row['to_concept_id']),
      edgeType: _string(row['edge_type']),
      weight: _double(row['weight'], fallback: 1),
      metadata: _decodeObject(row['metadata_json']),
    );
  }

  static List<Map<String, dynamic>> _jsonObjectList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
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

  static String _gradeBandFromNode(Map<String, dynamic> node) {
    final phase = _nullableString(node['phase']);
    final schoolLevel = _nullableString(node['school_level']);
    final gradeRange = _nullableString(node['grade_range']);
    final parts = <String?>[
      phase == null ? null : 'Fase $phase',
      schoolLevel,
      gradeRange,
    ];
    return parts.whereType<String>().join(' ').trim();
  }

  static String _string(Object? value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableString(Object? value) {
    final text = _string(value);
    return text.isEmpty ? null : text;
  }

  static double _double(Object? value, {double fallback = 0}) {
    return switch (value) {
      final int number => number.toDouble(),
      final double number => number,
      final String text => double.tryParse(text) ?? fallback,
      _ => fallback,
    };
  }
}
