import 'package:flutter/material.dart';

import 'src/app/wicara_app.dart';
import 'src/core/network/api_client.dart';
import 'src/features/auth/data/mock_auth_repository.dart';
import 'src/features/curriculum/data/api_curriculum_repository.dart';
import 'src/features/onboarding/data/mock_onboarding_repository.dart';
import 'src/features/pretest/data/mock_pretest_repository.dart';

void main() {
  final apiClient = ApiClient(baseUrl: ApiClient.defaultBaseUrl);

  runApp(
    WicaraApp(
      authRepository: MockAuthRepository(),
      curriculumRepository: ApiCurriculumRepository(apiClient: apiClient),
      onboardingRepository: MockOnboardingRepository(),
      pretestRepository: MockPretestRepository(),
    ),
  );
}
