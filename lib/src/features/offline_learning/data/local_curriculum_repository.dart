import 'dart:collection';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../curriculum/domain/curriculum_models.dart';
import '../../curriculum/domain/curriculum_repository.dart';
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
    this.curriculumVersion,
  });

  final bool seeded;
  final String assetPath;
  final int conceptsCount;
  final int edgesCount;
  final String? curriculumVersion;
}

class LocalCurriculumRepository implements CurriculumRepository {
  LocalCurriculumRepository({
    required LocalWicaraDatabase database,
    Future<String> Function(String path)? assetLoader,
  }) : _database = database,
       _assetLoader = assetLoader ?? rootBundle.loadString;

  static const defaultPilotGraphAssetPath =
      'assets/offline_graph/math_derivatives_pilot.json';
  static const defaultFullCurriculumAssetPath =
      'assets/offline_graph/full_curriculum_dump.json';
  static const _metaCurriculumVersionKey = 'curriculum_version';

  final LocalWicaraDatabase _database;
  final Future<String> Function(String path) _assetLoader;

  Future<String?> readCurriculumVersion() async {
    final db = await _database.database;
    final rows = await db.query(
      LocalDbTables.localMeta,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_metaCurriculumVersionKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _nullableString(rows.first['value']);
  }

  Future<void> writeCurriculumVersion(String version) async {
    final normalized = version.trim();
    if (normalized.isEmpty) {
      return;
    }
    final db = await _database.database;
    await db.insert(LocalDbTables.localMeta, {
      'key': _metaCurriculumVersionKey,
      'value': normalized,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> hasLocalCurriculum() async {
    final db = await _database.database;
    final existingCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(1) FROM ${LocalDbTables.localConcepts}',
          ),
        ) ??
        0;
    return existingCount > 0;
  }

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
  }) {
    return loadCurriculumFromAsset(
      assetPath: assetPath,
      clearExisting: clearExisting,
    );
  }

  Future<LocalCurriculumSeedResult> loadCurriculumFromAsset({
    required String assetPath,
    bool clearExisting = false,
  }) async {
    final raw = await _assetLoader(assetPath);
    final parsed = jsonDecode(raw);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException(
        'Offline curriculum asset must be JSON object.',
      );
    }
    final version = _extractCurriculumVersion(parsed);
    return _importDump(
      parsed,
      assetPath: assetPath,
      clearExisting: clearExisting,
      curriculumVersion: version,
    );
  }

  Future<LocalCurriculumSeedResult> _importDump(
    Map<String, dynamic> parsed, {
    required String assetPath,
    required bool clearExisting,
    String? curriculumVersion,
  }) async {
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
        final title = _localizedLabel(node, locale: 'id');
        final description = _localizedDescription(node, locale: 'id');
        final gradeBand = _gradeBandFromNode(node);
        await txn.insert(
          LocalDbTables.localConcepts,
          {
            'id': id,
            'code': _string(node['code'], fallback: id),
            'title': title.isEmpty ? id : title,
            'subject_code': _normalizedSubjectCode(node['subject']),
            'description': description,
            'grade_band': gradeBand,
            'metadata_json': jsonEncode(node),
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final edge in edges) {
        final fromConceptId = _string(edge['from_concept_id']).isNotEmpty
            ? _string(edge['from_concept_id'])
            : _string(edge['from_node_id'], fallback: _string(edge['from']));
        final toConceptId = _string(edge['to_concept_id']).isNotEmpty
            ? _string(edge['to_concept_id'])
            : _string(edge['to_node_id'], fallback: _string(edge['to']));
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

    if (curriculumVersion != null && curriculumVersion.isNotEmpty) {
      await writeCurriculumVersion(curriculumVersion);
    }

    return LocalCurriculumSeedResult(
      seeded: true,
      assetPath: assetPath,
      conceptsCount: nodes.length,
      edgesCount: edges.length,
      curriculumVersion: curriculumVersion,
    );
  }

  Future<List<LocalConceptRecord>> listConcepts({String? subjectCode}) async {
    final db = await _database.database;
    final aliases = _subjectAliases(subjectCode);
    String? where;
    List<Object?>? whereArgs;
    if (aliases.isNotEmpty) {
      final placeholders = List.filled(aliases.length, '?').join(', ');
      where = 'subject_code IN ($placeholders)';
      whereArgs = aliases.toList(growable: false);
    }
    final rows = await db.query(
      LocalDbTables.localConcepts,
      where: where,
      whereArgs: whereArgs,
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

  @override
  Future<List<CurriculumSubject>> fetchSubjects({String locale = 'id'}) async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
SELECT subject_code, COUNT(1) AS total
FROM ${LocalDbTables.localConcepts}
GROUP BY subject_code
ORDER BY subject_code ASC
''');
    if (rows.isEmpty) {
      return const <CurriculumSubject>[];
    }
    final subjects = <CurriculumSubject>[];
    for (final row in rows) {
      final code = _string(row['subject_code']);
      if (code.isEmpty) {
        continue;
      }
      subjects.add(
        CurriculumSubject(
          code: code,
          name: _subjectDisplayName(code, locale: locale),
          isActive: true,
        ),
      );
    }
    subjects.sort((left, right) {
      final leftRank = _subjectOrder(left.code);
      final rightRank = _subjectOrder(right.code);
      if (leftRank != rightRank) {
        return leftRank.compareTo(rightRank);
      }
      return left.name.compareTo(right.name);
    });
    return subjects;
  }

  @override
  Future<CurriculumKnowledgeMap> fetchKnowledgeMap({
    required String subject,
    String locale = 'id',
  }) async {
    var concepts = await listConcepts(subjectCode: subject);
    if (concepts.isEmpty) {
      concepts = await listConcepts();
    }
    if (concepts.isEmpty) {
      return const CurriculumKnowledgeMap(
        title: 'Knowledge Map',
        width: 1280,
        height: 720,
        topDown: false,
        groups: <CurriculumKnowledgeGroup>[],
        nodes: <CurriculumKnowledgeNode>[],
        edges: <CurriculumKnowledgeEdge>[],
      );
    }
    final conceptById = <String, LocalConceptRecord>{
      for (final concept in concepts) concept.id: concept,
    };
    final edges = await listEdges();
    final scopedEdges = edges
        .where(
          (edge) =>
              conceptById.containsKey(edge.fromConceptId) &&
              conceptById.containsKey(edge.toConceptId) &&
              edge.edgeType == 'prerequisite',
        )
        .toList(growable: false);
    final mastery = await _masteryStatusByConceptId(conceptById.keys.toList());
    final layout = _buildLayout(concepts: concepts, edges: scopedEdges);
    final nodes = <CurriculumKnowledgeNode>[];
    for (final concept in layout.orderedConcepts) {
      final metadata = concept.metadata;
      final depth = layout.depthByConceptId[concept.id] ?? 0;
      final order = layout.orderByConceptId[concept.id] ?? 0;
      final status = _statusFromLocal(mastery[concept.id]);
      final x = 40.0 + (depth * 300.0);
      final y = 82.0 + (order * 86.0);
      final localizedLabel = _localizedLabel(metadata, locale: locale);
      final idDescription = _localizedDescription(metadata, locale: 'id') ?? '';
      final enDescription = _localizedDescription(metadata, locale: 'en') ?? '';
      nodes.add(
        CurriculumKnowledgeNode(
          id: concept.code,
          label: localizedLabel.isEmpty ? concept.title : localizedLabel,
          description: locale == 'en' ? enDescription : idDescription,
          idDesc: idDescription,
          enDesc: enDescription,
          gradeBand: concept.gradeBand ?? '',
          x: x,
          y: y,
          status: status,
          statusLabel: status.name.toUpperCase(),
        ),
      );
    }
    final groups = <CurriculumKnowledgeGroup>[];
    for (var depth = 0; depth <= layout.maxDepth; depth++) {
      groups.add(
        CurriculumKnowledgeGroup(
          label: 'Layer ${depth + 1}',
          x: 40 + depth * 300,
        ),
      );
    }
    final width = 40 + ((layout.maxDepth + 1) * 300) + 220;
    final height = 220 + (layout.maxLayerSize * 86);
    return CurriculumKnowledgeMap(
      title: _subjectDisplayName(subject, locale: locale),
      width: width.toDouble(),
      height: height < 600 ? 600 : height.toDouble(),
      topDown: false,
      groups: groups,
      nodes: nodes,
      edges: [
        for (final edge in scopedEdges)
          CurriculumKnowledgeEdge(
            from: conceptById[edge.fromConceptId]!.code,
            to: conceptById[edge.toConceptId]!.code,
          ),
      ],
    );
  }

  @override
  Future<CurriculumConceptDetail> fetchConceptDetail({
    required String conceptCode,
    String? subject,
    String locale = 'id',
  }) async {
    final allConcepts = await listConcepts(subjectCode: subject);
    if (allConcepts.isEmpty) {
      throw const FormatException('Konsep tidak ditemukan di kurikulum lokal.');
    }
    final conceptByCode = <String, LocalConceptRecord>{
      for (final concept in allConcepts) concept.code: concept,
    };
    final concept = conceptByCode[conceptCode];
    if (concept == null) {
      throw FormatException(
        'Konsep "$conceptCode" tidak ditemukan di kurikulum lokal.',
      );
    }
    final conceptById = <String, LocalConceptRecord>{
      for (final item in allConcepts) item.id: item,
    };
    final mastery = await _masteryStatusByConceptId(
      conceptById.keys.toList(growable: false),
    );
    final edges = await listEdges();
    final prerequisites = <CurriculumConceptRelation>[];
    final related = <CurriculumConceptRelation>[];
    final crossSubject = <CurriculumConceptRelation>[];
    for (final edge in edges) {
      if (edge.edgeType != 'prerequisite') {
        continue;
      }
      if (edge.toConceptId == concept.id) {
        final prereq = conceptById[edge.fromConceptId];
        if (prereq == null) {
          continue;
        }
        final relation = _toRelation(
          prereq,
          locale: locale,
          masteryStatus: mastery[prereq.id],
        );
        prerequisites.add(relation);
        if (_normalizedSubjectCode(prereq.subjectCode) !=
            _normalizedSubjectCode(concept.subjectCode)) {
          crossSubject.add(relation);
        }
      } else if (edge.fromConceptId == concept.id) {
        final target = conceptById[edge.toConceptId];
        if (target == null) {
          continue;
        }
        final relation = _toRelation(
          target,
          locale: locale,
          masteryStatus: mastery[target.id],
        );
        related.add(relation);
        if (_normalizedSubjectCode(target.subjectCode) !=
            _normalizedSubjectCode(concept.subjectCode)) {
          crossSubject.add(relation);
        }
      }
    }
    final nodeStatus = _statusFromLocal(mastery[concept.id]);
    final conceptNode = CurriculumKnowledgeNode(
      id: concept.code,
      label: _localizedLabel(concept.metadata, locale: locale).isEmpty
          ? concept.title
          : _localizedLabel(concept.metadata, locale: locale),
      description:
          _localizedDescription(concept.metadata, locale: locale) ??
          (concept.description ?? ''),
      idDesc:
          _localizedDescription(concept.metadata, locale: 'id') ??
          (concept.description ?? ''),
      enDesc:
          _localizedDescription(concept.metadata, locale: 'en') ??
          (concept.description ?? ''),
      gradeBand: concept.gradeBand ?? '',
      x: 0,
      y: 0,
      status: nodeStatus,
      statusLabel: nodeStatus.name.toUpperCase(),
    );
    final masteryScore = _masteryScoreFromStatus(mastery[concept.id]);
    return CurriculumConceptDetail(
      concept: conceptNode,
      masteryConfidence: masteryScore,
      prerequisites: _dedupRelations(prerequisites),
      relatedConcepts: _dedupRelations(related),
      crossSubjectConnections: _dedupRelations(crossSubject),
    );
  }

  Future<Map<String, String>> _masteryStatusByConceptId(
    List<String> conceptIds,
  ) async {
    if (conceptIds.isEmpty) {
      return const <String, String>{};
    }
    final db = await _database.database;
    final placeholders = List.filled(conceptIds.length, '?').join(', ');
    final rows = await db.rawQuery(
      'SELECT concept_id, status FROM ${LocalDbTables.localMasteryStates} WHERE concept_id IN ($placeholders)',
      conceptIds,
    );
    return {
      for (final row in rows)
        _string(row['concept_id']): _string(row['status'], fallback: 'ready'),
    };
  }

  _LayoutResult _buildLayout({
    required List<LocalConceptRecord> concepts,
    required List<LocalConceptEdgeRecord> edges,
  }) {
    final depthById = <String, int>{};
    final orderById = <String, int>{};
    final indegree = <String, int>{
      for (final concept in concepts) concept.id: 0,
    };
    final adjacency = <String, List<String>>{
      for (final concept in concepts) concept.id: <String>[],
    };
    for (final edge in edges) {
      if (!indegree.containsKey(edge.fromConceptId) ||
          !indegree.containsKey(edge.toConceptId)) {
        continue;
      }
      adjacency[edge.fromConceptId]!.add(edge.toConceptId);
      indegree[edge.toConceptId] = (indegree[edge.toConceptId] ?? 0) + 1;
    }
    final conceptById = <String, LocalConceptRecord>{
      for (final concept in concepts) concept.id: concept,
    };
    final queue = SplayTreeSet<String>((left, right) {
      final leftConcept = conceptById[left];
      final rightConcept = conceptById[right];
      final byTitle = _string(
        leftConcept?.title,
      ).compareTo(_string(rightConcept?.title));
      if (byTitle != 0) {
        return byTitle;
      }
      return left.compareTo(right);
    });
    for (final entry in indegree.entries) {
      if (entry.value == 0) {
        queue.add(entry.key);
        depthById[entry.key] = 0;
      }
    }
    if (queue.isEmpty) {
      for (final concept in concepts) {
        queue.add(concept.id);
        depthById[concept.id] = 0;
      }
    }

    final visited = <String>{};
    while (queue.isNotEmpty) {
      final current = queue.first;
      queue.remove(current);
      visited.add(current);
      for (final next in adjacency[current] ?? const <String>[]) {
        final currentDepth = depthById[current] ?? 0;
        final nextDepth = currentDepth + 1;
        if (nextDepth > (depthById[next] ?? 0)) {
          depthById[next] = nextDepth;
        }
        indegree[next] = (indegree[next] ?? 0) - 1;
        if ((indegree[next] ?? 0) <= 0) {
          queue.add(next);
        }
      }
    }
    for (final concept in concepts) {
      depthById.putIfAbsent(concept.id, () => 0);
    }
    final grouped = <int, List<LocalConceptRecord>>{};
    for (final concept in concepts) {
      final depth = depthById[concept.id] ?? 0;
      grouped.putIfAbsent(depth, () => <LocalConceptRecord>[]).add(concept);
    }
    var maxLayerSize = 0;
    var maxDepth = 0;
    final ordered = <LocalConceptRecord>[];
    final sortedDepths = grouped.keys.toList()..sort();
    for (final depth in sortedDepths) {
      final layer = grouped[depth] ?? <LocalConceptRecord>[];
      layer.sort((left, right) => left.title.compareTo(right.title));
      if (layer.length > maxLayerSize) {
        maxLayerSize = layer.length;
      }
      if (depth > maxDepth) {
        maxDepth = depth;
      }
      for (var index = 0; index < layer.length; index++) {
        orderById[layer[index].id] = index;
      }
      ordered.addAll(layer);
    }
    return _LayoutResult(
      orderedConcepts: ordered,
      depthByConceptId: depthById,
      orderByConceptId: orderById,
      maxDepth: maxDepth,
      maxLayerSize: maxLayerSize == 0 ? 1 : maxLayerSize,
    );
  }

  CurriculumConceptRelation _toRelation(
    LocalConceptRecord concept, {
    required String locale,
    required String? masteryStatus,
  }) {
    final status = _statusFromLocal(masteryStatus);
    return CurriculumConceptRelation(
      id: concept.code,
      label: _localizedLabel(concept.metadata, locale: locale).isEmpty
          ? concept.title
          : _localizedLabel(concept.metadata, locale: locale),
      subjectName: _subjectDisplayName(concept.subjectCode, locale: locale),
      status: status,
      statusLabel: status.name.toUpperCase(),
    );
  }

  List<CurriculumConceptRelation> _dedupRelations(
    List<CurriculumConceptRelation> relations,
  ) {
    final seen = <String>{};
    final result = <CurriculumConceptRelation>[];
    for (final relation in relations) {
      if (seen.contains(relation.id)) {
        continue;
      }
      seen.add(relation.id);
      result.add(relation);
      if (result.length >= 8) {
        break;
      }
    }
    return result;
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
    return value
        .whereType<Map>()
        .map((item) => item.map((key, val) => MapEntry(key.toString(), val)))
        .toList(growable: false);
  }

  static Map<String, dynamic> _decodeObject(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, val) => MapEntry(key.toString(), val));
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

  static String _extractCurriculumVersion(Map<String, dynamic> payload) {
    final metadata = payload['metadata'];
    if (metadata is Map<String, dynamic>) {
      return _string(
        metadata['curriculum_version'],
        fallback: _string(metadata['version'], fallback: 'v0'),
      );
    }
    if (metadata is Map) {
      return _string(
        metadata['curriculum_version'],
        fallback: _string(metadata['version'], fallback: 'v0'),
      );
    }
    return 'v0';
  }

  static String _localizedLabel(
    Map<String, dynamic> node, {
    String locale = 'id',
  }) {
    final preferred = locale.toLowerCase() == 'en'
        ? _string(node['label_en'])
        : _string(node['label_id']);
    if (preferred.isNotEmpty) {
      return preferred;
    }
    final fallback = locale.toLowerCase() == 'en'
        ? _string(node['label_id'])
        : _string(node['label_en']);
    if (fallback.isNotEmpty) {
      return fallback;
    }
    final title = _string(node['title']);
    if (title.isNotEmpty) {
      return title;
    }
    return _string(node['id']);
  }

  static String? _localizedDescription(
    Map<String, dynamic> node, {
    String locale = 'id',
  }) {
    final preferred = locale.toLowerCase() == 'en'
        ? _nullableString(node['description_en'])
        : _nullableString(node['description_id']);
    if (preferred != null) {
      return preferred;
    }
    final fallback = locale.toLowerCase() == 'en'
        ? _nullableString(node['description_id'])
        : _nullableString(node['description_en']);
    return fallback;
  }

  static String _subjectDisplayName(String code, {required String locale}) {
    final normalized = _normalizedSubjectCode(code);
    final isEnglish = locale.toLowerCase() == 'en';
    return switch (normalized) {
      'matematika' => isEnglish ? 'Math' : 'Matematika',
      'fisika' => isEnglish ? 'Physics' : 'Fisika',
      'kimia' => isEnglish ? 'Chemistry' : 'Kimia',
      'biologi' => isEnglish ? 'Biology' : 'Biologi',
      'ipa' => isEnglish ? 'Science' : 'IPA',
      'ipas' => 'IPAS',
      _ => normalized,
    };
  }

  static int _subjectOrder(String code) {
    return switch (_normalizedSubjectCode(code)) {
      'matematika' => 0,
      'ipas' => 1,
      'ipa' => 2,
      'fisika' => 3,
      'kimia' => 4,
      'biologi' => 5,
      _ => 50,
    };
  }

  static Set<String> _subjectAliases(String? subjectCode) {
    if (subjectCode == null || subjectCode.trim().isEmpty) {
      return const <String>{};
    }
    final normalized = _normalizedSubjectCode(subjectCode);
    return switch (normalized) {
      'matematika' => const <String>{'matematika', 'math'},
      'fisika' => const <String>{'fisika', 'physics'},
      'kimia' => const <String>{'kimia', 'chemistry'},
      'biologi' => const <String>{'biologi', 'biology'},
      'ipa' => const <String>{'ipa', 'science'},
      'ipas' => const <String>{'ipas'},
      _ => <String>{normalized},
    };
  }

  static String _normalizedSubjectCode(Object? value) {
    final normalized = _string(value).toLowerCase();
    if (normalized.contains('math') || normalized.contains('matematika')) {
      return 'matematika';
    }
    if (normalized.contains('physics') || normalized.contains('fisika')) {
      return 'fisika';
    }
    if (normalized.contains('chemistry') || normalized.contains('kimia')) {
      return 'kimia';
    }
    if (normalized.contains('biology') || normalized.contains('biologi')) {
      return 'biologi';
    }
    if (normalized == 'science' || normalized == 'ipa') {
      return 'ipa';
    }
    if (normalized == 'ipas') {
      return 'ipas';
    }
    return normalized;
  }

  static CurriculumNodeStatus _statusFromLocal(String? status) {
    final normalized = _string(status).toLowerCase();
    return switch (normalized) {
      'mastered' => CurriculumNodeStatus.mastered,
      'active' || 'in_progress' => CurriculumNodeStatus.active,
      'review' || 'review_due' => CurriculumNodeStatus.review,
      'gap' => CurriculumNodeStatus.gap,
      'locked' => CurriculumNodeStatus.locked,
      _ => CurriculumNodeStatus.ready,
    };
  }

  static double _masteryScoreFromStatus(String? status) {
    return switch (_string(status).toLowerCase()) {
      'mastered' => 0.95,
      'active' || 'in_progress' => 0.7,
      'review' || 'review_due' => 0.55,
      'gap' => 0.25,
      'locked' => 0.1,
      _ => 0.5,
    };
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

class _LayoutResult {
  const _LayoutResult({
    required this.orderedConcepts,
    required this.depthByConceptId,
    required this.orderByConceptId,
    required this.maxDepth,
    required this.maxLayerSize,
  });

  final List<LocalConceptRecord> orderedConcepts;
  final Map<String, int> depthByConceptId;
  final Map<String, int> orderByConceptId;
  final int maxDepth;
  final int maxLayerSize;
}
