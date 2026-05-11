import 'package:flutter/material.dart';

import '../../../../core/theme/wicara_colors.dart';
import '../../domain/auth_repository.dart';

class RolePill extends StatelessWidget {
  const RolePill({required this.role, super.key});

  final AuthRole role;

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
          role.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: WicaraColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
