import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/wicara_colors.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/domain/onboarding_copy.dart';
import '../../pretest/presentation/widgets/fishbone_canvas.dart';

enum _WorkspaceContentMode { choosing, explanation, videoLoading, videoReady }

enum _WorkspaceQuizState { unanswered, correct, review }

class WorkspaceModulesPage extends StatefulWidget {
  const WorkspaceModulesPage({
    required this.onboardingController,
    super.key,
  });

  final OnboardingController onboardingController;

  @override
  State<WorkspaceModulesPage> createState() => _WorkspaceModulesPageState();
}

class _WorkspaceModulesPageState extends State<WorkspaceModulesPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_WorkspaceChatEntry> _chatEntries = [];
  final List<CanvasWorkSnapshot> _canvasSnapshots = [];

  _WorkspaceContentMode _contentMode = _WorkspaceContentMode.choosing;
  _WorkspaceQuizState _quizState = _WorkspaceQuizState.unanswered;
  String? _selectedQuizAnswer;
  Timer? _videoTimer;

  @override
  void dispose() {
    _videoTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _chooseExplanation() {
    _videoTimer?.cancel();
    setState(() {
      _contentMode = _WorkspaceContentMode.explanation;
      _quizState = _WorkspaceQuizState.unanswered;
      _selectedQuizAnswer = null;
    });
    _scrollToBottom();
  }

  void _generateVideo() {
    _videoTimer?.cancel();
    setState(() {
      _contentMode = _WorkspaceContentMode.videoLoading;
      _quizState = _WorkspaceQuizState.unanswered;
      _selectedQuizAnswer = null;
    });
    _scrollToBottom();

    _videoTimer = Timer(const Duration(milliseconds: 1350), () {
      if (!mounted) return;
      setState(() => _contentMode = _WorkspaceContentMode.videoReady);
      _scrollToBottom();
    });
  }

  void _answerQuiz(String answer) {
    setState(() {
      _selectedQuizAnswer = answer;
      _quizState = answer == '3'
          ? _WorkspaceQuizState.correct
          : _WorkspaceQuizState.review;
    });
    _scrollToBottom();
  }

  void _handleCanvasSentToChat(CanvasWorkSnapshot snapshot) {
    setState(() {
      _canvasSnapshots.add(snapshot);
      _chatEntries.add(_WorkspaceChatEntry.canvas(snapshot));
    });
    _scrollToBottom();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    setState(() {
      _chatEntries.add(_WorkspaceChatEntry.text(text: message, isUser: true));
      _chatEntries.add(
        const _WorkspaceChatEntry.text(
          text:
              'Nice. I will keep the canvas and chat in sync while we work through this module.',
          isUser: false,
        ),
      );
    });
    _scrollToBottom();
  }

  void _openCanvas() {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Canvas workspace',
      barrierDismissible: true,
      barrierColor: WicaraColors.ink.withValues(alpha: 0.14),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _WorkspaceCanvasDialog(
          onCanvasSent: (snapshot) {
            _handleCanvasSentToChat(snapshot);
            Navigator.of(context).pop();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = OnboardingCopy.forLanguage(
      widget.onboardingController.profile.preferredLanguage,
    );
    return Scaffold(
      backgroundColor: WicaraColors.pageBackground,
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
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
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Image.asset(
                                'lib/src/assets/workspaceIcon.png',
                                width: 84,
                                height: 84,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Workspace',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _WorkspaceTopicCard(copy: copy),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, viewportConstraints) {
                          return SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: viewportConstraints.maxHeight - 12,
                              ),
                              child: _WorkspaceChatPanel(
                                contentMode: _contentMode,
                                quizState: _quizState,
                                selectedQuizAnswer: _selectedQuizAnswer,
                                chatEntries: _chatEntries,
                                canvasSnapshots: _canvasSnapshots,
                                onChooseExplanation: _chooseExplanation,
                                onGenerateVideo: _generateVideo,
                                onAnswerQuiz: _answerQuiz,
                                onOpenCanvas: _openCanvas,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _WorkspaceFooter(
                      controller: _messageController,
                      onSend: _sendMessage,
                      copy: copy,
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
}

class _WorkspaceChatEntry {
  const _WorkspaceChatEntry.text({required this.text, required this.isUser})
    : snapshot = null;

  const _WorkspaceChatEntry.canvas(this.snapshot) : text = null, isUser = true;

  final String? text;
  final bool isUser;
  final CanvasWorkSnapshot? snapshot;

  bool get isCanvas => snapshot != null;
}

class _WorkspaceChatPanel extends StatelessWidget {
  const _WorkspaceChatPanel({
    required this.contentMode,
    required this.quizState,
    required this.selectedQuizAnswer,
    required this.chatEntries,
    required this.canvasSnapshots,
    required this.onChooseExplanation,
    required this.onGenerateVideo,
    required this.onAnswerQuiz,
    required this.onOpenCanvas,
  });

  final _WorkspaceContentMode contentMode;
  final _WorkspaceQuizState quizState;
  final String? selectedQuizAnswer;
  final List<_WorkspaceChatEntry> chatEntries;
  final List<CanvasWorkSnapshot> canvasSnapshots;
  final VoidCallback onChooseExplanation;
  final VoidCallback onGenerateVideo;
  final ValueChanged<String> onAnswerQuiz;
  final VoidCallback onOpenCanvas;

  @override
  Widget build(BuildContext context) {
    return _WorkspacePanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AssistantMessageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WorkspaceBubble(
                  text:
                      'Okay, before we start learning limits from graphs, what do you prefer?',
                  isUser: false,
                ),
                SizedBox(height: 9),
                _WorkspaceBubble(
                  text:
                      'I can write a clear long-form explanation, or I can generate a short visual video and save it here for you.',
                  isUser: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _WorkspaceChoiceGrid(
            contentMode: contentMode,
            onChooseExplanation: onChooseExplanation,
            onGenerateVideo: onGenerateVideo,
          ),
          if (contentMode == _WorkspaceContentMode.explanation) ...[
            const SizedBox(height: 14),
            const _WorkspaceBubble(
              text: 'Long explanation, please.',
              isUser: true,
            ),
            const SizedBox(height: 9),
            const _ConceptExplanationBubble(),
          ] else if (contentMode == _WorkspaceContentMode.videoLoading) ...[
            const SizedBox(height: 14),
            const _WorkspaceBubble(text: 'Generate a video.', isUser: true),
            const SizedBox(height: 10),
            const _WorkspaceVideoLoadingCard(),
          ] else if (contentMode == _WorkspaceContentMode.videoReady) ...[
            const SizedBox(height: 14),
            const _WorkspaceBubble(text: 'Generate a video.', isUser: true),
            const SizedBox(height: 10),
            const _GeneratedWorkspaceVideoCard(),
          ],
          if (contentMode == _WorkspaceContentMode.explanation ||
              contentMode == _WorkspaceContentMode.videoReady) ...[
            const SizedBox(height: 14),
            _WorkspaceQuizCard(
              quizState: quizState,
              selectedAnswer: selectedQuizAnswer,
              onAnswer: onAnswerQuiz,
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _WorkspaceCanvasPromptBubble(
              hasCanvasWork: canvasSnapshots.isNotEmpty,
              onUseCanvas: onOpenCanvas,
            ),
          ),
          for (final entry in chatEntries) ...[
            const SizedBox(height: 9),
            if (entry.isCanvas)
              Align(
                alignment: Alignment.centerRight,
                child: _CanvasSnapshotBubble(snapshot: entry.snapshot!),
              )
            else if (entry.isUser)
              _WorkspaceBubble(text: entry.text!, isUser: true)
            else
              _AssistantMessageFrame(
                child: _WorkspaceBubble(text: entry.text!, isUser: false),
              ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceCanvasDialog extends StatelessWidget {
  const _WorkspaceCanvasDialog({required this.onCanvasSent});

  final ValueChanged<CanvasWorkSnapshot> onCanvasSent;

  @override
  Widget build(BuildContext context) {
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
              final verticalPadding = constraints.maxHeight > 700 ? 24.0 : 12.0;
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
                    onSendToChat: onCanvasSent,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WorkspaceChoiceGrid extends StatelessWidget {
  const _WorkspaceChoiceGrid({
    required this.contentMode,
    required this.onChooseExplanation,
    required this.onGenerateVideo,
  });

  final _WorkspaceContentMode contentMode;
  final VoidCallback onChooseExplanation;
  final VoidCallback onGenerateVideo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _WorkspaceChoiceButton(
            label: 'Long explanation',
            icon: Icons.notes_rounded,
            isSelected: contentMode == _WorkspaceContentMode.explanation,
            onPressed: onChooseExplanation,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _WorkspaceChoiceButton(
            label: 'Generate video',
            icon: Icons.smart_display_rounded,
            isSelected:
                contentMode == _WorkspaceContentMode.videoLoading ||
                contentMode == _WorkspaceContentMode.videoReady,
            onPressed: onGenerateVideo,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceChoiceButton extends StatelessWidget {
  const _WorkspaceChoiceButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final background = isSelected ? WicaraColors.speechBlue : Colors.white;
    final borderColor = isSelected ? WicaraColors.primary : WicaraColors.line;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 78,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: WicaraColors.primaryDeep, size: 20),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: WicaraColors.ink,
                    fontWeight: FontWeight.w700,
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

class _WorkspaceBubble extends StatelessWidget {
  const _WorkspaceBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 250),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isUser ? WicaraColors.speechBlue : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isUser ? WicaraColors.primaryLight : WicaraColors.line,
            ),
            boxShadow: [
              BoxShadow(
                color: WicaraColors.shadowBlue.withValues(alpha: 0.18),
                blurRadius: 15,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantMessageFrame extends StatelessWidget {
  const _AssistantMessageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AgentAvatar(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agent',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: WicaraColors.secondaryDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WicaraColors.secondary, WicaraColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: WicaraColors.secondary.withValues(alpha: 0.26),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Image.asset(
          'lib/src/assets/waveIcon.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _WorkspaceTopicCard extends StatelessWidget {
  const _WorkspaceTopicCard({required this.copy});

  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: WicaraColors.line),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: WicaraColors.secondarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              copy.currentTopicLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: WicaraColors.secondaryDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Limits from graphs',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: WicaraColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Focus on reading left-hand and right-hand behavior, then connect what the graph approaches to the limit value.',
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

class _WorkspaceCanvasPromptBubble extends StatelessWidget {
  const _WorkspaceCanvasPromptBubble({
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
        _WorkspaceCanvasQuickActionButton(
          label: hasCanvasWork ? 'Open canvas' : 'Use canvas',
          onPressed: onUseCanvas,
        ),
      ],
    );
  }
}

class _WorkspaceCanvasQuickActionButton extends StatelessWidget {
  const _WorkspaceCanvasQuickActionButton({
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

class _ConceptExplanationBubble extends StatelessWidget {
  const _ConceptExplanationBubble();

  @override
  Widget build(BuildContext context) {
    return _WorkspaceRichBubble(
      icon: Icons.lightbulb_outline_rounded,
      title: 'Concept explanation',
      child: Text(
        'A limit is the value a function is moving toward, not always the value it reaches. On a graph, trace the curve from the left and from the right. If both sides approach the same height, that height is the limit. The filled or open dot at the exact x-value matters for the function value, but the limit cares about the nearby behavior.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: WicaraColors.text,
          fontWeight: FontWeight.w600,
          height: 1.42,
        ),
      ),
    );
  }
}

class _WorkspaceVideoLoadingCard extends StatelessWidget {
  const _WorkspaceVideoLoadingCard();

  @override
  Widget build(BuildContext context) {
    return _WorkspaceRichBubble(
      icon: Icons.movie_creation_outlined,
      title: 'Generating video',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(
              minHeight: 7,
              color: WicaraColors.primary,
              backgroundColor: WicaraColors.primarySoft,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            'Building scenes, narration, and a quick graph animation...',
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

class _GeneratedWorkspaceVideoCard extends StatelessWidget {
  const _GeneratedWorkspaceVideoCard();

  @override
  Widget build(BuildContext context) {
    return _WorkspaceRichBubble(
      icon: Icons.video_collection_outlined,
      title: 'Saved generated video',
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WicaraColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _WorkspaceVideoPreviewPainter()),
                    Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: WicaraColors.shadowBlue.withValues(
                                alpha: 0.32,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: WicaraColors.secondary,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Limits from graphs in 5 minutes',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: WicaraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const _GeneratedVideoChip('04:52'),
                      const SizedBox(width: 7),
                      const _GeneratedVideoChip('AI video'),
                      const Spacer(),
                      Icon(
                        Icons.check_circle_rounded,
                        color: WicaraColors.accentMint,
                        size: 18,
                      ),
                    ],
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

class _GeneratedVideoChip extends StatelessWidget {
  const _GeneratedVideoChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: WicaraColors.line),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: WicaraColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WorkspaceQuizCard extends StatelessWidget {
  const _WorkspaceQuizCard({
    required this.quizState,
    required this.selectedAnswer,
    required this.onAnswer,
  });

  final _WorkspaceQuizState quizState;
  final String? selectedAnswer;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceRichBubble(
      icon: Icons.quiz_outlined,
      title: 'Sudden check',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'If the graph approaches y = 3 from both sides as x approaches 2, what is the limit?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.text,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          for (final answer in const ['2', '3', 'Does not exist'])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WorkspaceQuizOption(
                label: answer,
                isSelected: selectedAnswer == answer,
                isCorrect: answer == '3',
                hasAnswered: quizState != _WorkspaceQuizState.unanswered,
                onPressed: () => onAnswer(answer),
              ),
            ),
          if (quizState != _WorkspaceQuizState.unanswered) ...[
            const SizedBox(height: 3),
            Text(
              quizState == _WorkspaceQuizState.correct
                  ? 'Correct. The nearby behavior on both sides points to 3.'
                  : 'Almost. Look at the height the curve approaches, not the x-value.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: quizState == _WorkspaceQuizState.correct
                    ? WicaraColors.accentMint
                    : WicaraColors.accentCoral,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceQuizOption extends StatelessWidget {
  const _WorkspaceQuizOption({
    required this.label,
    required this.isSelected,
    required this.isCorrect,
    required this.hasAnswered,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final bool isCorrect;
  final bool hasAnswered;
  final VoidCallback onPressed;

  Color get _borderColor {
    if (!hasAnswered || !isSelected) return WicaraColors.line;
    return isCorrect ? WicaraColors.accentMint : WicaraColors.accentCoral;
  }

  Color get _background {
    if (!hasAnswered || !isSelected) return Colors.white;
    return isCorrect
        ? WicaraColors.speechGreen
        : WicaraColors.glowPeach.withValues(alpha: 0.62);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _background,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _borderColor, width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hasAnswered && isSelected)
                Icon(
                  isCorrect
                      ? Icons.check_circle_rounded
                      : Icons.refresh_rounded,
                  color: isCorrect
                      ? WicaraColors.accentMint
                      : WicaraColors.accentCoral,
                  size: 19,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasSnapshotBubble extends StatelessWidget {
  const _CanvasSnapshotBubble({required this.snapshot});

  final CanvasWorkSnapshot snapshot;

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
                Icons.draw_outlined,
                color: WicaraColors.primaryDeep,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Canvas sent',
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
          Text(
            '${snapshot.elementCount} marks${snapshot.hasAttachment ? ' • paper attached' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _WorkspaceFooter extends StatelessWidget {
  const _WorkspaceFooter({
    required this.controller,
    required this.onSend,
    required this.copy,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final OnboardingCopy copy;

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
        child: _WorkspaceComposerInput(
          controller: controller,
          onSend: onSend,
          copy: copy,
        ),
      ),
    );
  }
}

class _WorkspaceComposerInput extends StatelessWidget {
  const _WorkspaceComposerInput({
    required this.controller,
    required this.onSend,
    required this.copy,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 2,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: copy.askOrReflectHereHint,
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
            onPressed: onSend,
            icon: const Icon(Icons.arrow_upward_rounded),
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceRichBubble extends StatelessWidget {
  const _WorkspaceRichBubble({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WicaraColors.line, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: WicaraColors.secondary, size: 19),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            child,
          ],
        ),
      ),
    );
  }
}

class _WorkspacePanel extends StatelessWidget {
  const _WorkspacePanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

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

class _WorkspaceVideoPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEEF6FF), Color(0xFFF7F2FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final axisPaint = Paint()
      ..color = WicaraColors.primaryDeep.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final graphRect = Rect.fromLTWH(
      size.width * 0.13,
      size.height * 0.18,
      size.width * 0.74,
      size.height * 0.62,
    );
    canvas.drawLine(
      Offset(graphRect.left, graphRect.center.dy),
      Offset(graphRect.right, graphRect.center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(graphRect.left + graphRect.width * 0.32, graphRect.top),
      Offset(graphRect.left + graphRect.width * 0.32, graphRect.bottom),
      axisPaint,
    );

    final curvePaint = Paint()
      ..color = WicaraColors.secondary
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final curve = Path()
      ..moveTo(graphRect.left + 8, graphRect.bottom - 8)
      ..cubicTo(
        graphRect.left + graphRect.width * 0.27,
        graphRect.top + 14,
        graphRect.left + graphRect.width * 0.48,
        graphRect.top + 12,
        graphRect.left + graphRect.width * 0.62,
        graphRect.center.dy,
      )
      ..cubicTo(
        graphRect.left + graphRect.width * 0.73,
        graphRect.bottom - 5,
        graphRect.right - 18,
        graphRect.bottom - 20,
        graphRect.right - 8,
        graphRect.top + 18,
      );
    canvas.drawPath(curve, curvePaint);

    final dotPaint = Paint()..color = WicaraColors.accentCoral;
    canvas.drawCircle(
      Offset(graphRect.left + graphRect.width * 0.61, graphRect.center.dy),
      6,
      dotPaint,
    );

    final tagPaint = Paint()..color = Colors.white.withValues(alpha: 0.86);
    final tagRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.08, size.height * 0.08, 86, 27),
      const Radius.circular(999),
    );
    canvas.drawRRect(tagRect, tagPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'limit = 3',
        style: TextStyle(
          color: WicaraColors.primaryDeep,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        tagRect.outerRect.left + 13,
        tagRect.outerRect.top +
            (tagRect.outerRect.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
