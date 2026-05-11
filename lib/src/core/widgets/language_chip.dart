import 'package:flutter/material.dart';

import '../theme/wicara_colors.dart';

class LanguageChip extends StatelessWidget {
  const LanguageChip({this.languageCode = 'EN', super.key});

  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: WicaraColors.line),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language_rounded, size: 18, color: WicaraColors.ink),
          const SizedBox(width: 6),
          Text(
            languageCode,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
