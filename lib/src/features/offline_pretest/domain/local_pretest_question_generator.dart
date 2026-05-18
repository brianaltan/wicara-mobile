import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../edge_ai/data/litert_gemma_runtime.dart';
import '../../edge_ai/domain/edge_ai_models.dart';
import '../../edge_ai/domain/edge_ai_runtime.dart';

class LocalQuestionGenerationProgress {
  const LocalQuestionGenerationProgress({
    required this.active,
    required this.conceptCode,
    required this.status,
    required this.attempt,
    required this.maxAttempts,
    required this.progress,
    this.estimatedRemainingSeconds,
    this.message = '',
    this.rawOutputPreview = '',
    this.parsedOutputPreview = '',
  });

  final bool active;
  final String conceptCode;
  final String status;
  final int attempt;
  final int maxAttempts;
  final double progress;
  final int? estimatedRemainingSeconds;
  final String message;
  final String rawOutputPreview;
  final String parsedOutputPreview;
}

class LocalPretestQuestionGenerator {
  const LocalPretestQuestionGenerator({
    this.runtime = defaultEdgeAiRuntime,
    this.maxAttempts = 3,
    this.perAttemptTimeout = const Duration(seconds: 60),
  });

  final EdgeAiRuntime runtime;
  final int maxAttempts;
  final Duration perAttemptTimeout;

  static const _difficulties = <String>['easy', 'medium', 'hard'];
  static final _progressController =
      StreamController<LocalQuestionGenerationProgress>.broadcast();

  static Stream<LocalQuestionGenerationProgress> get progressStream =>
      _progressController.stream;

  Future<Map<String, dynamic>?> generatePack({
    required String conceptCode,
    required String conceptTitle,
    required String conceptDescription,
  }) async {
    final startedAt = DateTime.now();
    try {
      final runtimeReady = await _ensureRuntimeReady(conceptCode: conceptCode);
      if (!runtimeReady) {
        _debugLog(
          'PACK_GEN[$conceptCode] runtime_not_ready -> fallback_deterministic',
        );
        _emit(
          LocalQuestionGenerationProgress(
            active: false,
            conceptCode: conceptCode,
            status: 'failed',
            attempt: maxAttempts,
            maxAttempts: maxAttempts,
            progress: 1,
            message:
                'Model LiteRT belum siap / belum terpasang. Gunakan fallback lokal.',
          ),
        );
        return null;
      }

      final merged = <String, Map<String, dynamic>>{};
      final errors = <String>[];
      final attemptDurationsMs = <int>[];
      var lastModelId = 'gemma-4-e2b-it-litertlm';
      var totalLatencyMs = 0;
      var attemptCount = 0;

      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        attemptCount = attempt;
        final estimatedRemaining = _estimateRemainingSeconds(
          attemptDurationsMs: attemptDurationsMs,
          currentAttempt: attempt,
          maxAttempts: maxAttempts,
        );
        _emit(
          LocalQuestionGenerationProgress(
            active: true,
            conceptCode: conceptCode,
            status: 'running',
            attempt: attempt,
            maxAttempts: maxAttempts,
            progress: ((attempt - 1) / maxAttempts).clamp(0, 1).toDouble(),
            estimatedRemainingSeconds: estimatedRemaining,
            message:
                'Generate soal lokal (percobaan $attempt/$maxAttempts, timeout ${perAttemptTimeout.inSeconds}s)...',
          ),
        );

        final requestStarted = DateTime.now();
        var rawOutputPreview = '';
        var parsedOutputPreview = '';
        var attemptMessage = '';
        final requestId =
            'pretest_pack_${DateTime.now().microsecondsSinceEpoch}';
        final missingDifficulties = _missingDifficulties(merged);
        _debugLog(
          'PACK_GEN[$conceptCode] attempt=$attempt request_id=$requestId missing=${missingDifficulties.join(',')}',
        );
        try {
          final response = await runtime
              .generateJson(
                EdgeJsonGenerationRequest(
                  requestId: requestId,
                  schemaName: 'pretest_local_pack_v1',
                  temperature: 0.2,
                  maxTokens: 320,
                  system:
                      "You are WICARA's on-device adaptive pretest item generator. Return valid JSON only.",
                  user: _prompt(
                    conceptCode: conceptCode,
                    conceptTitle: conceptTitle,
                    conceptDescription: conceptDescription,
                    missingDifficulties: missingDifficulties,
                  ),
                ),
              )
              .timeout(perAttemptTimeout);

          lastModelId = _string(
            response.base.raw['modelId'],
            fallback: lastModelId,
          );
          totalLatencyMs += response.base.metrics.totalMs;

          final parsedPrimary = _parseJsonObject(response.parsedJsonString);
          final parsed = parsedPrimary.isNotEmpty
              ? parsedPrimary
              : _parseJsonObject(response.rawText);
          final partial = _normalizePackPartial(parsed);
          rawOutputPreview = _preview(response.rawText, maxLength: 2400);
          parsedOutputPreview = parsed.isEmpty
              ? ''
              : _preview(jsonEncode(parsed), maxLength: 2400);
          _debugLog(
            'PACK_GEN[$conceptCode] attempt=$attempt raw=${_preview(response.rawText)}',
          );
          _debugLog(
            'PACK_GEN[$conceptCode] attempt=$attempt parsed=${jsonEncode(parsed)}',
          );
          _debugLog(
            'PACK_GEN[$conceptCode] attempt=$attempt valid_difficulties=${partial.keys.join(',')}',
          );

          for (final entry in partial.entries) {
            merged.putIfAbsent(entry.key, () => entry.value);
          }
          if (partial.isEmpty) {
            errors.add('attempt_$attempt: no_valid_questions');
            attemptMessage =
                'Output model belum valid, coba ulang ($attempt/$maxAttempts).';
          } else {
            attemptMessage =
                'Model menghasilkan ${partial.length} level valid (${partial.keys.join(', ')}).';
          }
        } on TimeoutException {
          errors.add('attempt_$attempt: timeout');
          _debugLog(
            'PACK_GEN[$conceptCode] attempt=$attempt timeout -> cancel request_id=$requestId',
          );
          await _safeCancel(requestId);
          attemptMessage =
              'Percobaan $attempt timeout (${perAttemptTimeout.inSeconds}s). Retry...';
        } catch (error) {
          errors.add('attempt_$attempt: ${error.runtimeType}');
          _debugLog(
            'PACK_GEN[$conceptCode] attempt=$attempt exception=${error.runtimeType}',
          );
          attemptMessage =
              'Percobaan $attempt gagal: ${error.runtimeType}. Melanjutkan retry.';
        } finally {
          final duration = DateTime.now()
              .difference(requestStarted)
              .inMilliseconds;
          attemptDurationsMs.add(duration);
          _emit(
            LocalQuestionGenerationProgress(
              active: true,
              conceptCode: conceptCode,
              status: 'running',
              attempt: attempt,
              maxAttempts: maxAttempts,
              progress: (attempt / maxAttempts).clamp(0, 1).toDouble(),
              estimatedRemainingSeconds: _estimateRemainingSeconds(
                attemptDurationsMs: attemptDurationsMs,
                currentAttempt: attempt + 1,
                maxAttempts: maxAttempts,
              ),
              message: attemptMessage,
              rawOutputPreview: rawOutputPreview,
              parsedOutputPreview: parsedOutputPreview,
            ),
          );
        }

        if (merged.length == _difficulties.length) {
          break;
        }
      }

      final dropped = _missingDifficulties(merged);
      final statusLabel = merged.isEmpty
          ? 'failed'
          : (dropped.isEmpty ? 'ready' : 'partial');

      _emit(
        LocalQuestionGenerationProgress(
          active: false,
          conceptCode: conceptCode,
          status: statusLabel,
          attempt: attemptCount,
          maxAttempts: maxAttempts,
          progress: 1,
          estimatedRemainingSeconds: 0,
          message: _finalMessage(statusLabel, dropped),
        ),
      );
      _debugLog(
        'PACK_GEN[$conceptCode] status=$statusLabel attempts=$attemptCount dropped=${dropped.join(',')} errors=${errors.join('|')}',
      );

      return <String, dynamic>{
        'source': 'litert_gemma4',
        'model': lastModelId,
        'status': statusLabel,
        'attempt_count': attemptCount,
        'max_attempts': maxAttempts,
        'latency_ms': totalLatencyMs,
        'duration_ms': DateTime.now().difference(startedAt).inMilliseconds,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'dropped_difficulties': dropped,
        'errors': errors,
        'pack': merged,
      };
    } catch (_) {
      _debugLog('PACK_GEN[$conceptCode] fatal_error -> fallback_deterministic');
      _emit(
        LocalQuestionGenerationProgress(
          active: false,
          conceptCode: conceptCode,
          status: 'failed',
          attempt: maxAttempts,
          maxAttempts: maxAttempts,
          progress: 1,
          message: 'Generate soal lokal gagal. Pakai fallback template.',
        ),
      );
      return null;
    }
  }

  Future<bool> _ensureRuntimeReady({required String conceptCode}) async {
    try {
      var status = await runtime.getStatus();
      _debugLog(
        'PACK_GEN[$conceptCode] runtime_status available=${status.available} loaded=${status.loaded} default_exists=${status.defaultModelExists}',
      );
      if (status.isReady) {
        return true;
      }
      if (!status.available) {
        return false;
      }
      final modelPath = status.modelPath ?? status.defaultModelPath;
      if (!status.defaultModelExists &&
          (modelPath == null || modelPath.isEmpty)) {
        return false;
      }
      _emit(
        LocalQuestionGenerationProgress(
          active: true,
          conceptCode: conceptCode,
          status: 'initializing',
          attempt: 0,
          maxAttempts: maxAttempts,
          progress: 0.03,
          estimatedRemainingSeconds: maxAttempts * 20,
          message: 'Menyiapkan model lokal...',
        ),
      );
      status = await runtime
          .initialize(modelPath: modelPath)
          .timeout(const Duration(seconds: 120));
      _debugLog(
        'PACK_GEN[$conceptCode] runtime_initialize loaded=${status.loaded} execution=${status.executionLocation}',
      );
      return status.isReady;
    } catch (error) {
      _debugLog(
        'PACK_GEN[$conceptCode] runtime_initialize_failed error=${error.runtimeType}: $error',
      );
      return false;
    }
  }

  String _prompt({
    required String conceptCode,
    required String conceptTitle,
    required String conceptDescription,
    required List<String> missingDifficulties,
  }) {
    final compactDescription =
        _trimToNull(conceptDescription, maxLength: 180) ?? '';
    final requiredKeys = missingDifficulties.isEmpty
        ? LocalPretestQuestionGenerator._difficulties
        : missingDifficulties;
    final payload = <String, dynamic>{
      'concept_code': conceptCode,
      'title': conceptTitle,
      'description': compactDescription,
      'language': 'id',
      'must_generate_difficulties': requiredKeys,
    };
    return '''
Buat soal pretest adaptif singkat dalam Bahasa Indonesia.
Hanya keluarkan key difficulty berikut: ${requiredKeys.join(', ')}.
Setiap soal wajib punya 4 opsi unik dan 1 jawaban benar.
Hindari penjelasan panjang. Tetap ringkas.

Return valid JSON only:
{
  "<difficulty>": {
    "prompt": "...",
    "helper_text": "...",
    "options": ["...", "...", "...", "..."],
    "correct_index": 0,
    "explanation": "..."
  }
}

Context JSON:
${jsonEncode(payload)}
''';
  }

  Future<void> _safeCancel(String requestId) async {
    try {
      await runtime.cancel(requestId);
    } catch (_) {
      // ignore cancel failures, generator will continue with retry.
    }
  }
}

Map<String, Map<String, dynamic>> _normalizePackPartial(
  Map<String, dynamic> payload,
) {
  final direct = payload;
  final nested = _map(payload['questions']);
  final source = nested.isNotEmpty ? nested : direct;
  final pack = <String, Map<String, dynamic>>{};
  for (final difficulty in LocalPretestQuestionGenerator._difficulties) {
    final question = _normalizeQuestion(source[difficulty]);
    if (question != null) {
      pack[difficulty] = question;
    }
  }
  final questionRows = payload['questions'];
  if (questionRows is List) {
    for (final item in questionRows) {
      if (item is! Map) {
        continue;
      }
      final mapped = item.cast<String, dynamic>();
      final difficulty = _string(mapped['difficulty']).toLowerCase();
      if (!LocalPretestQuestionGenerator._difficulties.contains(difficulty) ||
          pack.containsKey(difficulty)) {
        continue;
      }
      final question = _normalizeQuestion(mapped);
      if (question != null) {
        pack[difficulty] = question;
      }
    }
  }
  return pack;
}

Map<String, dynamic>? _normalizeQuestion(Object? raw) {
  final node = _map(raw);
  if (node.isEmpty) {
    return null;
  }
  final prompt = _trimToNull(node['prompt'], maxLength: 260);
  final helperText = _trimToNull(node['helper_text'], maxLength: 140);
  final explanation = _trimToNull(node['explanation'], maxLength: 260);
  if (prompt == null) {
    return null;
  }
  final optionResult = _extractOptions(node['options']);
  final options = optionResult.options;
  if (options.length != 4) {
    return null;
  }
  final correctOption = _resolveCorrectOption(node, optionResult);
  if (correctOption == null) {
    return null;
  }
  return <String, dynamic>{
    'prompt': prompt,
    'helper_text': helperText ?? '',
    'options': options,
    'correct_option': correctOption,
    'explanation':
        explanation ??
        'Gunakan langkah konsep dasar untuk memeriksa pilihan yang benar.',
  };
}

_OptionParseResult _extractOptions(Object? raw) {
  final options = <String>[];
  final labelMap = <String, String>{};

  if (raw is List) {
    for (var index = 0; index < raw.length; index++) {
      final item = raw[index];
      final fallbackLabel = _labelFromIndex(index);
      if (item is Map) {
        final mapped = item.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final text = _extractOptionText(mapped);
        if (text == null) {
          continue;
        }
        final label = _string(
          mapped['label'],
          fallback: fallbackLabel,
        ).toUpperCase();
        options.add(text);
        labelMap[label] = text;
        continue;
      }
      final text = _trimToNull(item, maxLength: 90);
      if (text == null) {
        continue;
      }
      options.add(text);
      labelMap[fallbackLabel] = text;
    }
  }

  if (raw is Map) {
    var index = 0;
    for (final entry in raw.entries) {
      final label = _string(
        entry.key,
        fallback: _labelFromIndex(index),
      ).toUpperCase();
      final text = entry.value is Map
          ? _extractOptionText((entry.value as Map).cast<String, dynamic>())
          : _trimToNull(entry.value, maxLength: 90);
      if (text == null) {
        index += 1;
        continue;
      }
      options.add(text);
      labelMap[label] = text;
      index += 1;
    }
  }

  if (options.length < 4) {
    return const _OptionParseResult(options: <String>[], labelMap: {});
  }
  final first4 = options.take(4).toList(growable: false);
  final first4Set = first4.toSet();
  final first4Labels = <String, String>{};
  for (final entry in labelMap.entries) {
    if (first4Set.contains(entry.value) &&
        !first4Labels.containsKey(entry.key)) {
      first4Labels[entry.key] = entry.value;
    }
  }
  for (var i = 0; i < first4.length; i++) {
    first4Labels.putIfAbsent(_labelFromIndex(i), () => first4[i]);
  }
  return _OptionParseResult(options: first4, labelMap: first4Labels);
}

String? _resolveCorrectOption(
  Map<String, dynamic> question,
  _OptionParseResult optionResult,
) {
  final options = optionResult.options;
  final labelMap = optionResult.labelMap;
  final indexRaw = question['correct_index'];
  final index = switch (indexRaw) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };
  if (index != null) {
    if (index >= 0 && index < options.length) {
      return options[index];
    }
    final oneBased = index - 1;
    if (oneBased >= 0 && oneBased < options.length) {
      return options[oneBased];
    }
  }
  final direct = _trimToNull(question['correct_option'], maxLength: 90);
  if (direct != null) {
    if (options.contains(direct)) {
      return direct;
    }
    final byLabel = labelMap[direct.toUpperCase()];
    if (byLabel != null) {
      return byLabel;
    }
  }
  final answerLabel = _trimToNull(question['correct_label'], maxLength: 4);
  if (answerLabel != null) {
    final byLabel = labelMap[answerLabel.toUpperCase()];
    if (byLabel != null) {
      return byLabel;
    }
  }
  final answerKey = _trimToNull(question['answer_key'], maxLength: 4);
  if (answerKey != null) {
    final byLabel = labelMap[answerKey.toUpperCase()];
    if (byLabel != null) {
      return byLabel;
    }
  }
  final answer = _trimToNull(question['answer'], maxLength: 90);
  if (answer != null) {
    if (options.contains(answer)) {
      return answer;
    }
    final byLabel = labelMap[answer.toUpperCase()];
    if (byLabel != null) {
      return byLabel;
    }
  }
  final optionsRaw = question['options'];
  if (optionsRaw is List) {
    for (final item in optionsRaw) {
      if (item is! Map || item['is_correct'] != true) {
        continue;
      }
      final mapped = item.cast<String, dynamic>();
      final text = _extractOptionText(mapped);
      if (text != null && options.contains(text)) {
        return text;
      }
      final label = _trimToNull(mapped['label'], maxLength: 4);
      if (label != null && labelMap.containsKey(label.toUpperCase())) {
        return labelMap[label.toUpperCase()];
      }
    }
  }
  return null;
}

Map<String, dynamic> _parseJsonObject(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const <String, dynamic>{};
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
  } catch (_) {
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(trimmed.substring(start, end + 1));
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (_) {
        return const <String, dynamic>{};
      }
    }
  }
  return const <String, dynamic>{};
}

List<String> _missingDifficulties(Map<String, Map<String, dynamic>> pack) {
  return LocalPretestQuestionGenerator._difficulties
      .where((difficulty) => !pack.containsKey(difficulty))
      .toList(growable: false);
}

String _labelFromIndex(int index) {
  return switch (index) {
    0 => 'A',
    1 => 'B',
    2 => 'C',
    3 => 'D',
    _ => 'X',
  };
}

String? _extractOptionText(Map<String, dynamic> item) {
  return _trimToNull(
    item['text'] ?? item['option'] ?? item['value'] ?? item['content'],
    maxLength: 90,
  );
}

int _estimateRemainingSeconds({
  required List<int> attemptDurationsMs,
  required int currentAttempt,
  required int maxAttempts,
}) {
  final remainingAttempts = maxAttempts - currentAttempt + 1;
  if (remainingAttempts <= 0) {
    return 0;
  }
  if (attemptDurationsMs.isEmpty) {
    return remainingAttempts * 20;
  }
  final avgMs =
      attemptDurationsMs.reduce((left, right) => left + right) /
      attemptDurationsMs.length;
  return ((avgMs * remainingAttempts) / 1000).ceil();
}

String _finalMessage(String status, List<String> droppedDifficulties) {
  return switch (status) {
    'ready' => 'Generate soal selesai.',
    'partial' =>
      'Sebagian soal valid. Drop: ${droppedDifficulties.join(', ')}.',
    _ => 'Generate soal gagal. Gunakan fallback template.',
  };
}

void _emit(LocalQuestionGenerationProgress progress) {
  final controller = LocalPretestQuestionGenerator._progressController;
  if (!controller.isClosed) {
    controller.add(progress);
  }
}

class _OptionParseResult {
  const _OptionParseResult({required this.options, required this.labelMap});

  final List<String> options;
  final Map<String, String> labelMap;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

String? _trimToNull(Object? value, {required int maxLength}) {
  final text = _string(value);
  if (text.isEmpty) {
    return null;
  }
  if (text.length <= maxLength) {
    return text;
  }
  return text.substring(0, maxLength).trimRight();
}

String _string(Object? value, {String fallback = ''}) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

String _preview(String text, {int maxLength = 1200}) {
  final normalized = text.replaceAll('\n', r'\n');
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return '${normalized.substring(0, maxLength)}...';
}

void _debugLog(String message) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(message);
}
