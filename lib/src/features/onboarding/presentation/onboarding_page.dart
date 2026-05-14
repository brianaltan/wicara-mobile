import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/wicara_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/security_note.dart';
import '../application/onboarding_controller.dart';
import '../domain/onboarding_copy.dart';
import '../domain/onboarding_options.dart';
import '../domain/onboarding_repository.dart';
import 'widgets/onboarding_progress.dart';
import 'widgets/onboarding_select_field.dart';
import 'widgets/preference_callout.dart';
import 'widgets/subject_tile.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.onboardingController, super.key});

  final OnboardingController onboardingController;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentStep = 1;
  bool _isSaving = false;

  OnboardingCopy get _copy =>
      OnboardingCopy.forLanguage(widget.onboardingController.profile.preferredLanguage);

  Future<void> _nextStep() async {
    if (_currentStep < 3) {
      setState(() => _currentStep += 1);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onboardingController.saveProfile();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRoutes.learningGoal);
    } on OnboardingException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _previousStep() {
    if (_currentStep == 1) {
      return;
    }
    setState(() => _currentStep -= 1);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _selectCountry() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SearchableOptionSheet(
        title: _copy.countryLabel,
        options: onboardingCountryOptions,
        initialValue: widget.onboardingController.profile.country,
        searchHint: _copy.searchLabel,
      ),
    );
    if (selected != null) {
      await widget.onboardingController.updateCountry(selected);
    }
  }

  Future<void> _editFullName() async {
    var draftName = widget.onboardingController.profile.fullName;
    final submitted = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_copy.fullNameLabel),
          content: TextFormField(
            initialValue: draftName,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: _copy.fullNameLabel,
            ),
            onChanged: (value) => draftName = value,
            onFieldSubmitted: (value) =>
                Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_copy.cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(draftName.trim()),
              child: Text(_copy.applyLabel),
            ),
          ],
        );
      },
    );

    if (submitted != null && submitted.isNotEmpty) {
      await widget.onboardingController.updateFullName(submitted);
    }
  }

  Future<void> _selectGradeLevel() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _OptionSheet(
        title: _copy.gradeLevelLabel,
        options: onboardingGradeLevelOptions,
        initialValue: widget.onboardingController.profile.gradeLevel,
        displayFor: _copy.gradeValue,
      ),
    );
    if (selected != null) {
      await widget.onboardingController.updateGradeLevel(selected);
    }
  }

  Future<void> _selectLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _OptionSheet(
        title: _copy.preferredLanguageLabel,
        options: onboardingLanguageOptions,
        initialValue: widget.onboardingController.profile.preferredLanguage,
      ),
    );
    if (selected != null) {
      await widget.onboardingController.updatePreferredLanguage(selected);
    }
  }

  Future<void> _selectStudyGoal() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _OptionSheet(
        title: _copy.studyGoalLabel,
        options: onboardingStudyGoalOptions,
        initialValue: widget.onboardingController.profile.studyGoal,
        displayFor: _copy.studyGoalDisplay,
      ),
    );
    if (selected != null) {
      await widget.onboardingController.updateStudyGoal(selected);
    }
  }

  Future<void> _selectDailyStudyTime() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _OptionSheet(
        title: _copy.dailyStudyTimeLabel,
        options: onboardingDailyStudyTimeOptions,
        initialValue: widget.onboardingController.profile.dailyStudyTime,
        displayFor: _copy.dailyStudyTimeDisplay,
      ),
    );
    if (selected != null) {
      await widget.onboardingController.updateDailyStudyTime(selected);
    }
  }

  Future<void> _toggleSubject(String subjectKey, bool isSelected) async {
    final subjects = [...widget.onboardingController.profile.selectedSubjects];
    if (isSelected) {
      if (!subjects.contains(subjectKey)) {
        subjects.add(subjectKey);
      }
    } else {
      subjects.remove(subjectKey);
    }
    await widget.onboardingController.updateSelectedSubjects(subjects);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.onboardingController,
      builder: (context, _) {
        final profile = widget.onboardingController.profile;
        final copy = _copy;

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pageWidth = math.min(constraints.maxWidth, 430.0);

                return Center(
                  child: SizedBox(
                    width: pageWidth,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 50, 28, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 74,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_currentStep > 1) ...[
                                _OnboardingBackButton(onPressed: _previousStep),
                                const SizedBox(height: 16),
                              ],
                              OnboardingProgress(currentStep: _currentStep),
                              const SizedBox(height: 52),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: KeyedSubtree(
                                  key: ValueKey(
                                    '$_currentStep-${profile.preferredLanguage}',
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: switch (_currentStep) {
                                      1 => [
                                        _OnboardingTitle(
                                          title: copy.letsSetYouUpTitle,
                                          subtitle: copy.letsSetYouUpSubtitle,
                                        ),
                                        const SizedBox(height: 37),
                                        OnboardingSelectField(
                                          label: copy.fullNameLabel,
                                          value: profile.fullName,
                                          showChevron: true,
                                          leading: const _SoftIcon(
                                            Icons.person_outline_rounded,
                                          ),
                                          onTap: _editFullName,
                                        ),
                                        const SizedBox(height: 26),
                                        OnboardingSelectField(
                                          label: copy.countryLabel,
                                          value: profile.country,
                                          leading: const _SoftIcon(
                                            Icons.public_rounded,
                                          ),
                                          onTap: _selectCountry,
                                        ),
                                        const SizedBox(height: 26),
                                        OnboardingSelectField(
                                          label: copy.gradeLevelLabel,
                                          value: copy.gradeValue(
                                            profile.gradeLevel,
                                          ),
                                          leading: const _SoftIcon(
                                            Icons.school_outlined,
                                          ),
                                          onTap: _selectGradeLevel,
                                        ),
                                        const SizedBox(height: 26),
                                        OnboardingSelectField(
                                          label: copy.preferredLanguageLabel,
                                          value: copy.languageDisplay(
                                            profile.preferredLanguage,
                                          ),
                                          leading: const _SoftIcon(
                                            Icons.language_rounded,
                                          ),
                                          onTap: _selectLanguage,
                                        ),
                                        const SizedBox(height: 34),
                                        GradientButton(
                                          label: copy.continueLabel,
                                          onPressed: _isSaving ? null : _nextStep,
                                        ),
                                        const SizedBox(height: 19),
                                        Text(
                                          copy.improveExperienceNote,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: WicaraColors.softMuted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 42),
                                        SecurityNote(
                                          maxWidth: 235,
                                          message: copy.securityNoteLabel,
                                        ),
                                      ],
                                      2 => [
                                        _OnboardingTitle(
                                          title: copy.chooseSubjectsTitle,
                                          subtitle: copy.chooseSubjectsSubtitle,
                                        ),
                                        const SizedBox(height: 31),
                                        for (final subject in onboardingSubjectOptions) ...[
                                          SubjectTile(
                                            title: copy.subjectLabel(subject.key),
                                            description: copy.subjectDescription(
                                              subject.key,
                                            ),
                                            icon: subject.icon,
                                            tint: subject.tint,
                                            isSelected: profile.selectedSubjects
                                                .contains(subject.key),
                                            onChanged: (value) => _toggleSubject(
                                              subject.key,
                                              value,
                                            ),
                                          ),
                                          if (subject !=
                                              onboardingSubjectOptions.last)
                                            const SizedBox(height: 10),
                                        ],
                                        const SizedBox(height: 29),
                                        GradientButton(
                                          label: copy.continueLabel,
                                          onPressed: _isSaving ? null : _nextStep,
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          copy.customizeLaterNote,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: WicaraColors.softMuted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                      _ => [
                                        _OnboardingTitle(
                                          title: copy.preferencesTitle,
                                          subtitle: copy.preferencesSubtitle,
                                        ),
                                        const SizedBox(height: 23),
                                        OnboardingSelectField(
                                          label: copy.studyGoalOptionalLabel,
                                          value: copy.studyGoalDisplay(
                                            profile.studyGoal,
                                          ),
                                          leading: const _SoftIcon(
                                            Icons.track_changes_rounded,
                                          ),
                                          onTap: _selectStudyGoal,
                                        ),
                                        const SizedBox(height: 25),
                                        OnboardingSelectField(
                                          label:
                                              copy.dailyStudyTimeOptionalLabel,
                                          value: copy.dailyStudyTimeDisplay(
                                            profile.dailyStudyTime,
                                          ),
                                          leading: const _SoftIcon(
                                            Icons.schedule_rounded,
                                          ),
                                          onTap: _selectDailyStudyTime,
                                        ),
                                        const SizedBox(height: 18),
                                        PreferenceCallout(
                                          message: copy.preferenceCallout,
                                        ),
                                        const SizedBox(height: 34),
                                        GradientButton(
                                          label: copy.adaptivePretestLabel,
                                          onPressed: _isSaving ? null : _nextStep,
                                          isLoading: _isSaving,
                                        ),
                                        const SizedBox(height: 19),
                                        Text(
                                          copy.personalizePathNote,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: WicaraColors.softMuted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
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

class _OnboardingBackButton extends StatelessWidget {
  const _OnboardingBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Back',
        onPressed: onPressed,
        icon: const Icon(Icons.chevron_left_rounded),
        iconSize: 32,
        color: WicaraColors.ink,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      ),
    );
  }
}

class _OnboardingTitle extends StatelessWidget {
  const _OnboardingTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'lib/src/assets/onboardingIcon.png',
          width: 84,
          height: 84,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontSize: 24, height: 1.12),
        ),
        const SizedBox(height: 13),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: WicaraColors.muted,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: WicaraColors.softMuted, size: 21);
  }
}

class _OptionSheet extends StatelessWidget {
  const _OptionSheet({
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

class _SearchableOptionSheet extends StatefulWidget {
  const _SearchableOptionSheet({
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
  State<_SearchableOptionSheet> createState() => _SearchableOptionSheetState();
}

class _SearchableOptionSheetState extends State<_SearchableOptionSheet> {
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
