import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicara_mobile/src/app/app_routes.dart';
import 'package:wicara_mobile/src/core/theme/wicara_theme.dart';
import 'package:wicara_mobile/src/features/learning_goal/domain/learning_goal_repository.dart';
import 'package:wicara_mobile/src/features/learning_goal/presentation/learning_goal_page.dart';
import 'package:wicara_mobile/src/features/onboarding/application/onboarding_controller.dart';
import 'package:wicara_mobile/src/features/onboarding/data/mock_onboarding_repository.dart';
import 'package:wicara_mobile/src/features/onboarding/data/onboarding_profile_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('subject picker only offers the four goal subjects', (
    tester,
  ) async {
    final repository = _RecordingLearningGoalRepository();

    await _pumpLearningGoalPage(
      tester,
      repository: repository,
      selectedSubjects: const ['Science', 'IPAS', 'Math'],
    );

    expect(find.text('Math'), findsOneWidget);
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('Chemistry'), findsOneWidget);
    expect(find.text('Lock'), findsNWidgets(3));
    expect(find.text('Science'), findsNothing);
    expect(find.text('IPA'), findsNothing);
    expect(find.text('IPAS'), findsNothing);
  });

  testWidgets('recommended node confirms without resolving again', (
    tester,
  ) async {
    final repository = _RecordingLearningGoalRepository();

    await _pumpLearningGoalPage(tester, repository: repository);
    await tester.enterText(find.byType(TextField), 'multiplication');
    await tester.pump();

    await tester.tap(find.text('Find learning goal node'));
    await tester.pumpAndSettle();

    expect(repository.resolveCount, 1);
    expect(find.text('Perkalian'), findsOneWidget);
    expect(
      find.text('Understand multiplication as equal groups.'),
      findsOneWidget,
    );
    expect(find.textContaining('Kurikulum Merdeka'), findsNothing);
    expect(find.textContaining('Phase D'), findsNothing);
    expect(find.text('View detail'), findsOneWidget);
    expect(
      find.text('Foundational concept below your current grade.'),
      findsOneWidget,
    );
    expect(find.text('Find learning goal node'), findsNothing);
    expect(find.text('Edit prompt'), findsOneWidget);
    expect(find.text('See graph'), findsOneWidget);
    expect(find.text('Not what you want? Refine'), findsNothing);
    expect(find.text('math.multiplication'), findsNothing);
    expect(find.text('primary'), findsNothing);
    expect(find.text('91%'), findsNothing);

    await tester.tap(find.text('View detail'));
    await tester.pumpAndSettle();

    expect(find.text('Node detail'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Subject'), findsWidgets);
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('math.multiplication'), findsNothing);
    expect(find.text('primary'), findsNothing);
    expect(find.textContaining('Phase D'), findsNothing);

    Navigator.of(tester.element(find.text('Node detail'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perkalian'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure you want to take this?'), findsOneWidget);

    await tester.tap(find.text('Start pretest'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Pretest reached'), findsOneWidget);
    expect(repository.resolveCount, 1);
    expect(repository.selectCount, 0);
    expect(repository.confirmCount, 1);
  });

  testWidgets('active duplicate node shows warning before confirmation', (
    tester,
  ) async {
    final repository = _RecordingLearningGoalRepository(
      activeGoal: const ActiveLearningGoal(
        id: 'active-goal-1',
        status: 'confirmed',
        rawTopic: 'Perkalian',
        nextAction: 'start_pretest',
        targetConcept: _multiplicationConcept,
      ),
    );

    await _pumpLearningGoalPage(tester, repository: repository);

    expect(find.text('New goals need a different node'), findsOneWidget);
    expect(
      find.text(
        'You can create another goal as long as that node is not active.',
      ),
      findsWidgets,
    );
    expect(find.textContaining('Current active node'), findsNothing);

    await tester.enterText(find.byType(TextField), 'multiplication');
    await tester.pump();
    await tester.ensureVisible(find.text('Find learning goal node'));
    await tester.tap(find.text('Find learning goal node'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Perkalian'));
    await tester.tap(find.text('Perkalian'));
    await tester.pumpAndSettle();

    expect(find.text('This node is already active'), findsOneWidget);
    expect(
      find.text(
        'You can create another goal as long as that node is not active.',
      ),
      findsWidgets,
    );
    expect(find.text('Choose another node'), findsOneWidget);
    expect(repository.confirmCount, 0);
    expect(repository.selectCount, 0);
  });

  testWidgets(
    'alternative node confirms before selecting and opening pretest',
    (tester) async {
      final repository = _RecordingLearningGoalRepository(
        resolution: _resolutionWithAlternative,
      );

      await _pumpLearningGoalPage(tester, repository: repository);
      await tester.enterText(find.byType(TextField), 'division');
      await tester.pump();
      await tester.tap(find.text('Find learning goal node'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pembagian'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to take this?'), findsOneWidget);
      expect(repository.selectCount, 0);

      await tester.tap(find.text('Start pretest'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Pretest reached'), findsOneWidget);
      expect(repository.resolveCount, 1);
      expect(repository.selectCount, 1);
      expect(repository.confirmCount, 1);
      expect(repository.selectedConceptId, 'concept-division');
    },
  );

  testWidgets('Indonesian profile localizes subjects and node actions', (
    tester,
  ) async {
    final repository = _RecordingLearningGoalRepository(
      resolution: _indonesianFallbackResolution,
    );

    await _pumpLearningGoalPage(
      tester,
      repository: repository,
      preferredLanguage: 'Indonesian',
      selectedSubjects: const ['Fisika'],
    );

    expect(find.text('Matematika'), findsOneWidget);
    expect(find.text('Fisika'), findsOneWidget);
    expect(find.text('Biologi'), findsOneWidget);
    expect(find.text('Kimia'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'gaya');
    await tester.pump();
    await tester.tap(find.text('Cari node goal belajar'));
    await tester.pumpAndSettle();

    expect(repository.lastSubjectCode, 'math');
    expect(find.text('Lihat detail'), findsOneWidget);
    expect(find.text('Ubah prompt'), findsOneWidget);
    expect(find.text('Lihat graph'), findsOneWidget);
    expect(
      find.text(
        'Node ini akan dipakai sebagai goal utama untuk pretest adaptif.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Gaya'));
    await tester.pumpAndSettle();

    expect(find.text('Yakin ingin mengambil node ini?'), findsOneWidget);
    expect(find.text('Mulai pretest'), findsOneWidget);
  });
}

Future<void> _pumpLearningGoalPage(
  WidgetTester tester, {
  required _RecordingLearningGoalRepository repository,
  String preferredLanguage = 'English',
  List<String> selectedSubjects = const ['Math'],
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final onboardingController = OnboardingController(
    onboardingRepository: const MockOnboardingRepository(delay: Duration.zero),
    profileStore: OnboardingProfileStore(),
  );
  await onboardingController.initialize(displayName: 'Learner');
  await onboardingController.replaceProfile(
    onboardingController.profile.copyWith(
      educationLevel: 'senior_high',
      gradeLevel: '11',
      preferredLanguage: preferredLanguage,
      selectedSubjects: selectedSubjects,
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: WicaraTheme.light(),
      routes: {
        AppRoutes.pretest: (_) =>
            const Scaffold(body: Center(child: Text('Pretest reached'))),
        AppRoutes.home: (_) =>
            const Scaffold(body: Center(child: Text('Home reached'))),
      },
      home: LearningGoalPage(
        learningGoalRepository: repository,
        onboardingController: onboardingController,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecordingLearningGoalRepository implements LearningGoalRepository {
  _RecordingLearningGoalRepository({
    LearningGoalResolution? resolution,
    this.activeGoal,
  }) : resolution = resolution ?? _defaultResolution;

  final LearningGoalResolution resolution;
  final ActiveLearningGoal? activeGoal;
  int activeGoalFetchCount = 0;
  int resolveCount = 0;
  int confirmCount = 0;
  int selectCount = 0;
  String? lastSubjectCode;
  String? selectedConceptId;

  @override
  Future<ActiveLearningGoal?> fetchActiveGoal() async {
    activeGoalFetchCount += 1;
    return activeGoal;
  }

  @override
  Future<LearningGoalResolution> resolveLearningGoal({
    required String rawQuery,
    String? subjectCode,
    String? educationLevel,
    String? gradeLevel,
    String? language,
  }) async {
    resolveCount += 1;
    lastSubjectCode = subjectCode;
    return resolution;
  }

  @override
  Future<LearningGoalBootstrap> confirmResolvedGoal({
    required String resolutionId,
  }) async {
    confirmCount += 1;
    return const LearningGoalBootstrap(learningGoalId: 'goal-1');
  }

  @override
  Future<LearningGoalResolution> selectResolvedConcept({
    required String resolutionId,
    required String conceptId,
  }) async {
    selectCount += 1;
    selectedConceptId = conceptId;
    final selected = resolution.alternatives.firstWhere(
      (concept) => concept.conceptId == conceptId,
    );
    return LearningGoalResolution(
      resolutionId: resolution.resolutionId,
      status: 'needs_confirmation',
      confidence: selected.confidence ?? 0.99,
      suggestedConcept: selected,
      alternatives: [
        if (resolution.suggestedConcept != null) resolution.suggestedConcept!,
      ],
    );
  }

  @override
  Future<LearningGoalBootstrap> createLearningGoal({
    required String rawTopic,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<LearningGoalBootstrap> createLearningGoalFromConcept({
    String? conceptId,
    String? conceptCode,
    String? subjectCode,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelGoal({required String learningGoalId}) async {}
}

const _multiplicationConcept = LearningConceptSuggestion(
  conceptId: 'concept-multiplication',
  conceptCode: 'math.multiplication',
  title: 'Perkalian',
  subject: 'Mathematics',
  subjectCode: 'math',
  description:
      'Understand multiplication as equal groups aligned with Kurikulum Merdeka Phase D learning outcomes.',
  idDesc:
      'Memahami perkalian sebagai kelompok sama banyak sesuai Capaian Pembelajaran Kurikulum Merdeka Fase D.',
  enDesc:
      'Understand multiplication as equal groups aligned with Kurikulum Merdeka Phase D learning outcomes.',
  gradeBand: 'primary',
  gradeRelation: 'below_current_level',
  levelNote: 'Foundational concept below your current grade.',
  confidence: 0.91,
);

const _divisionConcept = LearningConceptSuggestion(
  conceptId: 'concept-division',
  conceptCode: 'math.division',
  title: 'Pembagian',
  subject: 'Mathematics',
  subjectCode: 'math',
  description: 'Understand division as sharing into equal groups.',
  idDesc: 'Memahami pembagian sebagai berbagi sama banyak.',
  enDesc: 'Understand division as sharing into equal groups.',
  gradeBand: 'primary',
  confidence: 0.86,
);

const _physicsConceptWithoutDescription = LearningConceptSuggestion(
  conceptId: 'concept-force',
  conceptCode: 'physics.force',
  title: 'Gaya',
  subject: 'Physics',
  subjectCode: 'physics',
  confidence: 0.92,
);

const _defaultResolution = LearningGoalResolution(
  resolutionId: 'resolution-1',
  status: 'needs_confirmation',
  confidence: 0.91,
  suggestedConcept: _multiplicationConcept,
);

const _resolutionWithAlternative = LearningGoalResolution(
  resolutionId: 'resolution-2',
  status: 'needs_confirmation',
  confidence: 0.91,
  suggestedConcept: _multiplicationConcept,
  alternatives: [_divisionConcept],
);

const _indonesianFallbackResolution = LearningGoalResolution(
  resolutionId: 'resolution-3',
  status: 'needs_confirmation',
  confidence: 0.92,
  suggestedConcept: _physicsConceptWithoutDescription,
);
