import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/wicara_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/domain/onboarding_copy.dart';
import '../domain/multiplication_assessment_bank.dart';
import '../domain/pretest_models.dart';
import '../domain/pretest_repository.dart';
import 'widgets/assessment_option_tile.dart';
import 'widgets/confidence_picker.dart';
import 'widgets/fishbone_canvas.dart';
import 'widgets/knowledge_state_card.dart';

enum _PretestStage { question, reasoning, result }

class PretestPage extends StatefulWidget {
  const PretestPage({
    required this.pretestRepository,
    required this.onboardingController,
    super.key,
  });

  final PretestRepository pretestRepository;
  final OnboardingController onboardingController;

  @override
  State<PretestPage> createState() => _PretestPageState();
}

class _PretestPageState extends State<PretestPage> {
  final _reasoningController = TextEditingController(
    text:
        'I chose B because defects are the outcome we need to understand before changing the process.',
  );

  late final HardcodedAssessmentPack _assessmentPack;
  late final List<PretestQuestion> _questions;
  _PretestStage _stage = _PretestStage.question;
  PretestQuestion? _question;
  int _questionIndex = 0;
  String _selectedOptionId = '';
  final Map<int, String> _pretestAnswers = {};
  int _confidence = 6;
  bool _isSubmitting = false;
  bool _isLoadingQuestion = false;
  String? _questionError;
  KnowledgeState? _knowledgeState;
  final List<CanvasWorkSnapshot> _canvasSnapshots = [];

  @override
  void initState() {
    super.initState();
    _assessmentPack = HardcodedAssessmentBank.packForEducation(
      educationLevel: widget.onboardingController.profile.educationLevel,
      gradeLevel: widget.onboardingController.profile.gradeLevel,
    );
    _questions = _assessmentPack.pretestQuestions;
    _loadQuestion();
  }

  @override
  void dispose() {
    _reasoningController.dispose();
    super.dispose();
  }

  void _loadQuestion() {
    setState(() {
      _stage = _PretestStage.question;
      _questionIndex = 0;
      _questionError = null;
      _question = _questions.first;
      _selectedOptionId = '';
      _pretestAnswers.clear();
      _knowledgeState = null;
      _canvasSnapshots.clear();
      _isLoadingQuestion = false;
    });
  }

  void _submitAnswer() {
    if (_selectedOptionId.isEmpty) {
      _showMessage('Pilih jawaban sebelum lanjut.');
      return;
    }

    _pretestAnswers[_questionIndex] = _selectedOptionId;
    if (_questionIndex < _questions.length - 1) {
      setState(() {
        _questionIndex += 1;
        _question = _questions[_questionIndex];
        _selectedOptionId = _pretestAnswers[_questionIndex] ?? '';
      });
      return;
    }

    final correctCount = _assessmentPack.correctCount(
      kind: HardcodedAssessmentKind.pretest,
      selectedAnswers: _pretestAnswers,
    );
    final totalQuestions = _questions.length;
    final isReady = correctCount >= 2;

    setState(() {
      _knowledgeState = KnowledgeState(
        skill: isReady
            ? 'Siap mulai belajar ${_assessmentPack.topicTitle}'
            : 'Fondasi ${_assessmentPack.topicTitle} perlu dipanaskan',
        gapLabel: '$correctCount/$totalQuestions',
        message:
            'Pretest selesai: $correctCount dari $totalQuestions jawaban benar.',
        pathTitle: 'Jalur belajar ${_assessmentPack.topicTitle} siap',
        pathMeta:
            'Pretest 3 soal   |   ${_assessmentPack.topicTitle} ${_assessmentPack.levelLabel}',
        pathDescription: isReady
            ? _assessmentPack.readyPathDescription
            : _assessmentPack.reviewPathDescription,
      );
      _stage = _PretestStage.result;
    });
  }

  Future<void> _submitReasoning() async {
    setState(() => _isSubmitting = true);
    try {
      final result = await widget.pretestRepository.submitReasoning(
        PretestReasoning(
          answer: _answer,
          explanation: _reasoningController.text,
          usedCanvas: _canvasSnapshots.isNotEmpty,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _knowledgeState = result;
        _stage = _PretestStage.result;
      });
    } on PretestException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  PretestAnswer get _answer {
    return PretestAnswer(
      questionId: _question?.id ?? '',
      optionId: _selectedOptionId,
      confidence: _confidence,
    );
  }

  PretestOption get _selectedOption =>
      _question!.options.firstWhere((option) => option.id == _selectedOptionId);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _handleCanvasSentToChat(CanvasWorkSnapshot snapshot) {
    setState(() => _canvasSnapshots.add(snapshot));
  }

  void _goBack() {
    if (_stage == _PretestStage.reasoning) {
      setState(() => _stage = _PretestStage.question);
      return;
    }
    if (_stage == _PretestStage.result) {
      setState(() => _stage = _PretestStage.question);
      return;
    }
    if (_questionIndex > 0) {
      setState(() {
        _questionIndex -= 1;
        _question = _questions[_questionIndex];
        _selectedOptionId = _pretestAnswers[_questionIndex] ?? '';
      });
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  void _goHome() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  void _openLargeCanvas() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: WicaraColors.pageBackground,
          surfaceTintColor: WicaraColors.pageBackground,
          child: SizedBox.expand(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth > 640
                      ? 28.0
                      : 12.0;
                  final verticalPadding = constraints.maxHeight > 700
                      ? 24.0
                      : 12.0;
                  final canvasWidth = math.min(
                    constraints.maxWidth - horizontalPadding * 2,
                    860.0,
                  );
                  final canvasHeight = math.max(
                    420.0,
                    constraints.maxHeight - verticalPadding * 2,
                  );

                  return Center(
                    child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: FishboneCanvas(
                        height: canvasHeight,
                        isLargePanel: true,
                        onOpenLargePanel: () => Navigator.of(context).pop(),
                        onSendToChat: _handleCanvasSentToChat,
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

  @override
  Widget build(BuildContext context) {
    final copy = OnboardingCopy.forLanguage(
      widget.onboardingController.profile.preferredLanguage,
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pageWidth = math.min(constraints.maxWidth, 430.0);

            return Center(
              child: SizedBox(
                width: pageWidth,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: KeyedSubtree(
                    key: ValueKey(_stage),
                    child: _stageView(constraints, copy),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _stageView(BoxConstraints constraints, OnboardingCopy copy) {
    if (_isLoadingQuestion) {
      return _PretestStateView(
        constraints: constraints,
        title: 'Loading pretest',
        message: 'Fetching seeded questions from backend.',
      );
    }
    if (_questionError != null || _question == null) {
      return _PretestStateView(
        constraints: constraints,
        title: 'Pretest unavailable',
        message: _questionError ?? 'Backend returned no question.',
        actionLabel: 'Try again',
        onAction: _loadQuestion,
      );
    }
    final question = _question!;

    return switch (_stage) {
      _PretestStage.question => _QuestionStage(
        constraints: constraints,
        copy: copy,
        question: question,
        progressValue: (_questionIndex + 1) / _questions.length,
        selectedOptionId: _selectedOptionId,
        confidence: _confidence,
        isSubmitting: _isSubmitting,
        onClose: _goHome,
        onSelected: (id) => setState(() => _selectedOptionId = id),
        onConfidenceChanged: (value) => setState(() => _confidence = value),
        submitLabel: _questionIndex == _questions.length - 1
            ? 'Selesai pretest'
            : 'Lanjut',
        onSubmit: _submitAnswer,
      ),
      _PretestStage.reasoning => _ReasoningStage(
        constraints: constraints,
        question: question,
        selectedOption: _selectedOption,
        controller: _reasoningController,
        canvasSnapshots: _canvasSnapshots,
        isSubmitting: _isSubmitting,
        onBack: _goBack,
        onUseCanvas: _openLargeCanvas,
        onSubmit: _submitReasoning,
      ),
      _PretestStage.result => _ResultStage(
        constraints: constraints,
        copy: copy,
        result: _knowledgeState,
        focusAreas: _assessmentPack.focusAreas,
        onContinue: _goHome,
      ),
    };
  }
}

class _PretestStateView extends StatelessWidget {
  const _PretestStateView({
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
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 30),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 24, height: 1.12),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
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

class _QuestionStage extends StatelessWidget {
  const _QuestionStage({
    required this.constraints,
    required this.copy,
    required this.question,
    required this.progressValue,
    required this.selectedOptionId,
    required this.confidence,
    required this.isSubmitting,
    required this.onClose,
    required this.onSelected,
    required this.onConfidenceChanged,
    required this.submitLabel,
    required this.onSubmit,
  });

  final BoxConstraints constraints;
  final OnboardingCopy copy;
  final PretestQuestion question;
  final double progressValue;
  final String selectedOptionId;
  final int confidence;
  final bool isSubmitting;
  final VoidCallback onClose;
  final ValueChanged<String> onSelected;
  final ValueChanged<int> onConfidenceChanged;
  final String submitLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AssessmentHeader(
              leading: Icons.close_rounded,
              onLeadingPressed: onClose,
            ),
            const SizedBox(height: 54),
            Text(
              'Pretest',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 25, height: 1.12),
            ),
            const SizedBox(height: 12),
            Text(
              question.stepLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _SlimProgress(value: progressValue),
            const SizedBox(height: 31),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 21),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: WicaraColors.line, width: 1.3),
                boxShadow: [
                  BoxShadow(
                    color: WicaraColors.shadowBlue.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
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
                  const SizedBox(height: 19),
                  ConfidencePicker(
                    value: confidence,
                    onChanged: onConfidenceChanged,
                    copy: copy,
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: submitLabel,
                    onPressed: selectedOptionId.isEmpty ? null : onSubmit,
                    isLoading: isSubmitting,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _AssessmentFooter(),
          ],
        ),
      ),
    );
  }
}

class _ReasoningStage extends StatelessWidget {
  const _ReasoningStage({
    required this.constraints,
    required this.question,
    required this.selectedOption,
    required this.controller,
    required this.canvasSnapshots,
    required this.isSubmitting,
    required this.onBack,
    required this.onUseCanvas,
    required this.onSubmit,
  });

  final BoxConstraints constraints;
  final PretestQuestion question;
  final PretestOption selectedOption;
  final TextEditingController controller;
  final List<CanvasWorkSnapshot> canvasSnapshots;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onUseCanvas;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: constraints.maxHeight,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AssessmentHeader(
                    leading: Icons.chevron_left_rounded,
                    onLeadingPressed: onBack,
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Help us understand your thinking',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      height: 1.14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review the question, your answer, then explain your reasoning.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 27),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _ChatBubble(text: question.prompt, isUser: false),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _ChatBubble(
                      text: '${selectedOption.label}. ${selectedOption.text}',
                      isUser: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _ChatBubble(
                      text:
                          'Why did you choose this answer? Explain your thinking.',
                      isUser: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _CanvasPromptBubble(
                      hasCanvasWork: canvasSnapshots.isNotEmpty,
                      onUseCanvas: onUseCanvas,
                    ),
                  ),
                  if (canvasSnapshots.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _CanvasAttachmentBubble(
                        snapshot: canvasSnapshots.last,
                        onOpenCanvas: onUseCanvas,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _ReasoningFooter(
            controller: controller,
            isSubmitting: isSubmitting,
            onSubmit: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _ReasoningFooter extends StatelessWidget {
  const _ReasoningFooter({
    required this.controller,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WicaraColors.pageBackground.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: WicaraColors.line)),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 11, 28, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ReasoningInput(
              controller: controller,
              isSubmitting: isSubmitting,
              onSubmit: onSubmit,
            ),
            const SizedBox(height: 11),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: WicaraColors.softMuted,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Same evidence pipeline (InputEvent)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStage extends StatelessWidget {
  const _ResultStage({
    required this.constraints,
    required this.copy,
    required this.result,
    required this.focusAreas,
    required this.onContinue,
  });

  final BoxConstraints constraints;
  final OnboardingCopy copy;
  final KnowledgeState? result;
  final List<AssessmentFocusArea> focusAreas;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final state =
        result ??
        KnowledgeState(
          skill: 'Missing prerequisite: causal drivers',
          gapLabel: 'GAP',
          message:
              'The gap looks like choosing a tool before naming the defect driver, evidence, and likely cause chain.',
          pathTitle: copy.personalizedPathGeneratedLabel,
          pathMeta: '12-15 min   •   3 skills',
          pathDescription: copy.personalizedPathDescription,
        );
    final localizedPathMeta = copy.isIndonesian
        ? state.pathMeta.replaceAll('skills', 'skill')
        : state.pathMeta;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 78),
            Text(
              copy.yourKnowledgeStateLabel,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 25, height: 1.12),
            ),
            const SizedBox(height: 10),
            Text(
              copy.basedOnYourResponsesLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 38),
            _KnowledgeGapDiagnosisCard(
              gapLabel: state.gapLabel,
              message: state.message,
              focusAreas: focusAreas,
              copy: copy,
            ),
            const SizedBox(height: 37),
            Text(
              copy.whatsNextLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            KnowledgeStateCard(
              title: copy.personalizedPathGeneratedLabel,
              message:
                  '$localizedPathMeta\n${copy.isIndonesian ? copy.personalizedPathDescription : state.pathDescription}',
              badge: '',
              icon: Icons.center_focus_strong_outlined,
              iconColor: WicaraColors.secondaryDeep,
              iconBackgroundColor: WicaraColors.secondarySoft,
              height: 116,
              showChevron: false,
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: copy.continueToMyPathLabel,
              onPressed: onContinue,
            ),
            const SizedBox(height: 20),
            Text(
              copy.retakePretestAnytimeLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.softMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KnowledgeGapDiagnosisCard extends StatelessWidget {
  const _KnowledgeGapDiagnosisCard({
    required this.gapLabel,
    required this.message,
    required this.focusAreas,
    required this.copy,
  });

  final String gapLabel;
  final String message;
  final List<AssessmentFocusArea> focusAreas;
  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    const colors = [
      WicaraColors.accentCoral,
      WicaraColors.secondary,
      WicaraColors.primaryDeep,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WicaraColors.line, width: 1.25),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.13),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: WicaraColors.glowPeach,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: WicaraColors.accentCoral,
                  size: 25,
                ),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        copy.missingPrerequisiteGapsLabel,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6E6),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        gapLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFC28A35),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < focusAreas.length; i++) ...[
            _GapDiagnosisRow(
              index: i + 1,
              focusArea: focusAreas[i],
              color: colors[i % colors.length],
            ),
            if (i != focusAreas.length - 1) const SizedBox(height: 13),
          ],
        ],
      ),
    );
  }
}

class _GapDiagnosisRow extends StatelessWidget {
  const _GapDiagnosisRow({
    required this.index,
    required this.focusArea,
    required this.color,
  });

  final int index;
  final AssessmentFocusArea focusArea;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$index',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                focusArea.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: WicaraColors.text,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                focusArea.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  focusArea.severity,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssessmentHeader extends StatelessWidget {
  const _AssessmentHeader({
    required this.leading,
    required this.onLeadingPressed,
  });

  final IconData leading;
  final VoidCallback onLeadingPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onLeadingPressed,
          icon: Icon(leading),
          iconSize: leading == Icons.close_rounded ? 28 : 33,
          color: WicaraColors.ink,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        ),
        const SizedBox(width: 38, height: 38),
      ],
    );
  }
}

class _SlimProgress extends StatelessWidget {
  const _SlimProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 5,
        color: WicaraColors.secondary,
        backgroundColor: WicaraColors.line,
      ),
    );
  }
}

class _AssessmentFooter extends StatelessWidget {
  const _AssessmentFooter();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.insights_rounded,
          color: WicaraColors.secondary,
          size: 19,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Adaptive probing  •  Knowledge Space Theory',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.softMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isUser ? WicaraColors.secondarySoft : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isUser ? WicaraColors.secondaryLight : WicaraColors.line,
        ),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.18),
            blurRadius: 15,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isUser ? WicaraColors.text : WicaraColors.muted,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}

class _CanvasPromptBubble extends StatelessWidget {
  const _CanvasPromptBubble({
    required this.hasCanvasWork,
    required this.onUseCanvas,
  });

  final bool hasCanvasWork;
  final VoidCallback onUseCanvas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: WicaraColors.line),
            boxShadow: [
              BoxShadow(
                color: WicaraColors.shadowBlue.withValues(alpha: 0.16),
                blurRadius: 15,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Text(
            hasCanvasWork
                ? 'Canvas work is attached. Add another sketch if needed.'
                : 'Need a whiteboard? Open canvas and send your sketch here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _CanvasQuickActionButton(
          label: hasCanvasWork ? 'Open canvas' : 'Use canvas',
          onPressed: onUseCanvas,
        ),
      ],
    );
  }
}

class _CanvasQuickActionButton extends StatelessWidget {
  const _CanvasQuickActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: WicaraColors.secondary,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: WicaraColors.secondary.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.draw_outlined, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasAttachmentBubble extends StatelessWidget {
  const _CanvasAttachmentBubble({
    required this.snapshot,
    required this.onOpenCanvas,
  });

  final CanvasWorkSnapshot snapshot;
  final VoidCallback onOpenCanvas;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 270),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: WicaraColors.primaryLight),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.18),
            blurRadius: 15,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.image_outlined,
                color: WicaraColors.primaryDeep,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Canvas work v${snapshot.version}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CanvasWorkPreview(snapshot: snapshot),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${snapshot.elementCount} marks${snapshot.hasAttachment ? ' • paper attached' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onOpenCanvas,
                style: TextButton.styleFrom(
                  foregroundColor: WicaraColors.primaryDeep,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReasoningInput extends StatelessWidget {
  const _ReasoningInput({
    required this.controller,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Type your answer...',
              filled: true,
              fillColor: WicaraColors.fieldFill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: WicaraColors.secondaryLight,
                  width: 1.4,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: WicaraColors.secondary,
                  width: 1.7,
                ),
              ),
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: WicaraColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 53,
          height: 53,
          decoration: BoxDecoration(
            color: WicaraColors.secondary,
            borderRadius: BorderRadius.circular(27),
            boxShadow: [
              BoxShadow(
                color: WicaraColors.secondary.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: IconButton(
            onPressed: isSubmitting ? null : onSubmit,
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.arrow_upward_rounded),
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
