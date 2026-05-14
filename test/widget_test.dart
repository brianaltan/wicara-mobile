import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicara_mobile/src/app/wicara_app.dart';
import 'package:wicara_mobile/src/core/theme/wicara_theme.dart';
import 'package:wicara_mobile/src/features/auth/data/mock_auth_repository.dart';
import 'package:wicara_mobile/src/features/curriculum/domain/curriculum_models.dart';
import 'package:wicara_mobile/src/features/curriculum/domain/curriculum_repository.dart';
import 'package:wicara_mobile/src/features/onboarding/data/mock_onboarding_repository.dart';
import 'package:wicara_mobile/src/features/pretest/presentation/widgets/fishbone_canvas.dart';
import 'package:wicara_mobile/src/features/pretest/data/mock_pretest_repository.dart';

const _curriculumRepository = _FailingCurriculumRepository();

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
        onboardingRepository: MockOnboardingRepository(delay: Duration.zero),
        pretestRepository: MockPretestRepository(delay: Duration.zero),
      ),
    );

    expect(
      find.text('Prerequisite-first AI tutor\nfor ASEAN learners'),
      findsOneWidget,
    );
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
  });

  testWidgets('sign in opens onboarding and advances through setup', (
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
        onboardingRepository: MockOnboardingRepository(delay: Duration.zero),
        pretestRepository: MockPretestRepository(delay: Duration.zero),
      ),
    );

    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'aisyah@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text("Let's set you up"), findsOneWidget);
    expect(find.text('Aisyah Putri'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your subjects'), findsOneWidget);
    expect(find.text('Math'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('How would you like to learn?'), findsOneWidget);
    expect(find.text('Continue to adaptive pretest'), findsOneWidget);
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
        onboardingRepository: MockOnboardingRepository(delay: Duration.zero),
        pretestRepository: MockPretestRepository(delay: Duration.zero),
      ),
    );

    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'aisyah@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to adaptive pretest'));
    await tester.pumpAndSettle();

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

    expect(find.text('Help us understand your thinking'), findsOneWidget);
    expect(find.text('Use canvas'), findsOneWidget);

    await tester.ensureVisible(find.text('Use canvas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use canvas'));
    await tester.pumpAndSettle();

    expect(find.text('Canvas workspace'), findsOneWidget);

    final canvasPaint = find.descendant(
      of: find.byType(FishboneCanvas),
      matching: find.byType(CustomPaint),
    );

    await tester.drag(canvasPaint.last, const Offset(56, 38));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save work'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send to chat'));
    await tester.pumpAndSettle();

    expect(find.text('Sent to chat'), findsOneWidget);

    await tester.tap(find.byTooltip('Close panel'));
    await tester.pumpAndSettle();

    expect(find.text('Canvas work v1'), findsOneWidget);
    expect(find.byType(CanvasWorkPreview), findsOneWidget);

    await tester.ensureVisible(find.byIcon(Icons.arrow_upward_rounded));
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Your knowledge state'), findsOneWidget);
    expect(find.text('Continue to my path'), findsOneWidget);

    await tester.ensureVisible(find.text('Continue to my path'));
    await tester.tap(find.text('Continue to my path'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Aisha 👋'), findsOneWidget);
    expect(find.text("Today's learning queue"), findsOneWidget);

    await tester.ensureVisible(find.text('Continue session'));
    await tester.tap(find.text('Continue session'));
    await tester.pumpAndSettle();

    expect(find.text('Workspace Modules'), findsOneWidget);
    expect(find.text('Generate video'), findsOneWidget);
    expect(find.byType(FishboneCanvas), findsOneWidget);

    await tester.tap(find.text('Generate video'));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('Saved generated video'), findsOneWidget);
    expect(find.text('Sudden check'), findsOneWidget);

    await tester.ensureVisible(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    expect(find.text('Calculus I'), findsWidgets);
    expect(find.text('Gallery'), findsOneWidget);

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    expect(find.text('Content Gallery'), findsOneWidget);
    expect(find.text('Derivatives intuition'), findsOneWidget);

    await tester.tap(find.text('Derivatives intuition'));
    await tester.pumpAndSettle();

    expect(find.text('What does a derivative tell us?'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Cheatsheet summary'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();

    expect(find.text('Progress'), findsWidgets);

    await tester.tap(find.text('Knowledge Map'));
    await tester.pumpAndSettle();

    expect(find.text('Mathematics Prerequisite Map'), findsOneWidget);
    expect(find.text('Calculus 3'), findsOneWidget);

    await tester.tap(find.text('Calculus 3').first);
    await tester.pumpAndSettle();

    expect(find.text('Mastery confidence'), findsOneWidget);
    expect(find.text('Prerequisites'), findsOneWidget);
    expect(find.text('Related concepts'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsWidgets);
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
