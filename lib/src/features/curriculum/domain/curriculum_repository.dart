import 'curriculum_models.dart';

abstract class CurriculumRepository {
  Future<List<CurriculumSubject>> fetchSubjects();

  Future<CurriculumKnowledgeMap> fetchKnowledgeMap({required String subject});

  Future<CurriculumConceptDetail> fetchConceptDetail({
    required String conceptCode,
    String? subject,
  });
}
