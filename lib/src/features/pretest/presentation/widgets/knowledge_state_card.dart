import 'package:flutter/material.dart';

import '../../../../core/theme/wicara_colors.dart';

class KnowledgeStateCard extends StatelessWidget {
  const KnowledgeStateCard({
    required this.title,
    required this.message,
    required this.badge,
    required this.icon,
    this.iconColor = WicaraColors.primaryDeep,
    this.iconBackgroundColor = WicaraColors.primarySoft,
    this.height = 354,
    this.showChevron = true,
    super.key,
  });

  final String title;
  final String message;
  final String badge;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final double height;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WicaraColors.line, width: 1.25),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.13),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 25),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (badge.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6E6),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          badge,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFFC28A35),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    if (showChevron) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: WicaraColors.softMuted,
                        size: 26,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
