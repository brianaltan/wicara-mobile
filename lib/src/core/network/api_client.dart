import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const defaultBaseUrl = String.fromEnvironment(
    'WICARA_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final String baseUrl;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse(
      baseUrl,
    ).replace(path: path, queryParameters: queryParameters);
    final response = await _httpClient
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 4));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiClientException(
        'GET $uri failed with status ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiClientException('Expected a JSON object response.');
    }

    return decoded;
  }
}

class ApiClientException implements Exception {
  const ApiClientException(this.message);

  final String message;

  @override
  String toString() => message;
}
