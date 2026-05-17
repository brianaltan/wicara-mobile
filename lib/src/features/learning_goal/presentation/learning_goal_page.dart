import 'dart:async';
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
  bool _isCheckingActive = true;
  bool _isComplete = false;
  ActiveLearningGoal? _activeGoal;
  LearningGoalResolution? _resolution;
  String? _selectedSubjectCode;

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
    unawaited(_loadActiveGoal());
  }

  void _handleTopicChanged() {
    setState(() => _resolution = null);
  }

  Future<void> _loadActiveGoal() async {
    try {
      final activeGoal = await widget.learningGoalRepository.fetchActiveGoal();
      if (!mounted) {
        return;
      }
      setState(() {
        _activeGoal = activeGoal;
        _isCheckingActive = false;
      });
    } on LearningGoalException catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isCheckingActive = false);
    }
  }

  Future<void> _generatePretest() async {
    if (_controller.text.trim().isEmpty || _isGenerating) {
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final existingResolution = _resolution;
      if (existingResolution == null ||
          existingResolution.suggestedConcept == null) {
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
        return;
      }

      await widget.learningGoalRepository.confirmResolvedGoal(
        resolutionId: existingResolution.resolutionId,
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

  Future<void> _cancelActiveGoal() async {
    final activeGoal = _activeGoal;
    if (activeGoal == null || _isGenerating) {
      return;
    }
    setState(() => _isGenerating = true);
    try {
      await widget.learningGoalRepository.cancelGoal(
        learningGoalId: activeGoal.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeGoal = null;
        _isGenerating = false;
      });
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

  void _continueActiveGoal() {
    final activeGoal = _activeGoal;
    if (activeGoal == null) {
      return;
    }
    if (activeGoal.nextAction == 'continue_learning') {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      return;
    }
    Navigator.of(context).pushReplacementNamed(AppRoutes.pretest);
  }

  void _refineResolution() {
    setState(() => _resolution = null);
  }

  void _selectSubject(String subjectCode) {
    setState(() {
      _selectedSubjectCode = subjectCode;
      _resolution = null;
    });
  }

  String _effectiveSubjectCode(List<String> selectedSubjects) {
    return _selectedSubjectCode ?? _defaultSubjectCode(selectedSubjects);
  }

  VoidCallback? _primaryAction() {
    if (_controller.text.trim().isEmpty) {
      return null;
    }
    final resolution = _resolution;
    if (resolution != null && resolution.suggestedConcept == null) {
      return _generatePretest;
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
      return copy.isIndonesian ? 'Cari ulang dengan query baru' : 'Search again';
    }
    return copy.isIndonesian
        ? 'Node cocok, mulai pretest'
        : 'Node looks right, start pretest';
  }

  Future<void> _selectAlternative(LearningConceptSuggestion suggestion) async {
    final resolution = _resolution;
    if (resolution == null || _isGenerating) {
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
        _isGenerating = false;
      });
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

  Future<void> _openManualSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _isGenerating) {
      return;
    }
    setState(() => _isGenerating = true);
    try {
      final profile = widget.onboardingController.profile;
      final subjectCode = _effectiveSubjectCode(profile.selectedSubjects);
      final results = await widget.learningGoalRepository.searchMaterials(
        query: query,
        subjectCode: subjectCode,
      );
      if (!mounted) {
        return;
      }
      setState(() => _isGenerating = false);
      if (results.isEmpty) {
        final copy = OnboardingCopy.forLanguage(profile.preferredLanguage);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                copy.isIndonesian
                    ? 'Belum ada node yang cocok. Coba query yang lebih spesifik.'
                    : 'No matching node yet. Try a more specific query.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _ManualSearchResultsSheet(
          results: results,
          isIndonesian: _isIndonesianLanguage(profile.preferredLanguage),
          onSelected: (suggestion) {
            Navigator.of(sheetContext).pop();
            unawaited(_selectAlternative(suggestion));
          },
        ),
      );
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
        final subjectChoices = _subjectChoices(
          profile.selectedSubjects,
          isIndonesian: copy.isIndonesian,
        );
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
                          minHeight: math.max(
                            0.0,
                            constraints.maxHeight - 42,
                          ),
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
                                        borderRadius: BorderRadius.circular(
                                          15,
                                        ),
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
                                          if (_isCheckingActive)
                                            const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          else if (_activeGoal != null)
                                            _ActiveGoalPanel(
                                              activeGoal: _activeGoal!,
                                              copy: copy,
                                              isLoading: _isGenerating,
                                              onContinue: _continueActiveGoal,
                                              onCancel: _cancelActiveGoal,
                                            )
                                          else ...[
                                            Text(
                                              copy.learningTopicLabel,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 13),
                                            _SubjectSelector(
                                              choices: subjectChoices,
                                              selectedCode:
                                                  selectedSubjectCode,
                                              isIndonesian:
                                                  copy.isIndonesian,
                                              onSelected: _selectSubject,
                                            ),
                                            const SizedBox(height: 14),
                                            _LearningGoalField(
                                              controller: _controller,
                                              copy: copy,
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
                                                      onRefine:
                                                          _refineResolution,
                                                      onManualSearch:
                                                          _openManualSearch,
                                                      onOpenGraph:
                                                          _openKnowledgeMap,
                                                      onAlternativeSelected:
                                                          _selectAlternative,
                                                    )
                                                  : _PretestPreviewNotice(
                                                      copy: copy,
                                                    ),
                                            ),
                                            const SizedBox(height: 22),
                                            GradientButton(
                                              label: _primaryActionLabel(
                                                copy,
                                              ),
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

class _LearningGoalField extends StatefulWidget {
  const _LearningGoalField({required this.controller, required this.copy});

  final TextEditingController controller;
  final OnboardingCopy copy;

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
  const _SubjectChoice({required this.code, required this.label});

  final String code;
  final String label;
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
          isIndonesian
              ? 'Pilih subject dulu supaya node tidak melenceng'
              : 'Choose the subject first so matching stays scoped',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: WicaraColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final choice in choices)
              ChoiceChip(
                label: Text(choice.label),
                selected: choice.code == selectedCode,
                onSelected: (_) => onSelected(choice.code),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: choice.code == selectedCode
                      ? Colors.white
                      : WicaraColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                selectedColor: WicaraColors.primaryDeep,
                backgroundColor: WicaraColors.fieldFill,
                side: BorderSide(
                  color: choice.code == selectedCode
                      ? WicaraColors.primaryDeep
                      : WicaraColors.line,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ],
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
    required this.onRefine,
    required this.onManualSearch,
    required this.onOpenGraph,
    required this.onAlternativeSelected,
  });

  final LearningGoalResolution resolution;
  final bool isIndonesian;
  final VoidCallback onRefine;
  final VoidCallback onManualSearch;
  final VoidCallback onOpenGraph;
  final ValueChanged<LearningConceptSuggestion> onAlternativeSelected;

  @override
  Widget build(BuildContext context) {
    final concept = resolution.suggestedConcept;
    final confidence = (resolution.confidence * 100).round();
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
                _AlternativeNodeButton(
                  suggestion: alternative,
                  isIndonesian: isIndonesian,
                  onSelected: onAlternativeSelected,
                ),
                const SizedBox(height: 7),
              ],
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onRefine,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(
                    isIndonesian ? 'Perjelas query' : 'Refine query',
                  ),
                ),
                TextButton.icon(
                  onPressed: onManualSearch,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: Text(
                    isIndonesian ? 'Cari manual' : 'Manual search',
                  ),
                ),
                TextButton.icon(
                  onPressed: onOpenGraph,
                  icon: const Icon(Icons.account_tree_outlined, size: 18),
                  label: Text(
                    isIndonesian ? 'Lihat graph' : 'Open graph',
                  ),
                ),
              ],
            ),
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
                  isIndonesian ? 'Node yang ditemukan' : 'Suggested node',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$confidence%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.primaryDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            concept.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: WicaraColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            concept.description.isNotEmpty
                ? concept.description
                : isIndonesian
                ? 'Node ini dipakai sebagai learning goal utama untuk pretest adaptif.'
                : 'This node will be used as the main learning goal for the adaptive pretest.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${concept.subject}${concept.gradeBand == null ? '' : ' • ${concept.gradeBand}'} • ${concept.conceptCode}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.softMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (concept.levelNote != null) ...[
            const SizedBox(height: 11),
            _LevelNoteBox(
              note: concept.levelNote!,
              relation: concept.gradeRelation,
            ),
          ],
          if (resolution.searchScopeReason != null) ...[
            const SizedBox(height: 10),
            _SearchScopeNote(text: resolution.searchScopeReason!),
          ],
          const SizedBox(height: 11),
          Text(
            isIndonesian
                ? 'Pastikan node ini benar dulu. Kalau sudah cocok, tekan tombol mulai pretest di bawah.'
                : 'Confirm this node first. If it looks right, press the start pretest button below.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
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
              _AlternativeNodeButton(
                suggestion: alternative,
                isIndonesian: isIndonesian,
                onSelected: onAlternativeSelected,
              ),
              const SizedBox(height: 7),
            ],
          ],
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: onRefine,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                  isIndonesian
                      ? 'Belum cocok? Perjelas'
                      : 'Not right? Refine',
                ),
              ),
              TextButton.icon(
                onPressed: onManualSearch,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: Text(isIndonesian ? 'Cari manual' : 'Manual search'),
              ),
              TextButton.icon(
                onPressed: onOpenGraph,
                icon: const Icon(Icons.account_tree_outlined, size: 18),
                label: Text(isIndonesian ? 'Lihat graph' : 'Open graph'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlternativeNodeButton extends StatelessWidget {
  const _AlternativeNodeButton({
    required this.suggestion,
    required this.isIndonesian,
    required this.onSelected,
  });

  final LearningConceptSuggestion suggestion;
  final bool isIndonesian;
  final ValueChanged<LearningConceptSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => onSelected(suggestion),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        side: const BorderSide(color: WicaraColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  suggestion.description.isNotEmpty
                      ? suggestion.description
                      : isIndonesian
                      ? 'Lihat apakah node ini lebih cocok dengan tujuanmu.'
                      : 'Check whether this node better matches your goal.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${suggestion.subject}${suggestion.gradeBand == null ? '' : ' • ${suggestion.gradeBand}'}${suggestion.conceptCode.isEmpty ? '' : ' • ${suggestion.conceptCode}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.softMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (suggestion.levelNote != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    suggestion.levelNote!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _levelNoteColor(suggestion.gradeRelation),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.search_rounded, size: 17),
        ],
      ),
    );
  }
}

class _NoticeHeader extends StatelessWidget {
  const _NoticeHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
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

class _ManualSearchResultsSheet extends StatelessWidget {
  const _ManualSearchResultsSheet({
    required this.results,
    required this.isIndonesian,
    required this.onSelected,
  });

  final List<LearningConceptSuggestion> results;
  final bool isIndonesian;
  final ValueChanged<LearningConceptSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, math.max(12, bottomInset)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: WicaraColors.line),
            boxShadow: [
              BoxShadow(
                color: WicaraColors.shadowBlue.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isIndonesian
                            ? 'Cari node secara manual'
                            : 'Manual node search',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                  itemCount: math.min(results.length, 12),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final suggestion = results[index];
                    return _AlternativeNodeButton(
                      suggestion: suggestion,
                      isIndonesian: isIndonesian,
                      onSelected: onSelected,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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

class _ActiveGoalPanel extends StatelessWidget {
  const _ActiveGoalPanel({
    required this.activeGoal,
    required this.copy,
    required this.isLoading,
    required this.onContinue,
    required this.onCancel,
  });

  final ActiveLearningGoal activeGoal;
  final OnboardingCopy copy;
  final bool isLoading;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final title = activeGoal.targetConcept?.title ?? activeGoal.rawTopic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NoticeBox(
          icon: Icons.lock_clock_rounded,
          title: copy.isIndonesian
              ? 'Learning goal aktif'
              : 'Active learning goal',
          description: copy.isIndonesian
              ? 'Lanjutkan "$title" sebelum membuat goal baru.'
              : 'Continue "$title" before creating a new goal.',
          color: WicaraColors.secondary,
        ),
        const SizedBox(height: 18),
        GradientButton(
          label: copy.isIndonesian ? 'Lanjut belajar' : 'Continue learning',
          onPressed: onContinue,
          isLoading: isLoading,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: isLoading ? null : onCancel,
          child: Text(copy.isIndonesian ? 'Batalkan goal' : 'Cancel goal'),
        ),
      ],
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

String? _preferredSubjectCode(List<String> subjects) {
  if (subjects.isEmpty) {
    return null;
  }
  final selected = subjects.first.toLowerCase();
  if (selected.contains('math') || selected.contains('matematika')) {
    return 'math';
  }
  if (selected.contains('ipas')) {
    return 'ipas';
  }
  if (selected == 'ipa' ||
      selected.contains('science') ||
      selected.contains('sains')) {
    return 'ipa';
  }
  if (selected.contains('physics') || selected.contains('fisika')) {
    return 'physics';
  }
  if (selected.contains('chemistry') || selected.contains('kimia')) {
    return 'chemistry';
  }
  if (selected.contains('biology') || selected.contains('biologi')) {
    return 'biology';
  }
  return subjects.first;
}

String _defaultSubjectCode(List<String> subjects) {
  return _preferredSubjectCode([if (subjects.isNotEmpty) subjects.first]) ??
      'math';
}

List<_SubjectChoice> _subjectChoices(
  List<String> selectedSubjects, {
  required bool isIndonesian,
}) {
  final choices = <_SubjectChoice>[];

  void add(String code) {
    final normalized = _normalizeSubjectCode(code);
    if (choices.any((choice) => choice.code == normalized)) {
      return;
    }
    choices.add(
      _SubjectChoice(
        code: normalized,
        label: _subjectLabel(normalized, isIndonesian: isIndonesian),
      ),
    );
  }

  for (final subject in selectedSubjects) {
    final mapped = _preferredSubjectCode([subject]);
    if (mapped != null && mapped.trim().isNotEmpty) {
      add(mapped);
    }
  }

  for (final fallback in const [
    'math',
    'ipas',
    'ipa',
    'physics',
    'chemistry',
    'biology',
  ]) {
    add(fallback);
  }

  return choices;
}

String _normalizeSubjectCode(String code) {
  final normalized = code.trim().toLowerCase();
  if (normalized.contains('math') || normalized.contains('matematika')) {
    return 'math';
  }
  if (normalized.contains('ipas')) {
    return 'ipas';
  }
  if (normalized == 'science' ||
      normalized == 'ipa' ||
      normalized.contains('sains')) {
    return 'ipa';
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
    'ipas' => 'IPAS',
    'ipa' => isIndonesian ? 'IPA' : 'Science',
    'physics' => isIndonesian ? 'Fisika' : 'Physics',
    'chemistry' => isIndonesian ? 'Kimia' : 'Chemistry',
    'biology' => isIndonesian ? 'Biologi' : 'Biology',
    final value => value,
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

bool _isIndonesianLanguage(String language) {
  final normalized = language.toLowerCase();
  return normalized == 'id' ||
      normalized.contains('indo') ||
      normalized.contains('bahasa');
}
