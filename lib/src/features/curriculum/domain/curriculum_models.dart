class CurriculumSubject {
  const CurriculumSubject({
    required this.code,
    required this.name,
    required this.isActive,
  });

  final String code;
  final String name;
  final bool isActive;
}

class CurriculumKnowledgeMap {
  const CurriculumKnowledgeMap({
    required this.title,
    required this.width,
    required this.height,
    required this.topDown,
    required this.groups,
    required this.nodes,
    required this.edges,
  });

  final String title;
  final double width;
  final double height;
  final bool topDown;
  final List<CurriculumKnowledgeGroup> groups;
  final List<CurriculumKnowledgeNode> nodes;
  final List<CurriculumKnowledgeEdge> edges;
}

class CurriculumKnowledgeGroup {
  const CurriculumKnowledgeGroup({required this.label, required this.x});

  final String label;
  final double x;
}

class CurriculumKnowledgeNode {
  const CurriculumKnowledgeNode({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.status,
  });

  final String id;
  final String label;
  final double x;
  final double y;
  final CurriculumNodeStatus status;
}

class CurriculumKnowledgeEdge {
  const CurriculumKnowledgeEdge({required this.from, required this.to});

  final String from;
  final String to;
}

enum CurriculumNodeStatus { mastered, active, review, ready, locked }
