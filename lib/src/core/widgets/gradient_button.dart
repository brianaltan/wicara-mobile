import 'package:flutter/material.dart';

import '../theme/wicara_colors.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isEnabled ? WicaraColors.secondary : WicaraColors.line,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (isEnabled)
            BoxShadow(
              color: WicaraColors.secondary.withValues(alpha: 0.24),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        height: 19,
                        width: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
