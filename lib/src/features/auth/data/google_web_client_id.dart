import 'google_web_client_id_stub.dart'
    if (dart.library.html) 'google_web_client_id_web.dart';

String resolveGoogleWebClientId(String configuredValue) {
  final normalizedValue = configuredValue.trim();
  if (normalizedValue.isNotEmpty) {
    return normalizedValue;
  }

  return readGoogleWebClientIdFromMetaTag()?.trim() ?? '';
}
