import '../../../core/network/api_client.dart';
import '../domain/curriculum_models.dart';
import '../domain/curriculum_repository.dart';
import 'curriculum_dto.dart';

class ApiCurriculumRepository implements CurriculumRepository {
  const ApiCurriculumRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<CurriculumSubject>> fetchSubjects({String locale = 'id'}) async {
    final json = await _apiClient.getJson(
      '/api/v1/subjects',
      queryParameters: {'locale': _supportedLocale(locale)},
    );
    return SubjectListDto.fromJson(json).toDomain();
  }

  @override
  Future<CurriculumKnowledgeMap> fetchKnowledgeMap({
    required String subject,
    String locale = 'id',
  }) async {
    final json = await _apiClient.getJson(
      '/api/v1/knowledge-map',
      queryParameters: {'subject': subject, 'locale': _supportedLocale(locale)},
    );
    return KnowledgeMapDto.fromJson(json).toDomain();
  }

  @override
  Future<CurriculumConceptDetail> fetchConceptDetail({
    required String conceptCode,
    String? subject,
    String locale = 'id',
  }) async {
    final queryParameters = <String, String>{
      'locale': _supportedLocale(locale),
    };
    if (subject != null) {
      queryParameters['subject'] = subject;
    }
    final json = await _apiClient.getJson(
      '/api/v1/knowledge-map/concepts/${Uri.encodeComponent(conceptCode)}',
      queryParameters: queryParameters,
    );
    return ConceptDetailDto.fromJson(json).toDomain();
  }

  String _supportedLocale(String locale) {
    final normalized = locale.trim().toLowerCase().replaceAll('_', '-');
    if (normalized == 'id' ||
        normalized == 'id-id' ||
        normalized == 'ind' ||
        normalized == 'indo' ||
        normalized == 'indonesian' ||
        normalized == 'bahasa' ||
        normalized == 'bahasa indonesia' ||
        normalized.contains('indo')) {
      return 'id';
    }
    return 'en';
  }
}
