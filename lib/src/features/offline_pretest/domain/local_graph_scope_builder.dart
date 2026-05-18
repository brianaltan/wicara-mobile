import '../../offline_learning/data/local_curriculum_repository.dart';

class LocalGraphScopeBuilder {
  const LocalGraphScopeBuilder();

  Map<String, dynamic> build({
    required List<LocalConceptRecord> concepts,
    required List<LocalConceptEdgeRecord> edges,
    required String targetConceptCode,
    int maxDepth = 2,
  }) {
    final conceptByCode = <String, LocalConceptRecord>{
      for (final concept in concepts) concept.code: concept,
    };
    final conceptById = <String, LocalConceptRecord>{
      for (final concept in concepts) concept.id: concept,
    };
    final target = conceptByCode[targetConceptCode];
    if (target == null) {
      throw const FormatException('Target concept was not found.');
    }
    final incomingByTargetId = <String, List<LocalConceptEdgeRecord>>{};
    for (final edge in edges) {
      if (edge.edgeType != 'prerequisite') {
        continue;
      }
      incomingByTargetId
          .putIfAbsent(edge.toConceptId, () => <LocalConceptEdgeRecord>[])
          .add(edge);
    }

    final nodesByCode = <String, Map<String, dynamic>>{
      target.code: <String, dynamic>{
        'concept_id': target.id,
        'concept_code': target.code,
        'title': target.title,
        'description': target.description ?? '',
        'depth': 0,
        'role': 'target',
        'parent': null,
      },
    };
    final scopeEdges = <Map<String, dynamic>>[];
    final queue = <({LocalConceptRecord concept, int depth})>[
      (concept: target, depth: 0),
    ];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (current.depth >= maxDepth) {
        continue;
      }
      final incoming =
          incomingByTargetId[current.concept.id] ??
          const <LocalConceptEdgeRecord>[];
      incoming.sort((left, right) => right.weight.compareTo(left.weight));
      for (final edge in incoming) {
        final prerequisite = conceptById[edge.fromConceptId];
        if (prerequisite == null) {
          continue;
        }
        final nextDepth = current.depth + 1;
        if (!nodesByCode.containsKey(prerequisite.code)) {
          nodesByCode[prerequisite.code] = <String, dynamic>{
            'concept_id': prerequisite.id,
            'concept_code': prerequisite.code,
            'title': prerequisite.title,
            'description': prerequisite.description ?? '',
            'depth': nextDepth,
            'role': 'prerequisite',
            'parent': current.concept.code,
          };
          queue.add((concept: prerequisite, depth: nextDepth));
        }
        scopeEdges.add(<String, dynamic>{
          'from': current.concept.code,
          'to': prerequisite.code,
          'edge_type': edge.edgeType,
          'weight': edge.weight,
          'depth': nextDepth,
        });
      }
    }

    final nodes = nodesByCode.values.toList(growable: false)
      ..sort((left, right) {
        final byDepth = _int(left['depth']).compareTo(_int(right['depth']));
        if (byDepth != 0) {
          return byDepth;
        }
        final byRole = (_string(left['role']) == 'target' ? 0 : 1).compareTo(
          _string(right['role']) == 'target' ? 0 : 1,
        );
        if (byRole != 0) {
          return byRole;
        }
        return _string(left['title']).compareTo(_string(right['title']));
      });
    return <String, dynamic>{
      'target': target.code,
      'target_concept_id': target.id,
      'subject_code': target.subjectCode,
      'max_depth': maxDepth,
      'nodes': nodes,
      'edges': scopeEdges,
    };
  }

  List<Map<String, dynamic>> buildProbeQueue(Map<String, dynamic> graphScope) {
    final edges = (graphScope['edges'] as List?) ?? const <dynamic>[];
    final edgeByTo = <String, Map<String, dynamic>>{};
    for (final edge in edges) {
      if (edge is! Map) {
        continue;
      }
      final mapped = edge.cast<String, dynamic>();
      edgeByTo[_string(mapped['to'])] = mapped;
    }
    final queue = <Map<String, dynamic>>[];
    for (final node in (graphScope['nodes'] as List?) ?? const <dynamic>[]) {
      if (node is! Map) {
        continue;
      }
      final mapped = node.cast<String, dynamic>();
      if (_string(mapped['role']) != 'prerequisite') {
        continue;
      }
      final depth = _int(mapped['depth'], fallback: 1);
      final edge =
          edgeByTo[_string(mapped['concept_code'])] ??
          const <String, dynamic>{};
      final weight = _double(edge['weight'], fallback: 1);
      queue.add(<String, dynamic>{
        'concept_code': _string(mapped['concept_code']),
        'concept_id': _string(mapped['concept_id']),
        'depth': depth,
        'priority': _round4(weight - (depth * 0.2)),
        'parent': mapped['parent'],
      });
    }
    queue.sort((left, right) {
      final byPriority = _double(
        right['priority'],
      ).compareTo(_double(left['priority']));
      if (byPriority != 0) {
        return byPriority;
      }
      final byDepth = _int(left['depth']).compareTo(_int(right['depth']));
      if (byDepth != 0) {
        return byDepth;
      }
      return _string(
        left['concept_code'],
      ).compareTo(_string(right['concept_code']));
    });
    return queue;
  }
}

double _round4(double value) => (value * 10000).round() / 10000;

double _double(Object? value, {double fallback = 0}) {
  return switch (value) {
    final int number => number.toDouble(),
    final double number => number,
    final String text => double.tryParse(text) ?? fallback,
    _ => fallback,
  };
}

int _int(Object? value, {int fallback = 0}) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text) ?? fallback,
    _ => fallback,
  };
}

String _string(Object? value, {String fallback = ''}) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}
