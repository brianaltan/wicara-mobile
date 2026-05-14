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
  String? _authToken;

  void setAuthToken(String? token) {
    final normalizedToken = token?.trim();
    _authToken = normalizedToken == null || normalizedToken.isEmpty
        ? null
        : normalizedToken;
  }

  void clearAuthToken() => _authToken = null;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      baseUrl,
    ).replace(path: path, queryParameters: queryParameters);
    final mergedHeaders = <String, String>{..._buildHeaders(), ...?headers};
    final response = await _httpClient
        .get(uri, headers: mergedHeaders)
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

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      baseUrl,
    ).replace(path: path, queryParameters: queryParameters);
    final mergedHeaders = <String, String>{
      ..._buildHeaders(includeJsonContentType: true),
      ...?headers,
    };
    final response = await _httpClient
        .post(uri, headers: mergedHeaders, body: jsonEncode(body ?? const {}))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiClientException(
        _errorMessage(response, method: 'POST', uri: uri),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiClientException('Expected a JSON object response.');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      baseUrl,
    ).replace(path: path, queryParameters: queryParameters);
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...?headers,
    };
    final response = await _httpClient
        .put(uri, headers: mergedHeaders, body: jsonEncode(body ?? const {}))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiClientException(
        _errorMessage(response, method: 'PUT', uri: uri),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiClientException('Expected a JSON object response.');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      baseUrl,
    ).replace(path: path, queryParameters: queryParameters);
    final mergedHeaders = <String, String>{
      ..._buildHeaders(includeJsonContentType: true),
      ...?headers,
    };
    final response = await _httpClient
        .patch(uri, headers: mergedHeaders, body: jsonEncode(body ?? const {}))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiClientException(
        _errorMessage(response, method: 'PATCH', uri: uri),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiClientException('Expected a JSON object response.');
    }

    return decoded;
  }

  Map<String, String> _buildHeaders({bool includeJsonContentType = false}) {
    return <String, String>{
      'Accept': 'application/json',
      if (includeJsonContentType) 'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }
}

String _errorMessage(
  http.Response response, {
  required String method,
  required Uri uri,
}) {
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
      final error = decoded['error'];
      if (error is String && error.trim().isNotEmpty) {
        return error;
      }
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
  } catch (_) {
    // Fall back to the transport-level message below.
  }
  return '$method $uri failed with status ${response.statusCode}';
}

class ApiClientException implements Exception {
  const ApiClientException(this.message);

  final String message;

  @override
  String toString() => message;
}
