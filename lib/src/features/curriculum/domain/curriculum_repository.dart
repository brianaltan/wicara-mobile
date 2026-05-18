import 'curriculum_models.dart';

abstract class CurriculumRepository {
  Future<List<CurriculumSubject>> fetchSubjects({String locale = 'id'});

  Future<CurriculumKnowledgeMap> fetchKnowledgeMap({
    required String subject,
    String locale = 'id',
  });

  Future<CurriculumConceptDetail> fetchConceptDetail({
    required String conceptCode,
    String? subject,
    String locale = 'id',
  });
}
