import 'package:flutter/material.dart';

import '../../../../core/theme/wicara_colors.dart';
import '../../../onboarding/domain/onboarding_copy.dart';

class ConfidencePicker extends StatelessWidget {
  const ConfidencePicker({
    required this.value,
    required this.onChanged,
    required this.copy,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: WicaraColors.line),
        const SizedBox(height: 17),
        Text(
          copy.confidenceQuestionLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: WicaraColors.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Flexible(
              child: Text(
                copy.lowLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.secondaryLight,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var score = 1; score <= 6; score++)
                    GestureDetector(
                      onTap: () => onChanged(score),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: score == value ? 18 : 8,
                        height: score == value ? 18 : 8,
                        decoration: BoxDecoration(
                          color: score == value
                              ? WicaraColors.secondary
                              : WicaraColors.softMuted.withValues(alpha: 0.58),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                copy.highLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
