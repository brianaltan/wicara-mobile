import '../../../core/network/api_client.dart';
import '../domain/curriculum_models.dart';
import '../domain/curriculum_repository.dart';
import 'curriculum_dto.dart';

class ApiCurriculumRepository implements CurriculumRepository {
  const ApiCurriculumRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<CurriculumSubject>> fetchSubjects() async {
    final json = await _apiClient.getJson('/api/v1/subjects');
    return SubjectListDto.fromJson(json).toDomain();
  }

  @override
  Future<CurriculumKnowledgeMap> fetchKnowledgeMap({
    required String subject,
  }) async {
    final json = await _apiClient.getJson(
      '/api/v1/knowledge-map',
      queryParameters: {'subject': subject},
    );
    return KnowledgeMapDto.fromJson(json).toDomain();
  }
}
