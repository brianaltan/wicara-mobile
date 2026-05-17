import 'package:flutter/material.dart';

import '../../../../core/theme/wicara_colors.dart';
import '../../domain/pretest_models.dart';
import 'rich_math_text.dart';

class AssessmentOptionTile extends StatelessWidget {
  const AssessmentOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final PretestOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? WicaraColors.secondary : WicaraColors.line;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1.3),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: WicaraColors.secondary.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 7),
                ),
            ],
          ),
          child: Row(
            children: [
              _SelectionDot(isSelected: isSelected),
              const SizedBox(width: 15),
              SizedBox(
                width: 17,
                child: Text(
                  option.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: WicaraColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichMathText(
                  option.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w400,
                    height: 1.28,
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

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isSelected ? WicaraColors.secondary : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? WicaraColors.secondary : WicaraColors.line,
          width: 2,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
