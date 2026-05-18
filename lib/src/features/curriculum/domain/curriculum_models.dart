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
    required this.description,
    required this.idDesc,
    required this.enDesc,
    required this.gradeBand,
    required this.x,
    required this.y,
    required this.status,
    required this.statusLabel,
  });

  final String id;
  final String label;
  final String description;
  final String idDesc;
  final String enDesc;
  final String gradeBand;
  final double x;
  final double y;
  final CurriculumNodeStatus status;
  final String statusLabel;
}

class CurriculumKnowledgeEdge {
  const CurriculumKnowledgeEdge({required this.from, required this.to});

  final String from;
  final String to;
}

class CurriculumConceptDetail {
  const CurriculumConceptDetail({
    required this.concept,
    required this.masteryConfidence,
    required this.prerequisites,
    required this.relatedConcepts,
    required this.crossSubjectConnections,
  });

  final CurriculumKnowledgeNode concept;
  final double masteryConfidence;
  final List<CurriculumConceptRelation> prerequisites;
  final List<CurriculumConceptRelation> relatedConcepts;
  final List<CurriculumConceptRelation> crossSubjectConnections;
}

class CurriculumConceptRelation {
  const CurriculumConceptRelation({
    required this.id,
    required this.label,
    required this.subjectName,
    required this.status,
    required this.statusLabel,
  });

  final String id;
  final String label;
  final String subjectName;
  final CurriculumNodeStatus status;
  final String statusLabel;
}

enum CurriculumNodeStatus { mastered, active, review, ready, gap, locked }
