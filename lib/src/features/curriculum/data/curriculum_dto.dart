import '../domain/curriculum_models.dart';

class SubjectListDto {
  const SubjectListDto({required this.items});

  factory SubjectListDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return SubjectListDto(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(SubjectDto.fromJson)
                .toList()
          : const [],
    );
  }

  final List<SubjectDto> items;

  List<CurriculumSubject> toDomain() {
    return [
      for (final item in items)
        CurriculumSubject(
          code: item.code,
          name: item.name,
          isActive: item.isActive,
        ),
    ];
  }
}

class SubjectDto {
  const SubjectDto({
    required this.code,
    required this.name,
    required this.isActive,
  });

  factory SubjectDto.fromJson(Map<String, dynamic> json) {
    return SubjectDto(
      code: _stringValue(json['code']),
      name: _stringValue(json['name']),
      isActive: json['is_active'] == true,
    );
  }

  final String code;
  final String name;
  final bool isActive;
}

class KnowledgeMapDto {
  const KnowledgeMapDto({
    required this.graph,
    required this.groups,
    required this.nodes,
    required this.edges,
  });

  factory KnowledgeMapDto.fromJson(Map<String, dynamic> json) {
    final graph = json['graph'];
    final groups = json['groups'];
    final nodes = json['nodes'];
    final edges = json['edges'];

    return KnowledgeMapDto(
      graph: graph is Map<String, dynamic>
          ? KnowledgeMapGraphDto.fromJson(graph)
          : const KnowledgeMapGraphDto.empty(),
      groups: groups is List
          ? groups
                .whereType<Map<String, dynamic>>()
                .map(KnowledgeMapGroupDto.fromJson)
                .toList()
          : const [],
      nodes: nodes is List
          ? nodes
                .whereType<Map<String, dynamic>>()
                .map(KnowledgeMapNodeDto.fromJson)
                .toList()
          : const [],
      edges: edges is List
          ? edges
                .whereType<Map<String, dynamic>>()
                .map(KnowledgeMapEdgeDto.fromJson)
                .toList()
          : const [],
    );
  }

  final KnowledgeMapGraphDto graph;
  final List<KnowledgeMapGroupDto> groups;
  final List<KnowledgeMapNodeDto> nodes;
  final List<KnowledgeMapEdgeDto> edges;

  CurriculumKnowledgeMap toDomain() {
    return CurriculumKnowledgeMap(
      title: graph.title,
      width: graph.width,
      height: graph.height,
      topDown: graph.topDown,
      groups: [
        for (final group in groups)
          CurriculumKnowledgeGroup(label: group.label, x: group.x),
      ],
      nodes: [
        for (final node in nodes)
          CurriculumKnowledgeNode(
            id: node.id,
            label: node.label,
            x: node.x,
            y: node.y,
            status: _statusFromBackend(node.status),
          ),
      ],
      edges: [
        for (final edge in edges)
          CurriculumKnowledgeEdge(from: edge.from, to: edge.to),
      ],
    );
  }
}

class KnowledgeMapGraphDto {
  const KnowledgeMapGraphDto({
    required this.title,
    required this.width,
    required this.height,
    required this.topDown,
  });

  const KnowledgeMapGraphDto.empty()
    : title = 'Mathematics Prerequisite Map',
      width = 2260,
      height = 600,
      topDown = true;

  factory KnowledgeMapGraphDto.fromJson(Map<String, dynamic> json) {
    return KnowledgeMapGraphDto(
      title: _stringValue(json['title']),
      width: _doubleValue(json['width'], fallback: 2260),
      height: _doubleValue(json['height'], fallback: 600),
      topDown: json['top_down'] != false,
    );
  }

  final String title;
  final double width;
  final double height;
  final bool topDown;
}

class KnowledgeMapGroupDto {
  const KnowledgeMapGroupDto({required this.label, required this.x});

  factory KnowledgeMapGroupDto.fromJson(Map<String, dynamic> json) {
    return KnowledgeMapGroupDto(
      label: _stringValue(json['label']),
      x: _doubleValue(json['x']),
    );
  }

  final String label;
  final double x;
}

class KnowledgeMapNodeDto {
  const KnowledgeMapNodeDto({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.status,
  });

  factory KnowledgeMapNodeDto.fromJson(Map<String, dynamic> json) {
    return KnowledgeMapNodeDto(
      id: _stringValue(json['id']),
      label: _stringValue(json['label'], fallback: _stringValue(json['title'])),
      x: _doubleValue(json['x']),
      y: _doubleValue(json['y']),
      status: _stringValue(json['status'], fallback: 'ready'),
    );
  }

  final String id;
  final String label;
  final double x;
  final double y;
  final String status;
}

class KnowledgeMapEdgeDto {
  const KnowledgeMapEdgeDto({required this.from, required this.to});

  factory KnowledgeMapEdgeDto.fromJson(Map<String, dynamic> json) {
    return KnowledgeMapEdgeDto(
      from: _stringValue(json['from']),
      to: _stringValue(json['to']),
    );
  }

  final String from;
  final String to;
}

CurriculumNodeStatus _statusFromBackend(String value) {
  return switch (value.toLowerCase()) {
    'mastered' => CurriculumNodeStatus.mastered,
    'active' || 'in_progress' => CurriculumNodeStatus.active,
    'review' || 'review_due' => CurriculumNodeStatus.review,
    'locked' => CurriculumNodeStatus.locked,
    _ => CurriculumNodeStatus.ready,
  };
}

String _stringValue(Object? value, {String fallback = ''}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

double _doubleValue(Object? value, {double fallback = 0}) {
  return switch (value) {
    final int number => number.toDouble(),
    final double number => number,
    final String text => double.tryParse(text) ?? fallback,
    _ => fallback,
  };
}
