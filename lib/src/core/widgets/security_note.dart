import 'package:flutter/material.dart';

import '../theme/wicara_colors.dart';

class SecurityNote extends StatelessWidget {
  const SecurityNote({this.maxWidth = 230, super.key});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: WicaraColors.glowMint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: WicaraColors.accentMint,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Text.rich(
              TextSpan(
                text: 'Your data is private and secure.\n',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WicaraColors.muted,
                  fontWeight: FontWeight.w400,
                ),
                children: [
                  TextSpan(
                    text: 'Learn how we protect you.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WicaraColors.primaryDeep,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}
