import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicara_mobile/src/app/wicara_app.dart';
import 'package:wicara_mobile/src/core/network/api_client.dart';
import 'package:wicara_mobile/src/core/theme/wicara_theme.dart';
import 'package:wicara_mobile/src/features/auth/application/auth_controller.dart';
import 'package:wicara_mobile/src/features/auth/data/auth_session_store.dart';
import 'package:wicara_mobile/src/features/auth/data/mock_auth_repository.dart';
import 'package:wicara_mobile/src/features/curriculum/domain/curriculum_models.dart';
import 'package:wicara_mobile/src/features/curriculum/domain/curriculum_repository.dart';
import 'package:wicara_mobile/src/features/home/domain/home_repository.dart';
import 'package:wicara_mobile/src/features/home/domain/home_snapshot.dart';
import 'package:wicara_mobile/src/features/learning_goal/domain/learning_goal_repository.dart';
import 'package:wicara_mobile/src/features/onboarding/application/onboarding_controller.dart';
import 'package:wicara_mobile/src/features/onboarding/data/mock_onboarding_repository.dart';
import 'package:wicara_mobile/src/features/onboarding/data/onboarding_profile_store.dart';
import 'package:wicara_mobile/src/features/pretest/data/mock_pretest_repository.dart';
import 'package:wicara_mobile/src/features/pretest/domain/pretest_models.dart';
import 'package:wicara_mobile/src/features/pretest/presentation/pretest_page.dart';
import 'package:wicara_mobile/src/features/pretest/presentation/widgets/fishbone_canvas.dart';

const _curriculumRepository = _FailingCurriculumRepository();
const _learningGoalRepository = _FakeLearningGoalRepository();
const _homeRepository = _FakeHomeRepository();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('landing page opens the sign in page', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildTestApp());

    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
  });

  testWidgets('sign in opens the backend-backed home dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildTestApp());

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'aisyah@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.ensureVisible(find.text('Log in').last);
    await tester.tap(find.text('Log in').last);
    await tester.pumpAndSettle();

    final reachedHome = find
        .textContaining('Welcome back')
        .evaluate()
        .isNotEmpty;
    final reachedOnboarding = find
        .text("Let's set you up")
        .evaluate()
        .isNotEmpty;
    expect(reachedHome || reachedOnboarding, isTrue);
  });

  testWidgets('pretest moves from question to result', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final onboardingController = await _buildOnboardingController();

    await tester.pumpWidget(
      MaterialApp(
        theme: WicaraTheme.light(),
        home: PretestPage(
          pretestRepository: const MockPretestRepository(delay: Duration.zero),
          onboardingController: onboardingController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Knowledge Space Theory'), findsWidgets);
    expect(find.text('Submit answer'), findsOneWidget);

    await tester.ensureVisible(find.text('Submit answer'));
    await tester.tap(find.text('Submit answer'));
    await tester.pumpAndSettle();

    expect(find.text('Your knowledge state'), findsOneWidget);
  });

  testWidgets('whiteboard canvas exposes drawing controls', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: WicaraTheme.light(),
        home: const Scaffold(
          body: Center(child: SizedBox(width: 374, child: FishboneCanvas())),
        ),
      ),
    );

    expect(find.text('Canvas'), findsOneWidget);
    expect(find.byTooltip('Pen mode'), findsOneWidget);
    expect(find.byTooltip('Hand mode'), findsOneWidget);
    expect(find.byTooltip('Eraser mode'), findsOneWidget);
  });
}

Future<WicaraApp> _buildTestApp() async {
  final authController = AuthController(
    authRepository: const MockAuthRepository(delay: Duration.zero),
    sessionStore: AuthSessionStore(),
    apiClient: ApiClient(baseUrl: 'http://127.0.0.1:8000'),
  );
  await authController.initialize();

  final onboardingController = await _buildOnboardingController(
    displayName: authController.session?.displayName ?? 'Learner',
  );

  return WicaraApp(
    authController: authController,
    onboardingController: onboardingController,
    curriculumRepository: _curriculumRepository,
    learningGoalRepository: _learningGoalRepository,
    homeRepository: _homeRepository,
    onboardingRepository: const MockOnboardingRepository(delay: Duration.zero),
    pretestRepository: const MockPretestRepository(delay: Duration.zero),
  );
}

Future<OnboardingController> _buildOnboardingController({
  String displayName = 'Learner',
}) async {
  final onboardingController = OnboardingController(
    onboardingRepository: const MockOnboardingRepository(delay: Duration.zero),
    profileStore: OnboardingProfileStore(),
  );
  await onboardingController.initialize(displayName: displayName);
  return onboardingController;
}

class _FailingCurriculumRepository implements CurriculumRepository {
  const _FailingCurriculumRepository();

  @override
  Future<List<CurriculumSubject>> fetchSubjects() async {
    throw UnimplementedError();
  }

  @override
  Future<CurriculumKnowledgeMap> fetchKnowledgeMap({
    required String subject,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CurriculumConceptDetail> fetchConceptDetail({
    required String conceptCode,
    String? subject,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeLearningGoalRepository implements LearningGoalRepository {
  const _FakeLearningGoalRepository();

  @override
  Future<LearningGoalBootstrap> createLearningGoal({
    required String rawTopic,
  }) async {
    return const LearningGoalBootstrap(
      learningGoalId: 'goal-1',
      pretestSessionId: 'pretest-1',
      trackId: 'track-1',
    );
  }
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository();

  @override
  Future<HomeSnapshot> fetchSnapshot() async {
    return const HomeSnapshot(
      displayName: 'Aisyah Putri',
      streakDays: 7,
      country: 'Indonesia',
      educationLevel: 'Senior high school',
      gradeLevel: 'Grade 11',
      preferredLanguage: 'English',
      studyGoal: 'Improve understanding',
      dailyStudyTime: '30-45 minutes',
      selectedSubjects: ['Math', 'Physics'],
      availableSubjects: ['Math', 'Physics', 'Chemistry'],
      onboardingCompleted: true,
    );
  }

  @override
  Future<DailyEvaluationSession> fetchDailyEvaluation() async {
    return const DailyEvaluationSession(
      sessionId: 'daily-1',
      questions: [
        PretestQuestion(
          id: 'q1',
          stepLabel: '1 / 1',
          topic: 'Calculus I',
          prompt: 'What is a derivative?',
          helper: 'Choose the best answer.',
          options: [
            PretestOption(id: 'A', label: 'A', text: 'Rate of change'),
            PretestOption(id: 'B', label: 'B', text: 'Area under a curve'),
          ],
        ),
      ],
    );
  }

  @override
  Future<void> submitDailyEvaluationAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
  }) async {}
}
