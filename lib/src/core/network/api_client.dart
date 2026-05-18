import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const deployedBaseUrl = 'http://16.78.247.45';

  static const defaultBaseUrl = String.fromEnvironment(
    'WICARA_API_BASE_URL',
    defaultValue: deployedBaseUrl,
  );

  /// Prevents a loopback URL from being used in web environments where the
  /// app is not served from localhost/127.0.0.1.
  static String resolveRuntimeBaseUrl(String configuredBaseUrl) {
    final configuredUri = Uri.tryParse(configuredBaseUrl);
    if (configuredUri == null) return configuredBaseUrl;
    if (!kIsWeb) return configuredBaseUrl;

    final configuredHost = configuredUri.host.toLowerCase();
    final isConfiguredLoopback =
        configuredHost == '127.0.0.1' || configuredHost == 'localhost';
    if (!isConfiguredLoopback) return configuredBaseUrl;

    final webHost = Uri.base.host.toLowerCase();
    final isWebLoopback = webHost == '127.0.0.1' || webHost == 'localhost';
    if (isWebLoopback) return configuredBaseUrl;

    return deployedBaseUrl;
  }

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
    Duration timeout = const Duration(seconds: 45),
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
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final (msg, rawDetail) = _errorMessageAndDetail(
        response,
        method: 'POST',
        uri: uri,
      );
      throw ApiClientException(msg, detail: rawDetail);
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

/// Returns (humanMessage, rawDetail) for an error response.
/// `rawDetail` is the raw JSON value of the `detail` key (if present), which
/// may be a String, Map, or null.
(String, Object?) _errorMessageAndDetail(
  http.Response response, {
  required String method,
  required Uri uri,
}) {
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return (detail, detail);
      }
      if (detail is Map<String, dynamic>) {
        final detailMessage = detail['message'];
        String msg = '$method $uri failed with status ${response.statusCode}';
        if (detailMessage is String && detailMessage.trim().isNotEmpty) {
          msg = detailMessage;
        } else {
          final detailError = detail['error'];
          if (detailError is String && detailError.trim().isNotEmpty) {
            msg = detailError;
          }
        }
        return (msg, detail);
      }
      final error = decoded['error'];
      if (error is String && error.trim().isNotEmpty) {
        return (error, null);
      }
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return (message, null);
      }
    }
  } catch (_) {
    // Fall back to the transport-level message below.
  }
  return ('$method $uri failed with status ${response.statusCode}', null);
}

// Legacy shim kept for methods that haven't been updated yet.
String _errorMessage(
  http.Response response, {
  required String method,
  required Uri uri,
}) => _errorMessageAndDetail(response, method: method, uri: uri).$1;

class ApiClientException implements Exception {
  const ApiClientException(this.message, {this.detail});

  final String message;

  /// The raw JSON `detail` value parsed from the error response body.
  /// May be a [String], [Map], or `null`.
  final Object? detail;

  @override
  String toString() => message;
}
