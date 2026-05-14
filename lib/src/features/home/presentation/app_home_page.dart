import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/wicara_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../curriculum/domain/curriculum_models.dart';
import '../../curriculum/domain/curriculum_repository.dart';
import '../../pretest/domain/pretest_models.dart';
import '../../pretest/presentation/widgets/assessment_option_tile.dart';

enum _HomeTab { home, queue, progress, profile }

enum _QueueTab { recommended, tracks, gallery }

class AppHomePage extends StatefulWidget {
  const AppHomePage({required this.curriculumRepository, super.key});

  final CurriculumRepository curriculumRepository;

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

  void _openDailyEvaluation() {
    setState(() {
      _selectedTab = _HomeTab.home;
      _showGalleryDetail = false;
      _showDailyEvaluation = true;
      _showEvaluationResult = false;
      _showLearningReport = false;
      _showKnowledgeMap = false;
      _dailyEvaluationIndex = 0;
      _dailyEvaluationAnswers.clear();
    });
  }

  void _selectDailyEvaluationAnswer(String optionId) {
    setState(() => _dailyEvaluationAnswers[_dailyEvaluationIndex] = optionId);
  }

  void _nextDailyEvaluationQuestion() {
    setState(() {
      if (_dailyEvaluationIndex < _dailyEvaluationQuestions.length - 1) {
        _dailyEvaluationIndex += 1;
        return;
      }

      _showDailyEvaluation = false;
      _showEvaluationResult = true;
    });
  }

  void _previousDailyEvaluationQuestion() {
    if (_dailyEvaluationIndex == 0) {
      _openHome();
      return;
    }

    setState(() => _dailyEvaluationIndex -= 1);
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

  void _openWorkspaceModules() {
    Navigator.of(context).pushNamed(AppRoutes.workspaceModules);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
                        child: _showEvaluationResult || _showDailyEvaluation
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
    if (_showDailyEvaluation) {
      return _DailyEvaluationQuestionPage(
        constraints: constraints,
        question: _dailyEvaluationQuestions[_dailyEvaluationIndex],
        questionIndex: _dailyEvaluationIndex,
        totalQuestions: _dailyEvaluationQuestions.length,
        selectedOptionId: _dailyEvaluationAnswers[_dailyEvaluationIndex],
        onBack: _previousDailyEvaluationQuestion,
        onSelected: _selectDailyEvaluationAnswer,
        onSubmit: _nextDailyEvaluationQuestion,
      );
    }

    if (_showEvaluationResult) {
      return _EvaluationCompletePage(
        constraints: constraints,
        onBackHome: _openHome,
      );
    }

    return switch (_selectedTab) {
      _HomeTab.home => _HomeDashboard(
        constraints: constraints,
        onOpenQueue: () => _openQueue(),
        onOpenTracks: () => _openQueue(_QueueTab.tracks),
        onContinueSession: _openWorkspaceModules,
        onTakeDailyEvaluation: _openDailyEvaluation,
      ),
      _HomeTab.queue => _LearningQueue(
        constraints: constraints,
        selectedTab: _queueTab,
        onTabChanged: (tab) => setState(() => _queueTab = tab),
        showGalleryDetail: _showGalleryDetail,
        onOpenGalleryDetail: () => setState(() => _showGalleryDetail = true),
        onCloseGalleryDetail: () => setState(() => _showGalleryDetail = false),
        onCreateTrack: _openLearningGoal,
        onOpenWorkspace: _openWorkspaceModules,
        onBack: _openHome,
      ),
      _HomeTab.progress => _ProgressHub(
        constraints: constraints,
        curriculumRepository: widget.curriculumRepository,
        onBack: _openHome,
        showLearningReport: _showLearningReport,
        showKnowledgeMap: _showKnowledgeMap,
        onOpenLearningReport: _openLearningReport,
        onCloseLearningReport: _closeLearningReport,
        onOpenKnowledgeMap: _openKnowledgeMap,
        onCloseKnowledgeMap: _closeKnowledgeMap,
      ),
      _HomeTab.profile => _ProfilePage(
        constraints: constraints,
        onBack: _openHome,
      ),
    };
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.constraints,
    required this.onOpenQueue,
    required this.onOpenTracks,
    required this.onContinueSession,
    required this.onTakeDailyEvaluation,
  });

  final BoxConstraints constraints;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenTracks;
  final VoidCallback onContinueSession;
  final VoidCallback onTakeDailyEvaluation;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 136),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: _SectionWordmark(
                assetPath: 'lib/src/assets/waveIcon.png',
                title: 'Welcome back,\nAisha',
                iconSize: 84,
                titleFontSize: 23,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ready to continue learning and build something great today?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 35),
            _ExploreTracksCard(onOpenTracks: onOpenTracks),
            const SizedBox(height: 20),
            _TodayQueueCard(
              onViewAll: onOpenQueue,
              onContinue: onContinueSession,
            ),
            const SizedBox(height: 25),
            const _StreakCard(),
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
    required this.selectedTab,
    required this.onTabChanged,
    required this.showGalleryDetail,
    required this.onOpenGalleryDetail,
    required this.onCloseGalleryDetail,
    required this.onCreateTrack,
    required this.onOpenWorkspace,
    required this.onBack,
  });

  final BoxConstraints constraints;
  final _QueueTab selectedTab;
  final ValueChanged<_QueueTab> onTabChanged;
  final bool showGalleryDetail;
  final VoidCallback onOpenGalleryDetail;
  final VoidCallback onCloseGalleryDetail;
  final VoidCallback onCreateTrack;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final description = switch (selectedTab) {
      _QueueTab.recommended => 'Suggested tracks to help you reach your goals.',
      _QueueTab.tracks =>
        'Explore your learning tracks or create a new one here.',
      _QueueTab.gallery =>
        'Review the videos and summaries from your learning journey.',
    };

    if (showGalleryDetail) {
      return _GalleryVideoDetail(
        constraints: constraints,
        onBack: onCloseGalleryDetail,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 132),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(onBack: onBack),
            const SizedBox(height: 34),
            const _SectionWordmark(
              assetPath: 'lib/src/assets/learnIcon.png',
              title: 'Learn',
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
              _RecommendedQueueContent(onContinue: onOpenWorkspace)
            else if (selectedTab == _QueueTab.tracks)
              _TracksQueueContent(
                onCreateTrack: onCreateTrack,
                onContinue: onOpenWorkspace,
              ),
            if (selectedTab == _QueueTab.gallery)
              _GalleryQueueContent(onOpenDetail: onOpenGalleryDetail),
          ],
        ),
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
  const _TodayQueueCard({required this.onViewAll, required this.onContinue});

  final VoidCallback onViewAll;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's learning queue",
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
                  'View all',
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
                    const _SoftBadge('Next up'),
                    const SizedBox(height: 11),
                    Text(
                      'Limits from graphs',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Calculus I',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Estimated 18 min   •   Medium',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WicaraColors.softMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const _LessonGlyph(text: 'lim', size: 73),
            ],
          ),
          const SizedBox(height: 24),
          GradientButton(label: 'Continue session', onPressed: onContinue),
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
                  'Want to learn something new?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Explore tracks you have created or start another one.',
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
            child: const Text('Explore'),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
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
                  'Current streak',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '7 days',
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
    return _Panel(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Daily evaluation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 11),
          Text.rich(
            TextSpan(
              text: "Today's topic: ",
              children: const [
                TextSpan(
                  text: 'Calculus I',
                  style: TextStyle(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text:
                      '. Pick a confidence score if you want, then take your daily check.',
                ),
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

const _dailyEvaluationQuestions = [
  PretestQuestion(
    stepLabel: 'Daily Evals',
    topic: 'Calculus I',
    prompt:
        'A graph approaches y = 3 as x gets closer to 2 from both sides. What does this suggest?',
    helper: 'Choose the strongest interpretation.',
    options: [
      PretestOption(
        id: 'A',
        label: 'A',
        text: 'The function must equal 3 when x is 2',
      ),
      PretestOption(
        id: 'B',
        label: 'B',
        text: 'The limit is likely 3 as x approaches 2',
      ),
      PretestOption(
        id: 'C',
        label: 'C',
        text: 'The graph has no meaningful behavior near x = 2',
      ),
      PretestOption(
        id: 'D',
        label: 'D',
        text: 'The slope is always 3 around x = 2',
      ),
    ],
  ),
  PretestQuestion(
    stepLabel: 'Daily Evals',
    topic: 'Application',
    prompt:
        'A student can solve derivative rules but misses word problems. What should they review next?',
    helper: 'Pick the next learning action.',
    options: [
      PretestOption(
        id: 'A',
        label: 'A',
        text: 'Repeat only memorized derivative formulas',
      ),
      PretestOption(
        id: 'B',
        label: 'B',
        text: 'Practice translating situations into equations',
      ),
      PretestOption(
        id: 'C',
        label: 'C',
        text: 'Skip application questions until later',
      ),
      PretestOption(
        id: 'D',
        label: 'D',
        text: 'Review unrelated algebra identities',
      ),
    ],
  ),
  PretestQuestion(
    stepLabel: 'Daily Evals',
    topic: 'Spaced Review',
    prompt:
        'You answered a concept correctly today after struggling yesterday. What is the best next step?',
    helper: 'Use memory strength to decide.',
    options: [
      PretestOption(
        id: 'A',
        label: 'A',
        text: 'Review it again after a short delay',
      ),
      PretestOption(
        id: 'B',
        label: 'B',
        text: 'Mark it mastered forever immediately',
      ),
      PretestOption(
        id: 'C',
        label: 'C',
        text: 'Remove it from all future practice',
      ),
      PretestOption(
        id: 'D',
        label: 'D',
        text: 'Only study brand new concepts now',
      ),
    ],
  ),
];

class _DailyEvaluationQuestionPage extends StatelessWidget {
  const _DailyEvaluationQuestionPage({
    required this.constraints,
    required this.question,
    required this.questionIndex,
    required this.totalQuestions,
    required this.selectedOptionId,
    required this.onBack,
    required this.onSelected,
    required this.onSubmit,
  });

  final BoxConstraints constraints;
  final PretestQuestion question;
  final int questionIndex;
  final int totalQuestions;
  final String? selectedOptionId;
  final VoidCallback onBack;
  final ValueChanged<String> onSelected;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final progress = (questionIndex + 1) / totalQuestions;
    final isLastQuestion = questionIndex == totalQuestions - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 30),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(onBack: onBack),
            const SizedBox(height: 34),
            const _SectionWordmark(
              assetPath: 'lib/src/assets/pretestIcon.png',
              title: 'Daily Evals',
              iconSize: 84,
            ),
            const SizedBox(height: 8),
            Text(
              'Quick check-in for today’s learning path.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  '${questionIndex + 1} / $totalQuestions',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _EvaluationProgressLine(value: progress)),
              ],
            ),
            const SizedBox(height: 24),
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
                        ? 'Finish Daily Evals'
                        : 'Next question',
                    onPressed: selectedOptionId == null ? null : onSubmit,
                  ),
                ],
              ),
            ),
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

class _EvaluationCompletePage extends StatelessWidget {
  const _EvaluationCompletePage({
    required this.constraints,
    required this.onBackHome,
  });

  final BoxConstraints constraints;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 30),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(onBack: onBackHome),
            const SizedBox(height: 25),
            Text(
              'Evaluation Complete 🎉',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              "Great work! You're building lasting knowledge.",
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
                  const Expanded(child: _EvaluationScoreRing(score: 0.87)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: const [
                        _EvaluationStat(value: '12', label: 'Reviewed'),
                        SizedBox(height: 17),
                        _EvaluationStat(value: '10', label: 'Correct'),
                        SizedBox(height: 17),
                        _EvaluationStat(value: '2', label: 'To review again'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _EvaluationConceptsPanel(),
            const SizedBox(height: 18),
            const _SpacedRepetitionImpactPanel(),
            const SizedBox(height: 28),
            _BackHomeButton(onPressed: onBackHome),
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
                    'Score',
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
  const _EvaluationConceptsPanel();

  static const _concepts = [
    ('Opportunity Cost', 'Good', WicaraColors.accentMint),
    ('Macro vs. Micro Economics', 'Strong', WicaraColors.accentMint),
    ('Supply and Demand', 'Good', WicaraColors.accentMint),
    ('Market Equilibrium', 'Review', WicaraColors.accentAmber),
    ('Elasticity', 'Review', WicaraColors.accentAmber),
  ];

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
          for (final concept in _concepts) ...[
            _ConceptResultTile(
              title: concept.$1,
              status: concept.$2,
              statusColor: concept.$3,
            ),
            if (concept != _concepts.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
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
  const _SpacedRepetitionImpactPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Spaced repetition impact',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
            "You've strengthened your memory.",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: const [
              Expanded(
                child: _ImpactMetric(
                  value: '+23%',
                  label: 'Retention Lift',
                  icon: Icons.arrow_upward_rounded,
                  iconColor: WicaraColors.primary,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ImpactMetric(
                  value: '7',
                  label: 'Days Until Next Review',
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

class _BackHomeButton extends StatelessWidget {
  const _BackHomeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
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
                'Back to Home',
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
              label: 'Recommended',
              isSelected: selectedTab == _QueueTab.recommended,
              onTap: () => onChanged(_QueueTab.recommended),
            ),
          ),
          Expanded(
            child: _QueueTabButton(
              label: 'Tracks',
              isSelected: selectedTab == _QueueTab.tracks,
              onTap: () => onChanged(_QueueTab.tracks),
            ),
          ),
          Expanded(
            child: _QueueTabButton(
              label: 'Gallery',
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
                      'Content Gallery',
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
                'All videos generated before are here, ready to replay with the notes that WICARA compiled for you.',
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
              "Recommended for Calculus I based on\nyour current gaps and readiness.",
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
            'Continue Learning',
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
                      'Learn something new',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Create a new track outside your current list.',
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
            'New track',
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
            label: 'Home',
            onSelected: onSelected,
          ),
          _ShortcutItem(
            tab: _HomeTab.queue,
            selectedTab: selectedTab,
            icon: Icons.school_outlined,
            label: 'Learn',
            onSelected: onSelected,
          ),
          _ShortcutItem(
            tab: _HomeTab.progress,
            selectedTab: selectedTab,
            icon: Icons.bar_chart_rounded,
            label: 'Progress',
            onSelected: onSelected,
          ),
          _ShortcutItem(
            tab: _HomeTab.profile,
            selectedTab: selectedTab,
            icon: Icons.person_outline_rounded,
            label: 'Profile',
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
  const _ProfilePage({required this.constraints, required this.onBack});

  final BoxConstraints constraints;
  final VoidCallback onBack;

  void _logout(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 118),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 136),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(onBack: onBack),
            const SizedBox(height: 34),
            const _SectionWordmark(
              assetPath: 'lib/src/assets/profileIcon.png',
              title: 'Profile',
              iconSize: 84,
            ),
            const SizedBox(height: 12),
            Text(
              'Manage your learning preferences and account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            const _ProfileHeaderCard(),
            const SizedBox(height: 22),
            const _ProfileSection(
              title: 'Learning setup',
              children: [
                _ProfileSettingTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Full name',
                  value: 'Aisyah Putri',
                ),
                _ProfileSettingTile(
                  icon: Icons.public_rounded,
                  label: 'Country',
                  value: 'Indonesia',
                ),
                _ProfileSettingTile(
                  icon: Icons.school_outlined,
                  label: 'Grade level',
                  value: 'Grade 11 (SMA Kelas 2)',
                ),
                _ProfileSettingTile(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  value: 'Bahasa Indonesia',
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _ProfileSection(
              title: 'Preferences',
              children: [
                _ProfileSettingTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Subjects',
                  value: 'Math, Physics, Chemistry, Biology',
                ),
                _ProfileSettingTile(
                  icon: Icons.track_changes_rounded,
                  label: 'Study goal',
                  value: 'Improve understanding',
                ),
                _ProfileSettingTile(
                  icon: Icons.schedule_rounded,
                  label: 'Daily study time',
                  value: '30-60 minutes',
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
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard();

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
              'AP',
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
                  'Aisyah Putri',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Learner',
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
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
          const Icon(
            Icons.chevron_right_rounded,
            color: WicaraColors.softMuted,
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _ProgressHub extends StatelessWidget {
  const _ProgressHub({
    required this.constraints,
    required this.curriculumRepository,
    required this.onBack,
    required this.showLearningReport,
    required this.showKnowledgeMap,
    required this.onOpenLearningReport,
    required this.onCloseLearningReport,
    required this.onOpenKnowledgeMap,
    required this.onCloseKnowledgeMap,
  });

  final BoxConstraints constraints;
  final CurriculumRepository curriculumRepository;
  final VoidCallback onBack;
  final bool showLearningReport;
  final bool showKnowledgeMap;
  final VoidCallback onOpenLearningReport;
  final VoidCallback onCloseLearningReport;
  final VoidCallback onOpenKnowledgeMap;
  final VoidCallback onCloseKnowledgeMap;

  @override
  Widget build(BuildContext context) {
    if (showLearningReport) {
      return _LearningReportDetail(
        constraints: constraints,
        onBack: onCloseLearningReport,
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
            const _SectionWordmark(
              assetPath: 'lib/src/assets/progressIcon.png',
              title: 'Progress',
              iconSize: 84,
            ),
            const SizedBox(height: 12),
            Text(
              'Start with your learning report, then explore the knowledge map.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 28),
            _LearningReportOption(onOpen: onOpenLearningReport),
            const SizedBox(height: 22),
            _KnowledgeMapOption(onOpen: onOpenKnowledgeMap),
          ],
        ),
      ),
    );
  }
}

class _LearningReportOption extends StatelessWidget {
  const _LearningReportOption({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _ProgressOptionPanel(
      onTap: onOpen,
      icon: Icons.analytics_outlined,
      iconColor: WicaraColors.primaryDeep,
      iconBackground: WicaraColors.speechBlue,
      title: 'Learning Report',
      subtitle: 'Weekly performance, fixed gaps, unlocked concepts.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'May 12 - May 18, 2025',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _SoftBadge('+4 fixed'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                _ReportBarGroup(label: 'Overall', before: 0.72, after: 0.88),
                SizedBox(width: 18),
                _ReportBarGroup(
                  label: 'Application',
                  before: 0.65,
                  after: 0.85,
                ),
                SizedBox(width: 18),
                _ReportBarGroup(label: 'Analysis', before: 0.58, after: 0.82),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(
                child: _ReportMetric(
                  label: 'Fixed gaps',
                  value: '12',
                  delta: '+4 this week',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _ReportMetric(
                  label: 'Remaining gaps',
                  value: '5',
                  delta: '-2 this week',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LearningReportDetail extends StatefulWidget {
  const _LearningReportDetail({
    required this.constraints,
    required this.onBack,
  });

  final BoxConstraints constraints;
  final VoidCallback onBack;

  @override
  State<_LearningReportDetail> createState() => _LearningReportDetailState();
}

class _LearningReportDetailState extends State<_LearningReportDetail> {
  int _selectedWeek = 3;

  static const _weeks = [
    _WeeklyReportData(
      range: 'Apr 21 - Apr 27',
      score: 74,
      fixed: 6,
      remaining: 11,
      retention: 16,
      overall: 0.72,
      application: 0.64,
      analysis: 0.58,
      concepts: 'Limits, graph reading',
    ),
    _WeeklyReportData(
      range: 'Apr 28 - May 4',
      score: 79,
      fixed: 8,
      remaining: 9,
      retention: 18,
      overall: 0.76,
      application: 0.69,
      analysis: 0.63,
      concepts: 'Derivatives, slope',
    ),
    _WeeklyReportData(
      range: 'May 5 - May 11',
      score: 83,
      fixed: 10,
      remaining: 7,
      retention: 21,
      overall: 0.81,
      application: 0.76,
      analysis: 0.71,
      concepts: 'Optimization, rates',
    ),
    _WeeklyReportData(
      range: 'May 12 - May 18',
      score: 88,
      fixed: 12,
      remaining: 5,
      retention: 23,
      overall: 0.88,
      application: 0.85,
      analysis: 0.82,
      concepts: 'Chain rule, review gaps',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _weeks[_selectedWeek];

    return SingleChildScrollView(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Learning Report',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      height: 1.12,
                    ),
                  ),
                ),
                _SoftBadge('Complete'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Hover or tap a week to preview growth, fixed gaps, and memory lift.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            _Panel(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    selected.range,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected.concepts,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _WeeklyReportSnapshot(
                      key: ValueKey(selected.range),
                      data: selected,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 102,
              child: Row(
                children: [
                  for (var index = 0; index < _weeks.length; index++) ...[
                    Expanded(
                      child: _WeeklyHoverTile(
                        data: _weeks[index],
                        weekNumber: index + 1,
                        isSelected: index == _selectedWeek,
                        onSelected: () => setState(() => _selectedWeek = index),
                      ),
                    ),
                    if (index < _weeks.length - 1) const SizedBox(width: 9),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            _Panel(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Skill growth',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 124,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _ReportBarGroup(
                          label: 'Overall',
                          before: math.max(selected.overall - 0.16, 0.18),
                          after: selected.overall,
                        ),
                        const SizedBox(width: 18),
                        _ReportBarGroup(
                          label: 'Application',
                          before: math.max(selected.application - 0.2, 0.18),
                          after: selected.application,
                        ),
                        const SizedBox(width: 18),
                        _ReportBarGroup(
                          label: 'Analysis',
                          before: math.max(selected.analysis - 0.24, 0.18),
                          after: selected.analysis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
  const _WeeklyReportSnapshot({required this.data, super.key});

  final _WeeklyReportData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ReportMetric(
            label: 'Score',
            value: '${data.score}%',
            delta: '+${data.retention}% retention',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ReportMetric(
            label: 'Fixed gaps',
            value: '${data.fixed}',
            delta: '${data.remaining} left',
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
                'W$weekNumber',
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

  @override
  void initState() {
    super.initState();
    _loadCurriculum();
  }

  Future<void> _loadCurriculum() async {
    try {
      final subjects = await widget.curriculumRepository.fetchSubjects();
      final tabs = _subjectTabsFromApi(subjects);
      final selectedSubjectCode = _defaultSubjectCode(tabs);
      final graph = await widget.curriculumRepository.fetchKnowledgeMap(
        subject: selectedSubjectCode,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _subjects = tabs;
        _selectedSubjectCode = selectedSubjectCode;
        _graph = _knowledgeGraphFromApi(graph);
        _visibleSectionCount = _initialVisibleSections;
        _selectedNode = null;
        _isUsingFallbackGraph = false;
        _isLoadingCurriculum = false;
        _isLoadingMoreSections = false;
      });
    } catch (_) {
      if (!mounted) {
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

      if (!mounted) {
        return;
      }

      setState(() {
        _graph = _knowledgeGraphFromApi(graph);
        _visibleSectionCount = _initialVisibleSections;
        _selectedNode = null;
        _isUsingFallbackGraph = false;
        _isLoadingCurriculum = false;
        _isLoadingMoreSections = false;
      });
    } catch (_) {
      if (!mounted) {
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
    final fallback = _ConceptDetailData.fromGraph(_graph, node);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ConceptDetailBottomSheet(
          detailFuture: _loadConceptDetail(node, fallback),
          fallback: fallback,
          onClose: () => Navigator.of(sheetContext).pop(),
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
                'Knowledge Map',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Explore Kurikulum Merdeka phases, subject domains, and prerequisite paths.',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final buttonWidth = (constraints.maxWidth - spacing) / 2;

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: WicaraColors.speechBlue,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: WicaraColors.primaryLight),
          ),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.center,
            children: [
              for (final subject in subjects)
                SizedBox(
                  width: buttonWidth,
                  child: _SubjectMapTabButton(
                    item: subject,
                    isSelected: subject.code == selectedCode,
                    onSelected: () => onSelected(subject),
                  ),
                ),
            ],
          ),
        );
      },
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
    final label = isLoading
        ? 'Loading curriculum from backend...'
        : isUsingFallback
        ? 'Static fallback graph'
        : 'Live Kurikulum Merdeka graph';
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
    return InkWell(
      onTap: item.isLocked ? null : onSelected,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? item.color.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: item.color.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.isLocked) ...[
                Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: isSelected ? item.color : WicaraColors.softMuted,
                ),
                const SizedBox(width: 3),
              ],
              Text(
                item.label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: item.isLocked
                      ? WicaraColors.softMuted
                      : isSelected
                      ? item.color
                      : WicaraColors.muted,
                  fontSize: 12,
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

class _KnowledgeMapPreview extends StatelessWidget {
  const _KnowledgeMapPreview();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _SubjectGraphPreviewTile(
            label: 'Math',
            color: WicaraColors.math,
            icon: Icons.calculate_outlined,
            nodes: 42,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _SubjectGraphPreviewTile(
            label: 'Physics',
            color: WicaraColors.physics,
            icon: Icons.bolt_outlined,
            nodes: 18,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _SubjectGraphPreviewTile(
            label: 'Chemistry',
            color: WicaraColors.chemistry,
            icon: Icons.science_outlined,
            nodes: 21,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _SubjectGraphPreviewTile(
            label: 'Biology',
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
            '$nodes nodes',
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
                          'Mastery confidence',
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
              title: 'About this concept',
              child: Text(
                _nodeDescription(node),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: WicaraColors.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ConceptDetailSection(
              title: 'Prerequisites',
              child: Column(
                children: [
                  if (prerequisites.isEmpty)
                    _ConceptRelationRow(
                      relation: _ConceptRelationItem.fromNode(node),
                      labelOverride: 'No direct prerequisite',
                    )
                  else
                    for (final relation in prerequisites)
                      _ConceptRelationRow(relation: relation),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ConceptDetailSection(
              title: 'Related concepts',
              child: Column(
                children: [
                  if (related.isEmpty)
                    _ConceptRelationRow(
                      relation: _ConceptRelationItem.fromNode(node),
                      labelOverride: 'No direct related concept',
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
                          'Cross-subject connections',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: WicaraColors.text,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Graph of Graphs links are visible when available.',
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
                    : 'Kurikulum Merdeka concept bridge',
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
          _SoftBadge('RELATED'),
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

String _nodeDescription(_KnowledgeNode node) {
  final description = node.description;
  if (description != null && description.isNotEmpty) {
    return description;
  }
  return 'Concept in the Kurikulum Merdeka prerequisite graph.';
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
  });

  final String title;
  final double width;
  final double height;
  final List<_MapGroup> groups;
  final List<_KnowledgeNode> nodes;
  final List<_KnowledgeEdge> edges;
  final bool topDown;

  List<_KnowledgeSection> get sections {
    return [
      for (var index = 0; index < groups.length; index++)
        _KnowledgeSection(
          label: groups[index].label,
          nodes: nodes
              .where((node) => _groupIndexFor(node.x) == index)
              .toList(),
        ),
    ];
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

_KnowledgeGraph _knowledgeGraphFromApi(CurriculumKnowledgeMap graph) {
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
    return _ProgressOptionPanel(
      onTap: onOpen,
      icon: Icons.account_tree_outlined,
      iconColor: WicaraColors.primaryDeep,
      iconBackground: WicaraColors.speechBlue,
      title: 'Knowledge Map',
      subtitle: 'Visualize prerequisites, gaps, and next concepts.',
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
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: titleFontSize,
            height: 1.1,
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
