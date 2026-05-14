// ignore_for_file: unused_element

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/wicara_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/language_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../../curriculum/domain/curriculum_models.dart';
import '../../curriculum/domain/curriculum_repository.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/domain/onboarding_copy.dart';
import '../../onboarding/domain/onboarding_options.dart';
import '../../onboarding/domain/onboarding_profile.dart';
import '../../onboarding/presentation/widgets/subject_tile.dart';
import '../domain/home_repository.dart';
import '../domain/home_snapshot.dart';
import '../../pretest/domain/pretest_models.dart';
import '../../pretest/presentation/widgets/assessment_option_tile.dart';
import '../../workspace/domain/workspace_models.dart';

enum _HomeTab { home, queue, progress, profile }

enum _QueueTab { recommended, tracks, gallery }

enum _ReportRangeOption { thisWeek, lastWeek, last4Weeks }

class _HomeCopyScope extends InheritedWidget {
  const _HomeCopyScope({required this.copy, required super.child});

  final OnboardingCopy copy;

  static OnboardingCopy of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_HomeCopyScope>();
    assert(scope != null, 'Missing _HomeCopyScope in widget tree.');
    return scope!.copy;
  }

  @override
  bool updateShouldNotify(_HomeCopyScope oldWidget) => copy != oldWidget.copy;
}

class AppHomePage extends StatefulWidget {
  const AppHomePage({
    required this.curriculumRepository,
    required this.homeRepository,
    required this.authController,
    required this.onboardingController,
    super.key,
  });

  final CurriculumRepository curriculumRepository;
  final HomeRepository homeRepository;
  final AuthController authController;
  final OnboardingController onboardingController;

  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage> {
  _HomeTab _selectedTab = _HomeTab.home;
  _QueueTab _queueTab = _QueueTab.recommended;
  bool _showGalleryDetail = false;
  bool _showDailyEvaluation = false;
  bool _showEvaluationResult = false;
  bool _showLearningReport = false;
  bool _showKnowledgeMap = false;
  int _dailyEvaluationIndex = 0;
  final Map<int, String> _dailyEvaluationAnswers = {};
  String? _dailyEvaluationSessionId;
  DailyEvaluationSession? _dailyEvaluationSession;
  DailyEvaluationResult? _dailyEvaluationResult;
  List<PretestQuestion> _backendDailyEvaluationQuestions = const [];
  bool _isLoadingDailyEvaluation = false;
  bool _isSubmittingDailyEvaluation = false;
  String? _dailyEvaluationError;
  late Future<HomeSnapshot> _homeSnapshotFuture;

  @override
  void initState() {
    super.initState();
    _homeSnapshotFuture = widget.homeRepository.fetchSnapshot();
  }

  void _retryHomeSnapshot() {
    setState(() {
      _homeSnapshotFuture = widget.homeRepository.fetchSnapshot();
    });
  }

  void _openQueue([_QueueTab tab = _QueueTab.recommended]) {
    setState(() {
      _queueTab = tab;
      _selectedTab = _HomeTab.queue;
      _showGalleryDetail = false;
      _showDailyEvaluation = false;
      _showEvaluationResult = false;
      _showLearningReport = false;
      _showKnowledgeMap = false;
    });
  }

  void _openHome() {
    setState(() {
      _selectedTab = _HomeTab.home;
      _showGalleryDetail = false;
      _showDailyEvaluation = false;
      _showEvaluationResult = false;
      _showLearningReport = false;
      _showKnowledgeMap = false;
    });
  }

  Future<void> _openDailyEvaluation() async {
    setState(() {
      _selectedTab = _HomeTab.home;
      _showGalleryDetail = false;
      _showDailyEvaluation = true;
      _showEvaluationResult = false;
      _showLearningReport = false;
      _showKnowledgeMap = false;
      _dailyEvaluationIndex = 0;
      _dailyEvaluationAnswers.clear();
      _dailyEvaluationSessionId = null;
      _dailyEvaluationSession = null;
      _dailyEvaluationResult = null;
      _backendDailyEvaluationQuestions = const [];
      _dailyEvaluationError = null;
      _isLoadingDailyEvaluation = true;
    });

    try {
      final session = await widget.homeRepository.fetchDailyEvaluation();
      if (!mounted) {
        return;
      }
      setState(() {
        _dailyEvaluationSessionId = session.sessionId;
        _dailyEvaluationSession = session;
        _dailyEvaluationIndex = _initialDailyEvaluationIndex(session);
        _backendDailyEvaluationQuestions = session.questions;
        _isLoadingDailyEvaluation = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _dailyEvaluationError = error.toString();
        _isLoadingDailyEvaluation = false;
      });
    }
  }

  void _selectDailyEvaluationAnswer(String optionId) {
    setState(() => _dailyEvaluationAnswers[_dailyEvaluationIndex] = optionId);
  }

  Future<void> _nextDailyEvaluationQuestion() async {
    final sessionId = _dailyEvaluationSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }
    final question = _backendDailyEvaluationQuestions[_dailyEvaluationIndex];
    final optionId = _dailyEvaluationAnswers[_dailyEvaluationIndex];
    if (optionId == null || optionId.isEmpty || _isSubmittingDailyEvaluation) {
      return;
    }

    setState(() => _isSubmittingDailyEvaluation = true);
    try {
      await widget.homeRepository.submitDailyEvaluationAnswer(
        sessionId: sessionId,
        questionId: question.id,
        optionId: optionId,
        confidence: 6,
      );
      DailyEvaluationResult? evaluationResult;
      final isLastQuestion =
          _dailyEvaluationIndex >= _backendDailyEvaluationQuestions.length - 1;
      if (isLastQuestion) {
        evaluationResult = await widget.homeRepository
            .fetchDailyEvaluationResult(sessionId: sessionId);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmittingDailyEvaluation = false;
        if (!isLastQuestion) {
          _dailyEvaluationIndex += 1;
          return;
        }

        _dailyEvaluationResult = evaluationResult;
        _showDailyEvaluation = false;
        _showEvaluationResult = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmittingDailyEvaluation = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _previousDailyEvaluationQuestion() {
    if (_dailyEvaluationIndex == 0) {
      _openHome();
      return;
    }

    setState(() => _dailyEvaluationIndex -= 1);
  }

  int _initialDailyEvaluationIndex(DailyEvaluationSession session) {
    final currentQuestionId = session.currentQuestion?.id;
    if (currentQuestionId != null && currentQuestionId.isNotEmpty) {
      final index = session.questions.indexWhere(
        (question) => question.id == currentQuestionId,
      );
      if (index >= 0) {
        return index;
      }
    }
    if (session.questions.isEmpty) {
      return 0;
    }
    return session.progress.completed
        .clamp(0, session.questions.length - 1)
        .toInt();
  }

  void _openLearningReport() {
    setState(() {
      _selectedTab = _HomeTab.progress;
      _showGalleryDetail = false;
      _showDailyEvaluation = false;
      _showEvaluationResult = false;
      _showLearningReport = true;
      _showKnowledgeMap = false;
    });
  }

  void _closeLearningReport() {
    setState(() => _showLearningReport = false);
  }

  void _openKnowledgeMap() {
    setState(() {
      _selectedTab = _HomeTab.progress;
      _showGalleryDetail = false;
      _showDailyEvaluation = false;
      _showEvaluationResult = false;
      _showLearningReport = false;
      _showKnowledgeMap = true;
    });
  }

  void _closeKnowledgeMap() {
    setState(() => _showKnowledgeMap = false);
  }

  void _openLearningGoal() {
    Navigator.of(context).pushNamed(AppRoutes.learningGoal);
  }

  Future<void> _openWorkspaceModules(WorkspaceRouteArguments arguments) async {
    await Navigator.of(
      context,
    ).pushNamed(AppRoutes.workspaceModules, arguments: arguments);
    if (!mounted) return;
    _retryHomeSnapshot();
  }

  void _handleRecommendedAction(RecommendedNextAction action) {
    switch (action.actionType.toLowerCase()) {
      case 'review':
        _openDailyEvaluation();
        return;
      case 'practice':
        _openQueue(_QueueTab.recommended);
        return;
      case 'deepen':
        _openQueue(_QueueTab.tracks);
        return;
      case 'continue_learning':
        _openQueue(_QueueTab.tracks);
        return;
      default:
        _openHome();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.onboardingController,
      builder: (context, _) {
        final copy = OnboardingCopy.forLanguage(
          widget.onboardingController.profile.preferredLanguage,
        );

        return Scaffold(
          body: _HomeCopyScope(
            copy: copy,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final pageWidth = math.min(constraints.maxWidth, 430.0);

                  return Center(
                    child: SizedBox(
                      width: pageWidth,
                      child: Stack(
                        children: [
                          Positioned.fill(child: _animatedTabView(constraints)),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child:
                                  _showEvaluationResult || _showDailyEvaluation
                                  ? const SizedBox.shrink()
                                  : _ShortcutBar(
                                      key: const ValueKey('shortcut-bar'),
                                      selectedTab: _selectedTab,
                                      onSelected: (tab) => setState(() {
                                        _selectedTab = tab;
                                        _showDailyEvaluation = false;
                                        _showEvaluationResult = false;
                                        _showLearningReport = false;
                                        _showKnowledgeMap = false;
                                      }),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _animatedTabView(BoxConstraints constraints) {
    final key = ValueKey(
      '${_selectedTab.name}-detail-$_showGalleryDetail-daily-$_showDailyEvaluation-$_dailyEvaluationIndex-eval-$_showEvaluationResult-report-$_showLearningReport-map-$_showKnowledgeMap',
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 170),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(children: [...previousChildren, ?currentChild]);
      },
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0.035, 0),
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(key: key, child: _tabView(constraints)),
    );
  }

  Widget _tabView(BoxConstraints constraints) {
    final copy = OnboardingCopy.forLanguage(
      widget.onboardingController.profile.preferredLanguage,
    );
    if (_showDailyEvaluation) {
      if (_isLoadingDailyEvaluation) {
        return _DashboardStatePage(
          constraints: constraints,
          title: copy.isIndonesian
              ? 'Memuat Evaluasi Harian'
              : 'Loading Daily Evals',
          message: copy.isIndonesian
              ? 'Mengambil soal spaced review dari backend.'
              : 'Fetching spaced-review questions from backend.',
        );
      }
      if (_dailyEvaluationError != null ||
          _backendDailyEvaluationQuestions.isEmpty) {
        return _DashboardStatePage(
          constraints: constraints,
          title: copy.isIndonesian
              ? 'Evaluasi Harian tidak tersedia'
              : 'Daily Evals unavailable',
          message:
              _dailyEvaluationError ??
              (copy.isIndonesian
                  ? 'Backend tidak mengembalikan soal review.'
                  : 'Backend returned no review questions.'),
          actionLabel: copy.isIndonesian ? 'Coba lagi' : 'Try again',
          onAction: () {
            _openDailyEvaluation();
          },
        );
      }
      return _DailyEvaluationQuestionPage(
        constraints: constraints,
        session: _dailyEvaluationSession,
        question: _backendDailyEvaluationQuestions[_dailyEvaluationIndex],
        questionIndex: _dailyEvaluationIndex,
        totalQuestions: _backendDailyEvaluationQuestions.length,
        selectedOptionId: _dailyEvaluationAnswers[_dailyEvaluationIndex],
        onBack: _previousDailyEvaluationQuestion,
        onSelected: _selectDailyEvaluationAnswer,
        isSubmitting: _isSubmittingDailyEvaluation,
        onSubmit: () {
          _nextDailyEvaluationQuestion();
        },
      );
    }

    if (_showEvaluationResult) {
      return _EvaluationCompletePage(
        constraints: constraints,
        result: _dailyEvaluationResult,
        onBackHome: _openHome,
        onActionSelected: _handleRecommendedAction,
      );
    }

    return switch (_selectedTab) {
      _HomeTab.home => _HomeDashboard(
        constraints: constraints,
        snapshotFuture: _homeSnapshotFuture,
        onRetrySnapshot: _retryHomeSnapshot,
        onOpenQueue: () => _openQueue(),
        onOpenTracks: () => _openQueue(_QueueTab.tracks),
        onTakeDailyEvaluation: () {
          _openDailyEvaluation();
        },
        onContinueSession: _openWorkspaceModules,
      ),
      _HomeTab.queue => _HomeSnapshotBuilder(
        constraints: constraints,
        snapshotFuture: _homeSnapshotFuture,
        onRetry: _retryHomeSnapshot,
        builder: (snapshot) => _LearningQueue(
          constraints: constraints,
          snapshot: snapshot,
          selectedTab: _queueTab,
          onTabChanged: (tab) => setState(() => _queueTab = tab),
          onCreateTrack: _openLearningGoal,
          onOpenWorkspace: _openWorkspaceModules,
          onBack: _openHome,
        ),
      ),
      _HomeTab.progress => _ProgressHub(
        constraints: constraints,
        homeRepository: widget.homeRepository,
        curriculumRepository: widget.curriculumRepository,
        onBack: _openHome,
        showLearningReport: _showLearningReport,
        showKnowledgeMap: _showKnowledgeMap,
        onOpenLearningReport: _openLearningReport,
        onCloseLearningReport: _closeLearningReport,
        onOpenKnowledgeMap: _openKnowledgeMap,
        onCloseKnowledgeMap: _closeKnowledgeMap,
        onRecommendationSelected: _handleRecommendedAction,
      ),
      _HomeTab.profile => _HomeSnapshotBuilder(
        constraints: constraints,
        snapshotFuture: _homeSnapshotFuture,
        onRetry: _retryHomeSnapshot,
        builder: (snapshot) => _ProfilePage(
          constraints: constraints,
          snapshot: snapshot,
          onBack: _openHome,
          authController: widget.authController,
          onboardingController: widget.onboardingController,
          onProfileSaved: _retryHomeSnapshot,
        ),
      ),
    };
  }
}

class _HomeSnapshotBuilder extends StatelessWidget {
  const _HomeSnapshotBuilder({
    required this.constraints,
    required this.snapshotFuture,
    required this.builder,
    required this.onRetry,
  });

  final BoxConstraints constraints;
  final Future<HomeSnapshot> snapshotFuture;
  final Widget Function(HomeSnapshot snapshot) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return FutureBuilder<HomeSnapshot>(
      future: snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return builder(snapshot.data!);
        }
        if (snapshot.hasError) {
          return _DashboardStatePage(
            constraints: constraints,
            title: copy.isIndonesian
                ? 'Dashboard tidak tersedia'
                : 'Dashboard unavailable',
            message: snapshot.error.toString(),
            actionLabel: copy.isIndonesian ? 'Coba lagi' : 'Retry',
            onAction: onRetry,
          );
        }
        return _DashboardStatePage(
          constraints: constraints,
          title: copy.isIndonesian ? 'Memuat dashboard' : 'Loading dashboard',
          message: copy.isIndonesian
              ? 'Mengambil profilmu dari backend.'
              : 'Fetching your profile from backend.',
        );
      },
    );
  }
}

String _displayGradeSummary(HomeSnapshot snapshot, OnboardingCopy copy) {
  final parts = <String>[];
  if (snapshot.educationLevel.trim().isNotEmpty) {
    parts.add(_educationLabel(snapshot.educationLevel, copy));
  }
  if (snapshot.gradeLevel.trim().isNotEmpty) {
    parts.add(copy.gradeValue(snapshot.gradeLevel));
  }
  return parts.join(' - ');
}

String _educationLabel(String value, OnboardingCopy copy) {
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'elementary' => copy.isIndonesian ? 'Sekolah dasar' : 'Elementary school',
    'junior_high' => copy.isIndonesian ? 'SMP' : 'Junior high school',
    'senior_high' => copy.isIndonesian ? 'SMA' : 'Senior high school',
    'university' => copy.isIndonesian ? 'Universitas' : 'University',
    _ => value,
  };
}

class _DashboardStatePage extends StatelessWidget {
  const _DashboardStatePage({
    required this.constraints,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final BoxConstraints constraints;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 136),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _SectionWordmark(
              assetPath: 'lib/src/assets/waveIcon.png',
              title: title,
              iconSize: 84,
              titleFontSize: 23,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              GradientButton(label: actionLabel!, onPressed: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.constraints,
    required this.snapshotFuture,
    required this.onRetrySnapshot,
    required this.onOpenQueue,
    required this.onOpenTracks,
    required this.onTakeDailyEvaluation,
    required this.onContinueSession,
  });

  final BoxConstraints constraints;
  final Future<HomeSnapshot> snapshotFuture;
  final VoidCallback onRetrySnapshot;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenTracks;
  final VoidCallback onTakeDailyEvaluation;
  final ValueChanged<WorkspaceRouteArguments> onContinueSession;

  @override
  Widget build(BuildContext context) {
    return _HomeSnapshotBuilder(
      constraints: constraints,
      snapshotFuture: snapshotFuture,
      onRetry: onRetrySnapshot,
      builder: (snapshot) => _HomeDashboardContent(
        constraints: constraints,
        snapshot: snapshot,
        onOpenQueue: onOpenQueue,
        onOpenTracks: onOpenTracks,
        onTakeDailyEvaluation: onTakeDailyEvaluation,
        onContinueSession: onContinueSession,
      ),
    );
  }
}

class _HomeDashboardContent extends StatelessWidget {
  const _HomeDashboardContent({
    required this.constraints,
    required this.snapshot,
    required this.onOpenQueue,
    required this.onOpenTracks,
    required this.onTakeDailyEvaluation,
    required this.onContinueSession,
  });

  final BoxConstraints constraints;
  final HomeSnapshot snapshot;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenTracks;
  final VoidCallback onTakeDailyEvaluation;
  final ValueChanged<WorkspaceRouteArguments> onContinueSession;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 136),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _SectionWordmark(
                assetPath: 'lib/src/assets/waveIcon.png',
                title: '${copy.welcomeBack}${snapshot.firstName}',
                iconSize: 84,
                titleFontSize: 23,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              copy.homeSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 35),
            _ExploreTracksCard(onOpenTracks: onOpenTracks),
            const SizedBox(height: 20),
            _TodayQueueCard(
              snapshot: snapshot,
              onViewAll: onOpenQueue,
              onContinue: onContinueSession,
            ),
            const SizedBox(height: 25),
            _StreakCard(streakDays: snapshot.streakDays),
            const SizedBox(height: 24),
            _DailyEvaluationCard(onTakeEvaluation: onTakeDailyEvaluation),
          ],
        ),
      ),
    );
  }
}

class _LearningQueue extends StatelessWidget {
  const _LearningQueue({
    required this.constraints,
    required this.snapshot,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onCreateTrack,
    required this.onOpenWorkspace,
    required this.onBack,
  });

  final BoxConstraints constraints;
  final HomeSnapshot snapshot;
  final _QueueTab selectedTab;
  final ValueChanged<_QueueTab> onTabChanged;
  final VoidCallback onCreateTrack;
  final ValueChanged<WorkspaceRouteArguments> onOpenWorkspace;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    final description = switch (selectedTab) {
      _QueueTab.recommended => copy.learnSubtitleRecommended,
      _QueueTab.tracks => copy.learnSubtitleTracks,
      _QueueTab.gallery => copy.learnSubtitleGallery,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 132),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(onBack: onBack),
            const SizedBox(height: 34),
            _SectionWordmark(
              assetPath: 'lib/src/assets/learnIcon.png',
              title: copy.learnLabel,
              iconSize: 84,
            ),
            const SizedBox(height: 16),
            _QueueTabs(selectedTab: selectedTab, onChanged: onTabChanged),
            const SizedBox(height: 16),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 28),
            if (selectedTab == _QueueTab.recommended)
              _BackendSubjectQueueContent(
                snapshot: snapshot,
                onContinue: onOpenWorkspace,
              )
            else if (selectedTab == _QueueTab.tracks)
              _BackendTrackQueueContent(
                snapshot: snapshot,
                onCreateTrack: onCreateTrack,
                onContinue: onOpenWorkspace,
              )
            else if (selectedTab == _QueueTab.gallery)
              const _BackendGalleryEmptyContent(),
          ],
        ),
      ),
    );
  }
}

class _BackendSubjectQueueContent extends StatelessWidget {
  const _BackendSubjectQueueContent({
    required this.snapshot,
    required this.onContinue,
  });

  final HomeSnapshot snapshot;
  final ValueChanged<WorkspaceRouteArguments> onContinue;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    final subjects = snapshot.selectedSubjects;
    final workspaceTarget = snapshot.firstWorkspaceTarget;
    if (subjects.isEmpty) {
      return _BackendEmptyPanel(
        icon: Icons.menu_book_outlined,
        title: copy.subjectsLabel,
        message: copy.chooseSubjectsSubtitle,
      );
    }

    return Column(
      children: [
        for (final subject in subjects) ...[
          _Panel(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: WicaraColors.speechBlue,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: WicaraColors.secondary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.subjectLabel(subject),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _displayGradeSummary(snapshot, copy),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: WicaraColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: workspaceTarget == null
                      ? null
                      : () => onContinue(workspaceTarget),
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: WicaraColors.secondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BackendTrackQueueContent extends StatelessWidget {
  const _BackendTrackQueueContent({
    required this.snapshot,
    required this.onCreateTrack,
    required this.onContinue,
  });

  final HomeSnapshot snapshot;
  final VoidCallback onCreateTrack;
  final ValueChanged<WorkspaceRouteArguments> onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackendSubjectQueueContent(snapshot: snapshot, onContinue: onContinue),
        const SizedBox(height: 8),
        GradientButton(label: 'Create learning goal', onPressed: onCreateTrack),
      ],
    );
  }
}

class _BackendGalleryEmptyContent extends StatelessWidget {
  const _BackendGalleryEmptyContent();

  @override
  Widget build(BuildContext context) {
    return const _BackendEmptyPanel(
      icon: Icons.video_library_outlined,
      title: 'No saved gallery items',
      message:
          'Generated videos will appear here after a backend job saves them.',
    );
  }
}

class _BackendEmptyPanel extends StatelessWidget {
  const _BackendEmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: WicaraColors.secondary, size: 28),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left_rounded),
          iconSize: 33,
          color: WicaraColors.ink,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        ),
      ],
    );
  }
}

class _TodayQueueCard extends StatelessWidget {
  const _TodayQueueCard({
    required this.snapshot,
    required this.onViewAll,
    required this.onContinue,
  });

  final HomeSnapshot snapshot;
  final VoidCallback onViewAll;
  final ValueChanged<WorkspaceRouteArguments> onContinue;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    final workspaceTarget = snapshot.firstWorkspaceTarget;
    final glyphSource = snapshot.selectedSubjects.isEmpty
        ? 'set'
        : snapshot.selectedSubjects.first.trim();
    final glyphText = glyphSource.length <= 3
        ? glyphSource.toLowerCase()
        : glyphSource.substring(0, 3).toLowerCase();

    return _Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  copy.todaysLearningQueueLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  copy.viewAllLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: WicaraColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SoftBadge(copy.customizeLaterNote),
                    const SizedBox(height: 11),
                    Text(
                      snapshot.selectedSubjects
                          .map(copy.subjectLabel)
                          .join(', '),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _displayGradeSummary(snapshot, copy),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      snapshot.dailyStudyTime.isEmpty
                          ? copy.dailyStudyTimeOptionalLabel
                          : copy.dailyStudyTimeDisplay(snapshot.dailyStudyTime),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.softMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _LessonGlyph(text: glyphText, size: 73),
            ],
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: copy.continueSessionLabel,
            onPressed: workspaceTarget == null
                ? null
                : () => onContinue(workspaceTarget),
          ),
        ],
      ),
    );
  }
}

class _ExploreTracksCard extends StatelessWidget {
  const _ExploreTracksCard({required this.onOpenTracks});

  final VoidCallback onOpenTracks;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: WicaraColors.secondarySoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.explore_outlined,
              color: WicaraColors.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.wantToLearnSomethingNewLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  copy.exploreTracksDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onOpenTracks,
            style: TextButton.styleFrom(
              foregroundColor: WicaraColors.secondary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(copy.exploreLabel),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return _Panel(
      padding: const EdgeInsets.fromLTRB(19, 18, 19, 18),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: WicaraColors.accentCoral,
            size: 28,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.currentStreakLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  copy.streakDaysLabel(streakDays),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 166, child: _WeekDots()),
        ],
      ),
    );
  }
}

class _DailyEvaluationUnavailableCard extends StatelessWidget {
  const _DailyEvaluationUnavailableCard();

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return _Panel(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            copy.dailyEvaluationLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            copy.isIndonesian
                ? 'Belum ada evaluasi harian yang ditugaskan.'
                : 'No daily evaluation assigned yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              copy.isIndonesian ? 'Belum ada evaluasi' : 'No evaluation',
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyEvaluationCard extends StatefulWidget {
  const _DailyEvaluationCard({required this.onTakeEvaluation});

  final VoidCallback onTakeEvaluation;

  @override
  State<_DailyEvaluationCard> createState() => _DailyEvaluationCardState();
}

class _DailyEvaluationCardState extends State<_DailyEvaluationCard> {
  int? _score = 3;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return _Panel(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            copy.dailyEvaluationLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 11),
          Text.rich(
            TextSpan(
              text: copy.todaysTopicLabel,
              children: [
                TextSpan(
                  text: 'Calculus I',
                  style: TextStyle(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: copy.dailyEvaluationPrompt),
              ],
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 21),
          Row(
            children: [
              for (var score = 1; score <= 5; score++) ...[
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _score = score),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 39,
                      decoration: BoxDecoration(
                        color: score == _score
                            ? WicaraColors.secondary
                            : WicaraColors.speechBlue,
                        borderRadius: BorderRadius.circular(10),
                        border: score == _score
                            ? null
                            : Border.all(color: WicaraColors.line),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$score',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: score == _score
                              ? Colors.white
                              : WicaraColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                if (score < 5) const SizedBox(width: 11),
              ],
            ],
          ),
          const SizedBox(height: 17),
          SizedBox(
            height: 16,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Not confident',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Very confident',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Take Daily Evaluation',
            onPressed: widget.onTakeEvaluation,
          ),
        ],
      ),
    );
  }
}

class _DailyEvaluationQuestionPage extends StatelessWidget {
  const _DailyEvaluationQuestionPage({
    required this.constraints,
    required this.session,
    required this.question,
    required this.questionIndex,
    required this.totalQuestions,
    required this.selectedOptionId,
    required this.onBack,
    required this.onSelected,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final BoxConstraints constraints;
  final DailyEvaluationSession? session;
  final PretestQuestion question;
  final int questionIndex;
  final int totalQuestions;
  final String? selectedOptionId;
  final VoidCallback onBack;
  final ValueChanged<String> onSelected;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final progress = totalQuestions == 0
        ? 0.0
        : (questionIndex + 1) / totalQuestions;
    final progressLabel = '${questionIndex + 1} of $totalQuestions';
    final isLastQuestion = questionIndex == totalQuestions - 1;
    final reviewDue = session?.reviewDue ?? const ReviewDueSummary();
    final forecast = session?.retentionForecast ?? const RetentionForecast();
    final callout =
        session?.recommendationCallout ?? const RecommendationCallout();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 30),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LearningSurfaceHeader(
              title: session?.title ?? 'Daily Evaluation',
              languageCode: _languageCode(session?.language ?? 'en'),
              onBack: onBack,
              leadingIcon: Icons.close_rounded,
            ),
            const SizedBox(height: 28),
            _ReviewDueCard(reviewDue: reviewDue),
            const SizedBox(height: 28),
            _DailyEvaluationSectionTitle(
              label: 'Quick check-in',
              progressLabel: progressLabel,
              subtitle: 'Answer five questions to strengthen your memory.',
            ),
            const SizedBox(height: 12),
            _EvaluationProgressLine(value: progress),
            const SizedBox(height: 18),
            _Panel(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: WicaraColors.speechBlue,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: WicaraColors.line),
                      ),
                      child: Text(
                        question.topic,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: WicaraColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    question.prompt,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    question.helper,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 26),
                  for (
                    var index = 0;
                    index < question.options.length;
                    index++
                  ) ...[
                    AssessmentOptionTile(
                      option: question.options[index],
                      isSelected:
                          question.options[index].id == selectedOptionId,
                      onTap: () => onSelected(question.options[index].id),
                    ),
                    if (index < question.options.length - 1)
                      const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 22),
                  GradientButton(
                    label: isLastQuestion
                        ? 'Finish evaluation'
                        : 'Next question',
                    onPressed: selectedOptionId == null ? null : onSubmit,
                    isLoading: isSubmitting,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _RetentionForecastPanel(forecast: forecast, callout: callout),
          ],
        ),
      ),
    );
  }
}

class _EvaluationProgressLine extends StatelessWidget {
  const _EvaluationProgressLine({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        color: WicaraColors.secondary,
        backgroundColor: WicaraColors.line,
      ),
    );
  }
}

class _LearningSurfaceHeader extends StatelessWidget {
  const _LearningSurfaceHeader({
    required this.title,
    required this.languageCode,
    required this.onBack,
    this.leadingIcon = Icons.chevron_left_rounded,
  });

  final String title;
  final String languageCode;
  final VoidCallback onBack;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(leadingIcon),
          iconSize: 30,
          color: WicaraColors.ink,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        LanguageChip(languageCode: languageCode),
      ],
    );
  }
}

class _ReviewDueCard extends StatelessWidget {
  const _ReviewDueCard({required this.reviewDue});

  final ReviewDueSummary reviewDue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1F4FF), Color(0xFFF6EFFF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: WicaraColors.secondary,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reviewDue.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  reviewDue.summary.isEmpty
                      ? '${reviewDue.dueCount} items ready for review'
                      : reviewDue.summary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WicaraColors.secondary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: WicaraColors.secondary.withValues(alpha: 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              reviewDue.actionLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyEvaluationSectionTitle extends StatelessWidget {
  const _DailyEvaluationSectionTitle({
    required this.label,
    required this.progressLabel,
    required this.subtitle,
  });

  final String label;
  final String progressLabel;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Text(
          progressLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: WicaraColors.secondaryDeep,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RetentionForecastPanel extends StatelessWidget {
  const _RetentionForecastPanel({
    required this.forecast,
    required this.callout,
  });

  final RetentionForecast forecast;
  final RecommendationCallout callout;

  @override
  Widget build(BuildContext context) {
    final points = forecast.points.isEmpty
        ? const [
            RetentionForecastPoint(label: 'Today', retentionPercent: 100),
            RetentionForecastPoint(label: 'Day 1', retentionPercent: 70),
            RetentionForecastPoint(label: 'Day 2', retentionPercent: 52),
            RetentionForecastPoint(label: 'Day 7', retentionPercent: 38),
            RetentionForecastPoint(
              label: 'Day 14',
              retentionPercent: 25,
              projected: true,
            ),
            RetentionForecastPoint(
              label: 'Day 30',
              retentionPercent: 17,
              projected: true,
            ),
          ]
        : forecast.points;

    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  forecast.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.info_outline_rounded,
                color: WicaraColors.muted,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            forecast.basis.isEmpty
                ? 'Based on the Ebbinghaus forgetting curve MVP.'
                : forecast.basis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 170,
            child: CustomPaint(
              painter: _RetentionForecastPainter(points: points),
              child: Align(
                alignment: Alignment.topRight,
                child: _RetentionCalloutBubble(callout: callout),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _RetentionCoachingNote(message: callout.message),
        ],
      ),
    );
  }
}

class _RetentionForecastPainter extends CustomPainter {
  const _RetentionForecastPainter({required this.points});

  final List<RetentionForecastPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(8, 12, size.width - 16, size.height - 38);
    final gridPaint = Paint()
      ..color = WicaraColors.line
      ..strokeWidth = 1;
    for (final factor in [0.0, 0.5, 1.0]) {
      final y = chartRect.bottom - chartRect.height * factor;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }
    final linePaint = Paint()
      ..color = WicaraColors.secondary
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = WicaraColors.secondary;
    final projectedPaint = Paint()
      ..color = WicaraColors.primaryDeep.withValues(alpha: 0.58)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final x = points.length == 1
          ? chartRect.left
          : chartRect.left + (chartRect.width / (points.length - 1)) * index;
      final y =
          chartRect.bottom -
          chartRect.height *
              (points[index].retentionPercent.clamp(0, 100).toDouble() / 100);
      final offset = Offset(x, y);
      offsets.add(offset);
      if (index == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else if (!points[index].projected) {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(path, linePaint);
    for (var index = 0; index < offsets.length; index++) {
      final point = points[index];
      if (point.projected && index > 0) {
        canvas.drawLine(offsets[index - 1], offsets[index], projectedPaint);
      }
      canvas.drawCircle(
        offsets[index],
        point.projected ? 4 : 5,
        point.projected ? (Paint()..color = Colors.white) : dotPaint,
      );
      if (point.projected) {
        canvas.drawCircle(offsets[index], 4, projectedPaint);
      }
      final textPainter = TextPainter(
        text: TextSpan(
          text: point.label,
          style: const TextStyle(
            color: WicaraColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 48);
      textPainter.paint(
        canvas,
        Offset(
          offsets[index].dx - textPainter.width / 2,
          chartRect.bottom + 12,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RetentionForecastPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _RetentionCalloutBubble extends StatelessWidget {
  const _RetentionCalloutBubble({required this.callout});

  final RecommendationCallout callout;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12, top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: WicaraColors.line),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            callout.actionLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.secondaryDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            callout.impactLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.accentMint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetentionCoachingNote extends StatelessWidget {
  const _RetentionCoachingNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.54),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.timeline_rounded,
              color: WicaraColors.secondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message.isEmpty
                  ? 'Keep reviewing to move the curve up and improve long-term retention.'
                  : message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvaluationCompletePage extends StatelessWidget {
  const _EvaluationCompletePage({
    required this.constraints,
    required this.result,
    required this.onBackHome,
    required this.onActionSelected,
  });

  final BoxConstraints constraints;
  final DailyEvaluationResult? result;
  final VoidCallback onBackHome;
  final ValueChanged<RecommendedNextAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final impact =
        result?.spacedRepetitionImpact ?? const SpacedRepetitionImpact();
    final nextReview = result?.nextReview ?? const DailyEvaluationNextReview();
    final actions = result?.recommendedNextActions ?? const [];
    final scoreFraction =
        ((result?.scorePercent ?? 0).clamp(0, 100).toDouble()) / 100;
    final copy = _HomeCopyScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 30),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LearningSurfaceHeader(
              title: 'Evaluation Complete',
              languageCode: 'EN',
              onBack: onBackHome,
            ),
            const SizedBox(height: 25),
            Text(
              copy.evaluationCompleteLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              copy.evaluationCompleteSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 26),
            _Panel(
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
              child: Row(
                children: [
                  Expanded(child: _EvaluationScoreRing(score: scoreFraction)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        _EvaluationStat(
                          value: '${result?.reviewedCount ?? 0}',
                          label: 'Reviewed',
                        ),
                        const SizedBox(height: 17),
                        _EvaluationStat(
                          value: '${result?.correctCount ?? 0}',
                          label: 'Correct',
                        ),
                        const SizedBox(height: 17),
                        _EvaluationStat(
                          value: '${result?.reviewAgainCount ?? 0}',
                          label: 'To review again',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _EvaluationConceptsPanel(
              concepts: result?.reviewedConcepts ?? const [],
            ),
            const SizedBox(height: 18),
            _SpacedRepetitionImpactPanel(
              impact: impact,
              nextReview: nextReview,
            ),
            const SizedBox(height: 18),
            _RecommendedNextActionsPanel(
              actions: actions,
              onActionSelected: onActionSelected,
            ),
            const SizedBox(height: 28),
            _BackHomeButton(
              label: result?.backToHome.label ?? 'Back to Home',
              onPressed: onBackHome,
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationScoreRing extends StatefulWidget {
  const _EvaluationScoreRing({required this.score});

  final double score;

  @override
  State<_EvaluationScoreRing> createState() => _EvaluationScoreRingState();
}

class _EvaluationScoreRingState extends State<_EvaluationScoreRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final animatedScore = widget.score * _animation.value;

          return CustomPaint(
            painter: _ScoreRingPainter(progress: animatedScore),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(animatedScore * 100).round()}%',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 31,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    copy.scoreLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.09;
    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    final track = Paint()
      ..color = WicaraColors.secondarySoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = WicaraColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _EvaluationStat extends StatelessWidget {
  const _EvaluationStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvaluationConceptsPanel extends StatelessWidget {
  const _EvaluationConceptsPanel({required this.concepts});

  final List<ReviewedConcept> concepts;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              'Reviewed concepts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (concepts.isEmpty)
            const _ConceptResultTile(
              title: 'No concepts reviewed yet',
              status: 'Pending',
              statusColor: WicaraColors.muted,
            ),
          for (final concept in concepts) ...[
            _ConceptResultTile(
              title: concept.title,
              status: concept.statusLabel,
              statusColor: _conceptStatusColor(concept.statusLabel),
            ),
            if (concept != concepts.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

Color _conceptStatusColor(String status) {
  return switch (status.toLowerCase()) {
    'strong' || 'good' => WicaraColors.accentMint,
    'review' => WicaraColors.accentAmber,
    _ => WicaraColors.primaryDeep,
  };
}

String _languageCode(String language) {
  return switch (language.trim().toLowerCase()) {
    'id' || 'indonesian' || 'bahasa indonesia' => 'ID',
    'ms' || 'bahasa melayu' => 'MS',
    'fil' || 'filipino' => 'FIL',
    'vi' || 'vietnamese' => 'VI',
    _ => 'EN',
  };
}

IconData _actionIcon(String actionType) {
  return switch (actionType.toLowerCase()) {
    'review' => Icons.calendar_today_rounded,
    'deepen' => Icons.event_note_rounded,
    'practice' => Icons.assignment_outlined,
    'continue_learning' => Icons.trending_up_rounded,
    _ => Icons.arrow_forward_rounded,
  };
}

Color _actionColor(String actionType) {
  return switch (actionType.toLowerCase()) {
    'review' => WicaraColors.accentAmber,
    'deepen' => WicaraColors.accentMint,
    'practice' => WicaraColors.secondary,
    'continue_learning' => WicaraColors.primaryDeep,
    _ => WicaraColors.secondary,
  };
}

Color _actionBackground(String actionType) {
  return _actionColor(actionType).withValues(alpha: 0.14);
}

class _ConceptResultTile extends StatelessWidget {
  const _ConceptResultTile({
    required this.title,
    required this.status,
    required this.statusColor,
  });

  final String title;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: WicaraColors.secondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 11,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 23,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpacedRepetitionImpactPanel extends StatelessWidget {
  const _SpacedRepetitionImpactPanel({
    required this.impact,
    required this.nextReview,
  });

  final SpacedRepetitionImpact impact;
  final DailyEvaluationNextReview nextReview;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Spaced repetition impact',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.info_outline_rounded,
                color: WicaraColors.muted,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            impact.summary.isEmpty
                ? "You've strengthened your memory."
                : impact.summary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _ImpactMetric(
                  value: '+${impact.retentionLiftPercent}%',
                  label: 'Retention Lift',
                  icon: Icons.arrow_upward_rounded,
                  iconColor: WicaraColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ImpactMetric(
                  value: '${impact.daysUntilNextReview}',
                  label: nextReview.label.isEmpty
                      ? 'Days Until Next Review'
                      : nextReview.label,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactMetric extends StatelessWidget {
  const _ImpactMetric({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 5),
              ],
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: WicaraColors.secondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedNextActionsPanel extends StatelessWidget {
  const _RecommendedNextActionsPanel({
    required this.actions,
    required this.onActionSelected,
  });

  final List<RecommendedNextAction> actions;
  final ValueChanged<RecommendedNextAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final rows = actions.isEmpty
        ? const [
            RecommendedNextAction(
              title: 'Continue learning',
              actionType: 'continue_learning',
              reason: 'Go to your learning path.',
            ),
          ]
        : actions;

    return _Panel(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recommended next actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          for (final action in rows) ...[
            _ActionRecommendationTile(
              action: action,
              onSelected: onActionSelected,
            ),
            if (action != rows.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ActionRecommendationTile extends StatelessWidget {
  const _ActionRecommendationTile({
    required this.action,
    required this.onSelected,
  });

  final RecommendedNextAction action;
  final ValueChanged<RecommendedNextAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => onSelected(action),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: WicaraColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: WicaraColors.secondarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _actionIcon(action.actionType),
                  color: WicaraColors.secondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: WicaraColors.softMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackHomeButton extends StatelessWidget {
  const _BackHomeButton({required this.onPressed, this.label = 'Back to Home'});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WicaraColors.secondary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.secondary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 47,
            child: Center(
              child: Text(
                label.isNotEmpty ? label : copy.backToHomeLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueTabs extends StatelessWidget {
  const _QueueTabs({required this.selectedTab, required this.onChanged});

  final _QueueTab selectedTab;
  final ValueChanged<_QueueTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WicaraColors.primaryLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _QueueTabButton(
              label: copy.recommendedLabel,
              isSelected: selectedTab == _QueueTab.recommended,
              onTap: () => onChanged(_QueueTab.recommended),
            ),
          ),
          Expanded(
            child: _QueueTabButton(
              label: copy.tracksLabel,
              isSelected: selectedTab == _QueueTab.tracks,
              onTap: () => onChanged(_QueueTab.tracks),
            ),
          ),
          Expanded(
            child: _QueueTabButton(
              label: copy.galleryLabel,
              isSelected: selectedTab == _QueueTab.gallery,
              onTap: () => onChanged(_QueueTab.gallery),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueTabButton extends StatelessWidget {
  const _QueueTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSelected ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: isSelected ? WicaraColors.primaryDeep : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: WicaraColors.primary.withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
            ],
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected ? Colors.white : WicaraColors.primaryDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendedQueueContent extends StatelessWidget {
  const _RecommendedQueueContent({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PriorityCallout(),
        const SizedBox(height: 22),
        _QueueLessonCard(
          index: '1',
          badge: 'Next up',
          title: 'Limits from graphs',
          subject: 'Calculus I',
          reason:
              'Why now? This unlocks continuity and\nfirst derivative intuition.',
          meta: '18 min   •   Medium',
          action: 'Continue',
          iconText: 'lim',
          isPrimary: true,
          onActionPressed: onContinue,
        ),
        const SizedBox(height: 20),
        _QueueLessonCard(
          index: '2',
          title: 'Derivative rules',
          subject: 'Calculus',
          reason:
              "Why now? You're ready after limits and\nslope interpretation.",
          meta: '24 min   •   Hard',
          action: 'Continue',
          iconText: 'd\ndx',
          onActionPressed: onContinue,
        ),
        const SizedBox(height: 20),
        _QueueLessonCard(
          index: '3',
          title: 'Function composition review',
          subject: 'Prerequisite',
          reason:
              'Why now? Needed before chain rule and\nimplicit differentiation.',
          meta: '12 min   •   Easy',
          action: 'Review',
          iconData: Icons.event_note_outlined,
          onActionPressed: onContinue,
        ),
      ],
    );
  }
}

class _TracksQueueContent extends StatelessWidget {
  const _TracksQueueContent({
    required this.onCreateTrack,
    required this.onContinue,
  });

  final VoidCallback onCreateTrack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NewTrackCard(onCreateTrack: onCreateTrack),
        const SizedBox(height: 22),
        _TrackCard(
          title: 'Continue Calculus I',
          subtitle: 'Limits, derivatives, applications',
          meta: 'Current track   •   58% complete',
          icon: Icons.show_chart_rounded,
          color: WicaraColors.secondary,
          onContinue: onContinue,
        ),
        const SizedBox(height: 12),
        _TrackCard(
          title: 'Linear Algebra',
          subtitle: 'Vectors, matrices, transformations',
          meta: 'Created track   •   12% complete',
          icon: Icons.grid_4x4_rounded,
          color: WicaraColors.primary,
          onContinue: onContinue,
        ),
        const SizedBox(height: 12),
        _TrackCard(
          title: 'Discrete Math',
          subtitle: 'Logic, sets, graphs, counting',
          meta: 'Created track   •   ready to continue',
          icon: Icons.hub_outlined,
          color: WicaraColors.accentCoral,
          onContinue: onContinue,
        ),
      ],
    );
  }
}

class _GalleryQueueContent extends StatelessWidget {
  const _GalleryQueueContent({required this.onOpenDetail});

  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          padding: const EdgeInsets.fromLTRB(19, 18, 19, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: WicaraColors.secondarySoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.video_library_outlined,
                      color: WicaraColors.secondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      copy.contentGalleryLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                copy.contentGalleryDescription,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _GalleryArtifactCard(
          title: 'Derivatives intuition',
          subtitle: 'What does a derivative tell us?',
          duration: '06:45',
          onTap: onOpenDetail,
        ),
        const SizedBox(height: 12),
        const _GalleryArtifactCard(
          title: 'Limits from graphs',
          subtitle: 'Approaching a value without touching it',
          duration: '04:18',
        ),
      ],
    );
  }
}

class _GalleryArtifactCard extends StatelessWidget {
  const _GalleryArtifactCard({
    required this.title,
    required this.subtitle,
    required this.duration,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String duration;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: _Panel(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Container(
                width: 92,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF181D27),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: CustomPaint(painter: _MiniDerivativePreviewPainter()),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    color: WicaraColors.secondary,
                    size: 31,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    duration,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryVideoDetail extends StatelessWidget {
  const _GalleryVideoDetail({required this.constraints, required this.onBack});

  final BoxConstraints constraints;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 132),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(onBack: onBack),
            const SizedBox(height: 32),
            Text(
              'Derivatives intuition',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 22, height: 1.12),
            ),
            const SizedBox(height: 5),
            Text(
              'What does a derivative tell us?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            const _GeneratedMathVideoPlayer(),
            const SizedBox(height: 18),
            const _VideoNotesCard(),
          ],
        ),
      ),
    );
  }
}

class _GeneratedMathVideoPlayer extends StatelessWidget {
  const _GeneratedMathVideoPlayer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 442,
      decoration: BoxDecoration(
        color: const Color(0xFF151A24),
        borderRadius: BorderRadius.circular(3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 13, 12, 7),
              child: CustomPaint(
                painter: _DerivativeScenePainter(),
                child: SizedBox.expand(),
              ),
            ),
          ),
          Container(
            height: 140,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF111722).withValues(alpha: 0.98),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PlaybackIcon(icon: Icons.replay_10_rounded, label: '10'),
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.pause_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    _PlaybackIcon(icon: Icons.forward_10_rounded, label: '10'),
                    Container(
                      height: 35,
                      padding: const EdgeInsets.symmetric(horizontal: 17),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '1.0x',
                        style: TextStyle(
                          color: Color(0xFFD8DEEA),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final played = constraints.maxWidth * 0.36;
                    return Column(
                      children: [
                        SizedBox(
                          height: 18,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C3340),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              Container(
                                width: played,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: WicaraColors.secondary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              Positioned(
                                left: played - 9,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '02:14',
                              style: TextStyle(
                                color: Color(0xFF848E9F),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '06:45',
                              style: TextStyle(
                                color: Color(0xFF848E9F),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackIcon extends StatelessWidget {
  const _PlaybackIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 30),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoNotesCard extends StatelessWidget {
  const _VideoNotesCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: WicaraColors.secondarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sticky_note_2_outlined,
                  color: WicaraColors.secondary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Cheatsheet summary',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A derivative measures how fast a function changes at one exact input. For a graph, that value is the slope of the tangent line at the point.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.text,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 13),
          const _NoteLine('Function in the video: f(x) = x².'),
          const _NoteLine('Point on the curve: (x, x²).'),
          const _NoteLine('Instant slope for x²: f′(x) = 2x.'),
          const _NoteLine('As x moves right, the tangent gets steeper.'),
          const _NoteLine('At x = 0, the tangent is flat, so the slope is 0.'),
          const _NoteLine('Use the tangent line to estimate local change.'),
        ],
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 5, color: WicaraColors.secondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w600,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDerivativePreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawDerivativeScene(canvas, size, compact: true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DerivativeScenePainter extends CustomPainter {
  const _DerivativeScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    _drawDerivativeScene(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void _drawDerivativeScene(Canvas canvas, Size size, {bool compact = false}) {
  final axis = Paint()
    ..color = const Color(0xFFAAB2C2)
    ..strokeWidth = compact ? 1 : 1.6
    ..strokeCap = StrokeCap.round;
  final curve = Paint()
    ..color = const Color(0xFF839CFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = compact ? 2 : 2.5
    ..strokeCap = StrokeCap.round;
  final tangent = Paint()
    ..color = const Color(0xFFA987E7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = compact ? 1.6 : 2.2
    ..strokeCap = StrokeCap.round;

  final origin = Offset(size.width * 0.43, size.height * 0.72);
  final xEnd = Offset(size.width * 0.94, origin.dy);
  final xStart = Offset(size.width * 0.06, origin.dy);
  final yTop = Offset(origin.dx, size.height * 0.12);
  final yBottom = Offset(origin.dx, size.height * 0.91);
  canvas.drawLine(xStart, xEnd, axis);
  canvas.drawLine(yBottom, yTop, axis);

  final arrow = Path()
    ..moveTo(xEnd.dx - 6, xEnd.dy - 4)
    ..lineTo(xEnd.dx, xEnd.dy)
    ..lineTo(xEnd.dx - 6, xEnd.dy + 4)
    ..moveTo(yTop.dx - 4, yTop.dy + 6)
    ..lineTo(yTop.dx, yTop.dy)
    ..lineTo(yTop.dx + 4, yTop.dy + 6);
  canvas.drawPath(arrow, axis);

  final path = Path();
  for (var i = 0; i <= 120; i++) {
    final t = -1.35 + (i / 120) * 2.7;
    final x = origin.dx + t * size.width * 0.24;
    final y = origin.dy - (t * t) * size.height * 0.26;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  canvas.drawPath(path, curve);

  final point = Offset(
    origin.dx + size.width * 0.16,
    origin.dy - size.height * 0.19,
  );
  canvas.drawLine(
    Offset(point.dx - size.width * 0.14, point.dy + size.height * 0.22),
    Offset(point.dx + size.width * 0.16, point.dy - size.height * 0.24),
    tangent,
  );
  canvas.drawCircle(point, compact ? 3 : 6, Paint()..color = Colors.white);

  if (compact) {
    return;
  }

  final titleStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.9),
    fontSize: 21,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
  );
  _paintText(
    canvas,
    'f(x) = x²',
    Offset(size.width * 0.39, size.height * 0.03),
    titleStyle,
  );
  _paintText(
    canvas,
    'y',
    Offset(origin.dx + 12, size.height * 0.14),
    titleStyle.copyWith(fontSize: 16),
  );
  _paintText(
    canvas,
    'x',
    Offset(size.width * 0.9, origin.dy + 16),
    titleStyle.copyWith(fontSize: 16),
  );
  _paintText(
    canvas,
    '(x, x²)',
    Offset(point.dx + 3, point.dy + 25),
    titleStyle.copyWith(fontSize: 16),
  );
  _paintText(
    canvas,
    'Slope of\ntangent line\n= 2x',
    Offset(size.width * 0.73, size.height * 0.34),
    titleStyle.copyWith(
      color: const Color(0xFFA987E7),
      fontSize: 18,
      height: 1.22,
    ),
  );
}

void _paintText(Canvas canvas, String text, Offset offset, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, offset);
}

class _PriorityCallout extends StatelessWidget {
  const _PriorityCallout();

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(19, 18, 19, 18),
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: WicaraColors.secondary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.wb_sunny_outlined,
            color: WicaraColors.secondary,
            size: 21,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              copy.recommendedForCurrentReadinessLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w600,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueLessonCard extends StatelessWidget {
  const _QueueLessonCard({
    required this.index,
    required this.title,
    required this.subject,
    required this.reason,
    required this.meta,
    required this.action,
    this.badge,
    this.iconText,
    this.iconData,
    this.isPrimary = false,
    this.onActionPressed,
  });

  final String index;
  final String title;
  final String subject;
  final String reason;
  final String meta;
  final String action;
  final String? badge;
  final String? iconText;
  final IconData? iconData;
  final bool isPrimary;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (index.isNotEmpty) ...[
                          _NumberBadge(index),
                          const SizedBox(width: 10),
                        ],
                        if (badge != null) _SoftBadge(badge!),
                      ],
                    ),
                    if (index.isNotEmpty || badge != null)
                      const SizedBox(height: 11),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subject,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        reason,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: WicaraColors.muted,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 13),
              _LessonGlyph(text: iconText, icon: iconData, size: 64),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _LessonMeta(meta)),
              if (action.isNotEmpty) ...[
                const SizedBox(width: 12),
                _SmallActionButton(
                  label: action,
                  filled: isPrimary,
                  onPressed: onActionPressed,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LessonMeta extends StatelessWidget {
  const _LessonMeta(this.meta);

  final String meta;

  @override
  Widget build(BuildContext context) {
    final parts = meta.split('•').map((part) => part.trim()).toList();

    final duration = parts.isNotEmpty ? parts.first : meta;
    final difficulty = parts.length > 1 ? parts.last : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          duration,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: WicaraColors.softMuted,
            fontWeight: FontWeight.w600,
          ),
        ),

        if (difficulty.isNotEmpty) ...[
          const SizedBox(width: 10),

          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: WicaraColors.softMuted,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 10),

          _DifficultyBadge(label: difficulty),
        ],
      ],
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.label});

  final String label;

  Color get _foreground {
    return switch (label.toLowerCase()) {
      'easy' => WicaraColors.accentMint,
      'medium' => WicaraColors.accentAmber,
      'hard' => WicaraColors.accentCoral,
      _ => WicaraColors.primaryDeep,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: _foreground,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.filled,
    this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? WicaraColors.secondary : Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 35,
          width: 112,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: filled
                ? null
                : Border.all(
                    color: WicaraColors.secondary.withValues(alpha: 0.34),
                    width: 1.4,
                  ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: filled ? Colors.white : WicaraColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
    required this.color,
    required this.onContinue,
  });

  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;
  final Color color;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.text,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: _TrackActionButton(
              filled: title == 'Continue Calculus I',
              onPressed: onContinue,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackActionButton extends StatelessWidget {
  const _TrackActionButton({required this.filled, required this.onPressed});

  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return Material(
      color: filled ? WicaraColors.secondary : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 39,
          constraints: const BoxConstraints(minWidth: 154),
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: filled
                ? null
                : Border.all(
                    color: WicaraColors.secondary.withValues(alpha: 0.34),
                    width: 1.4,
                  ),
          ),
          alignment: Alignment.center,
          child: Text(
            copy.continueLearningLabel,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: filled ? Colors.white : WicaraColors.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _NewTrackCard extends StatelessWidget {
  const _NewTrackCard({required this.onCreateTrack});

  final VoidCallback onCreateTrack;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: WicaraColors.glowPeach,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: WicaraColors.accentCoral,
                  size: 29,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.learnSomethingNewLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      copy.newTrackDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: _NewTrackActionButton(onPressed: onCreateTrack),
          ),
        ],
      ),
    );
  }
}

class _NewTrackActionButton extends StatelessWidget {
  const _NewTrackActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 39,
          constraints: const BoxConstraints(minWidth: 118),
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(
            color: WicaraColors.secondary,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            copy.newTrackLabel,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutBar extends StatelessWidget {
  const _ShortcutBar({
    required this.selectedTab,
    required this.onSelected,
    super.key,
  });

  final _HomeTab selectedTab;
  final ValueChanged<_HomeTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return Container(
      height: 78,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            WicaraColors.primarySoft,
            WicaraColors.secondarySoft,
          ],
        ),
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: WicaraColors.primaryLight.withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.secondaryDeep.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.42),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _ShortcutItem(
            tab: _HomeTab.home,
            selectedTab: selectedTab,
            icon: Icons.home_rounded,
            label: copy.homeLabel,
            onSelected: onSelected,
          ),
          _ShortcutItem(
            tab: _HomeTab.queue,
            selectedTab: selectedTab,
            icon: Icons.school_outlined,
            label: copy.learnLabel,
            onSelected: onSelected,
          ),
          _ShortcutItem(
            tab: _HomeTab.progress,
            selectedTab: selectedTab,
            icon: Icons.bar_chart_rounded,
            label: copy.progressLabel,
            onSelected: onSelected,
          ),
          _ShortcutItem(
            tab: _HomeTab.profile,
            selectedTab: selectedTab,
            icon: Icons.person_outline_rounded,
            label: copy.profileTitle,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  const _ShortcutItem({
    required this.tab,
    required this.selectedTab,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final _HomeTab tab;
  final _HomeTab selectedTab;
  final IconData icon;
  final String label;
  final ValueChanged<_HomeTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = tab == selectedTab;
    final activeColor = WicaraColors.secondaryDeep;
    final inactiveColor = WicaraColors.muted;

    return Expanded(
      child: InkWell(
        onTap: () => onSelected(tab),
        borderRadius: BorderRadius.circular(24),
        splashColor: WicaraColors.secondary.withValues(alpha: 0.10),
        highlightColor: WicaraColors.secondarySoft.withValues(alpha: 0.38),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? WicaraColors.secondaryDeep
                  : Colors.transparent,
              width: 1.1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: WicaraColors.secondaryDeep.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : inactiveColor,
                size: isSelected ? 24 : 23,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected ? Colors.white : inactiveColor,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.constraints,
    required this.snapshot,
    required this.onBack,
    required this.authController,
    required this.onboardingController,
    required this.onProfileSaved,
  });

  final BoxConstraints constraints;
  final HomeSnapshot snapshot;
  final VoidCallback onBack;
  final AuthController authController;
  final OnboardingController onboardingController;
  final VoidCallback onProfileSaved;

  Future<void> _persistProfileUpdate(
    BuildContext context,
    Future<void> Function() update,
  ) async {
    final copy = OnboardingCopy.forLanguage(
      onboardingController.profile.preferredLanguage,
    );

    try {
      await onboardingController.replaceProfile(_profileFromSnapshot());
      await update();
      await onboardingController.saveProfile();
      onProfileSaved();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              copy.isIndonesian
                  ? 'Profil berhasil diperbarui.'
                  : 'Profile updated.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _editCountry(BuildContext context, OnboardingCopy copy) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SearchableProfileOptionSheet(
        title: copy.countryLabel,
        options: onboardingCountryOptions,
        initialValue: snapshot.country,
        searchHint: copy.searchLabel,
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (selected != null) {
      await _persistProfileUpdate(
        context,
        () => onboardingController.updateCountry(selected),
      );
    }
  }

  Future<void> _editGradeLevel(
    BuildContext context,
    OnboardingCopy copy,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ProfileOptionSheet(
        title: copy.gradeLevelLabel,
        options: onboardingGradeLevelOptions,
        initialValue: snapshot.gradeLevel,
        displayFor: copy.gradeValue,
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (selected != null) {
      await _persistProfileUpdate(
        context,
        () => onboardingController.updateGradeLevel(selected),
      );
    }
  }

  Future<void> _editLanguage(BuildContext context, OnboardingCopy copy) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ProfileOptionSheet(
        title: copy.languageLabel,
        options: onboardingLanguageOptions,
        initialValue: snapshot.preferredLanguage,
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (selected != null && selected != snapshot.preferredLanguage) {
      await _persistProfileUpdate(
        context,
        () => onboardingController.updatePreferredLanguage(selected),
      );
    }
  }

  Future<void> _editStudyGoal(BuildContext context, OnboardingCopy copy) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ProfileOptionSheet(
        title: copy.studyGoalLabel,
        options: onboardingStudyGoalOptions,
        initialValue: snapshot.studyGoal,
        displayFor: copy.studyGoalDisplay,
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (selected != null) {
      await _persistProfileUpdate(
        context,
        () => onboardingController.updateStudyGoal(selected),
      );
    }
  }

  Future<void> _editDailyStudyTime(
    BuildContext context,
    OnboardingCopy copy,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ProfileOptionSheet(
        title: copy.dailyStudyTimeLabel,
        options: onboardingDailyStudyTimeOptions,
        initialValue: snapshot.dailyStudyTime,
        displayFor: copy.dailyStudyTimeDisplay,
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (selected != null) {
      await _persistProfileUpdate(
        context,
        () => onboardingController.updateDailyStudyTime(selected),
      );
    }
  }

  Future<void> _editSubjects(BuildContext context, OnboardingCopy copy) async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SubjectSelectionSheet(
        title: copy.subjectsLabel,
        selectedSubjects: snapshot.selectedSubjects,
        copy: copy,
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (selected != null) {
      await _persistProfileUpdate(
        context,
        () => onboardingController.updateSelectedSubjects(selected),
      );
    }
  }

  Future<void> _editFullName(BuildContext context, OnboardingCopy copy) async {
    var draftName = snapshot.displayName;
    final submitted = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(copy.fullNameLabel),
          content: TextFormField(
            initialValue: draftName,
            autofocus: true,
            decoration: InputDecoration(hintText: copy.fullNameLabel),
            textInputAction: TextInputAction.done,
            onChanged: (value) => draftName = value,
            onFieldSubmitted: (value) =>
                Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(copy.cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(draftName.trim()),
              child: Text(copy.applyLabel),
            ),
          ],
        );
      },
    );

    if (!context.mounted) {
      return;
    }
    if (submitted != null && submitted.isNotEmpty) {
      await _persistProfileUpdate(
        context,
        () => onboardingController.updateFullName(submitted),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await authController.signOut();
    if (!context.mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = onboardingController.profile;
    final copy = OnboardingCopy.forLanguage(profile.preferredLanguage);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 136),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(onBack: onBack),
            const SizedBox(height: 34),
            _SectionWordmark(
              assetPath: 'lib/src/assets/profileIcon.png',
              title: copy.profileTitle,
              iconSize: 84,
            ),
            const SizedBox(height: 12),
            Text(
              copy.profileSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            _ProfileHeaderCard(
              snapshot: snapshot,
              roleLabel: copy.learnerLabel,
            ),
            const SizedBox(height: 22),
            _ProfileSection(
              title: copy.learningSetupTitle,
              children: [
                _ProfileSettingTile(
                  icon: Icons.person_outline_rounded,
                  label: copy.fullNameLabel,
                  value: snapshot.displayName,
                  onTap: () => _editFullName(context, copy),
                ),
                _ProfileSettingTile(
                  icon: Icons.public_rounded,
                  label: copy.countryLabel,
                  value: snapshot.country,
                  onTap: () => _editCountry(context, copy),
                ),
                _ProfileSettingTile(
                  icon: Icons.school_outlined,
                  label: copy.gradeLevelLabel,
                  value: _displayGradeSummary(snapshot, copy),
                  onTap: () => _editGradeLevel(context, copy),
                ),
                _ProfileSettingTile(
                  icon: Icons.language_rounded,
                  label: copy.languageLabel,
                  value: copy.languageDisplay(snapshot.preferredLanguage),
                  onTap: () => _editLanguage(context, copy),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ProfileSection(
              title: copy.preferencesSectionTitle,
              children: [
                _ProfileSettingTile(
                  icon: Icons.menu_book_outlined,
                  label: copy.subjectsLabel,
                  value: snapshot.selectedSubjects
                      .map(copy.subjectLabel)
                      .join(', '),
                  onTap: () => _editSubjects(context, copy),
                ),
                _ProfileSettingTile(
                  icon: Icons.track_changes_rounded,
                  label: copy.studyGoalLabel,
                  value: copy.studyGoalDisplay(snapshot.studyGoal),
                  onTap: () => _editStudyGoal(context, copy),
                ),
                _ProfileSettingTile(
                  icon: Icons.schedule_rounded,
                  label: copy.dailyStudyTimeLabel,
                  value: copy.dailyStudyTimeDisplay(snapshot.dailyStudyTime),
                  onTap: () => _editDailyStudyTime(context, copy),
                ),
              ],
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => _logout(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WicaraColors.line, width: 1.4),
                foregroundColor: const Color(0xFFE57373),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: Text(copy.logoutLabel),
            ),
          ],
        ),
      ),
    );
  }

  OnboardingProfile _profileFromSnapshot() {
    return OnboardingProfile(
      fullName: snapshot.displayName,
      country: snapshot.country,
      educationLevel: snapshot.educationLevel,
      gradeLevel: snapshot.gradeLevel,
      preferredLanguage: snapshot.preferredLanguage,
      selectedSubjects: snapshot.selectedSubjects,
      studyGoal: snapshot.studyGoal,
      dailyStudyTime: snapshot.dailyStudyTime,
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.snapshot, required this.roleLabel});

  final HomeSnapshot snapshot;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: WicaraColors.secondarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              snapshot.initials,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: WicaraColors.secondaryDeep,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  roleLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileSettingTile extends StatelessWidget {
  const _ProfileSettingTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: WicaraColors.speechBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: WicaraColors.secondary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: WicaraColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: WicaraColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: onTap == null
                      ? WicaraColors.softMuted
                      : WicaraColors.secondary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileOptionSheet extends StatelessWidget {
  const _ProfileOptionSheet({
    required this.title,
    required this.options,
    required this.initialValue,
    this.displayFor,
  });

  final String title;
  final List<String> options;
  final String initialValue;
  final String Function(String value)? displayFor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option == initialValue;
                  return ListTile(
                    title: Text(displayFor?.call(option) ?? option),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: WicaraColors.secondary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchableProfileOptionSheet extends StatefulWidget {
  const _SearchableProfileOptionSheet({
    required this.title,
    required this.options,
    required this.initialValue,
    required this.searchHint,
  });

  final String title;
  final List<String> options;
  final String initialValue;
  final String searchHint;

  @override
  State<_SearchableProfileOptionSheet> createState() =>
      _SearchableProfileOptionSheetState();
}

class _SearchableProfileOptionSheetState
    extends State<_SearchableProfileOptionSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final filteredOptions = widget.options.where((option) {
      if (query.isEmpty) {
        return true;
      }
      return option.toLowerCase().contains(query);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: WicaraColors.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filteredOptions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = filteredOptions[index];
                  final isSelected = option == widget.initialValue;
                  return ListTile(
                    title: Text(option),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: WicaraColors.secondary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectSelectionSheet extends StatefulWidget {
  const _SubjectSelectionSheet({
    required this.title,
    required this.selectedSubjects,
    required this.copy,
  });

  final String title;
  final List<String> selectedSubjects;
  final OnboardingCopy copy;

  @override
  State<_SubjectSelectionSheet> createState() => _SubjectSelectionSheetState();
}

class _SubjectSelectionSheetState extends State<_SubjectSelectionSheet> {
  late final List<String> _selectedSubjects = [...widget.selectedSubjects];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: onboardingSubjectOptions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final subject = onboardingSubjectOptions[index];
                  final isSelected = _selectedSubjects.contains(subject.key);
                  return SubjectTile(
                    title: widget.copy.subjectLabel(subject.key),
                    description: widget.copy.subjectDescription(subject.key),
                    icon: subject.icon,
                    tint: subject.tint,
                    isSelected: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value) {
                          if (!_selectedSubjects.contains(subject.key)) {
                            _selectedSubjects.add(subject.key);
                          }
                        } else {
                          _selectedSubjects.remove(subject.key);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_selectedSubjects),
                child: Text(widget.copy.applyLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHub extends StatelessWidget {
  const _ProgressHub({
    required this.constraints,
    required this.homeRepository,
    required this.curriculumRepository,
    required this.onBack,
    required this.showLearningReport,
    required this.showKnowledgeMap,
    required this.onOpenLearningReport,
    required this.onCloseLearningReport,
    required this.onOpenKnowledgeMap,
    required this.onCloseKnowledgeMap,
    required this.onRecommendationSelected,
  });

  final BoxConstraints constraints;
  final HomeRepository homeRepository;
  final CurriculumRepository curriculumRepository;
  final VoidCallback onBack;
  final bool showLearningReport;
  final bool showKnowledgeMap;
  final VoidCallback onOpenLearningReport;
  final VoidCallback onCloseLearningReport;
  final VoidCallback onOpenKnowledgeMap;
  final VoidCallback onCloseKnowledgeMap;
  final ValueChanged<RecommendedNextAction> onRecommendationSelected;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    if (showLearningReport) {
      return _LearningReportDetail(
        constraints: constraints,
        homeRepository: homeRepository,
        onBack: onCloseLearningReport,
        onRecommendationSelected: onRecommendationSelected,
      );
    }
    if (showKnowledgeMap) {
      return _KnowledgeMapDetail(
        constraints: constraints,
        curriculumRepository: curriculumRepository,
        onBack: onCloseKnowledgeMap,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 136),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(onBack: onBack),
            const SizedBox(height: 34),
            _SectionWordmark(
              assetPath: 'lib/src/assets/progressIcon.png',
              title: copy.progressLabel,
              iconSize: 84,
            ),
            const SizedBox(height: 12),
            Text(
              copy.progressSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 28),
            _LearningReportOption(
              homeRepository: homeRepository,
              onOpen: onOpenLearningReport,
            ),
            const SizedBox(height: 22),
            _KnowledgeMapOption(onOpen: onOpenKnowledgeMap),
          ],
        ),
      ),
    );
  }
}

class _LearningReportOption extends StatefulWidget {
  const _LearningReportOption({
    required this.homeRepository,
    required this.onOpen,
  });

  final HomeRepository homeRepository;
  final VoidCallback onOpen;

  @override
  State<_LearningReportOption> createState() => _LearningReportOptionState();
}

class _LearningReportOptionState extends State<_LearningReportOption> {
  late Future<WeeklyLearningReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _fetchCurrentWeekReport();
  }

  @override
  void didUpdateWidget(covariant _LearningReportOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeRepository != widget.homeRepository) {
      _reportFuture = _fetchCurrentWeekReport();
    }
  }

  Future<WeeklyLearningReport> _fetchCurrentWeekReport() {
    final range = _reportRangeFor(_ReportRangeOption.thisWeek, DateTime.now());
    return widget.homeRepository.fetchWeeklyLearningReport(
      start: range.start,
      end: range.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return _ProgressOptionPanel(
      onTap: widget.onOpen,
      icon: Icons.analytics_outlined,
      iconColor: WicaraColors.primaryDeep,
      iconBackground: WicaraColors.speechBlue,
      title: copy.learningReportLabel,
      subtitle: copy.learningReportDescription,
      child: FutureBuilder<WeeklyLearningReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          final report = snapshot.data;
          if (report != null) {
            return _LearningReportPreview(report: report);
          }
          if (snapshot.hasError) {
            return const _LearningReportPreviewState(
              label: 'Report unavailable',
              badge: 'Open detail',
              message: 'Open the report to retry loading backend data.',
            );
          }
          return const _LearningReportPreviewState(
            label: 'Loading current week',
            badge: 'Syncing',
            message: 'Fetching learning performance from backend attempts.',
          );
        },
      ),
    );
  }
}

class _LearningReportPreview extends StatelessWidget {
  const _LearningReportPreview({required this.report});

  final WeeklyLearningReport report;

  @override
  Widget build(BuildContext context) {
    final fixed =
        report.gapMetrics['fixed'] ??
        GapMetric(
          count: report.fixedGaps,
          weeklyDelta: report.fixedGapsDelta,
          deltaLabel: '+${report.fixedGapsDelta} this week',
        );
    final remaining =
        report.gapMetrics['remaining'] ??
        GapMetric(
          count: report.remainingGaps,
          weeklyDelta: report.remainingGapsDelta,
          deltaLabel: '${report.remainingGapsDelta} this week',
        );
    final groups = report.performanceGroups.take(3).toList(growable: false);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                report.rangeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _SoftBadge(fixed.deltaLabel),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 112,
          child: groups.isEmpty
              ? const _LearningReportPreviewState(
                  label: 'No performance data yet',
                  badge: 'Start',
                  message: 'Take a daily evaluation to build the graph.',
                  compact: true,
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var index = 0; index < groups.length; index++) ...[
                      _ReportBarGroup(
                        label: groups[index].label,
                        before: groups[index].preTestRatio,
                        after: groups[index].postTestRatio,
                      ),
                      if (index < groups.length - 1) const SizedBox(width: 18),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _ReportMetric(
                label: 'Fixed gaps',
                value: '${fixed.count}',
                delta: fixed.deltaLabel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ReportMetric(
                label: 'Remaining gaps',
                value: '${remaining.count}',
                delta: remaining.deltaLabel,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LearningReportPreviewState extends StatelessWidget {
  const _LearningReportPreviewState({
    required this.label,
    required this.badge,
    required this.message,
    this.compact = false,
  });

  final String label;
  final String badge;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: WicaraColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _SoftBadge(badge),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(
            color: WicaraColors.pageBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WicaraColors.line),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LearningReportDetail extends StatefulWidget {
  const _LearningReportDetail({
    required this.constraints,
    required this.homeRepository,
    required this.onBack,
    required this.onRecommendationSelected,
  });

  final BoxConstraints constraints;
  final HomeRepository homeRepository;
  final VoidCallback onBack;
  final ValueChanged<RecommendedNextAction> onRecommendationSelected;

  @override
  State<_LearningReportDetail> createState() => _LearningReportDetailState();
}

class _LearningReportDetailState extends State<_LearningReportDetail> {
  _ReportRangeOption _selectedRange = _ReportRangeOption.thisWeek;
  late Future<WeeklyLearningReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _fetchSelectedReport();
  }

  void _retryReport() {
    setState(() {
      _reportFuture = _fetchSelectedReport();
    });
  }

  Future<WeeklyLearningReport> _fetchSelectedReport() {
    final range = _reportRangeFor(_selectedRange, DateTime.now());
    return widget.homeRepository.fetchWeeklyLearningReport(
      start: range.start,
      end: range.end,
    );
  }

  void _selectRange(_ReportRangeOption option) {
    setState(() {
      _selectedRange = option;
      _reportFuture = _fetchSelectedReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeeklyLearningReport>(
      future: _reportFuture,
      builder: (context, snapshot) {
        final report = snapshot.data;
        if (report != null) {
          return _LearningReportContent(
            constraints: widget.constraints,
            report: report,
            onBack: widget.onBack,
            selectedRange: _selectedRange,
            onRangeSelected: _selectRange,
            onRecommendationSelected: widget.onRecommendationSelected,
          );
        }
        if (snapshot.hasError) {
          return _DashboardStatePage(
            constraints: widget.constraints,
            title: 'Learning Report unavailable',
            message: snapshot.error.toString(),
            actionLabel: 'Try again',
            onAction: _retryReport,
          );
        }
        return _DashboardStatePage(
          constraints: widget.constraints,
          title: 'Loading Learning Report',
          message: 'Fetching weekly gap and recommendation data.',
        );
      },
    );
  }
}

class _LearningReportContent extends StatelessWidget {
  const _LearningReportContent({
    required this.constraints,
    required this.report,
    required this.onBack,
    required this.selectedRange,
    required this.onRangeSelected,
    required this.onRecommendationSelected,
  });

  final BoxConstraints constraints;
  final WeeklyLearningReport report;
  final VoidCallback onBack;
  final _ReportRangeOption selectedRange;
  final ValueChanged<_ReportRangeOption> onRangeSelected;
  final ValueChanged<RecommendedNextAction> onRecommendationSelected;

  @override
  Widget build(BuildContext context) {
    final fixed =
        report.gapMetrics['fixed'] ??
        GapMetric(
          count: report.fixedGaps,
          weeklyDelta: report.fixedGapsDelta,
          deltaLabel: '+${report.fixedGapsDelta} this week',
        );
    final remaining =
        report.gapMetrics['remaining'] ??
        GapMetric(
          count: report.remainingGaps,
          weeklyDelta: report.remainingGapsDelta,
          deltaLabel: '${report.remainingGapsDelta} this week',
        );
    final copy = _HomeCopyScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 136),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(onBack: onBack),
            const SizedBox(height: 38),
            Row(
              children: [
                Expanded(
                  child: Text(
                    copy.learningReportLabel,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      height: 1.12,
                    ),
                  ),
                ),
                _SoftBadge(copy.completeLabel),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              copy.learningReportHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: _DateRangePill(
                label: report.rangeLabel,
                selectedRange: selectedRange,
                onRangeSelected: onRangeSelected,
              ),
            ),
            const SizedBox(height: 18),
            _ReportPerformancePanel(report: report),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ReportMetric(
                    label: copy.fixedGapsLabel,
                    value: '${fixed.count}',
                    delta: fixed.deltaLabel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReportMetric(
                    label: copy.remainingGapsLabel,
                    value: '${remaining.count}',
                    delta: remaining.deltaLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _UnlockedThisWeekCard(summary: report.unlockedThisWeek),
            const SizedBox(height: 18),
            _UpcomingRecommendationsPanel(
              recommendations: report.upcomingRecommendations,
              onRecommendationSelected: onRecommendationSelected,
            ),
            const SizedBox(height: 18),
            _ConsistencySummaryCard(summary: report.consistencySummary),
          ],
        ),
      ),
    );
  }
}

class _DateRangePill extends StatelessWidget {
  const _DateRangePill({
    required this.label,
    required this.selectedRange,
    required this.onRangeSelected,
  });

  final String label;
  final _ReportRangeOption selectedRange;
  final ValueChanged<_ReportRangeOption> onRangeSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ReportRangeOption>(
      initialValue: selectedRange,
      onSelected: onRangeSelected,
      itemBuilder: (context) => [
        for (final option in _ReportRangeOption.values)
          PopupMenuItem(
            value: option,
            child: Text(_reportRangeOptionLabel(option)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: WicaraColors.line),
          boxShadow: [
            BoxShadow(
              color: WicaraColors.shadowBlue.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: WicaraColors.ink,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportDateRange {
  const _ReportDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

_ReportDateRange _reportRangeFor(_ReportRangeOption option, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final thisMonday = today.subtract(Duration(days: today.weekday - 1));
  return switch (option) {
    _ReportRangeOption.thisWeek => _ReportDateRange(
      start: thisMonday,
      end: thisMonday.add(const Duration(days: 6)),
    ),
    _ReportRangeOption.lastWeek => _ReportDateRange(
      start: thisMonday.subtract(const Duration(days: 7)),
      end: thisMonday.subtract(const Duration(days: 1)),
    ),
    _ReportRangeOption.last4Weeks => _ReportDateRange(
      start: today.subtract(const Duration(days: 27)),
      end: today,
    ),
  };
}

String _reportRangeOptionLabel(_ReportRangeOption option) {
  return switch (option) {
    _ReportRangeOption.thisWeek => 'This week',
    _ReportRangeOption.lastWeek => 'Last week',
    _ReportRangeOption.last4Weeks => 'Last 4 weeks',
  };
}

class _ReportPerformancePanel extends StatelessWidget {
  const _ReportPerformancePanel({required this.report});

  final WeeklyLearningReport report;

  @override
  Widget build(BuildContext context) {
    final groups = report.performanceGroups;

    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Learning performance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Pre-test vs Post-test',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _ReportLegendDot(
                label: 'Pre-test',
                color: WicaraColors.primaryLight,
              ),
              SizedBox(width: 18),
              _ReportLegendDot(
                label: 'Post-test',
                color: WicaraColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (groups.isEmpty)
            const _EmptyReportPerformanceState()
          else
            SizedBox(
              height: 144,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < groups.length; index++) ...[
                    _ReportBarGroup(
                      label: groups[index].label,
                      before: groups[index].preTestRatio,
                      after: groups[index].postTestRatio,
                    ),
                    if (index < groups.length - 1) const SizedBox(width: 18),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyReportPerformanceState extends StatelessWidget {
  const _EmptyReportPerformanceState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: WicaraColors.pageBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Text(
        'No assessment attempts in this range yet. Take a daily evaluation to build this graph.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: WicaraColors.muted,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ReportLegendDot extends StatelessWidget {
  const _ReportLegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: WicaraColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _UnlockedThisWeekCard extends StatelessWidget {
  const _UnlockedThisWeekCard({required this.summary});

  final UnlockedConceptSummary summary;

  @override
  Widget build(BuildContext context) {
    final concepts = summary.concepts.take(5).toList(growable: false);
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Unlocked this week',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.person_outline_rounded,
                color: WicaraColors.primaryDeep,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${summary.count}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'New concepts',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (concepts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final concept in concepts)
                  _UnlockedConceptChip(label: concept),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UnlockedConceptChip extends StatelessWidget {
  const _UnlockedConceptChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: WicaraColors.primaryDeep,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UpcomingRecommendationsPanel extends StatelessWidget {
  const _UpcomingRecommendationsPanel({
    required this.recommendations,
    required this.onRecommendationSelected,
  });

  final List<RecommendedNextAction> recommendations;
  final ValueChanged<RecommendedNextAction> onRecommendationSelected;

  @override
  Widget build(BuildContext context) {
    final rows = recommendations.isEmpty
        ? const [
            RecommendedNextAction(
              title: 'Review due concepts',
              actionType: 'review',
              reason: 'Due this week',
            ),
          ]
        : recommendations;
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upcoming recommendations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          for (final recommendation in rows) ...[
            _ReportRecommendationTile(
              recommendation: recommendation,
              onSelected: onRecommendationSelected,
            ),
            if (recommendation != rows.last) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _ReportRecommendationTile extends StatelessWidget {
  const _ReportRecommendationTile({
    required this.recommendation,
    required this.onSelected,
  });

  final RecommendedNextAction recommendation;
  final ValueChanged<RecommendedNextAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => onSelected(recommendation),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 10, 9, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: WicaraColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _actionBackground(recommendation.actionType),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _actionIcon(recommendation.actionType),
                  color: _actionColor(recommendation.actionType),
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      recommendation.dueLabel ?? recommendation.reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: WicaraColors.softMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsistencySummaryCard extends StatelessWidget {
  const _ConsistencySummaryCard({required this.summary});

  final ConsistencySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1F4FF), Color(0xFFF6EFFF)],
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.secondaryDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary.narrative,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'W',
            style: TextStyle(
              color: WicaraColors.secondaryLight,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReportData {
  const _WeeklyReportData({
    required this.range,
    required this.score,
    required this.fixed,
    required this.remaining,
    required this.retention,
    required this.overall,
    required this.application,
    required this.analysis,
    required this.concepts,
  });

  final String range;
  final int score;
  final int fixed;
  final int remaining;
  final int retention;
  final double overall;
  final double application;
  final double analysis;
  final String concepts;
}

class _WeeklyReportSnapshot extends StatelessWidget {
  const _WeeklyReportSnapshot({required this.data});

  final _WeeklyReportData data;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return Row(
      children: [
        Expanded(
          child: _ReportMetric(
            label: copy.scoreLabel,
            value: '${data.score}%',
            delta: copy.retentionDeltaLabel(data.retention),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ReportMetric(
            label: copy.fixedGapsLabel,
            value: '${data.fixed}',
            delta: copy.remainingCountLabel(data.remaining),
          ),
        ),
      ],
    );
  }
}

class _WeeklyHoverTile extends StatelessWidget {
  const _WeeklyHoverTile({
    required this.data,
    required this.weekNumber,
    required this.isSelected,
    required this.onSelected,
  });

  final _WeeklyReportData data;
  final int weekNumber;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    final barColor = isSelected
        ? WicaraColors.primaryDeep
        : WicaraColors.primaryLight;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onSelected(),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 9),
          decoration: BoxDecoration(
            color: isSelected ? WicaraColors.speechBlue : Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isSelected ? WicaraColors.primaryLight : WicaraColors.line,
              width: 1.2,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: WicaraColors.primary.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 7),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                copy.weekLabel(weekNumber),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? WicaraColors.primaryDeep
                      : WicaraColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: data.score / 100,
                    widthFactor: 0.58,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${data.score}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnowledgeMapDetail extends StatefulWidget {
  const _KnowledgeMapDetail({
    required this.constraints,
    required this.curriculumRepository,
    required this.onBack,
  });

  final BoxConstraints constraints;
  final CurriculumRepository curriculumRepository;
  final VoidCallback onBack;

  @override
  State<_KnowledgeMapDetail> createState() => _KnowledgeMapDetailState();
}

class _KnowledgeMapDetailState extends State<_KnowledgeMapDetail> {
  static const _initialVisibleSections = 4;
  static const _sectionBatchSize = 3;
  static const _fallbackSubjects = [
    _SubjectMapItem('math', 'Math', WicaraColors.math, false),
    _SubjectMapItem('physics', 'Physics', WicaraColors.physics, true),
    _SubjectMapItem('chemistry', 'Chemistry', WicaraColors.chemistry, true),
    _SubjectMapItem('biology', 'Biology', WicaraColors.biology, true),
  ];

  _KnowledgeGraph _graph = _mathKnowledgeGraph;
  List<_SubjectMapItem> _subjects = _fallbackSubjects;
  String _selectedSubjectCode = 'math';
  int _visibleSectionCount = _initialVisibleSections;
  _KnowledgeNode? _selectedNode;
  bool _isLoadingCurriculum = true;
  bool _isLoadingMoreSections = false;
  bool _isUsingFallbackGraph = true;
  int _curriculumRequestSerial = 0;

  @override
  void initState() {
    super.initState();
    _loadCurriculum();
  }

  Future<void> _loadCurriculum() async {
    final requestSerial = ++_curriculumRequestSerial;
    try {
      final subjects = await widget.curriculumRepository.fetchSubjects();
      final tabs = _subjectTabsFromApi(subjects);
      final selectedSubjectCode = _defaultSubjectCode(tabs);
      final graph = await widget.curriculumRepository.fetchKnowledgeMap(
        subject: selectedSubjectCode,
      );

      if (!mounted || requestSerial != _curriculumRequestSerial) {
        return;
      }

      setState(() {
        _subjects = tabs;
        _selectedSubjectCode = selectedSubjectCode;
        _graph = _knowledgeGraphFromApi(
          graph,
          focusSubjectCode: selectedSubjectCode,
        );
        _visibleSectionCount = _initialVisibleSections;
        _selectedNode = null;
        _isUsingFallbackGraph = false;
        _isLoadingCurriculum = false;
        _isLoadingMoreSections = false;
      });
    } catch (_) {
      if (!mounted || requestSerial != _curriculumRequestSerial) {
        return;
      }

      setState(() {
        _graph = _mathKnowledgeGraph;
        _subjects = _fallbackSubjects;
        _selectedSubjectCode = 'math';
        _visibleSectionCount = _initialVisibleSections;
        _selectedNode = null;
        _isUsingFallbackGraph = true;
        _isLoadingCurriculum = false;
        _isLoadingMoreSections = false;
      });
    }
  }

  Future<void> _selectSubject(_SubjectMapItem subject) async {
    if (subject.isLocked || subject.code == _selectedSubjectCode) {
      return;
    }

    final requestSerial = ++_curriculumRequestSerial;
    setState(() {
      _selectedSubjectCode = subject.code;
      _isLoadingCurriculum = true;
      _visibleSectionCount = _initialVisibleSections;
      _selectedNode = null;
      _isLoadingMoreSections = false;
    });

    try {
      final graph = await widget.curriculumRepository.fetchKnowledgeMap(
        subject: subject.code,
      );

      if (!mounted || requestSerial != _curriculumRequestSerial) {
        return;
      }

      setState(() {
        _graph = _knowledgeGraphFromApi(graph, focusSubjectCode: subject.code);
        _visibleSectionCount = _initialVisibleSections;
        _selectedNode = null;
        _isUsingFallbackGraph = false;
        _isLoadingCurriculum = false;
        _isLoadingMoreSections = false;
      });
    } catch (_) {
      if (!mounted || requestSerial != _curriculumRequestSerial) {
        return;
      }

      setState(() {
        _graph = _mathKnowledgeGraph;
        _subjects = _fallbackSubjects;
        _selectedSubjectCode = 'math';
        _visibleSectionCount = _initialVisibleSections;
        _selectedNode = null;
        _isUsingFallbackGraph = true;
        _isLoadingCurriculum = false;
        _isLoadingMoreSections = false;
      });
    }
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 360) {
      _loadMoreSections();
    }

    return false;
  }

  Future<void> _loadMoreSections() async {
    if (_isLoadingMoreSections ||
        _visibleSectionCount >= _graph.sections.length) {
      return;
    }

    setState(() => _isLoadingMoreSections = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));

    if (!mounted) {
      return;
    }

    setState(() {
      _visibleSectionCount = math.min(
        _visibleSectionCount + _sectionBatchSize,
        _graph.sections.length,
      );
      _isLoadingMoreSections = false;
    });
  }

  void _selectNode(_KnowledgeNode node) {
    setState(() => _selectedNode = node);
    final copy = _HomeCopyScope.of(context);
    final fallback = _ConceptDetailData.fromGraph(_graph, node);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _HomeCopyScope(
          copy: copy,
          child: _ConceptDetailBottomSheet(
            detailFuture: _loadConceptDetail(node, fallback),
            fallback: fallback,
            onClose: () => Navigator.of(sheetContext).pop(),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() => _selectedNode = null);
      }
    });
  }

  Future<_ConceptDetailData> _loadConceptDetail(
    _KnowledgeNode node,
    _ConceptDetailData fallback,
  ) async {
    try {
      final detail = await widget.curriculumRepository.fetchConceptDetail(
        conceptCode: node.id,
        subject: _selectedSubjectCode,
      );
      return _ConceptDetailData.fromApi(detail, fallbackNode: node);
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 118),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: widget.constraints.maxHeight - 136,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QueueHeader(onBack: widget.onBack),
              const SizedBox(height: 38),
              Text(
                copy.knowledgeMapLabel,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy.knowledgeMapDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: WicaraColors.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              _SubjectMapTabs(
                subjects: _subjects,
                selectedCode: _selectedSubjectCode,
                onSelected: _selectSubject,
              ),
              const SizedBox(height: 18),
              _Panel(
                padding: const EdgeInsets.fromLTRB(14, 15, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _graph.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: WicaraColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _CurriculumSourceLabel(
                      isLoading: _isLoadingCurriculum,
                      isUsingFallback: _isUsingFallbackGraph,
                    ),
                    const SizedBox(height: 14),
                    const _KnowledgeMapLegend(),
                    const SizedBox(height: 22),
                    _KnowledgeGraphCanvas(
                      graph: _graph,
                      visibleSectionCount: _visibleSectionCount,
                      isLoadingMore: _isLoadingMoreSections,
                      selectedNodeId: _selectedNode?.id,
                      onNodeSelected: _selectNode,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectMapTabs extends StatelessWidget {
  const _SubjectMapTabs({
    required this.subjects,
    required this.selectedCode,
    required this.onSelected,
  });

  final List<_SubjectMapItem> subjects;
  final String selectedCode;
  final ValueChanged<_SubjectMapItem> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < subjects.length; index++) ...[
              _SubjectMapTabButton(
                item: subjects[index],
                isSelected: subjects[index].code == selectedCode,
                onSelected: () => onSelected(subjects[index]),
              ),
              if (index != subjects.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubjectMapTabButton extends StatelessWidget {
  const _SubjectMapTabButton({
    required this.item,
    required this.isSelected,
    required this.onSelected,
  });

  final _SubjectMapItem item;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? item.color.withValues(alpha: 0.62)
        : WicaraColors.primaryLight;
    final textColor = item.isLocked
        ? WicaraColors.softMuted
        : isSelected
        ? item.color
        : WicaraColors.muted;

    return InkWell(
      onTap: item.isLocked ? null : onSelected,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? item.color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.isLocked) ...[
              Icon(Icons.lock_rounded, size: 12, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurriculumSourceLabel extends StatelessWidget {
  const _CurriculumSourceLabel({
    required this.isLoading,
    required this.isUsingFallback,
  });

  final bool isLoading;
  final bool isUsingFallback;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    final label = isLoading
        ? copy.loadingCurriculumLabel
        : isUsingFallback
        ? copy.fallbackGraphLabel
        : copy.liveCurriculumGraphLabel;
    final color = isUsingFallback
        ? WicaraColors.accentAmber
        : WicaraColors.math;

    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _KnowledgeMapLegend extends StatelessWidget {
  const _KnowledgeMapLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in _NodeStatus.values)
          _KnowledgeMapLegendItem(status),
      ],
    );
  }
}

class _KnowledgeMapLegendItem extends StatelessWidget {
  const _KnowledgeMapLegendItem(this.status);

  final _NodeStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: status.color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: status.color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectMapItem {
  const _SubjectMapItem(this.code, this.label, this.color, this.isLocked);

  final String code;
  final String label;
  final Color color;
  final bool isLocked;
}

class _KnowledgeMapPreview extends StatelessWidget {
  const _KnowledgeMapPreview();

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return Row(
      children: [
        Expanded(
          child: _SubjectGraphPreviewTile(
            label: copy.subjectLabel('Math'),
            color: WicaraColors.math,
            icon: Icons.calculate_outlined,
            nodes: 42,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SubjectGraphPreviewTile(
            label: copy.subjectLabel('Physics'),
            color: WicaraColors.physics,
            icon: Icons.bolt_outlined,
            nodes: 18,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SubjectGraphPreviewTile(
            label: copy.subjectLabel('Chemistry'),
            color: WicaraColors.chemistry,
            icon: Icons.science_outlined,
            nodes: 21,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SubjectGraphPreviewTile(
            label: copy.subjectLabel('Biology'),
            color: WicaraColors.biology,
            icon: Icons.eco_outlined,
            nodes: 19,
          ),
        ),
      ],
    );
  }
}

class _SubjectGraphPreviewTile extends StatelessWidget {
  const _SubjectGraphPreviewTile({
    required this.label,
    required this.color,
    required this.icon,
    required this.nodes,
  });

  final String label;
  final Color color;
  final IconData icon;
  final int nodes;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(painter: _MiniSubjectGraphPainter(color)),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.text,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            copy.nodeCountLabel(nodes),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSubjectGraphPainter extends CustomPainter {
  const _MiniSubjectGraphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: 0.38)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final dots = [
      Offset(size.width * 0.5, size.height * 0.08),
      Offset(size.width * 0.24, size.height * 0.34),
      Offset(size.width * 0.68, size.height * 0.35),
      Offset(size.width * 0.43, size.height * 0.62),
      Offset(size.width * 0.78, size.height * 0.72),
      Offset(size.width * 0.25, size.height * 0.86),
    ];

    for (final pair in [(0, 1), (0, 2), (1, 3), (2, 3), (2, 4), (3, 5)]) {
      canvas.drawLine(dots[pair.$1], dots[pair.$2], line);
    }

    for (var index = 0; index < dots.length; index++) {
      canvas.drawCircle(
        dots[index],
        index == 0 ? 4.8 : 4,
        Paint()
          ..color = index == 0 ? color : Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        dots[index],
        index == 0 ? 4.8 : 4,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniSubjectGraphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _KnowledgeGraphCanvas extends StatelessWidget {
  const _KnowledgeGraphCanvas({
    required this.graph,
    required this.visibleSectionCount,
    required this.isLoadingMore,
    required this.selectedNodeId,
    required this.onNodeSelected,
  });

  final _KnowledgeGraph graph;
  final int visibleSectionCount;
  final bool isLoadingMore;
  final String? selectedNodeId;
  final ValueChanged<_KnowledgeNode> onNodeSelected;

  @override
  Widget build(BuildContext context) {
    final sections = graph.topDown
        ? graph.sections
        : graph.sections.reversed.toList();
    final visibleSections = sections.take(visibleSectionCount).toList();
    final hasMore = visibleSections.length < sections.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _KnowledgeGraphLayout.build(
          sections: visibleSections,
          edges: graph.edges,
          maxWidth: constraints.maxWidth,
        );

        return Column(
          children: [
            SizedBox(
              height: layout.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _KnowledgeGraphLinkPainter(layout.links),
                    ),
                  ),
                  for (final header in layout.headers)
                    Positioned(
                      left: header.left,
                      top: header.top,
                      width: header.width,
                      child: _MapGroupHeader(label: header.label),
                    ),
                  for (final placement in layout.nodes)
                    Positioned(
                      left: placement.left,
                      top: placement.top,
                      width: placement.width,
                      child: _KnowledgeGraphNode(
                        node: placement.node,
                        isSelected: placement.node.id == selectedNodeId,
                        onSelected: () => onNodeSelected(placement.node),
                      ),
                    ),
                ],
              ),
            ),
            if (hasMore) _KnowledgeMapLazyTail(isLoading: isLoadingMore),
          ],
        );
      },
    );
  }
}

class _KnowledgeMapLazyTail extends StatelessWidget {
  const _KnowledgeMapLazyTail({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          child: isLoading
              ? SizedBox(
                  key: const ValueKey('knowledge-map-loading-tail'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: WicaraColors.primaryDeep,
                    backgroundColor: WicaraColors.primaryLight,
                  ),
                )
              : Row(
                  key: const ValueKey('knowledge-map-idle-tail'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < 3; index++) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: WicaraColors.primaryLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      if (index < 2) const SizedBox(width: 5),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _MapGroupHeader extends StatelessWidget {
  const _MapGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      constraints: const BoxConstraints(minHeight: 38),
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WicaraColors.primaryLight),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: WicaraColors.primaryDeep,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
      ),
    );
  }
}

class _KnowledgeGraphLayout {
  const _KnowledgeGraphLayout({
    required this.height,
    required this.headers,
    required this.nodes,
    required this.links,
  });

  final double height;
  final List<_GraphHeaderPlacement> headers;
  final List<_GraphNodePlacement> nodes;
  final List<_GraphLinkPlacement> links;

  static _KnowledgeGraphLayout build({
    required List<_KnowledgeSection> sections,
    required List<_KnowledgeEdge> edges,
    required double maxWidth,
  }) {
    const cardHeight = 116.0;
    const headerHeight = 44.0;
    const headerGap = 30.0;
    const rowGap = 28.0;
    const layerGap = 72.0;
    const horizontalGap = 10.0;

    final visibleSections = sections
        .where((section) => section.nodes.isNotEmpty)
        .toList(growable: false);
    final orderedNodes = <_KnowledgeNode>[
      for (final section in visibleSections)
        ...([...section.nodes]..sort((a, b) => a.y.compareTo(b.y))),
    ];
    if (orderedNodes.isEmpty) {
      return const _KnowledgeGraphLayout(
        height: 120,
        headers: [],
        nodes: [],
        links: [],
      );
    }

    final sectionIndexByNodeId = <String, int>{};
    final sectionLabelByNodeId = <String, String>{};
    for (var index = 0; index < visibleSections.length; index++) {
      for (final node in visibleSections[index].nodes) {
        sectionIndexByNodeId[node.id] = index;
        sectionLabelByNodeId[node.id] = visibleSections[index].label;
      }
    }

    final visibleNodeIds = orderedNodes.map((node) => node.id).toSet();
    final visibleEdges = edges
        .where(
          (edge) =>
              visibleNodeIds.contains(edge.from) &&
              visibleNodeIds.contains(edge.to),
        )
        .toList(growable: false);
    final levels = _assignLevels(
      nodes: orderedNodes,
      edges: visibleEdges,
      sectionIndexByNodeId: sectionIndexByNodeId,
    );
    final nodesByLevel = <int, List<_KnowledgeNode>>{};
    for (final node in orderedNodes) {
      nodesByLevel.putIfAbsent(levels[node.id] ?? 0, () => []).add(node);
    }

    final maxColumns = maxWidth >= 352
        ? 3
        : maxWidth >= 230
        ? 2
        : 1;
    final headers = <_GraphHeaderPlacement>[];
    final placements = <_GraphNodePlacement>[];
    var top = 2.0;

    for (final level in nodesByLevel.keys.toList()..sort()) {
      final levelNodes = nodesByLevel[level]!
        ..sort((a, b) {
          final sectionCompare = (sectionIndexByNodeId[a.id] ?? 0).compareTo(
            sectionIndexByNodeId[b.id] ?? 0,
          );
          if (sectionCompare != 0) {
            return sectionCompare;
          }
          return a.y.compareTo(b.y);
        });
      final headerLabel = _levelLabel(levelNodes, sectionLabelByNodeId);
      headers.add(
        _GraphHeaderPlacement(
          label: headerLabel,
          left: math.max(0.0, (maxWidth - 198.0) / 2),
          top: top,
          width: math.min(198.0, maxWidth),
        ),
      );
      top += headerHeight + headerGap;

      var cursor = 0;
      while (cursor < levelNodes.length) {
        final remaining = levelNodes.length - cursor;
        final columns = math.min(maxColumns, remaining);
        final cardWidth = _cardWidthFor(
          maxWidth: maxWidth,
          columns: columns,
          horizontalGap: horizontalGap,
        );
        final rowWidth =
            (cardWidth * columns) + (horizontalGap * (columns - 1));
        final startLeft = math.max(0.0, (maxWidth - rowWidth) / 2);

        for (var column = 0; column < columns; column++) {
          final node = levelNodes[cursor + column];
          placements.add(
            _GraphNodePlacement(
              node: node,
              left: startLeft + (column * (cardWidth + horizontalGap)),
              top: top,
              width: cardWidth,
              height: cardHeight,
            ),
          );
        }

        cursor += columns;
        top += cardHeight + rowGap;
      }

      top += layerGap - rowGap;
    }

    final placementsById = {for (final node in placements) node.node.id: node};
    final links = <_GraphLinkPlacement>[
      for (final edge in visibleEdges)
        if (placementsById[edge.from] case final from?)
          if (placementsById[edge.to] case final to?)
            _GraphLinkPlacement(
              from: from.bottomCenter,
              to: to.topCenter,
              color: to.node.status.color,
            ),
    ];

    return _KnowledgeGraphLayout(
      height: math.max(120.0, top - layerGap + 26),
      headers: headers,
      nodes: placements,
      links: links,
    );
  }

  static Map<String, int> _assignLevels({
    required List<_KnowledgeNode> nodes,
    required List<_KnowledgeEdge> edges,
    required Map<String, int> sectionIndexByNodeId,
  }) {
    final nodeIds = nodes.map((node) => node.id).toSet();
    final levels = {
      for (final node in nodes) node.id: sectionIndexByNodeId[node.id] ?? 0,
    };
    final orderedEdges = [...edges]
      ..sort((a, b) {
        final fromCompare = (sectionIndexByNodeId[a.from] ?? 0).compareTo(
          sectionIndexByNodeId[b.from] ?? 0,
        );
        if (fromCompare != 0) {
          return fromCompare;
        }
        return a.to.compareTo(b.to);
      });

    for (var pass = 0; pass < nodes.length; pass++) {
      var changed = false;
      for (final edge in orderedEdges) {
        if (!nodeIds.contains(edge.from) || !nodeIds.contains(edge.to)) {
          continue;
        }
        final fromLevel = levels[edge.from] ?? 0;
        final currentToLevel = levels[edge.to] ?? 0;
        final nextToLevel = math.max(currentToLevel, fromLevel + 1);
        if (nextToLevel != currentToLevel) {
          levels[edge.to] = nextToLevel;
          changed = true;
        }
      }
      if (!changed) {
        break;
      }
    }

    final compactedLevels = <int, int>{};
    var nextLevel = 0;
    for (final level in (levels.values.toSet().toList()..sort())) {
      compactedLevels[level] = nextLevel++;
    }

    return {
      for (final entry in levels.entries)
        entry.key: compactedLevels[entry.value] ?? 0,
    };
  }

  static double _cardWidthFor({
    required double maxWidth,
    required int columns,
    required double horizontalGap,
  }) {
    final available = math.max(120.0, maxWidth - 4);
    final width = (available - (horizontalGap * (columns - 1))) / columns;
    if (columns == 1) {
      return math.min(224.0, width);
    }
    if (columns == 2) {
      return math.min(150.0, width);
    }
    return math.min(108.0, width);
  }

  static String _levelLabel(
    List<_KnowledgeNode> nodes,
    Map<String, String> sectionLabelByNodeId,
  ) {
    final labels = <String>[];
    for (final node in nodes) {
      final label = sectionLabelByNodeId[node.id];
      if (label != null && !labels.contains(label)) {
        labels.add(label);
      }
    }
    if (labels.isEmpty) {
      return 'Prerequisite layer';
    }
    if (labels.length == 1) {
      return labels.first;
    }
    return '${labels.first} + ${labels.length - 1}';
  }
}

class _GraphHeaderPlacement {
  const _GraphHeaderPlacement({
    required this.label,
    required this.left,
    required this.top,
    required this.width,
  });

  final String label;
  final double left;
  final double top;
  final double width;
}

class _GraphNodePlacement {
  const _GraphNodePlacement({
    required this.node,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final _KnowledgeNode node;
  final double left;
  final double top;
  final double width;
  final double height;

  Offset get topCenter => Offset(left + (width / 2), top);
  Offset get bottomCenter => Offset(left + (width / 2), top + height);
}

class _GraphLinkPlacement {
  const _GraphLinkPlacement({
    required this.from,
    required this.to,
    required this.color,
  });

  final Offset from;
  final Offset to;
  final Color color;
}

class _KnowledgeGraphLinkPainter extends CustomPainter {
  const _KnowledgeGraphLinkPainter(this.links);

  final List<_GraphLinkPlacement> links;

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in links) {
      final paint = Paint()
        ..color = link.color.withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      final midY = (link.from.dy + link.to.dy) / 2;
      final path = Path()
        ..moveTo(link.from.dx, link.from.dy)
        ..cubicTo(link.from.dx, midY, link.to.dx, midY, link.to.dx, link.to.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _KnowledgeGraphLinkPainter oldDelegate) {
    return oldDelegate.links != links;
  }
}

class _KnowledgeGraphNode extends StatefulWidget {
  const _KnowledgeGraphNode({
    required this.node,
    required this.isSelected,
    required this.onSelected,
  });

  final _KnowledgeNode node;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  State<_KnowledgeGraphNode> createState() => _KnowledgeGraphNodeState();
}

class _KnowledgeGraphNodeState extends State<_KnowledgeGraphNode> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.node.status.color;
    final selected =
        widget.isSelected ||
        _isHovered ||
        widget.node.status == _NodeStatus.active;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onSelected,
        child: SizedBox(
          height: widget.node.height,
          child: Column(
            children: [
              _NodeStatusMarker(status: widget.node.status),
              const SizedBox(height: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? color.withValues(alpha: 0.55)
                          : color.withValues(alpha: 0.24),
                      width: selected ? 1.8 : 1.1,
                    ),
                    boxShadow: [
                      if (selected)
                        BoxShadow(
                          color: color.withValues(alpha: 0.15),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            widget.node.label,
                            maxLines: 3,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: WicaraColors.text,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.12,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.node.statusLabel ?? widget.node.status.label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodeStatusMarker extends StatelessWidget {
  const _NodeStatusMarker({required this.status});

  final _NodeStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    final icon = switch (status) {
      _NodeStatus.mastered => Icons.check_rounded,
      _NodeStatus.active => Icons.radio_button_unchecked_rounded,
      _NodeStatus.review => Icons.schedule_rounded,
      _NodeStatus.ready => Icons.circle_rounded,
      _NodeStatus.gap => Icons.priority_high_rounded,
      _NodeStatus.locked => Icons.lock_outline_rounded,
    };

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: status == _NodeStatus.active
                ? Colors.white
                : color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color, width: 1.7),
          ),
          child: Icon(
            icon,
            color: color,
            size: status == _NodeStatus.ready ? 9 : 13,
          ),
        ),
      ),
    );
  }
}

class _ConceptDetailBottomSheet extends StatelessWidget {
  const _ConceptDetailBottomSheet({
    required this.detailFuture,
    required this.fallback,
    required this.onClose,
  });

  final Future<_ConceptDetailData> detailFuture;
  final _ConceptDetailData fallback;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: FutureBuilder<_ConceptDetailData>(
            future: detailFuture,
            initialData: fallback,
            builder: (context, snapshot) {
              final detail = snapshot.data ?? fallback;
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: WicaraColors.line,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _KnowledgeConceptDetailPanel(
                      detail: detail,
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                      onClose: onClose,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ConceptDetailData {
  const _ConceptDetailData({
    required this.node,
    required this.masteryConfidence,
    required this.prerequisites,
    required this.relatedConcepts,
    required this.crossSubjectConnections,
  });

  final _KnowledgeNode node;
  final double masteryConfidence;
  final List<_ConceptRelationItem> prerequisites;
  final List<_ConceptRelationItem> relatedConcepts;
  final List<_ConceptRelationItem> crossSubjectConnections;

  factory _ConceptDetailData.fromGraph(
    _KnowledgeGraph graph,
    _KnowledgeNode node,
  ) {
    return _ConceptDetailData(
      node: node,
      masteryConfidence: node.confidence,
      prerequisites: [
        for (final relation in graph.prerequisitesFor(node).take(5))
          _ConceptRelationItem.fromNode(relation),
      ],
      relatedConcepts: [
        for (final relation in graph.relatedFor(node).take(5))
          _ConceptRelationItem.fromNode(relation),
      ],
      crossSubjectConnections: const [],
    );
  }

  factory _ConceptDetailData.fromApi(
    CurriculumConceptDetail detail, {
    required _KnowledgeNode fallbackNode,
  }) {
    final concept = detail.concept;
    return _ConceptDetailData(
      node: _KnowledgeNode(
        id: concept.id.isEmpty ? fallbackNode.id : concept.id,
        label: concept.label.isEmpty ? fallbackNode.label : concept.label,
        x: fallbackNode.x,
        y: fallbackNode.y,
        description: concept.description.isEmpty
            ? fallbackNode.description
            : concept.description,
        gradeBand: concept.gradeBand.isEmpty
            ? fallbackNode.gradeBand
            : concept.gradeBand,
        status: _nodeStatusFromApi(concept.status),
        statusLabel: concept.statusLabel.isEmpty
            ? fallbackNode.statusLabel
            : concept.statusLabel,
      ),
      masteryConfidence: detail.masteryConfidence.clamp(0, 1).toDouble(),
      prerequisites: [
        for (final relation in detail.prerequisites)
          _ConceptRelationItem.fromApi(relation),
      ],
      relatedConcepts: [
        for (final relation in detail.relatedConcepts)
          _ConceptRelationItem.fromApi(relation),
      ],
      crossSubjectConnections: [
        for (final relation in detail.crossSubjectConnections)
          _ConceptRelationItem.fromApi(relation),
      ],
    );
  }
}

class _ConceptRelationItem {
  const _ConceptRelationItem({
    required this.label,
    required this.subjectName,
    required this.status,
    required this.statusLabel,
  });

  final String label;
  final String subjectName;
  final _NodeStatus status;
  final String statusLabel;

  factory _ConceptRelationItem.fromNode(_KnowledgeNode node) {
    return _ConceptRelationItem(
      label: node.label,
      subjectName: node.gradeBand ?? '',
      status: node.status,
      statusLabel: node.statusLabel ?? node.status.label,
    );
  }

  factory _ConceptRelationItem.fromApi(CurriculumConceptRelation relation) {
    return _ConceptRelationItem(
      label: relation.label,
      subjectName: relation.subjectName,
      status: _nodeStatusFromApi(relation.status),
      statusLabel: relation.statusLabel,
    );
  }
}

class _KnowledgeConceptDetailPanel extends StatefulWidget {
  const _KnowledgeConceptDetailPanel({
    required this.detail,
    required this.isLoading,
    required this.onClose,
  });

  final _ConceptDetailData detail;
  final bool isLoading;
  final VoidCallback onClose;

  @override
  State<_KnowledgeConceptDetailPanel> createState() =>
      _KnowledgeConceptDetailPanelState();
}

class _KnowledgeConceptDetailPanelState
    extends State<_KnowledgeConceptDetailPanel> {
  bool _showCrossSubject = true;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    final node = widget.detail.node;
    final masteryConfidence = widget.detail.masteryConfidence
        .clamp(0, 1)
        .toDouble();
    final confidencePercent = (masteryConfidence * 100).round();
    final prerequisites = widget.detail.prerequisites.take(3).toList();
    final related = widget.detail.relatedConcepts.take(3).toList();
    final crossSubject = widget.detail.crossSubjectConnections.isEmpty
        ? null
        : widget.detail.crossSubjectConnections.first;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(node.id),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    node.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: WicaraColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(status: node.status),
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.onClose,
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      color: WicaraColors.muted,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.isLoading) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(
                  minHeight: 3,
                  color: WicaraColors.primaryDeep,
                  backgroundColor: WicaraColors.primaryLight,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: WicaraColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          copy.masteryConfidenceLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: WicaraColors.text,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      Text(
                        '$confidencePercent%',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: WicaraColors.primaryDeep,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: masteryConfidence,
                      backgroundColor: WicaraColors.primaryLight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        node.status.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ConceptDetailSection(
              title: copy.aboutThisConceptLabel,
              child: Text(
                _nodeDescription(node, copy),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: WicaraColors.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ConceptDetailSection(
              title: copy.prerequisitesLabel,
              child: Column(
                children: [
                  if (prerequisites.isEmpty)
                    _ConceptRelationRow(
                      relation: _ConceptRelationItem.fromNode(node),
                      labelOverride: copy.noDirectPrerequisiteLabel,
                    )
                  else
                    for (final relation in prerequisites)
                      _ConceptRelationRow(relation: relation),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ConceptDetailSection(
              title: copy.relatedConceptsLabel,
              child: Column(
                children: [
                  if (related.isEmpty)
                    _ConceptRelationRow(
                      relation: _ConceptRelationItem.fromNode(node),
                      labelOverride: copy.noDirectRelatedConceptLabel,
                    )
                  else
                    for (final relation in related)
                      _ConceptRelationRow(relation: relation),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WicaraColors.fieldFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: WicaraColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.crossSubjectConnectionsLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: WicaraColors.text,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          copy.graphOfGraphsHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: WicaraColors.muted,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _showCrossSubject,
                    activeThumbColor: WicaraColors.primaryDeep,
                    activeTrackColor: WicaraColors.primaryLight,
                    onChanged: (value) =>
                        setState(() => _showCrossSubject = value),
                  ),
                ],
              ),
            ),
            if (_showCrossSubject) ...[
              const SizedBox(height: 10),
              _CrossSubjectCard(
                relation: crossSubject,
                fallbackLabel: node.gradeBand?.isNotEmpty == true
                    ? node.gradeBand!
                    : copy.conceptBridgeFallbackLabel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConceptDetailSection extends StatelessWidget {
  const _ConceptDetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: WicaraColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ConceptRelationRow extends StatelessWidget {
  const _ConceptRelationRow({required this.relation, this.labelOverride});

  final _ConceptRelationItem relation;
  final String? labelOverride;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Row(
        children: [
          _NodeStatusDot(status: relation.status),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              labelOverride ?? relation.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(status: relation.status),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: WicaraColors.softMuted,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _CrossSubjectCard extends StatelessWidget {
  const _CrossSubjectCard({
    required this.relation,
    required this.fallbackLabel,
  });

  final _ConceptRelationItem? relation;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: WicaraColors.secondarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WicaraColors.secondaryLight),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.hub_outlined,
              color: WicaraColors.secondaryDeep,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              relation == null
                  ? fallbackLabel
                  : '${relation!.label} - ${relation!.subjectName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SoftBadge(_HomeCopyScope.of(context).relatedBadgeLabel),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _NodeStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        maxLines: 1,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: status.color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NodeStatusDot extends StatelessWidget {
  const _NodeStatusDot({required this.status});

  final _NodeStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color, width: 1.5),
      ),
      child: status == _NodeStatus.mastered
          ? const Icon(
              Icons.check_rounded,
              size: 12,
              color: WicaraColors.accentMint,
            )
          : null,
    );
  }
}

String _nodeDescription(_KnowledgeNode node, OnboardingCopy copy) {
  final description = node.description;
  if (description != null && description.isNotEmpty) {
    return description;
  }
  return copy.conceptFallbackDescription;
}

class _KnowledgeGraph {
  const _KnowledgeGraph({
    required this.title,
    required this.width,
    required this.height,
    required this.groups,
    required this.nodes,
    required this.edges,
    this.topDown = false,
    this.focusSubjectCode,
  });

  final String title;
  final double width;
  final double height;
  final List<_MapGroup> groups;
  final List<_KnowledgeNode> nodes;
  final List<_KnowledgeEdge> edges;
  final bool topDown;
  final String? focusSubjectCode;

  List<_KnowledgeSection> get sections {
    final orderedSections = [
      for (var index = 0; index < groups.length; index++)
        _KnowledgeSection(
          label: groups[index].label,
          nodes: nodes
              .where((node) => _groupIndexFor(node.x) == index)
              .toList(),
        ),
    ];
    final subjectCode = focusSubjectCode;
    if (subjectCode == null || subjectCode.isEmpty) {
      return orderedSections;
    }
    return _focusOrderedSections(orderedSections, subjectCode);
  }

  int _groupIndexFor(double x) {
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var index = 0; index < groups.length; index++) {
      final distance = (groups[index].x - x).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  _KnowledgeNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }

  List<_KnowledgeNode> prerequisitesFor(_KnowledgeNode node) {
    final prerequisites = <_KnowledgeNode>[];
    for (final edge in edges) {
      if (edge.to != node.id) {
        continue;
      }
      final prerequisite = nodeById(edge.from);
      if (prerequisite != null) {
        prerequisites.add(prerequisite);
      }
    }
    return prerequisites;
  }

  List<_KnowledgeNode> relatedFor(_KnowledgeNode node) {
    final relatedNodes = <_KnowledgeNode>[];
    for (final edge in edges) {
      if (edge.from != node.id) {
        continue;
      }
      final related = nodeById(edge.to);
      if (related != null) {
        relatedNodes.add(related);
      }
    }
    return relatedNodes;
  }
}

class _KnowledgeSection {
  const _KnowledgeSection({required this.label, required this.nodes});

  final String label;
  final List<_KnowledgeNode> nodes;
}

class _RankedKnowledgeSection {
  const _RankedKnowledgeSection({
    required this.section,
    required this.rank,
    required this.index,
  });

  final _KnowledgeSection section;
  final int rank;
  final int index;
}

List<_KnowledgeSection> _focusOrderedSections(
  List<_KnowledgeSection> sections,
  String subjectCode,
) {
  final rankedSections = <_RankedKnowledgeSection>[
    for (var index = 0; index < sections.length; index++)
      _RankedKnowledgeSection(
        section: sections[index],
        rank: _focusSectionRank(sections[index].label, subjectCode),
        index: index,
      ),
  ];
  rankedSections.sort((left, right) {
    final rankCompare = left.rank.compareTo(right.rank);
    if (rankCompare != 0) {
      return rankCompare;
    }
    return left.index.compareTo(right.index);
  });
  return [for (final item in rankedSections) item.section];
}

int _focusSectionRank(String label, String subjectCode) {
  final normalizedSubject = subjectCode.trim().toLowerCase();
  final normalizedLabel = label.trim().toLowerCase();
  final isIpas = normalizedLabel.startsWith('ipas');
  final isIpa = normalizedLabel.startsWith('ipa terpadu');

  return switch (normalizedSubject) {
    'matematika' || 'math' => normalizedLabel.contains(' - ') ? 1 : 0,
    'ipas' => isIpas || !normalizedLabel.contains(' - ') ? 0 : 1,
    'ipa' =>
      isIpa
          ? 0
          : isIpas
          ? 1
          : 2,
    'fisika' =>
      normalizedLabel.startsWith('fisika')
          ? 0
          : isIpa
          ? 1
          : isIpas
          ? 2
          : 3,
    'kimia' =>
      normalizedLabel.startsWith('kimia')
          ? 0
          : isIpa
          ? 1
          : isIpas
          ? 2
          : 3,
    'biologi' =>
      normalizedLabel.startsWith('biologi')
          ? 0
          : isIpa
          ? 1
          : isIpas
          ? 2
          : 3,
    _ => 0,
  };
}

class _MapGroup {
  const _MapGroup({required this.label, required this.x});

  final String label;
  final double x;
}

class _KnowledgeNode {
  const _KnowledgeNode({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    this.description,
    this.gradeBand,
    this.status = _NodeStatus.ready,
    this.statusLabel,
  });

  final String id;
  final String label;
  final double x;
  final double y;
  final String? description;
  final String? gradeBand;
  final _NodeStatus status;
  final String? statusLabel;

  double get width => 154;
  double get height => 116;

  double get confidence {
    return switch (status) {
      _NodeStatus.mastered => 0.92,
      _NodeStatus.active => 0.62,
      _NodeStatus.review => 0.48,
      _NodeStatus.ready => 0.34,
      _NodeStatus.gap => 0.18,
      _NodeStatus.locked => 0.08,
    };
  }
}

class _KnowledgeEdge {
  const _KnowledgeEdge(this.from, this.to);

  final String from;
  final String to;
}

enum _NodeStatus {
  mastered('MASTERED', WicaraColors.accentMint),
  active('IN PROGRESS', WicaraColors.primaryDeep),
  review('REVIEW', WicaraColors.accentAmber),
  ready('READY', WicaraColors.primary),
  gap('GAP', WicaraColors.accentCoral),
  locked('LOCKED', WicaraColors.softMuted);

  const _NodeStatus(this.label, this.color);

  final String label;
  final Color color;
}

List<_SubjectMapItem> _subjectTabsFromApi(List<CurriculumSubject> subjects) {
  final activeSubjects = subjects.where((subject) => subject.isActive).toList();
  if (activeSubjects.isEmpty) {
    return _KnowledgeMapDetailState._fallbackSubjects;
  }

  return [
    for (final subject in activeSubjects)
      _SubjectMapItem(
        subject.code,
        _subjectLabel(subject),
        _subjectColor(subject.code),
        false,
      ),
  ];
}

String _defaultSubjectCode(List<_SubjectMapItem> subjects) {
  for (final preferredCode in ['matematika', 'math']) {
    for (final subject in subjects) {
      if (subject.code == preferredCode && !subject.isLocked) {
        return subject.code;
      }
    }
  }

  return subjects.firstWhere((subject) => !subject.isLocked).code;
}

_KnowledgeGraph _knowledgeGraphFromApi(
  CurriculumKnowledgeMap graph, {
  String? focusSubjectCode,
}) {
  if (graph.groups.isEmpty || graph.nodes.isEmpty) {
    return _mathKnowledgeGraph;
  }

  return _KnowledgeGraph(
    title: graph.title,
    width: graph.width,
    height: graph.height,
    topDown: graph.topDown,
    groups: [
      for (final group in graph.groups)
        _MapGroup(label: group.label, x: group.x),
    ],
    nodes: [
      for (final node in graph.nodes)
        _KnowledgeNode(
          id: node.id,
          label: node.label,
          x: node.x,
          y: node.y,
          description: node.description,
          gradeBand: node.gradeBand,
          status: _nodeStatusFromApi(node.status),
          statusLabel: node.statusLabel.isEmpty ? null : node.statusLabel,
        ),
    ],
    edges: [for (final edge in graph.edges) _KnowledgeEdge(edge.from, edge.to)],
    focusSubjectCode: focusSubjectCode,
  );
}

String _subjectLabel(CurriculumSubject subject) {
  return switch (subject.code) {
    'matematika' => 'Matematika',
    'ipas' => 'IPAS',
    'ipa' => 'IPA',
    'fisika' => 'Fisika',
    'kimia' => 'Kimia',
    'biologi' => 'Biologi',
    'math' => 'Math',
    'physics' => 'Physics',
    'chemistry' => 'Chemistry',
    'biology' => 'Biology',
    _ => subject.name,
  };
}

Color _subjectColor(String code) {
  return switch (code) {
    'matematika' => WicaraColors.math,
    'ipas' || 'ipa' => WicaraColors.physics,
    'fisika' => WicaraColors.physics,
    'kimia' => WicaraColors.chemistry,
    'biologi' => WicaraColors.biology,
    'math' => WicaraColors.math,
    'physics' => WicaraColors.physics,
    'chemistry' => WicaraColors.chemistry,
    'biology' => WicaraColors.biology,
    _ => WicaraColors.primary,
  };
}

_NodeStatus _nodeStatusFromApi(CurriculumNodeStatus status) {
  return switch (status) {
    CurriculumNodeStatus.mastered => _NodeStatus.mastered,
    CurriculumNodeStatus.active => _NodeStatus.active,
    CurriculumNodeStatus.review => _NodeStatus.review,
    CurriculumNodeStatus.ready => _NodeStatus.ready,
    CurriculumNodeStatus.gap => _NodeStatus.gap,
    CurriculumNodeStatus.locked => _NodeStatus.locked,
  };
}

const _mathKnowledgeGraph = _KnowledgeGraph(
  title: 'Mathematics Prerequisite Map',
  width: 2260,
  height: 600,
  topDown: false,
  groups: [
    _MapGroup(label: 'Primary Math', x: 28),
    _MapGroup(label: 'Lower Secondary', x: 330),
    _MapGroup(label: 'Algebra and Functions', x: 650),
    _MapGroup(label: 'Precalculus', x: 970),
    _MapGroup(label: 'Limits and Continuity', x: 1290),
    _MapGroup(label: 'Calculus 1', x: 1570),
    _MapGroup(label: 'Calculus 2', x: 1845),
    _MapGroup(label: 'Calculus 3', x: 2070),
  ],
  nodes: [
    _KnowledgeNode(
      id: 'counting',
      label: 'Counting',
      x: 28,
      y: 82,
      status: _NodeStatus.mastered,
    ),
    _KnowledgeNode(
      id: 'place_value',
      label: 'Place Value',
      x: 28,
      y: 152,
      status: _NodeStatus.mastered,
    ),
    _KnowledgeNode(
      id: 'operations',
      label: 'Arithmetic Operations',
      x: 28,
      y: 222,
      status: _NodeStatus.mastered,
    ),
    _KnowledgeNode(
      id: 'fractions',
      label: 'Fractions and Decimals',
      x: 28,
      y: 292,
      status: _NodeStatus.mastered,
    ),
    _KnowledgeNode(
      id: 'geometry_basic',
      label: 'Basic Shapes and Measurement',
      x: 28,
      y: 362,
      status: _NodeStatus.mastered,
    ),
    _KnowledgeNode(
      id: 'data_basic',
      label: 'Tables, Charts, and Mean',
      x: 28,
      y: 432,
      status: _NodeStatus.ready,
    ),
    _KnowledgeNode(
      id: 'integers',
      label: 'Integers and Rational Numbers',
      x: 330,
      y: 82,
      status: _NodeStatus.mastered,
    ),
    _KnowledgeNode(
      id: 'exponents_basic',
      label: 'Exponents and Roots Basics',
      x: 330,
      y: 152,
      status: _NodeStatus.mastered,
    ),
    _KnowledgeNode(
      id: 'linear_equations',
      label: 'Linear Equations',
      x: 330,
      y: 222,
      status: _NodeStatus.mastered,
    ),
    _KnowledgeNode(
      id: 'coordinate_graphing',
      label: 'Coordinate Graphing',
      x: 330,
      y: 292,
      status: _NodeStatus.mastered,
    ),
    _KnowledgeNode(
      id: 'slope',
      label: 'Slope and Intercepts',
      x: 330,
      y: 362,
      status: _NodeStatus.review,
    ),
    _KnowledgeNode(
      id: 'pythagorean',
      label: 'Pythagorean Theorem',
      x: 330,
      y: 432,
      status: _NodeStatus.ready,
    ),
    _KnowledgeNode(
      id: 'functions',
      label: 'Functions, Domain, and Range',
      x: 650,
      y: 82,
      status: _NodeStatus.mastered,
    ),
    _KnowledgeNode(
      id: 'composition',
      label: 'Function Composition and Inverses',
      x: 650,
      y: 152,
      status: _NodeStatus.review,
    ),
    _KnowledgeNode(
      id: 'exponential_log',
      label: 'Exponential and Logarithmic Functions',
      x: 650,
      y: 222,
      status: _NodeStatus.ready,
    ),
    _KnowledgeNode(
      id: 'quadratics',
      label: 'Quadratic and Polynomial Functions',
      x: 650,
      y: 292,
      status: _NodeStatus.mastered,
    ),
    _KnowledgeNode(
      id: 'rational_functions',
      label: 'Rational Functions',
      x: 650,
      y: 362,
      status: _NodeStatus.ready,
    ),
    _KnowledgeNode(
      id: 'sequences',
      label: 'Sequences, Series, Sigma Notation',
      x: 650,
      y: 432,
      status: _NodeStatus.ready,
    ),
    _KnowledgeNode(
      id: 'analytic_geometry',
      label: 'Analytic Geometry and Conics',
      x: 970,
      y: 82,
      status: _NodeStatus.ready,
    ),
    _KnowledgeNode(
      id: 'trig_functions',
      label: 'Trigonometric Functions and Graphs',
      x: 970,
      y: 152,
      status: _NodeStatus.ready,
    ),
    _KnowledgeNode(
      id: 'trig_identities',
      label: 'Trigonometric Identities and Equations',
      x: 970,
      y: 222,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'vectors_basic',
      label: 'Vectors, Parametric, and Polar Basics',
      x: 970,
      y: 292,
      status: _NodeStatus.ready,
    ),
    _KnowledgeNode(
      id: 'precalc_fluency',
      label: 'Precalculus Fluency',
      x: 970,
      y: 362,
      status: _NodeStatus.active,
    ),
    _KnowledgeNode(
      id: 'intuitive_limits',
      label: 'Intuitive Limits',
      x: 1290,
      y: 102,
      status: _NodeStatus.active,
    ),
    _KnowledgeNode(
      id: 'limit_laws',
      label: 'Limit Laws and Algebraic Techniques',
      x: 1290,
      y: 172,
      status: _NodeStatus.ready,
    ),
    _KnowledgeNode(
      id: 'trig_limits',
      label: 'Trigonometric Limits and Squeeze Theorem',
      x: 1290,
      y: 242,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'continuity',
      label: 'Continuity and Intermediate Value Theorem',
      x: 1290,
      y: 312,
      status: _NodeStatus.ready,
    ),
    _KnowledgeNode(
      id: 'derivative_definition',
      label: 'Derivative Definition',
      x: 1570,
      y: 72,
      status: _NodeStatus.ready,
    ),
    _KnowledgeNode(
      id: 'derivative_rules',
      label: 'Derivative Rules',
      x: 1570,
      y: 142,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'chain_rule',
      label: 'Chain Rule and Implicit Differentiation',
      x: 1570,
      y: 212,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'applications_derivatives',
      label: 'Related Rates, Optimization, Curve Sketching',
      x: 1570,
      y: 282,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'basic_integrals',
      label: 'Antiderivatives, Riemann Sums, Definite Integrals',
      x: 1570,
      y: 352,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'ftc',
      label: 'Fundamental Theorem of Calculus',
      x: 1570,
      y: 422,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'integration_techniques',
      label: 'Integration Techniques',
      x: 1845,
      y: 102,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'integral_applications',
      label: 'Area, Volume, Work, Fluid Force',
      x: 1845,
      y: 172,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'calculus_series',
      label: 'Convergence Tests and Power Series',
      x: 1845,
      y: 242,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'parametric_polar',
      label: 'Parametric and Polar Calculus',
      x: 1845,
      y: 312,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'vectors_3d',
      label: '3D Coordinates and Vector Operations',
      x: 2070,
      y: 102,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'partial_derivatives',
      label: 'Partial Derivatives and Gradients',
      x: 2070,
      y: 172,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'multiple_integrals',
      label: 'Double and Triple Integrals',
      x: 2070,
      y: 242,
      status: _NodeStatus.locked,
    ),
    _KnowledgeNode(
      id: 'vector_calculus',
      label: 'Vector Fields, Line Integrals, Green, Stokes, Divergence',
      x: 2070,
      y: 312,
      status: _NodeStatus.locked,
    ),
  ],
  edges: [
    _KnowledgeEdge('counting', 'place_value'),
    _KnowledgeEdge('place_value', 'operations'),
    _KnowledgeEdge('operations', 'fractions'),
    _KnowledgeEdge('operations', 'integers'),
    _KnowledgeEdge('fractions', 'integers'),
    _KnowledgeEdge('fractions', 'linear_equations'),
    _KnowledgeEdge('geometry_basic', 'pythagorean'),
    _KnowledgeEdge('data_basic', 'sequences'),
    _KnowledgeEdge('integers', 'linear_equations'),
    _KnowledgeEdge('exponents_basic', 'exponential_log'),
    _KnowledgeEdge('linear_equations', 'slope'),
    _KnowledgeEdge('coordinate_graphing', 'slope'),
    _KnowledgeEdge('slope', 'functions'),
    _KnowledgeEdge('functions', 'composition'),
    _KnowledgeEdge('functions', 'quadratics'),
    _KnowledgeEdge('quadratics', 'rational_functions'),
    _KnowledgeEdge('exponential_log', 'trig_functions'),
    _KnowledgeEdge('composition', 'precalc_fluency'),
    _KnowledgeEdge('rational_functions', 'precalc_fluency'),
    _KnowledgeEdge('sequences', 'calculus_series'),
    _KnowledgeEdge('pythagorean', 'analytic_geometry'),
    _KnowledgeEdge('analytic_geometry', 'vectors_basic'),
    _KnowledgeEdge('trig_functions', 'trig_identities'),
    _KnowledgeEdge('trig_identities', 'trig_limits'),
    _KnowledgeEdge('vectors_basic', 'parametric_polar'),
    _KnowledgeEdge('precalc_fluency', 'intuitive_limits'),
    _KnowledgeEdge('intuitive_limits', 'limit_laws'),
    _KnowledgeEdge('limit_laws', 'continuity'),
    _KnowledgeEdge('trig_limits', 'derivative_rules'),
    _KnowledgeEdge('continuity', 'derivative_definition'),
    _KnowledgeEdge('derivative_definition', 'derivative_rules'),
    _KnowledgeEdge('derivative_rules', 'chain_rule'),
    _KnowledgeEdge('chain_rule', 'applications_derivatives'),
    _KnowledgeEdge('derivative_rules', 'basic_integrals'),
    _KnowledgeEdge('basic_integrals', 'ftc'),
    _KnowledgeEdge('ftc', 'integration_techniques'),
    _KnowledgeEdge('integration_techniques', 'integral_applications'),
    _KnowledgeEdge('integration_techniques', 'calculus_series'),
    _KnowledgeEdge('parametric_polar', 'vectors_3d'),
    _KnowledgeEdge('vectors_3d', 'partial_derivatives'),
    _KnowledgeEdge('partial_derivatives', 'multiple_integrals'),
    _KnowledgeEdge('multiple_integrals', 'vector_calculus'),
  ],
);

class _KnowledgeMapOption extends StatelessWidget {
  const _KnowledgeMapOption({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeCopyScope.of(context);
    return _ProgressOptionPanel(
      onTap: onOpen,
      icon: Icons.account_tree_outlined,
      iconColor: WicaraColors.primaryDeep,
      iconBackground: WicaraColors.speechBlue,
      title: copy.knowledgeMapLabel,
      subtitle: copy.isIndonesian
          ? 'Visualisasikan prasyarat, gap, dan konsep berikutnya.'
          : 'Visualize prerequisites, gaps, and next concepts.',
      child: SizedBox(height: 164, child: _KnowledgeMapPreview()),
    );
  }
}

class _ProgressOptionPanel extends StatelessWidget {
  const _ProgressOptionPanel({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          hoverColor: WicaraColors.primaryLight.withValues(alpha: 0.36),
          highlightColor: WicaraColors.primaryLight.withValues(alpha: 0.48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(19, 18, 19, 19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, color: iconColor, size: 23),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: WicaraColors.muted,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: WicaraColors.softMuted,
                      size: 25,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportBarGroup extends StatelessWidget {
  const _ReportBarGroup({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final double before;
  final double after;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ReportBar(value: before, color: WicaraColors.primaryLight),
                  const SizedBox(width: 6),
                  _ReportBar(value: after, color: WicaraColors.secondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBar extends StatelessWidget {
  const _ReportBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: value,
      child: Container(
        width: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        ),
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: WicaraColors.pageBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 23, height: 1),
          ),
          const SizedBox(height: 6),
          Text(
            delta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.accentMint,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: WicaraColors.line, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.12),
            blurRadius: 17,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionWordmark extends StatelessWidget {
  const _SectionWordmark({
    required this.assetPath,
    required this.title,
    this.iconSize = 34,
    this.titleFontSize = 24,
  });

  final String assetPath;
  final String title;
  final double iconSize;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          assetPath,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            maxLines: title.contains('\n') ? 2 : 1,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: titleFontSize,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _LessonGlyph extends StatelessWidget {
  const _LessonGlyph({this.text, this.icon, this.size = 64});

  final String? text;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: WicaraColors.secondary, size: size * 0.43)
          : Text(
              text ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: WicaraColors.secondary,
                fontSize: size * 0.32,
                fontWeight: FontWeight.w600,
                height: 0.9,
              ),
            ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: WicaraColors.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: Alignment.center,
      child: Text(
        value,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: WicaraColors.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WeekDots extends StatelessWidget {
  const _WeekDots();

  @override
  Widget build(BuildContext context) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    const alphas = [0.18, 0.28, 0.38, 0.5, 0.62, 0.78, 0.94];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < labels.length; i++)
          SizedBox(
            width: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: WicaraColors.secondary.withValues(alpha: alphas[i]),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
