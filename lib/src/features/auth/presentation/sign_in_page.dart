import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/wicara_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/security_note.dart';
import '../domain/auth_repository.dart';
import 'widgets/google_sign_in_action.dart';
import 'widgets/role_pill.dart';
import 'widgets/wicara_text_field.dart';

enum _AuthMode { login, register }

class SignInPage extends StatefulWidget {
  const SignInPage({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _role = AuthRole.learner;

  _AuthMode _mode = _AuthMode.login;
  bool _isPasswordHidden = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
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
      if (_mode == _AuthMode.login) {
        final session = await widget.authRepository.signIn(
          SignInRequest(
            emailOrPhone: _emailController.text,
            password: _passwordController.text,
            role: _role,
          ),
        );
        if (!mounted) {
          return;
        }
        _openNextRoute(session);
      } else {
        final session = await widget.authRepository.register(
          RegisterRequest(
            email: _emailController.text,
            password: _passwordController.text,
            displayName: _nameController.text,
            role: _role,
          ),
        );
        if (!mounted) {
          return;
        }
        _openNextRoute(session);
      }
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
      final session = await widget.authRepository.signInWithGoogle(role: _role);
      if (!mounted) {
        return;
      }
      _openNextRoute(session);
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

  void _startGoogleWebSignIn() {
    setState(() => _isSubmitting = true);
  }

  Future<void> _continueWithGoogleIdToken(
    GoogleWebCredential credential,
  ) async {
    setState(() => _isSubmitting = true);
    try {
      final session = await widget.authRepository.signInWithGoogleIdToken(
        idToken: credential.idToken,
        nonce: credential.nonce,
        role: _role,
      );
      if (!mounted) {
        return;
      }
      _openNextRoute(session);
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

  void _openNextRoute(AuthSession session) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      session.onboardingCompleted ? AppRoutes.home : AppRoutes.onboarding,
      (route) => false,
    );
  }

  void _selectMode(_AuthMode mode) {
    if (_mode == mode || _isSubmitting) {
      return;
    }
    setState(() {
      _mode = mode;
      _formKey.currentState?.reset();
    });
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
                                  _mode == _AuthMode.login
                                      ? 'Welcome back'
                                      : 'Create your account',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _mode == _AuthMode.login
                                      ? 'Sign in to continue your learning'
                                      : 'Register once, then continue with your learning path',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: WicaraColors.muted,
                                        fontWeight: FontWeight.w400,
                                      ),
                                ),
                                const SizedBox(height: 28),
                                _AuthModeSwitch(
                                  selectedMode: _mode,
                                  onSelected: _selectMode,
                                ),
                                const SizedBox(height: 22),
                                RolePill(role: _role),
                                const SizedBox(height: 30),
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_mode == _AuthMode.register) ...[
                                        const _FieldLabel('Full name'),
                                        const SizedBox(height: 10),
                                        WicaraTextField(
                                          controller: _nameController,
                                          hintText: 'Enter your full name',
                                          icon: Icons.person_outline_rounded,
                                          textInputAction: TextInputAction.next,
                                          validator: (value) {
                                            if (_mode != _AuthMode.register) {
                                              return null;
                                            }
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Enter your full name';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 22),
                                      ],
                                      _FieldLabel(
                                        _mode == _AuthMode.login
                                            ? 'Email or phone'
                                            : 'Email',
                                      ),
                                      const SizedBox(height: 10),
                                      WicaraTextField(
                                        controller: _emailController,
                                        hintText: _mode == _AuthMode.login
                                            ? 'Enter your email or phone'
                                            : 'Enter your email',
                                        icon: Icons.mail_outline_rounded,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return _mode == _AuthMode.login
                                                ? 'Enter your email or phone'
                                                : 'Enter your email';
                                          }
                                          if (_mode == _AuthMode.register &&
                                              !value.contains('@')) {
                                            return 'Use an email address for registration';
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
                                          if (_mode == _AuthMode.register &&
                                              value.length < 6) {
                                            return 'Password must be at least 6 characters';
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
                                if (_mode == _AuthMode.login)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _showMessage(
                                        'Password reset will be sent from your account email settings.',
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
                                  label: _mode == _AuthMode.login
                                      ? 'Log in'
                                      : 'Register',
                                  onPressed: _submit,
                                  isLoading: _isSubmitting,
                                ),
                                const SizedBox(height: 30),
                                const _DividerText(),
                                const SizedBox(height: 18),
                                GoogleSignInAction(
                                  onPressed: _isSubmitting
                                      ? null
                                      : kIsWeb
                                      ? _startGoogleWebSignIn
                                      : _continueWithGoogle,
                                  onWebCredential: _continueWithGoogleIdToken,
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

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({required this.selectedMode, required this.onSelected});

  final _AuthMode selectedMode;
  final ValueChanged<_AuthMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: WicaraColors.fieldFill,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Row(
        children: [
          _AuthModeOption(
            label: 'Log in',
            isSelected: selectedMode == _AuthMode.login,
            onTap: () => onSelected(_AuthMode.login),
          ),
          _AuthModeOption(
            label: 'Register',
            isSelected: selectedMode == _AuthMode.register,
            onTap: () => onSelected(_AuthMode.register),
          ),
        ],
      ),
    );
  }
}

class _AuthModeOption extends StatelessWidget {
  const _AuthModeOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? WicaraColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isSelected ? Colors.white : WicaraColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
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
