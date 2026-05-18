import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicara_mobile/src/app/wicara_app.dart';
import 'package:wicara_mobile/src/core/network/api_client.dart';
import 'package:wicara_mobile/src/core/theme/wicara_theme.dart';
import 'package:wicara_mobile/src/features/auth/application/auth_controller.dart';
import 'package:wicara_mobile/src/features/auth/data/auth_session_store.dart';
import 'package:wicara_mobile/src/features/auth/data/mock_auth_repository.dart';
import 'package:wicara_mobile/src/features/auth/domain/auth_repository.dart';
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
import 'package:wicara_mobile/src/features/workspace/domain/workspace_models.dart';
import 'package:wicara_mobile/src/features/workspace/domain/workspace_repository.dart';

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

  testWidgets('daily evaluation renders backend result payload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildSignedInTestApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Take Daily Evaluation'));
    await tester.tap(find.text('Take Daily Evaluation'));
    await tester.pumpAndSettle();

    expect(find.text('Review due'), findsOneWidget);
    expect(find.text('1 item ready for review'), findsOneWidget);
    expect(find.text('Your retention forecast'), findsOneWidget);

    await tester.ensureVisible(find.text('Review it briefly'));
    await tester.tap(find.text('Review it briefly'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Finish evaluation'));
    await tester.tap(find.text('Finish evaluation'));
    await tester.pumpAndSettle();

    expect(find.text('Evaluation Complete'), findsWidgets);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Spaced Review'), findsOneWidget);
    expect(find.text('Recommended next actions'), findsOneWidget);

    await tester.ensureVisible(find.text('Review: Spaced Review'));
    await tester.tap(find.text('Review: Spaced Review'));
    await tester.pumpAndSettle();

    expect(find.text('Review due'), findsOneWidget);
  });

  testWidgets(
    'daily evaluation keeps advancing when backend completed flag is early',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        await _buildSignedInTestApp(
          homeRepository: const _PrematureCompletedDailyRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Take Daily Evaluation'));
      await tester.tap(find.text('Take Daily Evaluation'));
      await tester.pumpAndSettle();

      expect(find.text('First review concept'), findsOneWidget);
      await tester.ensureVisible(find.text('Answer first review'));
      await tester.tap(find.text('Answer first review'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next question'));
      await tester.tap(find.text('Next question'));
      await tester.pumpAndSettle();

      expect(find.text('Second review concept'), findsOneWidget);
      expect(find.text('Evaluation Complete'), findsNothing);
    },
  );

  testWidgets('workspace completion opens hardcoded multiplication posttest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      await _buildSignedInTestApp(
        homeRepository: const _WorkspaceReadyHomeRepository(),
        workspaceRepository: const _FakeWorkspaceRepository(),
        educationLevel: 'elementary',
        gradeLevel: '4',
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continue session'));
    await tester.tap(find.text('Continue session'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Long explanation'));
    await tester.tap(find.text('Long explanation'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('12'));
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mulai Posttest'));
    await tester.tap(find.text('Mulai Posttest'));
    await tester.pumpAndSettle();

    expect(find.text('Posttest Perkalian'), findsWidgets);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('auth.lastProtectedRoute'), '/home');

    for (final answer in const [
      '28',
      '54',
      '7 + 7 + 7',
      '26',
      '48',
      '42',
      '6 x 7',
      '32',
      '24',
      '40',
    ]) {
      await tester.ensureVisible(find.text(answer));
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle();
      final isLastAnswer = answer == '40';
      await tester.ensureVisible(
        find.text(isLastAnswer ? 'Selesai posttest' : 'Lanjut'),
      );
      await tester.tap(find.text(isLastAnswer ? 'Selesai posttest' : 'Lanjut'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Evaluation Complete'), findsWidgets);
    expect(
      find.text('Posttest: 10 jawaban benar dari 10 soal.'),
      findsOneWidget,
    );
    expect(find.text('100%'), findsOneWidget);

    await tester.ensureVisible(find.text('Kembali ke Home'));
    await tester.tap(find.text('Kembali ke Home'));
    await tester.pumpAndSettle();

    expect(find.text('Evaluation Complete'), findsNothing);
    expect(find.text('Continue session'), findsOneWidget);
    expect(preferences.getString('auth.lastProtectedRoute'), '/home');
  });

  testWidgets('learning report detail renders backend payload', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildSignedInTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final thisWeek = _reportRangeForTest('thisWeek', now);
    final lastWeek = _reportRangeForTest('lastWeek', now);

    expect(find.text(_reportRangeLabelForTest(thisWeek)), findsOneWidget);
    expect(find.text('May 12 - May 18, 2025'), findsNothing);

    await tester.tap(find.text('Learning Report'));
    await tester.pumpAndSettle();

    expect(find.text(_reportRangeLabelForTest(thisWeek)), findsOneWidget);
    expect(find.text('Learning performance'), findsOneWidget);
    expect(find.text('Unlocked this week'), findsOneWidget);
    expect(find.text('Upcoming recommendations'), findsOneWidget);
    expect(find.text('Consistency is compounding.'), findsOneWidget);

    await tester.tap(find.text(_reportRangeLabelForTest(thisWeek)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last week'));
    await tester.pumpAndSettle();

    expect(find.text(_reportRangeLabelForTest(lastWeek)), findsOneWidget);
  });

  testWidgets('pretest moves from question to result', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final onboardingController = await _buildOnboardingController(
      educationLevel: 'elementary',
      gradeLevel: '4',
    );

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

    expect(find.text('Perkalian'), findsWidgets);
    expect(find.text('Lanjut'), findsOneWidget);

    await tester.ensureVisible(find.text('12'));
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lanjut'));
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Help us understand your thinking'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '4 groups of 3 is 12');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(find.text('22'), findsOneWidget);

    await tester.ensureVisible(find.text('22'));
    await tester.tap(find.text('22'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lanjut'));
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      '6 x 4 is 24, minus 2 is 22',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Your knowledge state'), findsOneWidget);
    expect(
      find.text('Kamu sudah siap di Perkalian; cukup review singkat.'),
      findsOneWidget,
    );
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

Future<WicaraApp> _buildSignedInTestApp({
  HomeRepository homeRepository = _homeRepository,
  WorkspaceRepository? workspaceRepository,
  String educationLevel = 'senior_high',
  String gradeLevel = '11',
}) async {
  final authController = AuthController(
    authRepository: const MockAuthRepository(delay: Duration.zero),
    sessionStore: AuthSessionStore(),
    apiClient: ApiClient(baseUrl: 'http://127.0.0.1:8000'),
  );
  await authController.initialize();
  await authController.startDevelopmentSession(
    role: AuthRole.learner,
    displayName: 'Aisyah Putri',
    onboardingCompleted: true,
  );

  final onboardingController = await _buildOnboardingController(
    displayName: authController.session?.displayName ?? 'Learner',
    educationLevel: educationLevel,
    gradeLevel: gradeLevel,
  );

  return WicaraApp(
    authController: authController,
    onboardingController: onboardingController,
    curriculumRepository: _curriculumRepository,
    learningGoalRepository: _learningGoalRepository,
    homeRepository: homeRepository,
    onboardingRepository: const MockOnboardingRepository(delay: Duration.zero),
    pretestRepository: const MockPretestRepository(delay: Duration.zero),
    workspaceRepository: workspaceRepository,
  );
}

Future<OnboardingController> _buildOnboardingController({
  String displayName = 'Learner',
  String educationLevel = 'senior_high',
  String gradeLevel = '11',
}) async {
  final onboardingController = OnboardingController(
    onboardingRepository: const MockOnboardingRepository(delay: Duration.zero),
    profileStore: OnboardingProfileStore(),
  );
  await onboardingController.initialize(displayName: displayName);
  await onboardingController.replaceProfile(
    onboardingController.profile.copyWith(
      educationLevel: educationLevel,
      gradeLevel: gradeLevel,
    ),
  );
  return onboardingController;
}

class _FailingCurriculumRepository implements CurriculumRepository {
  const _FailingCurriculumRepository();

  @override
  Future<List<CurriculumSubject>> fetchSubjects({String locale = 'id'}) async {
    throw UnimplementedError();
  }

  @override
  Future<CurriculumKnowledgeMap> fetchKnowledgeMap({
    required String subject,
    String locale = 'id',
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CurriculumConceptDetail> fetchConceptDetail({
    required String conceptCode,
    String? subject,
    String locale = 'id',
  }) async {
    throw UnimplementedError();
  }
}

class _FakeLearningGoalRepository implements LearningGoalRepository {
  const _FakeLearningGoalRepository();

  @override
  Future<ActiveLearningGoal?> fetchActiveGoal() async => null;

  @override
  Future<LearningGoalResolution> resolveLearningGoal({
    required String rawQuery,
    String? subjectCode,
    String? educationLevel,
    String? gradeLevel,
    String? language,
  }) async {
    return const LearningGoalResolution(
      resolutionId: 'resolution-1',
      status: 'needs_confirmation',
      confidence: 0.91,
      suggestedConcept: LearningConceptSuggestion(
        conceptId: 'concept-1',
        conceptCode: 'math.multiplication',
        title: 'Perkalian',
        subject: 'Matematika',
        description: 'Memahami perkalian sebagai kelompok sama banyak.',
        subjectCode: 'math',
        gradeBand: 'primary',
        gradeRelation: 'below_current_level',
        levelNote:
            'This is a foundational concept below your current grade. It is still useful for review or prerequisite repair.',
        confidence: 0.91,
      ),
      clarificationQuestion: 'Benar kamu mau belajar Perkalian?',
    );
  }

  @override
  Future<LearningGoalBootstrap> confirmResolvedGoal({
    required String resolutionId,
  }) async {
    return const LearningGoalBootstrap(learningGoalId: 'goal-1');
  }

  @override
  Future<LearningGoalResolution> selectResolvedConcept({
    required String resolutionId,
    required String conceptId,
  }) async {
    return resolveLearningGoal(rawQuery: 'Perkalian');
  }

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

  @override
  Future<List<LearningConceptSuggestion>> searchMaterials({
    required String query,
    String? subjectCode,
  }) async {
    return const [
      LearningConceptSuggestion(
        conceptId: 'concept-1',
        conceptCode: 'math.multiplication',
        title: 'Perkalian',
        subject: 'Matematika',
        description: 'Memahami perkalian sebagai kelompok sama banyak.',
        subjectCode: 'math',
        gradeBand: 'primary',
      ),
    ];
  }

  @override
  Future<void> cancelGoal({required String learningGoalId}) async {}
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
      sessionId: 'daily-widget-test',
      title: 'Daily Evaluation',
      language: 'en',
      reviewDue: ReviewDueSummary(
        dueCount: 1,
        summary: '1 item ready for review',
      ),
      progress: DailyEvaluationProgress(
        current: 1,
        total: 1,
        completed: 0,
        label: '1 of 1',
      ),
      questions: [
        PretestQuestion(
          id: 'daily-question-widget-test',
          stepLabel: 'Daily Evals',
          topic: 'Spaced Review',
          prompt: 'What should happen when a concept is due for review?',
          helper: 'Pick the retention-focused action.',
          options: [
            PretestOption(id: 'A', label: 'A', text: 'Review it briefly'),
            PretestOption(id: 'B', label: 'B', text: 'Delete the concept'),
          ],
        ),
      ],
    );
  }

  @override
  Future<DailyEvaluationAnswerResult> submitDailyEvaluationAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
  }) async {
    return const DailyEvaluationAnswerResult(
      attemptId: 'attempt-widget-test',
      isCorrect: true,
      nextReviewLabel: 'Review in 3 days',
      masteryDelta: 0.08,
      sessionStatus: 'completed',
      completed: true,
    );
  }

  @override
  Future<DailyEvaluationResult> fetchDailyEvaluationResult({
    required String sessionId,
  }) async {
    return const DailyEvaluationResult(
      sessionId: 'daily-widget-test',
      title: 'Daily Evaluation',
      status: 'completed',
      source: 'widget_test',
      scorePercent: 100,
      reviewedCount: 1,
      correctCount: 1,
      reviewAgainCount: 0,
      reviewedConcepts: [
        ReviewedConcept(
          title: 'Spaced Review',
          statusLabel: 'Strong',
          masteryScore: 0.9,
        ),
      ],
      spacedRepetitionImpact: SpacedRepetitionImpact(
        retentionLiftPercent: 17,
        daysUntilNextReview: 7,
        summary: 'Memory strengthened.',
      ),
      nextReview: DailyEvaluationNextReview(
        label: 'Review in 7 days',
        dueDate: '2026-05-21',
        intervalDays: 7,
      ),
      recommendedNextActions: [
        RecommendedNextAction(
          title: 'Review: Spaced Review',
          actionType: 'review',
          reason: 'Focus on high-impact memory reinforcement.',
        ),
        RecommendedNextAction(
          title: 'Continue learning',
          actionType: 'continue_learning',
          reason: 'Go to your learning path.',
        ),
      ],
      backToHome: ActionTarget(
        label: 'Back to Home',
        actionType: 'navigate',
        target: '/home',
      ),
    );
  }

  @override
  Future<DailyEvaluationSession> startPosttest({
    String? learningGoalId,
    String? trackId,
  }) async {
    return const DailyEvaluationSession(
      sessionId: 'posttest-perkalian-widget-test',
      title: 'Posttest Perkalian',
      language: 'id',
      reviewDue: ReviewDueSummary(
        title: 'Posttest siap',
        dueCount: 10,
        summary: '10 soal untuk validasi mastery perkalian.',
        actionLabel: 'Mulai',
      ),
      progress: DailyEvaluationProgress(
        current: 1,
        total: 10,
        completed: 0,
        label: '1 of 10',
      ),
      questions: [
        PretestQuestion(
          id: 'posttest-1',
          stepLabel: 'Posttest',
          topic: 'Perkalian',
          prompt: '7 x 4 = ?',
          helper: 'Pilih hasil perkalian.',
          options: [
            PretestOption(id: 'A', label: 'A', text: '28'),
            PretestOption(id: 'B', label: 'B', text: '24'),
          ],
        ),
        PretestQuestion(
          id: 'posttest-2',
          stepLabel: 'Posttest',
          topic: 'Perkalian',
          prompt: '6 x 9 = ?',
          helper: 'Pilih hasil perkalian.',
          options: [
            PretestOption(id: 'A', label: 'A', text: '54'),
            PretestOption(id: 'B', label: 'B', text: '45'),
          ],
        ),
        PretestQuestion(
          id: 'posttest-3',
          stepLabel: 'Posttest',
          topic: 'Perkalian',
          prompt: 'Mana bentuk penjumlahan berulang untuk 3 x 7?',
          helper: 'Pilih bentuk yang setara.',
          options: [
            PretestOption(id: 'A', label: 'A', text: '7 + 7 + 7'),
            PretestOption(id: 'B', label: 'B', text: '3 + 3 + 3'),
          ],
        ),
        PretestQuestion(
          id: 'posttest-4',
          stepLabel: 'Posttest',
          topic: 'Perkalian',
          prompt: '13 x 2 = ?',
          helper: 'Pilih hasil perkalian.',
          options: [
            PretestOption(id: 'A', label: 'A', text: '26'),
            PretestOption(id: 'B', label: 'B', text: '24'),
          ],
        ),
        PretestQuestion(
          id: 'posttest-5',
          stepLabel: 'Posttest',
          topic: 'Perkalian',
          prompt: '6 x 8 = ?',
          helper: 'Pilih hasil perkalian.',
          options: [
            PretestOption(id: 'A', label: 'A', text: '48'),
            PretestOption(id: 'B', label: 'B', text: '42'),
          ],
        ),
        PretestQuestion(
          id: 'posttest-6',
          stepLabel: 'Posttest',
          topic: 'Perkalian',
          prompt: '7 x 6 = ?',
          helper: 'Pilih hasil perkalian.',
          options: [
            PretestOption(id: 'A', label: 'A', text: '42'),
            PretestOption(id: 'B', label: 'B', text: '36'),
          ],
        ),
        PretestQuestion(
          id: 'posttest-7',
          stepLabel: 'Posttest',
          topic: 'Perkalian',
          prompt: 'Mana bentuk perkalian dari 6 kelompok berisi 7?',
          helper: 'Pilih bentuk perkalian.',
          options: [
            PretestOption(id: 'A', label: 'A', text: '6 x 7'),
            PretestOption(id: 'B', label: 'B', text: '6 + 7'),
          ],
        ),
        PretestQuestion(
          id: 'posttest-8',
          stepLabel: 'Posttest',
          topic: 'Perkalian',
          prompt: '4 x 8 = ?',
          helper: 'Pilih hasil perkalian.',
          options: [
            PretestOption(id: 'A', label: 'A', text: '32'),
            PretestOption(id: 'B', label: 'B', text: '28'),
          ],
        ),
        PretestQuestion(
          id: 'posttest-9',
          stepLabel: 'Posttest',
          topic: 'Perkalian',
          prompt: '6 x 4 = ?',
          helper: 'Pilih hasil perkalian.',
          options: [
            PretestOption(id: 'A', label: 'A', text: '24'),
            PretestOption(id: 'B', label: 'B', text: '20'),
          ],
        ),
        PretestQuestion(
          id: 'posttest-10',
          stepLabel: 'Posttest',
          topic: 'Perkalian',
          prompt: '5 x 8 = ?',
          helper: 'Pilih hasil perkalian.',
          options: [
            PretestOption(id: 'A', label: 'A', text: '40'),
            PretestOption(id: 'B', label: 'B', text: '45'),
          ],
        ),
      ],
    );
  }

  @override
  Future<DailyEvaluationAnswerResult> submitPosttestAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
  }) async {
    return DailyEvaluationAnswerResult(
      attemptId: 'attempt-$questionId',
      isCorrect: true,
      nextReviewLabel: '',
      masteryDelta: 0,
      sessionStatus: questionId == 'posttest-10' ? 'completed' : 'active',
      completed: questionId == 'posttest-10',
    );
  }

  @override
  Future<DailyEvaluationResult> finalizePosttest({
    required String sessionId,
  }) async {
    return const DailyEvaluationResult(
      sessionId: 'posttest-perkalian-widget-test',
      title: 'Posttest Perkalian',
      status: 'completed',
      source: 'widget_test',
      scorePercent: 100,
      reviewedCount: 10,
      correctCount: 10,
      reviewAgainCount: 0,
      reviewedConcepts: [
        ReviewedConcept(
          title: 'Perkalian',
          statusLabel: 'Strong',
          masteryScore: 1,
        ),
      ],
      spacedRepetitionImpact: SpacedRepetitionImpact(
        retentionLiftPercent: 100,
        daysUntilNextReview: 7,
        summary: 'Posttest: 10 jawaban benar dari 10 soal.',
      ),
      nextReview: DailyEvaluationNextReview(
        label: 'Review ringan',
        dueDate: '',
        intervalDays: 7,
      ),
      recommendedNextActions: [
        RecommendedNextAction(
          title: 'Lanjut materi berikutnya',
          actionType: 'continue_learning',
          reason: 'Semua soal posttest lulus.',
        ),
      ],
      backToHome: ActionTarget(
        label: 'Kembali ke Home',
        actionType: 'navigate',
        target: '/home',
      ),
    );
  }

  @override
  Future<WeeklyLearningReport> fetchWeeklyLearningReport({
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveStart = start ?? DateTime(2025, 5, 12);
    final effectiveEnd = end ?? DateTime(2025, 5, 18);
    return WeeklyLearningReport(
      rangeLabel: _reportRangeLabelForTest(
        _TestDateRange(start: effectiveStart, end: effectiveEnd),
      ),
      rangeStart: _dateOnlyForTest(effectiveStart),
      rangeEnd: _dateOnlyForTest(effectiveEnd),
      status: 'complete',
      source: 'widget_test',
      score: 88,
      fixedGaps: 12,
      fixedGapsDelta: 4,
      remainingGaps: 5,
      remainingGapsDelta: -2,
      retentionMinutes: 23,
      concepts: 'Spaced review',
      summaryNotes: ['Widget test summary'],
      performanceGroups: [
        ReportPerformanceGroup(
          label: 'Overall',
          preTestPercent: 72,
          postTestPercent: 86,
        ),
        ReportPerformanceGroup(
          label: 'Application',
          preTestPercent: 65,
          postTestPercent: 85,
        ),
        ReportPerformanceGroup(
          label: 'Analysis',
          preTestPercent: 58,
          postTestPercent: 82,
        ),
      ],
      gapMetrics: {
        'fixed': GapMetric(
          count: 12,
          weeklyDelta: 4,
          deltaLabel: '+4 this week',
        ),
        'remaining': GapMetric(
          count: 5,
          weeklyDelta: -2,
          deltaLabel: '-2 this week',
        ),
      },
      unlockedThisWeek: UnlockedConceptSummary(
        count: 8,
        concepts: ['Spaced review', 'Opportunity cost'],
      ),
      upcomingRecommendations: [
        RecommendedNextAction(
          title: 'Review: Spaced Review',
          actionType: 'review',
          reason: 'Due in 2 days',
          dueLabel: 'Due in 2 days',
        ),
      ],
      consistencySummary: ConsistencySummary(
        title: 'Consistency is compounding.',
        narrative: 'Keep it up.',
        signal: 'widget_test',
      ),
    );
  }
}

class _WorkspaceReadyHomeRepository extends _FakeHomeRepository {
  const _WorkspaceReadyHomeRepository();

  @override
  Future<HomeSnapshot> fetchSnapshot() async {
    return const HomeSnapshot(
      displayName: 'Aisyah Putri',
      streakDays: 7,
      country: 'Indonesia',
      educationLevel: 'Elementary school',
      gradeLevel: 'Grade 4',
      preferredLanguage: 'English',
      studyGoal: 'Improve understanding',
      dailyStudyTime: '30-45 minutes',
      selectedSubjects: ['Math'],
      availableSubjects: ['Math', 'Physics', 'Chemistry'],
      onboardingCompleted: true,
      nextQueueItem: LearningQueueItem(
        id: 'queue-perkalian',
        trackId: 'track-perkalian',
        moduleId: 'module-perkalian',
        title: 'Perkalian',
        subtitle: 'Latihan perkalian untuk SD',
        status: 'ready',
      ),
    );
  }
}

class _FakeWorkspaceRepository implements WorkspaceRepository {
  const _FakeWorkspaceRepository();

  @override
  Future<WorkspaceSession> createOrResumeWorkspace({
    required String trackId,
    required String moduleId,
    String? workspaceSessionId,
    bool startNewSession = false,
  }) async {
    return WorkspaceSession(
      id: 'workspace-perkalian',
      trackId: trackId,
      moduleId: moduleId,
      currentTopic: 'Perkalian',
      contentMode: 'chat',
      status: 'active',
      events: const [],
    );
  }

  @override
  WorkspaceSessionHistory sessionHistory({
    required String trackId,
    required String moduleId,
  }) {
    return const WorkspaceSessionHistory(
      activeWorkspaceId: 'workspace-perkalian',
      workspaceIds: ['workspace-perkalian'],
    );
  }

  @override
  Future<void> setActiveSession({
    required String trackId,
    required String moduleId,
    required String workspaceId,
  }) async {}

  @override
  Future<List<WorkspaceSessionSummary>> fetchSessionHistory({
    required String trackId,
    required String moduleId,
  }) async {
    return const [
      WorkspaceSessionSummary(
        id: 'workspace-perkalian',
        trackId: 'track-perkalian',
        moduleId: 'module-perkalian',
        title: 'Perkalian',
        preview: 'Latihan perkalian',
        messageCount: 1,
        createdAt: '2026-05-18T00:00:00Z',
        updatedAt: '2026-05-18T00:00:00Z',
      ),
    ];
  }

  @override
  Future<WorkspaceSession> fetchWorkspace(String workspaceId) async {
    return const WorkspaceSession(
      id: 'workspace-perkalian',
      trackId: 'track-perkalian',
      moduleId: 'module-perkalian',
      currentTopic: 'Perkalian',
      contentMode: 'chat',
      status: 'active',
      events: [],
    );
  }

  @override
  Future<WorkspaceAppendResult> appendEvent({
    required String workspaceId,
    required String eventType,
    String textPayload = '',
    Map<String, dynamic> metadata = const {},
  }) async {
    final event = WorkspaceEvent(
      id: 'event-$eventType',
      workspaceId: workspaceId,
      eventIndex: 1,
      eventType: eventType,
      actorType: 'learner',
      textPayload: textPayload,
      metadata: metadata,
    );
    return WorkspaceAppendResult(
      event: event,
      workspace: WorkspaceSession(
        id: workspaceId,
        trackId: 'track-perkalian',
        moduleId: 'module-perkalian',
        currentTopic: 'Perkalian',
        contentMode: 'chat',
        status: 'active',
        events: [event],
      ),
    );
  }

  @override
  Future<WorkspaceGenerateVideoResult> generateVideo({
    required String workspaceId,
    String generationMode = 'context_auto',
    String? templateId,
    Map<String, dynamic>? specJson,
    String language = 'id',
    String qualityProfile = 'standard',
    String? conceptId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final event = WorkspaceEvent(
      id: 'event-video',
      workspaceId: workspaceId,
      eventIndex: 2,
      eventType: 'generate_video',
      actorType: 'system',
      textPayload: '',
      metadata: metadata,
    );
    final workspace = WorkspaceSession(
      id: workspaceId,
      trackId: 'track-perkalian',
      moduleId: 'module-perkalian',
      currentTopic: 'Perkalian',
      contentMode: 'chat',
      status: 'active',
      events: [event],
    );
    return WorkspaceGenerateVideoResult(
      queue: const WorkspaceAnimationQueue(
        jobId: 'job-video',
        artifactId: 'artifact-video',
        status: 'ready',
      ),
      event: event,
      workspace: workspace,
    );
  }

  @override
  Future<WorkspaceAnimationJobStatus> getAnimationStatus({
    required String jobId,
  }) async {
    return WorkspaceAnimationJobStatus(
      jobId: jobId,
      status: 'ready',
      progress: 100,
      message: 'Ready',
      artifactId: 'artifact-video',
    );
  }

  @override
  Future<void> updateModuleState({
    required String trackId,
    required String moduleId,
    required String status,
  }) async {}
}

class _PrematureCompletedDailyRepository extends _FakeHomeRepository {
  const _PrematureCompletedDailyRepository();

  @override
  Future<DailyEvaluationSession> fetchDailyEvaluation() async {
    return const DailyEvaluationSession(
      sessionId: 'daily-premature-completed-test',
      title: 'Daily Evaluation',
      language: 'en',
      reviewDue: ReviewDueSummary(
        dueCount: 3,
        summary: '3 items ready for review',
      ),
      progress: DailyEvaluationProgress(
        current: 1,
        total: 3,
        completed: 0,
        label: '1 of 3',
      ),
      questions: [
        PretestQuestion(
          id: 'daily-question-one',
          stepLabel: 'Daily Evals',
          topic: 'First review concept',
          prompt: 'What is the first review action?',
          helper: 'First helper',
          options: [
            PretestOption(id: 'A', label: 'A', text: 'Answer first review'),
            PretestOption(id: 'B', label: 'B', text: 'Skip first review'),
          ],
        ),
        PretestQuestion(
          id: 'daily-question-two',
          stepLabel: 'Daily Evals',
          topic: 'Second review concept',
          prompt: 'What is the second review action?',
          helper: 'Second helper',
          options: [
            PretestOption(id: 'A', label: 'A', text: 'Answer second review'),
            PretestOption(id: 'B', label: 'B', text: 'Skip second review'),
          ],
        ),
        PretestQuestion(
          id: 'daily-question-three',
          stepLabel: 'Daily Evals',
          topic: 'Third review concept',
          prompt: 'What is the third review action?',
          helper: 'Third helper',
          options: [
            PretestOption(id: 'A', label: 'A', text: 'Answer third review'),
            PretestOption(id: 'B', label: 'B', text: 'Skip third review'),
          ],
        ),
      ],
    );
  }

  @override
  Future<DailyEvaluationAnswerResult> submitDailyEvaluationAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
  }) async {
    return const DailyEvaluationAnswerResult(
      attemptId: 'premature-attempt-widget-test',
      isCorrect: true,
      nextReviewLabel: 'Review in 3 days',
      masteryDelta: 0.08,
      sessionStatus: 'completed',
      completed: true,
    );
  }
}

class _TestDateRange {
  const _TestDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

_TestDateRange _reportRangeForTest(String option, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final thisMonday = today.subtract(Duration(days: today.weekday - 1));
  if (option == 'lastWeek') {
    return _TestDateRange(
      start: thisMonday.subtract(const Duration(days: 7)),
      end: thisMonday.subtract(const Duration(days: 1)),
    );
  }
  return _TestDateRange(
    start: thisMonday,
    end: thisMonday.add(const Duration(days: 6)),
  );
}

String _reportRangeLabelForTest(_TestDateRange range) {
  return '${_dateOnlyForTest(range.start)} - ${_dateOnlyForTest(range.end)}';
}

String _dateOnlyForTest(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
