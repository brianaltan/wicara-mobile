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

  testWidgets('daily evaluation renders backend result payload', (
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
        initialRoute: AppRoutes.home,
      ),
    );
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
        const WicaraApp(
          authRepository: MockAuthRepository(delay: Duration.zero),
          curriculumRepository: _curriculumRepository,
          learningGoalRepository: _learningGoalRepository,
          homeRepository: _PrematureCompletedDailyRepository(),
          onboardingRepository: MockOnboardingRepository(delay: Duration.zero),
          pretestRepository: MockPretestRepository(delay: Duration.zero),
          initialRoute: AppRoutes.home,
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

  testWidgets('learning report detail renders backend payload', (tester) async {
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
        initialRoute: AppRoutes.home,
      ),
    );
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
