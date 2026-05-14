import 'package:flutter/material.dart';

import 'google_sign_in_action_stub.dart'
    if (dart.library.html) 'google_sign_in_action_web.dart';
import 'google_web_credential.dart';

export 'google_web_credential.dart';

class GoogleSignInAction extends StatelessWidget {
  const GoogleSignInAction({
    required this.onPressed,
    required this.onWebCredential,
    super.key,
  });

  final VoidCallback? onPressed;
  final ValueChanged<GoogleWebCredential> onWebCredential;

  @override
  Widget build(BuildContext context) {
    return buildGoogleSignInAction(
      context,
      onPressed: onPressed,
      onWebCredential: onWebCredential,
    );
  }
}
