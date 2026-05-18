import 'curriculum_models.dart';

abstract class CurriculumRepository {
  Future<List<CurriculumSubject>> fetchSubjects({String locale = 'en'});

  Future<CurriculumKnowledgeMap> fetchKnowledgeMap({
    required String subject,
    String locale = 'en',
  });

  Future<CurriculumConceptDetail> fetchConceptDetail({
    required String conceptCode,
    String? subject,
    String locale = 'en',
  });
}
