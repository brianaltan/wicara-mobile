import 'package:flutter/material.dart';

import '../../../../core/theme/wicara_colors.dart';
import '../../domain/auth_repository.dart';
import '../../../onboarding/domain/onboarding_copy.dart';

class RolePill extends StatelessWidget {
  const RolePill({required this.role, required this.copy, super.key});

  final AuthRole role;
  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        height: 42,
        width: 204,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: WicaraColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: WicaraColors.shadowBlue.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          copy.learnerLabel,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: WicaraColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
