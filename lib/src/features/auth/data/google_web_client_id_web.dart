// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

String? readGoogleWebClientIdFromMetaTag() {
  final meta = html.document.querySelector(
    'meta[name="google-signin-client_id"]',
  );
  final content = meta?.getAttribute('content')?.trim();

  if (content == null || content.isEmpty) {
    return null;
  }

  return content;
}
