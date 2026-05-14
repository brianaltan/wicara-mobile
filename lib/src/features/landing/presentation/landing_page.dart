import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/domain/onboarding_copy.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({required this.onboardingController, super.key});

  final OnboardingController onboardingController;

  static const double _horizontalInset = 24;
  static const double _primaryButtonTopMargin = 20;
  static const double _buttonGap = 16;
  static const double _buttonGroupBottomMargin = 24;
  static const double _imageVerticalPadding = 12;
  static const String _backgroundAsset = 'lib/src/assets/landingPage.png';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: onboardingController,
      builder: (context, _) {
        final copy = OnboardingCopy.forLanguage(
          onboardingController.profile.preferredLanguage,
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF3F3FD),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final pageWidth = math.min(constraints.maxWidth, 430.0);

              return Center(
                child: SizedBox(
                  width: pageWidth,
                  height: constraints.maxHeight,
                  child: SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: ColoredBox(
                            color: const Color(0xFFF3F3FD),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: _imageVerticalPadding,
                              ),
                              child: Image.asset(
                                _backgroundAsset,
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            _horizontalInset,
                            _primaryButtonTopMargin,
                            _horizontalInset,
                            _buttonGroupBottomMargin,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PrimaryLandingButton(
                                label: copy.getStartedLabel,
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.signIn),
                              ),
                              const SizedBox(height: _buttonGap),
                              _SecondaryButton(
                                label: copy.alreadyHaveAccountLabel,
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.signIn),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFD8DDE8), width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: const Color(0xFF1F2A44),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: const Color(0xFF1F2A44),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _PrimaryLandingButton extends StatelessWidget {
  const _PrimaryLandingButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.copyWith(
          labelLarge: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
      child: GradientButton(label: label, onPressed: onPressed),
    );
  }
}
