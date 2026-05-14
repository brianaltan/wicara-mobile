import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicara_mobile/src/app/app_routes.dart';
import 'package:wicara_mobile/src/app/wicara_app.dart';
import 'package:wicara_mobile/src/core/theme/wicara_theme.dart';
import 'package:wicara_mobile/src/features/auth/data/mock_auth_repository.dart';
import 'package:wicara_mobile/src/features/curriculum/domain/curriculum_models.dart';
import 'package:wicara_mobile/src/features/curriculum/domain/curriculum_repository.dart';
import 'package:wicara_mobile/src/features/home/domain/home_repository.dart';
import 'package:wicara_mobile/src/features/home/domain/home_snapshot.dart';
import 'package:wicara_mobile/src/features/learning_goal/domain/learning_goal_repository.dart';
import 'package:wicara_mobile/src/features/onboarding/data/mock_onboarding_repository.dart';
import 'package:wicara_mobile/src/features/pretest/domain/pretest_models.dart';
import 'package:wicara_mobile/src/features/pretest/presentation/widgets/fishbone_canvas.dart';
import 'package:wicara_mobile/src/features/pretest/data/mock_pretest_repository.dart';

const _curriculumRepository = _FailingCurriculumRepository();
const _learningGoalRepository = _FakeLearningGoalRepository();
const _homeRepository = _FakeHomeRepository();

void main() {
  testWidgets('landing page opens the sign in page', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const WicaraApp(
        authRepository: MockAuthRepository(delay: Duration.zero),
        curriculumRepository: _curriculumRepository,
        learningGoalRepository: _learningGoalRepository,
        homeRepository: _homeRepository,
        onboardingRepository: MockOnboardingRepository(delay: Duration.zero),
        pretestRepository: MockPretestRepository(delay: Duration.zero),
      ),
    );

    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
    expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
  });

  testWidgets('sign in opens the backend-backed home dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const WicaraApp(
        authRepository: MockAuthRepository(delay: Duration.zero),
        curriculumRepository: _curriculumRepository,
        learningGoalRepository: _learningGoalRepository,
        homeRepository: _homeRepository,
        onboardingRepository: MockOnboardingRepository(delay: Duration.zero),
        pretestRepository: MockPretestRepository(delay: Duration.zero),
        initialRoute: AppRoutes.signIn,
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'aisyah@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Log in').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.text("Today's learning queue"), findsOneWidget);
    expect(find.text('Take Daily Evaluation'), findsOneWidget);
  });

  testWidgets('pretest moves from question to reasoning and result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const WicaraApp(
        authRepository: MockAuthRepository(delay: Duration.zero),
        curriculumRepository: _curriculumRepository,
        learningGoalRepository: _learningGoalRepository,
        homeRepository: _homeRepository,
        onboardingRepository: MockOnboardingRepository(delay: Duration.zero),
        pretestRepository: MockPretestRepository(delay: Duration.zero),
        initialRoute: AppRoutes.learningGoal,
      ),
    );

    expect(find.text('What would you like to learn?'), findsOneWidget);
    expect(find.text('Generate Pretest'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Calculus I');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Generate Pretest'));
    await tester.tap(find.text('Generate Pretest'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Pretest generated complete!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('Knowledge Space Theory'), findsWidgets);
    expect(find.text('Submit answer'), findsOneWidget);

    await tester.ensureVisible(find.text('Submit answer'));
    await tester.tap(find.text('Submit answer'));
    await tester.pumpAndSettle();

    expect(find.text('Your knowledge state'), findsOneWidget);
    expect(find.text('Continue to my path'), findsOneWidget);

    await tester.ensureVisible(find.text('Continue to my path'));
    await tester.tap(find.text('Continue to my path'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.text("Today's learning queue"), findsOneWidget);
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
    expect(find.byTooltip('Shape helper'), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    expect(find.byTooltip('Hide grid'), findsOneWidget);
    expect(find.byTooltip('Clear canvas'), findsOneWidget);
    expect(find.byTooltip('Pen size 6.0'), findsOneWidget);
    expect(find.byTooltip('Pen color'), findsNWidgets(5));
    expect(find.text('Save work'), findsOneWidget);
    expect(find.text('Send to chat'), findsOneWidget);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();

    expect(find.text('125%'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide grid'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Show grid'), findsOneWidget);

    await tester.tap(find.byTooltip('Shape helper'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Line shape'), findsOneWidget);
    expect(find.byTooltip('Arrow shape'), findsOneWidget);
    expect(find.byTooltip('Rectangle shape'), findsOneWidget);

    await tester.tap(find.byTooltip('Rectangle shape'));
    await tester.pumpAndSettle();
    final canvasPaint = find.descendant(
      of: find.byType(FishboneCanvas),
      matching: find.byType(CustomPaint),
    );

    await tester.drag(canvasPaint.last, const Offset(64, 48));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hand mode'));
    await tester.pumpAndSettle();

    await tester.drag(canvasPaint.last, const Offset(24, 18));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pen mode'));
    await tester.tap(find.byTooltip('Pen size 6.0'));
    await tester.tap(find.byTooltip('Pen color').at(2));
    await tester.pumpAndSettle();

    await tester.drag(canvasPaint.last, const Offset(42, 32));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Eraser mode'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unsaved'), findsOneWidget);

    await tester.tap(find.text('Save work'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.text('Saved, ready to send'), findsOneWidget);

    await tester.tap(find.text('Send to chat'));
    await tester.pumpAndSettle();

    expect(find.text('Sent to chat'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear canvas'));
    await tester.pumpAndSettle();

    expect(find.text('Clear canvas?'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Clear canvas?'), findsNothing);
  });
}

class _FakeLearningGoalRepository implements LearningGoalRepository {
  const _FakeLearningGoalRepository();

  @override
  Future<LearningGoalBootstrap> createLearningGoal({
    required String rawTopic,
  }) async {
    return const LearningGoalBootstrap(
      learningGoalId: 'goal-widget-test',
      pretestSessionId: 'pretest-widget-test',
      trackId: 'track-widget-test',
    );
  }
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository();

  @override
  Future<HomeSnapshot> fetchSnapshot() async {
    return const HomeSnapshot(
      displayName: 'Aisha Rahman',
      country: 'Indonesia',
      educationLevel: 'Senior high school',
      gradeLevel: 'Grade 11',
      preferredLanguage: 'Bahasa Indonesia',
      studyGoal: 'Understand calculus foundations',
      dailyStudyTime: '30 minutes',
      selectedSubjects: ['Mathematics'],
      availableSubjects: ['Mathematics', 'Physics'],
      onboardingCompleted: true,
    );
  }

  @override
  Future<DailyEvaluationSession> fetchDailyEvaluation() async {
    return const DailyEvaluationSession(
      sessionId: 'daily-widget-test',
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
  Future<void> submitDailyEvaluationAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
  }) async {}
}

class _FailingCurriculumRepository implements CurriculumRepository {
  const _FailingCurriculumRepository();

  @override
  Future<CurriculumKnowledgeMap> fetchKnowledgeMap({required String subject}) {
    return Future.error(Exception('Use static fallback in widget tests.'));
  }

  @override
  Future<CurriculumConceptDetail> fetchConceptDetail({
    required String conceptCode,
    String? subject,
  }) {
    return Future.error(Exception('Use static fallback in widget tests.'));
  }

  @override
  Future<List<CurriculumSubject>> fetchSubjects() {
    return Future.error(Exception('Use static fallback in widget tests.'));
  }
}
