import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/wicara_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/domain/onboarding_copy.dart';
import '../domain/learning_goal_repository.dart';

class LearningGoalPage extends StatefulWidget {
  const LearningGoalPage({
    required this.learningGoalRepository,
    required this.onboardingController,
    super.key,
  });

  final LearningGoalRepository learningGoalRepository;
  final OnboardingController onboardingController;

  @override
  State<LearningGoalPage> createState() => _LearningGoalPageState();
}

class _LearningGoalPageState extends State<LearningGoalPage> {
  final _controller = TextEditingController();
  bool _isGenerating = false;
  bool _isComplete = false;
  LearningGoalResolution? _resolution;

  @override
  void dispose() {
    _controller.removeListener(_handleTopicChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTopicChanged);
  }

  void _handleTopicChanged() {
    if (_resolution != null) {
      return;
    }
    setState(() {});
  }

  Future<void> _generatePretest() async {
    if (_controller.text.trim().isEmpty || _isGenerating) {
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final profile = widget.onboardingController.profile;
      final subjectCode = _effectiveSubjectCode(profile.selectedSubjects);
      final resolution = await widget.learningGoalRepository
          .resolveLearningGoal(
            rawQuery: _controller.text.trim(),
            subjectCode: subjectCode,
            educationLevel: profile.educationLevel,
            gradeLevel: profile.gradeLevel,
            language: profile.preferredLanguage,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _resolution = resolution;
        _isGenerating = false;
      });
    } on ActiveGoalConflictException catch (conflict) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      await _showConflictDialog(conflict);
    } on LearningGoalException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _showConflictDialog(ActiveGoalConflictException conflict) async {
    final copy = OnboardingCopy.forLanguage(
      widget.onboardingController.profile.preferredLanguage,
    );
    final isId = copy.isIndonesian;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(isId ? 'Goal aktif ditemukan' : 'Active goal found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isId
                  ? 'Kamu sudah punya goal aktif untuk node ini:'
                  : 'You already have an active goal for this node:',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${conflict.existingTopic}"',
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: WicaraColors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isId
                  ? 'Kamu bisa lanjutkan goal ini, atau kembali memilih node.'
                  : 'You can continue this goal, or go back to choose a node.',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              setState(() => _resolution = null);
            },
            child: Text(isId ? 'Kembali' : 'Back'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _continueActiveGoal(nextAction: conflict.existingNextAction);
            },
            child: Text(isId ? 'Lanjutkan goal ini' : 'Continue existing goal'),
          ),
        ],
      ),
    );
  }

  void _continueActiveGoal({required String nextAction}) {
    if (nextAction == 'continue_learning' || nextAction == 'enter_workspace') {
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.home,
        arguments: {'open_goal_history': true},
      );
      return;
    }
    Navigator.of(context).pushReplacementNamed(AppRoutes.pretest);
  }

  void _refineResolution() {
    setState(() => _resolution = null);
  }

  void _selectSubject(String subjectCode) {
    if (subjectCode != 'math') {
      return;
    }
    setState(() => _resolution = null);
  }

  String _effectiveSubjectCode(List<String> _) {
    return 'math';
  }

  VoidCallback? _primaryAction() {
    if (_controller.text.trim().isEmpty || _isGenerating) {
      return null;
    }
    return _generatePretest;
  }

  String _primaryActionLabel(OnboardingCopy copy) {
    final resolution = _resolution;
    if (resolution == null) {
      return copy.isIndonesian
          ? 'Cari node goal belajar'
          : 'Find learning goal node';
    }
    if (resolution.suggestedConcept == null) {
      return copy.isIndonesian
          ? 'Cari ulang dengan query baru'
          : 'Search again';
    }
    return copy.isIndonesian
        ? 'Cari ulang dengan query baru'
        : 'Search again with a new query';
  }

  Future<void> _selectRecommendedNode() async {
    final resolution = _resolution;
    if (resolution == null ||
        resolution.suggestedConcept == null ||
        _isGenerating) {
      return;
    }
    try {
      await _confirmSelectedResolution(resolution);
    } on ActiveGoalConflictException catch (conflict) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      await _showConflictDialog(conflict);
    } on LearningGoalException catch (error) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showLearningGoalError(error);
    }
  }

  Future<void> _selectAlternative(LearningConceptSuggestion suggestion) async {
    final resolution = _resolution;
    if (resolution == null || _isGenerating) {
      return;
    }
    final confirmed = await _showGoalConfirmationDialog(suggestion);
    if (!mounted || !confirmed) {
      return;
    }
    setState(() => _isGenerating = true);
    try {
      final selected = await widget.learningGoalRepository
          .selectResolvedConcept(
            resolutionId: resolution.resolutionId,
            conceptId: suggestion.conceptId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _resolution = selected;
      });
      await _confirmResolutionAndOpenPretest(selected.resolutionId);
    } on ActiveGoalConflictException catch (conflict) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      await _showConflictDialog(conflict);
    } on LearningGoalException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isGenerating = false);
      _showLearningGoalError(error);
    }
  }

  Future<void> _confirmResolutionAndOpenPretest(String resolutionId) async {
    setState(() => _isGenerating = true);
    await widget.learningGoalRepository.confirmResolvedGoal(
      resolutionId: resolutionId,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isGenerating = false;
      _isComplete = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(AppRoutes.pretest);
  }

  Future<void> _confirmSelectedResolution(
    LearningGoalResolution resolution,
  ) async {
    final concept = resolution.suggestedConcept;
    if (concept == null) {
      setState(() => _isGenerating = false);
      return;
    }
    if (_isGenerating) {
      setState(() => _isGenerating = false);
    }
    final confirmed = await _showGoalConfirmationDialog(concept);
    if (!mounted || !confirmed) {
      return;
    }
    await _confirmResolutionAndOpenPretest(resolution.resolutionId);
  }

  Future<bool> _showGoalConfirmationDialog(
    LearningConceptSuggestion concept,
  ) async {
    final copy = OnboardingCopy.forLanguage(
      widget.onboardingController.profile.preferredLanguage,
    );
    final isId = copy.isIndonesian;
    final description = _nodeDescription(concept, isIndonesian: isId);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              isId
                  ? 'Yakin ingin mengambil node ini?'
                  : 'Are you sure you want to take this?',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concept.title,
                  style: Theme.of(dialogContext).textTheme.titleMedium
                      ?.copyWith(
                        color: WicaraColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(isId ? 'Pilih node lain' : 'Choose another node'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(isId ? 'Mulai pretest' : 'Start pretest'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showNodeDetail(
    LearningConceptSuggestion concept,
    LearningGoalResolution resolution,
  ) async {
    final copy = OnboardingCopy.forLanguage(
      widget.onboardingController.profile.preferredLanguage,
    );
    final isId = copy.isIndonesian;
    final description = _nodeDescription(concept, isIndonesian: isId);
    final confidence = ((concept.confidence ?? resolution.confidence) * 100)
        .round();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            22,
            4,
            22,
            22 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isId ? 'Detail node' : 'Node detail',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: WicaraColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                concept.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: WicaraColors.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isId ? 'Deskripsi' : 'Description',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: WicaraColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                decoration: BoxDecoration(
                  color: WicaraColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: WicaraColors.primary.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _NodeDetailRow(
                label: isId ? 'Mata pelajaran' : 'Subject',
                value: _subjectLabel(
                  concept.subjectCode.isEmpty
                      ? concept.subject
                      : concept.subjectCode,
                  isIndonesian: isId,
                ),
              ),
              _NodeDetailRow(
                label: isId ? 'Kecocokan' : 'Match',
                value: '$confidence%',
              ),
              if (concept.levelNote != null) ...[
                const SizedBox(height: 10),
                _LevelNoteBox(
                  note: concept.levelNote!,
                  relation: concept.gradeRelation,
                ),
              ],
              if (resolution.searchScopeReason != null) ...[
                const SizedBox(height: 10),
                _SearchScopeNote(text: resolution.searchScopeReason!),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _openKnowledgeMap();
                  },
                  icon: const Icon(Icons.account_tree_outlined, size: 18),
                  label: Text(isId ? 'Lihat graph' : 'See graph'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLearningGoalError(LearningGoalException error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openKnowledgeMap() {
    Navigator.of(context).pushNamed(
      AppRoutes.home,
      arguments: {
        'focus_concept_codes': _resolution?.graphFocusCodes ?? const <String>[],
        'subject_code': _resolution?.graphSubjectCode,
      },
    );
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.onboardingController,
      builder: (context, _) {
        final copy = OnboardingCopy.forLanguage(
          widget.onboardingController.profile.preferredLanguage,
        );
        final profile = widget.onboardingController.profile;
        final subjectChoices = _subjectChoices(isIndonesian: copy.isIndonesian);
        final selectedSubjectCode = _effectiveSubjectCode(
          profile.selectedSubjects,
        );

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pageWidth = math.min(constraints.maxWidth, 430.0);
                final horizontalPadding = constraints.maxWidth < 360
                    ? 18.0
                    : 28.0;

                if (_resolution != null && !_isComplete) {
                  return _ResolvedLearningGoalLayout(
                    pageWidth: pageWidth,
                    horizontalPadding: horizontalPadding,
                    copy: copy,
                    subjectChoices: subjectChoices,
                    selectedSubjectCode: selectedSubjectCode,
                    controller: _controller,
                    resolution: _resolution!,
                    onBack: _goBack,
                    onSubjectSelected: _selectSubject,
                    onRefine: _refineResolution,
                    onOpenGraph: _openKnowledgeMap,
                    onRecommendedSelected: _selectRecommendedNode,
                    onAlternativeSelected: _selectAlternative,
                    onViewDetail: _showNodeDetail,
                  );
                }

                return Center(
                  child: SizedBox(
                    width: pageWidth,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        14,
                        horizontalPadding,
                        28,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(0.0, constraints.maxHeight - 42),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _goBack,
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  iconSize: 33,
                                  color: WicaraColors.ink,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 38,
                                    height: 38,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
                              child: AnimatedPadding(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                padding: EdgeInsets.only(
                                  bottom: math.min(
                                    _controller.text.length * 0.25,
                                    24,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Center(
                                      child: Image.asset(
                                        'lib/src/assets/pretestIcon.png',
                                        width: 84,
                                        height: 84,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      copy.learningGoalTitle,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontSize: 24,
                                            height: 1.12,
                                          ),
                                    ),
                                    const SizedBox(height: 9),
                                    Text(
                                      copy.learningGoalSubtitle,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: WicaraColors.muted,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.35,
                                          ),
                                    ),
                                    const SizedBox(height: 28),
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        19,
                                        20,
                                        21,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: WicaraColors.line,
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: WicaraColors.shadowBlue
                                                .withValues(alpha: 0.12),
                                            blurRadius: 17,
                                            offset: const Offset(0, 9),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            copy.learningTopicLabel,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 13),
                                          _SubjectSelector(
                                            choices: subjectChoices,
                                            selectedCode: selectedSubjectCode,
                                            isIndonesian: copy.isIndonesian,
                                            onSelected: _selectSubject,
                                          ),
                                          const SizedBox(height: 14),
                                          _LearningGoalField(
                                            controller: _controller,
                                            copy: copy,
                                            isLocked: _resolution != null,
                                          ),
                                          const SizedBox(height: 18),
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            child: _isComplete
                                                ? _GeneratedPretestNotice(
                                                    copy: copy,
                                                  )
                                                : _resolution != null
                                                ? _ResolutionNotice(
                                                    resolution: _resolution!,
                                                    isIndonesian:
                                                        copy.isIndonesian,
                                                    onRecommendedSelected:
                                                        _selectRecommendedNode,
                                                    onAlternativeSelected:
                                                        _selectAlternative,
                                                    onViewDetail:
                                                        _showNodeDetail,
                                                  )
                                                : _PretestPreviewNotice(
                                                    copy: copy,
                                                  ),
                                          ),
                                          if (_resolution == null) ...[
                                            const SizedBox(height: 22),
                                            GradientButton(
                                              label: _primaryActionLabel(copy),
                                              onPressed: _primaryAction(),
                                              isLoading: _isGenerating,
                                            ),
                                          ],
                                        ],
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
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ResolvedLearningGoalLayout extends StatelessWidget {
  const _ResolvedLearningGoalLayout({
    required this.pageWidth,
    required this.horizontalPadding,
    required this.copy,
    required this.subjectChoices,
    required this.selectedSubjectCode,
    required this.controller,
    required this.resolution,
    required this.onBack,
    required this.onSubjectSelected,
    required this.onRefine,
    required this.onOpenGraph,
    required this.onRecommendedSelected,
    required this.onAlternativeSelected,
    required this.onViewDetail,
  });

  final double pageWidth;
  final double horizontalPadding;
  final OnboardingCopy copy;
  final List<_SubjectChoice> subjectChoices;
  final String selectedSubjectCode;
  final TextEditingController controller;
  final LearningGoalResolution resolution;
  final VoidCallback onBack;
  final ValueChanged<String> onSubjectSelected;
  final VoidCallback onRefine;
  final VoidCallback onOpenGraph;
  final VoidCallback onRecommendedSelected;
  final ValueChanged<LearningConceptSuggestion> onAlternativeSelected;
  final void Function(
    LearningConceptSuggestion concept,
    LearningGoalResolution resolution,
  )
  onViewDetail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: pageWidth,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            10,
            horizontalPadding,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.chevron_left_rounded),
                    iconSize: 33,
                    color: WicaraColors.ink,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 38,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      copy.learningGoalTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: WicaraColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: WicaraColors.line, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: WicaraColors.shadowBlue.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      copy.learningTopicLabel,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 11),
                    _SubjectSelector(
                      choices: subjectChoices,
                      selectedCode: selectedSubjectCode,
                      isIndonesian: copy.isIndonesian,
                      onSelected: onSubjectSelected,
                    ),
                    const SizedBox(height: 12),
                    _LearningGoalField(
                      controller: controller,
                      copy: copy,
                      isLocked: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _ResolutionNotice(
                    resolution: resolution,
                    isIndonesian: copy.isIndonesian,
                    onRecommendedSelected: onRecommendedSelected,
                    onAlternativeSelected: onAlternativeSelected,
                    onViewDetail: onViewDetail,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _ResolutionActionBar(
                isIndonesian: copy.isIndonesian,
                onRefine: onRefine,
                onOpenGraph: onOpenGraph,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearningGoalField extends StatefulWidget {
  const _LearningGoalField({
    required this.controller,
    required this.copy,
    required this.isLocked,
  });

  final TextEditingController controller;
  final OnboardingCopy copy;
  final bool isLocked;

  @override
  State<_LearningGoalField> createState() => _LearningGoalFieldState();
}

class _LearningGoalFieldState extends State<_LearningGoalField> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: WicaraColors.fieldFill,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: WicaraColors.line, width: 1.3),
      ),
      child: TextField(
        controller: widget.controller,
        readOnly: widget.isLocked,
        minLines: 1,
        maxLines: 4,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: widget.copy.typeATopicHint),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: WicaraColors.text,
          fontSize: _topicFontSize(widget.controller.text),
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }

  double _topicFontSize(String text) {
    if (text.length > 72) {
      return 13;
    }
    if (text.length > 36) {
      return 14;
    }
    return 16;
  }
}

class _SubjectChoice {
  const _SubjectChoice({
    required this.code,
    required this.label,
    this.isLocked = false,
  });

  final String code;
  final String label;
  final bool isLocked;
}

class _SubjectSelector extends StatelessWidget {
  const _SubjectSelector({
    required this.choices,
    required this.selectedCode,
    required this.isIndonesian,
    required this.onSelected,
  });

  final List<_SubjectChoice> choices;
  final String selectedCode;
  final bool isIndonesian;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isIndonesian ? 'Mata pelajaran' : 'Subject',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: WicaraColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final itemWidth = math.max(
              0.0,
              (constraints.maxWidth - spacing) / 2,
            );
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final choice in choices)
                  SizedBox(
                    width: itemWidth,
                    child: _SubjectChoiceTile(
                      choice: choice,
                      isSelected: choice.code == selectedCode,
                      isIndonesian: isIndonesian,
                      onTap: choice.isLocked
                          ? null
                          : () => onSelected(choice.code),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SubjectChoiceTile extends StatelessWidget {
  const _SubjectChoiceTile({
    required this.choice,
    required this.isSelected,
    required this.isIndonesian,
    required this.onTap,
  });

  final _SubjectChoice choice;
  final bool isSelected;
  final bool isIndonesian;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _subjectColor(choice.code);
    final isLocked = choice.isLocked;
    return Material(
      color: isLocked
          ? WicaraColors.fieldFill
          : isSelected
          ? color.withValues(alpha: 0.14)
          : WicaraColors.fieldFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLocked
              ? WicaraColors.line
              : isSelected
              ? color
              : WicaraColors.line,
          width: isSelected ? 1.4 : 1.1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isSelected ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isLocked
                      ? Icons.lock_outline_rounded
                      : _subjectIcon(choice.code),
                  color: isLocked ? WicaraColors.softMuted : color,
                  size: 17,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  choice.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isLocked ? WicaraColors.muted : WicaraColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isLocked) ...[
                const SizedBox(width: 6),
                Text(
                  isIndonesian ? 'Kunci' : 'Lock',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.softMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PretestPreviewNotice extends StatelessWidget {
  const _PretestPreviewNotice({required this.copy});

  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return _NoticeBox(
      icon: Icons.manage_search_rounded,
      title: copy.isIndonesian
          ? 'Cari goal belajar dulu'
          : 'Find the learning goal first',
      description: copy.isIndonesian
          ? 'Tulis tujuanmu, lalu WICARA akan mencocokkan ke node materi. Pretest baru mulai setelah node ini kamu setujui.'
          : 'Type your goal, then WICARA will match it to a material node. The pretest starts only after you confirm the node.',
      color: WicaraColors.primary,
    );
  }
}

class _GeneratedPretestNotice extends StatelessWidget {
  const _GeneratedPretestNotice({required this.copy});

  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return _NoticeBox(
      icon: Icons.check_circle_rounded,
      title: copy.pretestGeneratedCompleteLabel,
      description: copy.openingAdaptivePretestLabel,
      color: WicaraColors.accentMint,
    );
  }
}

class _ResolutionNotice extends StatelessWidget {
  const _ResolutionNotice({
    required this.resolution,
    required this.isIndonesian,
    required this.onRecommendedSelected,
    required this.onAlternativeSelected,
    required this.onViewDetail,
  });

  final LearningGoalResolution resolution;
  final bool isIndonesian;
  final VoidCallback onRecommendedSelected;
  final ValueChanged<LearningConceptSuggestion> onAlternativeSelected;
  final void Function(
    LearningConceptSuggestion concept,
    LearningGoalResolution resolution,
  )
  onViewDetail;

  @override
  Widget build(BuildContext context) {
    final concept = resolution.suggestedConcept;
    if (concept == null) {
      return Container(
        key: ValueKey(resolution.resolutionId),
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
        decoration: BoxDecoration(
          color: WicaraColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: WicaraColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NoticeHeader(
              icon: Icons.manage_search_rounded,
              title: isIndonesian ? 'Node belum pasti' : 'Node is not certain',
              trailing: resolution.searchScope.isEmpty
                  ? null
                  : resolution.searchScope.replaceAll('_', ' '),
            ),
            const SizedBox(height: 9),
            Text(
              resolution.clarificationQuestion ??
                  (isIndonesian
                      ? 'Coba tambahkan kelas, mata pelajaran, atau topik yang lebih spesifik.'
                      : 'Try adding grade, subject, or a more specific topic.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            if (resolution.searchScopeReason != null) ...[
              const SizedBox(height: 10),
              _SearchScopeNote(text: resolution.searchScopeReason!),
            ],
            if (resolution.alternatives.isNotEmpty) ...[
              const SizedBox(height: 13),
              Text(
                isIndonesian
                    ? 'Pilih kandidat yang paling mirip'
                    : 'Pick the closest candidate',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final alternative in resolution.alternatives.take(4)) ...[
                _NodeOptionCard(
                  suggestion: alternative,
                  isIndonesian: isIndonesian,
                  onSelected: () => onAlternativeSelected(alternative),
                  onViewDetail: () => onViewDetail(alternative, resolution),
                ),
                const SizedBox(height: 7),
              ],
            ],
          ],
        ),
      );
    }
    return Container(
      key: ValueKey(resolution.resolutionId),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: WicaraColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WicaraColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_tree_outlined,
                color: WicaraColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isIndonesian ? 'Node rekomendasi' : 'Recommended node',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _NodeOptionCard(
            suggestion: concept,
            isIndonesian: isIndonesian,
            onSelected: onRecommendedSelected,
            onViewDetail: () => onViewDetail(concept, resolution),
          ),
          if (resolution.alternatives.isNotEmpty) ...[
            const SizedBox(height: 13),
            Text(
              isIndonesian ? 'Kemungkinan node lain' : 'Other possible nodes',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final alternative in resolution.alternatives.take(3)) ...[
              _NodeOptionCard(
                suggestion: alternative,
                isIndonesian: isIndonesian,
                onSelected: () => onAlternativeSelected(alternative),
                onViewDetail: () => onViewDetail(alternative, resolution),
              ),
              const SizedBox(height: 7),
            ],
          ],
        ],
      ),
    );
  }
}

class _ResolutionActionBar extends StatelessWidget {
  const _ResolutionActionBar({
    required this.isIndonesian,
    required this.onRefine,
    required this.onOpenGraph,
  });

  final bool isIndonesian;
  final VoidCallback onRefine;
  final VoidCallback onOpenGraph;

  @override
  Widget build(BuildContext context) {
    final actionTextStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WicaraColors.line),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRefine,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(isIndonesian ? 'Ubah prompt' : 'Edit prompt'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: WicaraColors.text,
                  side: const BorderSide(color: WicaraColors.line),
                  textStyle: actionTextStyle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: onOpenGraph,
                icon: const Icon(Icons.account_tree_outlined, size: 18),
                label: Text(isIndonesian ? 'Lihat graph' : 'See graph'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: WicaraColors.primary,
                  foregroundColor: Colors.white,
                  textStyle: actionTextStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeOptionCard extends StatelessWidget {
  const _NodeOptionCard({
    required this.suggestion,
    required this.isIndonesian,
    required this.onSelected,
    required this.onViewDetail,
  });

  final LearningConceptSuggestion suggestion;
  final bool isIndonesian;
  final VoidCallback onSelected;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    final description = _nodeDescription(
      suggestion,
      isIndonesian: isIndonesian,
    );
    final gradeFit = _gradeFitDescription(
      suggestion,
      isIndonesian: isIndonesian,
    );
    return Material(
      color: Colors.white.withValues(alpha: 0.78),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: WicaraColors.line),
      ),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                suggestion.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: WicaraColors.text,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.28,
                ),
              ),
              if (gradeFit.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                  decoration: BoxDecoration(
                    color: _levelNoteColor(
                      suggestion.gradeRelation,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _levelNoteColor(
                        suggestion.gradeRelation,
                      ).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _levelNoteIcon(suggestion.gradeRelation),
                        color: _levelNoteColor(suggestion.gradeRelation),
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          gradeFit,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: WicaraColors.text,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onViewDetail,
                  icon: const Icon(Icons.info_outline_rounded, size: 17),
                  label: Text(isIndonesian ? 'Lihat detail' : 'View detail'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
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

class _NodeDetailRow extends StatelessWidget {
  const _NodeDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.softMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w700,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _nodeDescription(
  LearningConceptSuggestion suggestion, {
  required bool isIndonesian,
}) {
  final candidates = isIndonesian
      ? [suggestion.idDesc, suggestion.description]
      : [suggestion.enDesc, suggestion.description];
  for (final candidate in candidates) {
    final description = _courseDescriptionOnly(candidate);
    if (description.isNotEmpty) {
      return description;
    }
  }
  return isIndonesian ? 'Deskripsi tidak ditemukan.' : 'Description not found.';
}

String _courseDescriptionOnly(String value) {
  var description = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (description.isEmpty) {
    return '';
  }
  final patterns = <RegExp>[
    RegExp(
      r'\s+within\s+.+?\s+for\s+Phase\s+[A-F](?:/[A-F])?'
      r'(?:\s*/\s*[^.]+)*\.?',
      caseSensitive: false,
    ),
    RegExp(
      r'\s+aligned with Kurikulum Merdeka(?:\s+[A-Z]+)?\s+Phase\s+[A-F]'
      r'(?:/[A-F])?(?:\s+[A-Z]+)?\s+learning outcomes\.?',
      caseSensitive: false,
    ),
    RegExp(
      r'\s+sesuai Capaian Pembelajaran Kurikulum Merdeka(?:\s+SD)?'
      r'\s+Fase\s+[A-F](?:/[A-F])?(?:\s+[A-Z]+)?\.?',
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    description = description.replaceAll(pattern, '').trim();
  }
  if (RegExp(
    r'^(build|building) understanding of .+\.?$',
    caseSensitive: false,
  ).hasMatch(description)) {
    return '';
  }
  if (description.isNotEmpty && !RegExp(r'[.!?]$').hasMatch(description)) {
    description = '$description.';
  }
  return description;
}

String _gradeFitDescription(
  LearningConceptSuggestion suggestion, {
  required bool isIndonesian,
}) {
  final note = suggestion.levelNote?.trim();
  if (note != null && note.isNotEmpty) {
    return note;
  }
  return switch (suggestion.gradeRelation) {
    'below_current_level' =>
      isIndonesian
          ? 'Node ini lebih rendah dari level kelasmu; cocok untuk memperkuat fondasi.'
          : 'This node is below your grade level; it can strengthen foundations.',
    'above_current_level' =>
      isIndonesian
          ? 'Node ini lebih tinggi dari level kelasmu; mungkin terasa lebih menantang.'
          : 'This node is above your grade level; it may feel more challenging.',
    'at_current_level' =>
      isIndonesian
          ? 'Node ini sesuai dengan level kelasmu.'
          : 'This node fits your grade level.',
    _ => '',
  };
}

class _NoticeHeader extends StatelessWidget {
  const _NoticeHeader({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: WicaraColors.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: WicaraColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trailing!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.primaryDeep,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchScopeNote extends StatelessWidget {
  const _SearchScopeNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.travel_explore_rounded,
            color: WicaraColors.primary,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelNoteBox extends StatelessWidget {
  const _LevelNoteBox({required this.note, required this.relation});

  final String note;
  final String? relation;

  @override
  Widget build(BuildContext context) {
    final color = _levelNoteColor(relation);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_levelNoteIcon(relation), color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(title),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontSize: 11,
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

const _learningGoalSubjectCodes = <String>[
  'math',
  'physics',
  'biology',
  'chemistry',
];

List<_SubjectChoice> _subjectChoices({required bool isIndonesian}) {
  return [
    for (final code in _learningGoalSubjectCodes)
      _SubjectChoice(
        code: code,
        label: _subjectLabel(code, isIndonesian: isIndonesian),
        isLocked: code != 'math',
      ),
  ];
}

String _normalizeSubjectCode(String code) {
  final normalized = code.trim().toLowerCase();
  if (normalized.contains('math') || normalized.contains('matematika')) {
    return 'math';
  }
  if (normalized.contains('physics') || normalized.contains('fisika')) {
    return 'physics';
  }
  if (normalized.contains('chemistry') || normalized.contains('kimia')) {
    return 'chemistry';
  }
  if (normalized.contains('biology') || normalized.contains('biologi')) {
    return 'biology';
  }
  return normalized;
}

String _subjectLabel(String code, {required bool isIndonesian}) {
  return switch (_normalizeSubjectCode(code)) {
    'math' => isIndonesian ? 'Matematika' : 'Math',
    'physics' => isIndonesian ? 'Fisika' : 'Physics',
    'chemistry' => isIndonesian ? 'Kimia' : 'Chemistry',
    'biology' => isIndonesian ? 'Biologi' : 'Biology',
    final value => value,
  };
}

Color _subjectColor(String code) {
  return switch (_normalizeSubjectCode(code)) {
    'math' => WicaraColors.math,
    'physics' => WicaraColors.physics,
    'chemistry' => WicaraColors.chemistry,
    'biology' => WicaraColors.biology,
    _ => WicaraColors.primary,
  };
}

IconData _subjectIcon(String code) {
  return switch (_normalizeSubjectCode(code)) {
    'math' => Icons.calculate_outlined,
    'physics' => Icons.bolt_outlined,
    'chemistry' => Icons.science_outlined,
    'biology' => Icons.biotech_outlined,
    _ => Icons.menu_book_outlined,
  };
}

Color _levelNoteColor(String? relation) {
  return switch (relation) {
    'below_current_level' => WicaraColors.accentMint,
    'above_current_level' => WicaraColors.accentAmber,
    'at_current_level' => WicaraColors.primaryDeep,
    _ => WicaraColors.primary,
  };
}

IconData _levelNoteIcon(String? relation) {
  return switch (relation) {
    'below_current_level' => Icons.school_rounded,
    'above_current_level' => Icons.trending_up_rounded,
    'at_current_level' => Icons.check_circle_outline_rounded,
    _ => Icons.info_outline_rounded,
  };
}
