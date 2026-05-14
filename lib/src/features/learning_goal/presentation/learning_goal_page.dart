import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/wicara_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../domain/learning_goal_repository.dart';

class LearningGoalPage extends StatefulWidget {
  const LearningGoalPage({required this.learningGoalRepository, super.key});

  final LearningGoalRepository learningGoalRepository;

  @override
  State<LearningGoalPage> createState() => _LearningGoalPageState();
}

class _LearningGoalPageState extends State<LearningGoalPage> {
  final _controller = TextEditingController();
  bool _isGenerating = false;
  bool _isComplete = false;

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
    setState(() {});
  }

  Future<void> _generatePretest() async {
    if (_controller.text.trim().isEmpty || _isGenerating) {
      return;
    }

    setState(() => _isGenerating = true);
    try {
      await widget.learningGoalRepository.createLearningGoal(
        rawTopic: _controller.text.trim(),
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
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pageWidth = math.min(constraints.maxWidth, 430.0);

            return Center(
              child: SizedBox(
                width: pageWidth,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 30),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
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
                        SizedBox(
                          height: math.max(constraints.maxHeight - 96, 560),
                          child: Center(
                            child: AnimatedPadding(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              padding: EdgeInsets.only(
                                bottom: math.min(
                                  _controller.text.length * 0.45,
                                  44,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
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
                                  const SizedBox(height: 14),
                                  Text(
                                    'What would you like to learn?',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontSize: 24, height: 1.12),
                                  ),
                                  const SizedBox(height: 9),
                                  Text(
                                    'Tell WICARA the topic. We will generate a short adaptive pretest before building your track.',
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
                                          'Learning topic',
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
                                        _LearningGoalField(
                                          controller: _controller,
                                        ),
                                        const SizedBox(height: 18),
                                        AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          child: _isComplete
                                              ? const _GeneratedPretestNotice()
                                              : const _PretestPreviewNotice(),
                                        ),
                                        const SizedBox(height: 22),
                                        GradientButton(
                                          label: 'Generate Pretest',
                                          onPressed:
                                              _controller.text.trim().isEmpty
                                              ? null
                                              : _generatePretest,
                                          isLoading: _isGenerating,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
  }
}

class _LearningGoalField extends StatefulWidget {
  const _LearningGoalField({required this.controller});

  final TextEditingController controller;

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
        decoration: const InputDecoration(hintText: 'Type a topic'),
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

class _PretestPreviewNotice extends StatelessWidget {
  const _PretestPreviewNotice();

  @override
  Widget build(BuildContext context) {
    return _NoticeBox(
      icon: Icons.psychology_alt_outlined,
      title: 'Adaptive pretest ready next',
      description: 'A few questions will calibrate your starting point.',
      color: WicaraColors.primary,
    );
  }
}

class _GeneratedPretestNotice extends StatelessWidget {
  const _GeneratedPretestNotice();

  @override
  Widget build(BuildContext context) {
    return _NoticeBox(
      icon: Icons.check_circle_rounded,
      title: 'Pretest generated complete!',
      description: 'Opening your adaptive pretest now.',
      color: WicaraColors.accentMint,
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
