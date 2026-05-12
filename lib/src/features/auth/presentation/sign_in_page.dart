import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/wicara_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/security_note.dart';
import '../domain/auth_repository.dart';
import 'widgets/role_pill.dart';
import 'widgets/wicara_text_field.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _role = AuthRole.learner;

  bool _isPasswordHidden = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.authRepository.signIn(
        SignInRequest(
          emailOrPhone: _emailController.text,
          password: _passwordController.text,
          role: _role,
        ),
      );
      if (!mounted) {
        return;
      }
      _openOnboarding();
    } on AuthException catch (error) {
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

  Future<void> _continueWithGoogle() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.authRepository.signInWithGoogle(role: _role);
      if (!mounted) {
        return;
      }
      _openOnboarding();
    } on AuthException catch (error) {
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _openOnboarding() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false);
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AppRoutes.landing);
    }
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
                  padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 34,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              const SizedBox(width: 38, height: 38),
                            ],
                          ),
                          const SizedBox(height: 48),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in to continue your learning',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: WicaraColors.muted,
                                        fontWeight: FontWeight.w400,
                                      ),
                                ),
                                const SizedBox(height: 28),
                                RolePill(role: _role),
                                const SizedBox(height: 30),
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _FieldLabel('Email or phone'),
                                      const SizedBox(height: 10),
                                      WicaraTextField(
                                        controller: _emailController,
                                        hintText: 'Enter your email or phone',
                                        icon: Icons.mail_outline_rounded,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Enter your email or phone';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 22),
                                      const _FieldLabel('Password'),
                                      const SizedBox(height: 10),
                                      WicaraTextField(
                                        controller: _passwordController,
                                        hintText: 'Enter your password',
                                        icon: Icons.lock_outline_rounded,
                                        obscureText: _isPasswordHidden,
                                        textInputAction: TextInputAction.done,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Enter your password';
                                          }
                                          return null;
                                        },
                                        suffix: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _isPasswordHidden =
                                                  !_isPasswordHidden;
                                            });
                                          },
                                          icon: Icon(
                                            _isPasswordHidden
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: WicaraColors.softMuted,
                                            size: 21,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => _showMessage(
                                      'Password reset is mocked for now.',
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: WicaraColors.secondary,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 38),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Forgot password?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: WicaraColors.secondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                GradientButton(
                                  label: 'Sign in',
                                  onPressed: _submit,
                                  isLoading: _isSubmitting,
                                ),
                                const SizedBox(height: 30),
                                const _DividerText(),
                                const SizedBox(height: 18),
                                _GoogleButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : _continueWithGoogle,
                                ),
                                const SizedBox(height: 40),
                                const SecurityNote(),
                              ],
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
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: WicaraColors.text,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DividerText extends StatelessWidget {
  const _DividerText();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: WicaraColors.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or continue with',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const Expanded(child: Divider(color: WicaraColors.line)),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: WicaraColors.line, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          foregroundColor: WicaraColors.text,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GoogleGlyph(),
            const SizedBox(width: 14),
            Text(
              'Google',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: WicaraColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    );
  }
}
