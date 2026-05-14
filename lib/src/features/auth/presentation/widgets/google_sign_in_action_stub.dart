import 'package:flutter/material.dart';

import '../../../../core/theme/wicara_colors.dart';
import 'google_web_credential.dart';

Widget buildGoogleSignInAction(
  BuildContext context, {
  required VoidCallback? onPressed,
  required ValueChanged<GoogleWebCredential> onWebCredential,
}) {
  return SizedBox(
    width: double.infinity,
    height: 47,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: WicaraColors.line, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        foregroundColor: WicaraColors.text,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Continue with Google',
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
