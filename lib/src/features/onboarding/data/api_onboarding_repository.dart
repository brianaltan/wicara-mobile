import '../../../core/network/api_client.dart';
import '../../auth/data/auth_session_store.dart';
import '../domain/onboarding_profile.dart';
import '../domain/onboarding_repository.dart';

class ApiOnboardingRepository implements OnboardingRepository {
  const ApiOnboardingRepository({
    required ApiClient apiClient,
    required AuthSessionStore sessionStore,
  }) : _apiClient = apiClient,
       _sessionStore = sessionStore;

  final ApiClient _apiClient;
  final AuthSessionStore _sessionStore;

  @override
  Future<void> saveProfile(OnboardingProfile profile) async {
    final token = _sessionStore.accessToken;
    if (token == null || token.isEmpty) {
      throw const OnboardingException('Please log in before onboarding.');
    }

    try {
      await _apiClient.putJson(
        '/api/v1/me/profile/onboarding',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'full_name': profile.fullName,
          'country_name': profile.country,
          'education_level': profile.educationLevel,
          'grade_level': profile.gradeLevel,
          'preferred_language': _languageCode(profile.preferredLanguage),
          'selected_subjects': profile.selectedSubjects,
          'study_goal': profile.studyGoal,
          'daily_study_time_label': profile.dailyStudyTime,
        },
      );
      await _sessionStore.markOnboardingCompleted(
        lastProtectedRoute: '/home',
        displayName: profile.fullName,
      );
    } on ApiClientException catch (error) {
      throw OnboardingException(error.message);
    }
  }

  String _languageCode(String label) {
    final normalized = label.trim().toLowerCase();
    return switch (normalized) {
      'bahasa indonesia' || 'indonesian' => 'id',
      'english' => 'en',
      'bahasa melayu' || 'malay' => 'ms',
      'filipino' || 'tagalog' => 'fil',
      'vietnamese' || 'tieng viet' => 'vi',
      _ => normalized.isEmpty ? 'id' : normalized,
    };
  }
}
