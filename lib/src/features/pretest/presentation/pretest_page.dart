import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/wicara_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../edge_ai/presentation/edge_runtime_status_panel.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/domain/onboarding_copy.dart';
import '../domain/pretest_models.dart';
import '../domain/pretest_repository.dart';
import 'widgets/assessment_option_tile.dart';
import 'widgets/confidence_picker.dart';
import 'widgets/fishbone_canvas.dart';
import 'widgets/knowledge_state_card.dart';
import 'widgets/rich_math_text.dart';

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
  final _reasoningController = TextEditingController(text: '');

  _PretestStage _stage = _PretestStage.question;
  PretestQuestion? _question;
  String _selectedOptionId = '';
  int _confidence = 6;
  bool _isSubmitting = false;
  bool _isLoadingQuestion = true;
  String? _questionError;
  KnowledgeState? _knowledgeState;
  final List<CanvasWorkSnapshot> _canvasSnapshots = [];

  @override
  void initState() {
    super.initState();
    _loadQuestion();
  }

  @override
  void dispose() {
    _reasoningController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestion() async {
    setState(() {
      _stage = _PretestStage.question;
      _questionError = null;
      _question = null;
      _selectedOptionId = '';
      _knowledgeState = null;
      _canvasSnapshots.clear();
      _isLoadingQuestion = true;
    });
    try {
      final question = await widget.pretestRepository.fetchCurrentQuestion();
      if (!mounted) {
        return;
      }
      setState(() {
        _question = question;
        _isLoadingQuestion = false;
      });
    } on PretestException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _questionError = error.message;
        _isLoadingQuestion = false;
      });
    }
  }

  Future<void> _submitAnswer() async {
    if (_selectedOptionId.isEmpty) {
      _showMessage('Pilih jawaban sebelum lanjut.');
      return;
    }

    await _submitCurrentAnswer(typedReasoning: '', usedCanvas: false);
  }

  void _openReasoning() {
    if (_selectedOptionId.isEmpty) {
      _showMessage('Pilih jawaban sebelum tambah cara.');
      return;
    }
    setState(() => _stage = _PretestStage.reasoning);
  }

  Future<void> _submitReasoning() async {
    await _submitCurrentAnswer(
      typedReasoning: _reasoningController.text,
      usedCanvas: _canvasSnapshots.isNotEmpty,
    );
  }

  Future<void> _submitCurrentAnswer({
    required String typedReasoning,
    required bool usedCanvas,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final result = await widget.pretestRepository.submitAnswer(
        PretestAnswer(
          questionId: _question?.id ?? '',
          optionId: _selectedOptionId,
          confidence: _confidence,
          typedReasoning: typedReasoning,
          usedCanvas: usedCanvas,
        ),
      );
      if (!mounted) {
        return;
      }
      if (result.completed) {
        setState(() {
          _knowledgeState = result.diagnosis;
          _stage = _PretestStage.result;
        });
      } else if (result.nextQuestion != null) {
        setState(() {
          _question = result.nextQuestion;
          _selectedOptionId = '';
          _reasoningController.clear();
          _canvasSnapshots.clear();
          _stage = _PretestStage.question;
        });
      }
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
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  Future<void> _selectPathAndGoHome() async {
    final state = _knowledgeState;
    if (state == null) {
      _goHome();
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await widget.pretestRepository.selectPath(state.recommendedPath);
      if (!mounted) {
        return;
      }
      _goHome();
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

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
      arguments: const {'auto_open_workspace': true},
    );
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
                  final availableWidth = math.max(
                    0.0,
                    constraints.maxWidth - horizontalPadding * 2,
                  );
                  final availableHeight = math.max(
                    0.0,
                    constraints.maxHeight - verticalPadding * 2,
                  );
                  final canvasWidth = math.min(availableWidth, 860.0);
                  final canvasHeight = math.min(
                    math.max(availableHeight, 220.0),
                    constraints.maxHeight,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: EdgeRuntimeStatusPanel(),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, stageConstraints) {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: KeyedSubtree(
                              key: ValueKey(_stage),
                              child: _stageView(stageConstraints, copy),
                            ),
                          );
                        },
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

  Widget _stageView(BoxConstraints constraints, OnboardingCopy copy) {
    if (_isLoadingQuestion) {
      return _PretestStateView(
        constraints: constraints,
        title: 'Loading pretest',
        message: 'Fetching adaptive questions from backend.',
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
        progressValue: (question.progressCurrent / question.progressMax)
            .clamp(0.0, 1.0)
            .toDouble(),
        selectedOptionId: _selectedOptionId,
        confidence: _confidence,
        isSubmitting: _isSubmitting,
        onClose: _goHome,
        onSelected: (id) => setState(() => _selectedOptionId = id),
        onConfidenceChanged: (value) => setState(() => _confidence = value),
        submitLabel: copy.isIndonesian ? 'Kirim jawaban' : 'Submit answer',
        addEvidenceLabel: copy.isIndonesian
            ? 'Tambah cara / coretan'
            : 'Add reasoning / sketch',
        onSubmit: _submitAnswer,
        onAddEvidence: _openReasoning,
      ),
      _PretestStage.reasoning => _ReasoningStage(
        constraints: constraints,
        copy: copy,
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
        onContinue: _isSubmitting ? () {} : _selectPathAndGoHome,
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
        constraints: BoxConstraints(
          minHeight: math.max(0.0, constraints.maxHeight - 48),
        ),
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
    required this.addEvidenceLabel,
    required this.onSubmit,
    required this.onAddEvidence,
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
  final String addEvidenceLabel;
  final VoidCallback onSubmit;
  final VoidCallback onAddEvidence;

  @override
  Widget build(BuildContext context) {
    final compact = constraints.maxHeight < 700;
    final horizontalPadding = constraints.maxWidth < 360 ? 18.0 : 28.0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact ? 10 : 14,
        horizontalPadding,
        22,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: math.max(0.0, constraints.maxHeight - 36),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AssessmentHeader(
              leading: Icons.close_rounded,
              onLeadingPressed: onClose,
            ),
            SizedBox(height: compact ? 22 : 54),
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
            SizedBox(height: compact ? 20 : 31),
            Container(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 24,
                compact ? 18 : 24,
                compact ? 18 : 24,
                21,
              ),
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
                  SizedBox(height: compact ? 18 : 26),
                  RichMathText(
                    question.prompt,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      height: 1.22,
                    ),
                  ),
                  SizedBox(height: compact ? 18 : 25),
                  RichMathText(
                    question.helper,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: compact ? 18 : 26),
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
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: selectedOptionId.isEmpty || isSubmitting
                        ? null
                        : onAddEvidence,
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: Text(addEvidenceLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WicaraColors.secondaryDeep,
                      side: const BorderSide(
                        color: WicaraColors.secondaryLight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
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
    required this.copy,
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
  final OnboardingCopy copy;
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
    final compact = constraints.maxHeight < 700;
    final horizontalPadding = constraints.maxWidth < 360 ? 18.0 : 28.0;
    return SizedBox(
      height: math.max(0.0, constraints.maxHeight),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                compact ? 10 : 14,
                horizontalPadding,
                18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AssessmentHeader(
                    leading: Icons.chevron_left_rounded,
                    onLeadingPressed: onBack,
                  ),
                  SizedBox(height: compact ? 22 : 48),
                  Text(
                    copy.isIndonesian
                        ? 'Tambah cara atau coretan'
                        : 'Add reasoning or canvas work',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      height: 1.14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.isIndonesian
                        ? 'Opsional: tulis langkahmu atau lampirkan coretan. Ini menaikkan confidence diagnosis, tapi jawaban pilihan ganda tetap jadi anchor.'
                        : 'Optional: type your steps or attach canvas work. This helps diagnosis confidence, but your MCQ answer stays the anchor.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: compact ? 18 : 27),
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _ChatBubble(
                      text: copy.isIndonesian
                          ? 'Mau tambah cara? Ketik di bawah atau pakai canvas.'
                          : 'Want to add your method? Type it below or use canvas.',
                      isUser: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _CanvasPromptBubble(
                      copy: copy,
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
            horizontalPadding: horizontalPadding,
            copy: copy,
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
    required this.horizontalPadding,
    required this.copy,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final double horizontalPadding;
  final OnboardingCopy copy;
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
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          11,
          horizontalPadding,
          14,
        ),
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
                    copy.isIndonesian
                        ? 'Evidence opsional; jawaban MCQ tetap utama'
                        : 'Optional evidence; MCQ answer stays primary',
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
    required this.onContinue,
  });

  final BoxConstraints constraints;
  final OnboardingCopy copy;
  final KnowledgeState? result;
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
        constraints: BoxConstraints(
          minHeight: math.max(0.0, constraints.maxHeight - 36),
        ),
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
            if (state.masteryScore != null || state.confidence != null) ...[
              const SizedBox(height: 22),
              _ScoreSummaryCard(
                masteryScore: state.masteryScore,
                confidence: state.confidence,
                overallMasteryPercent: state.overallMasteryPercent,
                copy: copy,
              ),
            ],
            const SizedBox(height: 28),
            _KnowledgeGapDiagnosisCard(
              gapLabel: state.gapLabel,
              message: state.message,
              strengths: state.strengths,
              gaps: state.gaps,
              evidenceNotes: state.evidenceNotes,
              copy: copy,
            ),
            if (state.nodeReports.isNotEmpty) ...[
              const SizedBox(height: 18),
              _NodeBreakdownCard(nodes: state.nodeReports, copy: copy),
            ],
            if (state.recommendedFocus.isNotEmpty) ...[
              const SizedBox(height: 18),
              _RecommendedFocusCard(items: state.recommendedFocus, copy: copy),
            ],
            const SizedBox(height: 34),
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

class _ScoreSummaryCard extends StatelessWidget {
  const _ScoreSummaryCard({
    required this.masteryScore,
    required this.confidence,
    required this.overallMasteryPercent,
    required this.copy,
  });

  final double? masteryScore;
  final double? confidence;
  final int? overallMasteryPercent;
  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    final scorePercent = ((masteryScore ?? 0).clamp(0.0, 1.0) * 100).round();
    final confidencePercent = confidence == null
        ? null
        : ((confidence!.clamp(0.0, 1.0)) * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: WicaraColors.line, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WicaraColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$scorePercent%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: WicaraColors.primaryDeep,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.scoreLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: WicaraColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (overallMasteryPercent != null)
                      '${copy.isIndonesian ? 'Keseluruhan' : 'Overall'} $overallMasteryPercent%',
                    if (confidencePercent != null)
                      '${copy.isIndonesian ? 'Keyakinan' : 'Confidence'} $confidencePercent%',
                    if (overallMasteryPercent == null &&
                        confidencePercent == null)
                      'Mastery estimate from adaptive pretest',
                  ].join(' • '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
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

class _KnowledgeGapDiagnosisCard extends StatelessWidget {
  const _KnowledgeGapDiagnosisCard({
    required this.gapLabel,
    required this.message,
    required this.strengths,
    required this.gaps,
    required this.evidenceNotes,
    required this.copy,
  });

  final String gapLabel;
  final String message;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> evidenceNotes;
  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
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
          if (strengths.isNotEmpty) ...[
            const SizedBox(height: 18),
            _ReportInsightList(
              title: copy.isIndonesian
                  ? 'Yang sudah kuat'
                  : 'What looks strong',
              icon: Icons.check_circle_outline_rounded,
              color: WicaraColors.secondary,
              items: strengths,
            ),
          ],
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ReportInsightList(
              title: copy.isIndonesian
                  ? 'Yang perlu diperbaiki'
                  : 'What needs work',
              icon: Icons.warning_amber_rounded,
              color: WicaraColors.accentCoral,
              items: gaps,
            ),
          ],
          if (evidenceNotes.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ReportInsightList(
              title: copy.isIndonesian ? 'Catatan evidence' : 'Evidence notes',
              icon: Icons.fact_check_outlined,
              color: WicaraColors.primaryDeep,
              items: evidenceNotes,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportInsightList extends StatelessWidget {
  const _ReportInsightList({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: WicaraColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        for (var i = 0; i < visibleItems.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Text(
              visibleItems[i],
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          if (i != visibleItems.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _NodeBreakdownCard extends StatelessWidget {
  const _NodeBreakdownCard({required this.nodes, required this.copy});

  final List<PretestNodeReport> nodes;
  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WicaraColors.line, width: 1.25),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.11),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            copy.isIndonesian ? 'Node yang dicek' : 'Checked nodes',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: WicaraColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < nodes.length; i++) ...[
            _NodeBreakdownRow(node: nodes[i], copy: copy),
            if (i != nodes.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _NodeBreakdownRow extends StatelessWidget {
  const _NodeBreakdownRow({required this.node, required this.copy});

  final PretestNodeReport node;
  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(node.status);
    final masteryText = node.masteryScore == null
        ? null
        : '${(node.masteryScore!.clamp(0.0, 1.0) * 100).round()}%';
    final reasoningText = _reasoningText(node, copy);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: WicaraColors.fieldFill,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  node.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _TinyBadge(label: node.status.toUpperCase(), color: statusColor),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (masteryText != null)
                _MetricPill(
                  label: copy.isIndonesian ? 'Mastery' : 'Mastery',
                  value: masteryText,
                ),
              _MetricPill(
                label: copy.isIndonesian ? 'Benar' : 'Correct',
                value: '${node.correctCount}/${node.attemptCount}',
              ),
              if (node.difficultyReached.isNotEmpty)
                _MetricPill(
                  label: copy.isIndonesian ? 'Level' : 'Level',
                  value: node.difficultyReached,
                ),
            ],
          ),
          if (reasoningText.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              reasoningText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendedFocusCard extends StatelessWidget {
  const _RecommendedFocusCard({required this.items, required this.copy});

  final List<String> items;
  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WicaraColors.secondarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WicaraColors.secondaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                color: WicaraColors.secondaryDeep,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  copy.isIndonesian
                      ? 'Fokus path berikutnya'
                      : 'Next path focus',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: WicaraColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.secondaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    items[i],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WicaraColors.text,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            if (i != items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: WicaraColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    'ready' || 'probably_ready' => WicaraColors.secondary,
    'partial' || 'fragile' => const Color(0xFFC28A35),
    'gap' || 'probably_gap' => WicaraColors.accentCoral,
    _ => WicaraColors.primaryDeep,
  };
}

String _reasoningText(PretestNodeReport node, OnboardingCopy copy) {
  if (node.misconceptionDetected) {
    return copy.isIndonesian
        ? 'Reasoning menunjukkan miskonsepsi pada node ini.'
        : 'Reasoning suggests a misconception on this node.';
  }
  if (node.carelessMistakePossible) {
    return copy.isIndonesian
        ? 'Ada indikasi salah pilih walau langkah cukup masuk akal.'
        : 'There is a possible careless choice despite reasonable reasoning.';
  }
  if (node.reasoningQuality == 'not_provided') {
    return copy.isIndonesian
        ? 'Tidak ada langkah tertulis, jadi confidence evidence lebih terbatas.'
        : 'No written steps were provided, so evidence confidence is limited.';
  }
  final score = node.avgReasoningScore == null
      ? ''
      : ' ${(node.avgReasoningScore!.clamp(0.0, 1.0) * 100).round()}%';
  return copy.isIndonesian
      ? 'Kualitas reasoning: ${node.reasoningQuality}$score.'
      : 'Reasoning quality: ${node.reasoningQuality}$score.';
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
      child: RichMathText(
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
    required this.copy,
    required this.hasCanvasWork,
    required this.onUseCanvas,
  });

  final OnboardingCopy copy;
  final bool hasCanvasWork;
  final VoidCallback onUseCanvas;

  @override
  Widget build(BuildContext context) {
    final message = copy.isIndonesian
        ? (hasCanvasWork
              ? 'Coretan canvas sudah masuk. Tambah lagi kalau perlu.'
              : 'Butuh papan coret? Buka canvas dan kirim coretanmu.')
        : (hasCanvasWork
              ? 'Canvas work is attached. Add another sketch if needed.'
              : 'Need a whiteboard? Open canvas and send your sketch here.');
    final buttonLabel = copy.isIndonesian
        ? (hasCanvasWork ? 'Buka canvas' : 'Pakai canvas')
        : (hasCanvasWork ? 'Open canvas' : 'Use canvas');

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
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _CanvasQuickActionButton(label: buttonLabel, onPressed: onUseCanvas),
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
              hintText: 'Type your method, or leave empty to submit...',
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
