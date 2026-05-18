import 'dart:convert';

import '../../edge_ai/data/litert_gemma_runtime.dart';
import '../../edge_ai/domain/edge_ai_models.dart';
import '../../edge_ai/domain/edge_ai_runtime.dart';

class LocalPretestDiagnosisService {
  const LocalPretestDiagnosisService({this.runtime = defaultEdgeAiRuntime});

  final EdgeAiRuntime runtime;

  static const pathOptions = <String>[
    'review_only',
    'target_reinforcement',
    'target_from_basics',
    'target_intro',
    'repair_prerequisites',
    'full_foundation_path',
  ];

  Future<Map<String, dynamic>> finalize({
    required Map<String, dynamic> graphScope,
    required Map<String, dynamic> decisionState,
    required String stopReason,
    Map<String, dynamic>? runtimeAudit,
    bool includeNarrative = true,
  }) async {
    final diagnosis = deterministicDiagnosis(
      graphScope: graphScope,
      decisionState: decisionState,
      stopReason: stopReason,
      runtimeAudit: runtimeAudit,
    );
    if (!includeNarrative) {
      return diagnosis;
    }
    return enrichNarrative(diagnosis);
  }

  Map<String, dynamic> deterministicDiagnosis({
    required Map<String, dynamic> graphScope,
    required Map<String, dynamic> decisionState,
    required String stopReason,
    Map<String, dynamic>? runtimeAudit,
  }) {
    return _deterministicDiagnosis(
      graphScope: graphScope,
      decisionState: decisionState,
      stopReason: stopReason,
      runtimeAudit: runtimeAudit,
    );
  }

  Future<Map<String, dynamic>> enrichNarrative(
    Map<String, dynamic> diagnosis,
  ) async {
    final enriched = <String, dynamic>{...diagnosis};
    final llmNarrative = await _synthesizeNarrative(diagnosis);
    if (llmNarrative == null) {
      return enriched;
    }

    if (llmNarrative.summary != null && llmNarrative.summary!.isNotEmpty) {
      enriched['summary'] = llmNarrative.summary;
    }
    final analysis =
        (enriched['analysis'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    if (llmNarrative.strengths.isNotEmpty) {
      analysis['strengths'] = llmNarrative.strengths;
    }
    if (llmNarrative.gaps.isNotEmpty) {
      analysis['gaps'] = llmNarrative.gaps;
    }
    if (llmNarrative.evidenceNotes.isNotEmpty) {
      analysis['evidence_notes'] = llmNarrative.evidenceNotes;
    }
    if (llmNarrative.recommendedFocus.isNotEmpty) {
      analysis['recommended_focus'] = llmNarrative.recommendedFocus;
    }
    enriched['analysis'] = analysis;

    final audit =
        (enriched['runtime_audit'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    enriched['runtime_audit'] = <String, dynamic>{
      ...audit,
      ...llmNarrative.auditPatch,
    };
    return enriched;
  }

  Map<String, dynamic> _deterministicDiagnosis({
    required Map<String, dynamic> graphScope,
    required Map<String, dynamic> decisionState,
    required String stopReason,
    Map<String, dynamic>? runtimeAudit,
  }) {
    final nodes = _diagnosisNodes(
      graphScope: graphScope,
      decisionState: decisionState,
    );
    final target = _firstWhereOrNull(
      nodes,
      (node) => _string(node['role']) == 'target',
    );
    final recommendedPath = _recommendedPath(
      nodes: nodes,
      stopReason: stopReason,
    );
    final analysis = _analysisReport(
      nodes: nodes,
      target: target,
      stopReason: stopReason,
      recommendedPath: recommendedPath,
    );
    return <String, dynamic>{
      'summary': _summary(target: target, recommendedPath: recommendedPath),
      'target': target,
      'nodes': nodes,
      'analysis': analysis,
      'stop_reason': stopReason,
      'score_percent': ((target?['mastery_score'] as num? ?? 0) * 100).round(),
      'confidence_percent': ((target?['confidence'] as num? ?? 0) * 100)
          .round(),
      'overall_mastery_percent': _int(analysis['overall_mastery_percent']),
      'recommended_path': recommendedPath,
      'path_options': pathOptions,
      'runtime_audit':
          runtimeAudit ??
          const <String, dynamic>{
            'primary_ai_runtime': 'deterministic_local_heuristic',
            'cloud_calls_used': 0,
            'execution_location': 'device',
          },
    };
  }

  Future<_DiagnosisNarrative?> _synthesizeNarrative(
    Map<String, dynamic> diagnosis,
  ) async {
    try {
      final status = await runtime.getStatus();
      if (!status.isReady) {
        return null;
      }
      final response = await runtime.generateJson(
        EdgeJsonGenerationRequest(
          requestId:
              'pretest_diagnosis_${DateTime.now().microsecondsSinceEpoch}',
          schemaName: 'pretest_diagnosis_report_v1',
          system:
              'Kamu adalah pelapor diagnostik pretest WICARA on-device. Tulis narasi spesifik berdasarkan soal & jawaban siswa yang diberikan, bukan generalisasi. Output JSON valid saja.',
          user: _diagnosisPrompt(diagnosis),
        ),
      );
      final parsedPrimary = _parseJsonObject(response.parsedJsonString);
      final parsed = parsedPrimary.isNotEmpty
          ? parsedPrimary
          : _parseJsonObject(response.rawText);
      final summary = _trimToNull(parsed['summary'], maxLength: 600);
      final strengths = _sanitizeNarrativeList(parsed['strengths']);
      final gaps = _sanitizeNarrativeList(parsed['gaps']);
      final evidenceNotes = _sanitizeNarrativeList(parsed['evidence_notes']);
      final recommendedFocus = _sanitizeNarrativeList(
        parsed['recommended_focus'],
      );

      final hasNarrative =
          summary != null ||
          strengths.isNotEmpty ||
          gaps.isNotEmpty ||
          evidenceNotes.isNotEmpty ||
          recommendedFocus.isNotEmpty;
      if (!hasNarrative) {
        return null;
      }

      return _DiagnosisNarrative(
        summary: summary,
        strengths: strengths,
        gaps: gaps,
        evidenceNotes: evidenceNotes,
        recommendedFocus: recommendedFocus,
        auditPatch: <String, dynamic>{
          'diagnosis_report_source': 'litert_gemma4',
          'diagnosis_report_runtime': response.base.runtime,
          'diagnosis_report_model': _string(
            response.base.raw['modelId'],
            fallback: 'gemma-4-e2b-it-litertlm',
          ),
          'diagnosis_report_execution_location':
              response.base.executionLocation,
          'diagnosis_report_latency_ms': response.base.metrics.totalMs,
        },
      );
    } catch (_) {
      return null;
    }
  }

  String _diagnosisPrompt(Map<String, dynamic> diagnosis) {
    final target = _map(diagnosis['target']);
    final testedNodes = ((diagnosis['nodes'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .where((node) => _string(node['status']) != 'not_tested')
        .toList(growable: false);
    final nodeContext = testedNodes
        .map((node) {
          final attempts =
              (node['evidence'] as List?)
                  ?.whereType<Map>()
                  .map((item) => item.cast<String, dynamic>())
                  .toList(growable: false) ??
              const <Map<String, dynamic>>[];
          final correctQuestions = <Map<String, dynamic>>[];
          final wrongQuestions = <Map<String, dynamic>>[];
          for (var index = 0; index < attempts.length; index++) {
            final attempt = attempts[index];
            final stem = _string(attempt['question_stem']);
            final selectedOption = _string(attempt['selected_option_text']);
            final correctOption = _string(attempt['correct_option_text']);
            final typedReasoning = _string(attempt['typed_reasoning']);
            final expectedReasoning = _string(attempt['expected_reasoning']);
            final canvasUsed = attempt['canvas_used'] == true;
            final strokeCount = _int(attempt['canvas_stroke_count']);
            if (stem.isEmpty) {
              continue;
            }
            if (attempt['is_correct'] == true) {
              correctQuestions.add(<String, dynamic>{
                'index': index + 1,
                'stem': stem,
                'siswa_pilih': selectedOption,
                'reasoning_siswa': typedReasoning,
                'siswa_pakai_canvas': canvasUsed,
                if (strokeCount > 0) 'stroke_count': strokeCount,
              });
              continue;
            }
            wrongQuestions.add(<String, dynamic>{
              'index': index + 1,
              'stem': stem,
              'jawaban_benar': correctOption,
              'siswa_pilih': selectedOption,
              'reasoning_siswa': typedReasoning,
              'expected_reasoning': expectedReasoning,
              'siswa_pakai_canvas': canvasUsed,
              if (strokeCount > 0) 'stroke_count': strokeCount,
            });
          }
          return <String, dynamic>{
            'concept': _string(node['title']),
            'role': _string(node['role']),
            'status_deterministic': _string(node['status']),
            'soal_benar': correctQuestions,
            'soal_salah': wrongQuestions,
          };
        })
        .toList(growable: false);

    final payload = <String, dynamic>{
      'target_concept': _string(target['title']),
      'recommended_path': _string(diagnosis['recommended_path']),
      'stop_reason': _string(diagnosis['stop_reason']),
      'score_percent': _int(diagnosis['score_percent']),
      'confidence_percent': _int(diagnosis['confidence_percent']),
      'nodes': nodeContext,
    };

    return '''
Tulis diagnosa pretest siswa. Bukan ringkasan, bukan motivasi - DIAGNOSA.
Gunakan HANYA data di "nodes" di bawah.
Bahasa: santai, langsung ke siswa ("Kamu ..."), tanpa jargon.
Jika siswa_pakai_canvas=true, sebutkan bahwa siswa menulis/mencoret saat mengerjakan (sinyal effort).

Aturan menulis tiap field:
- "summary" (2-3 kalimat, kira-kira 80-120 kata):
  sebut konsep target spesifik + 1 hal yang sudah dipahami (rujuk soal benar) + 1 hal yang masih kurang (rujuk soal salah).
  Hindari kalimat motivasi ("semangat", "kamu pasti bisa").
- "strengths" (1-3 poin, tiap poin 1-2 kalimat penuh):
  format: "Di soal [inti pertanyaan], kamu [langkah yang benar]."
  Wajib rujuk reasoning_siswa jika tersedia.
- "gaps" (1-3 poin, tiap poin 2-3 kalimat penuh):
  format: "Di soal [inti pertanyaan], kamu pilih [siswa_pilih] padahal benar [jawaban_benar]. [Kontraskan reasoning_siswa vs expected_reasoning atau jelaskan salahnya]."
- "evidence_notes" (0-2 poin):
  tulis pola lintas-soal yang konkret (mis. reasoning kosong di soal sulit, effort canvas muncul, dst).
- "recommended_focus" (1-3 poin):
  latihan konkret yang langsung memperbaiki gap (sebut sub-topik latihan, bukan "latihan lagi").

DILARANG: kalimat generik ("perlu latihan lagi", "konsep belum kuat").
Selalu sebut konten soal dari data.

Output JSON valid saja:
{
  "summary": "...",
  "strengths": ["..."],
  "gaps": ["..."],
  "evidence_notes": ["..."],
  "recommended_focus": ["..."]
}

nodes:
${jsonEncode(payload)}
''';
  }

  List<Map<String, dynamic>> _diagnosisNodes({
    required Map<String, dynamic> graphScope,
    required Map<String, dynamic> decisionState,
  }) {
    final nodeResults =
        (decisionState['node_results'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rows = <Map<String, dynamic>>[];
    for (final node in (graphScope['nodes'] as List?) ?? const <dynamic>[]) {
      if (node is! Map) {
        continue;
      }
      final mapped = node.cast<String, dynamic>();
      final conceptCode = _string(mapped['concept_code']);
      final result =
          (nodeResults[conceptCode] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final status = _string(result['status'], fallback: 'not_tested');
      final attempts =
          (result['attempts'] as List?)
              ?.whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList(growable: false) ??
          const <Map<String, dynamic>>[];
      final evidenceSummary = _evidenceSummary(attempts);
      rows.add(<String, dynamic>{
        'concept_id': mapped['concept_id'],
        'concept_code': conceptCode,
        'title': mapped['title'],
        'role': mapped['role'],
        'depth': mapped['depth'],
        'status': status,
        'mastery_score': _mastery(status),
        'confidence': _nodeConfidence(attempts),
        'difficulty_reached': _difficultyReached(result),
        'evidence': attempts,
        'evidence_summary': evidenceSummary,
      });
    }
    return rows;
  }

  String _recommendedPath({
    required List<Map<String, dynamic>> nodes,
    required String stopReason,
  }) {
    if (stopReason == 'target_ready') {
      return 'review_only';
    }
    if (stopReason == 'target_reinforcement') {
      return 'target_reinforcement';
    }
    final target = _firstWhereOrNull(
      nodes,
      (node) => _string(node['role']) == 'target',
    );
    final targetStatus = _string(target?['status']);
    final prerequisiteNodes = nodes
        .where((node) {
          return _string(node['role']) == 'prerequisite' &&
              _string(node['status']) != 'not_tested';
        })
        .toList(growable: false);
    final hasGap = prerequisiteNodes.any(
      (node) => _string(node['status']) == 'gap',
    );
    if (hasGap) {
      final hasDeepGap = prerequisiteNodes.any(
        (node) => _string(node['status']) == 'gap' && _int(node['depth']) >= 2,
      );
      return hasDeepGap ? 'full_foundation_path' : 'repair_prerequisites';
    }
    final hasFragile = prerequisiteNodes.any((node) {
      final status = _string(node['status']);
      return status == 'fragile' || status == 'partial';
    });
    if (hasFragile) {
      return 'repair_prerequisites';
    }
    if (targetStatus == 'fragile') {
      return 'target_from_basics';
    }
    if (targetStatus == 'gap') {
      return 'target_intro';
    }
    return 'target_reinforcement';
  }

  Map<String, dynamic> _analysisReport({
    required List<Map<String, dynamic>> nodes,
    required Map<String, dynamic>? target,
    required String stopReason,
    required String recommendedPath,
  }) {
    final testedNodes = nodes
        .where((node) {
          return _string(node['status']) != 'not_tested';
        })
        .toList(growable: false);
    final strengths = testedNodes
        .where((node) {
          final status = _string(node['status']);
          return status == 'ready' || status == 'probably_ready';
        })
        .map((node) => '${_string(node['title'])} terlihat siap.')
        .toList(growable: false);
    final gaps = testedNodes
        .where((node) {
          const gapStatuses = <String>{
            'gap',
            'fragile',
            'partial',
            'probably_gap',
          };
          return gapStatuses.contains(_string(node['status']));
        })
        .map(
          (node) =>
              '${_string(node['title'])} masih ${_string(node['status'])}.',
        )
        .toList(growable: false);
    final evidenceNotes = <String>[];
    for (final node in testedNodes) {
      final summary =
          (node['evidence_summary'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final title = _string(node['title']);
      if (summary['misconception_detected'] == true) {
        evidenceNotes.add(
          '$title: reasoning menunjukkan miskonsepsi, bukan sekadar salah pilih.',
        );
        continue;
      }
      if (summary['careless_mistake_possible'] == true) {
        evidenceNotes.add(
          '$title: jawaban MCQ salah, tapi reasoning cukup kuat; mungkin careless.',
        );
        continue;
      }
      final reasoningQuality = _string(summary['reasoning_quality']);
      if (reasoningQuality == 'not_provided') {
        evidenceNotes.add(
          '$title: tidak ada penjelasan langkah, confidence diagnosis lebih rendah.',
        );
      } else if (reasoningQuality == 'weak') {
        evidenceNotes.add(
          '$title: langkah pengerjaan masih lemah atau belum nyambung.',
        );
      }
    }
    final masteryValues = testedNodes
        .map((node) => _double(node['mastery_score']))
        .toList(growable: false);
    final avgMastery = masteryValues.isEmpty
        ? 0
        : ((masteryValues.reduce((left, right) => left + right) /
                      masteryValues.length) *
                  100)
              .round();
    return <String, dynamic>{
      'target_status': target == null ? 'unknown' : _string(target['status']),
      'stop_reason': stopReason,
      'overall_mastery_percent': avgMastery,
      'strengths': strengths,
      'gaps': gaps,
      'evidence_notes': evidenceNotes,
      'recommended_focus': _recommendedFocus(recommendedPath),
    };
  }

  Map<String, dynamic> _evidenceSummary(List<Map<String, dynamic>> attempts) {
    if (attempts.isEmpty) {
      return <String, dynamic>{
        'attempt_count': 0,
        'correct_count': 0,
        'avg_evidence_score': 0.0,
        'avg_reasoning_score': null,
        'reasoning_quality': 'not_provided',
        'diagnostic_signals': const <String>[],
        'answered_difficulties': const <String>[],
        'careless_mistake_possible': false,
        'misconception_detected': false,
      };
    }
    final evidenceValues = attempts
        .map((item) => _double(item['evidence_score']))
        .toList(growable: false);
    final reasoningValues = attempts
        .where((item) => item['reasoning_score'] != null)
        .map((item) => _double(item['reasoning_score']))
        .toList(growable: false);
    final signals = attempts
        .map((item) => _string(item['diagnostic_signal']))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final difficulties = attempts
        .map((item) => _string(item['difficulty']))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final avgEvidence =
        evidenceValues.reduce((left, right) => left + right) /
        evidenceValues.length;
    final avgReasoning = reasoningValues.isEmpty
        ? null
        : reasoningValues.reduce((left, right) => left + right) /
              reasoningValues.length;
    return <String, dynamic>{
      'attempt_count': attempts.length,
      'correct_count': attempts
          .where((item) => item['is_correct'] == true)
          .length,
      'avg_evidence_score': _round4(avgEvidence),
      'avg_reasoning_score': avgReasoning == null
          ? null
          : _round4(avgReasoning),
      'reasoning_quality': _reasoningQuality(avgReasoning),
      'diagnostic_signals': signals,
      'answered_difficulties': difficulties,
      'careless_mistake_possible': signals.contains(
        'possible_careless_mistake',
      ),
      'misconception_detected': signals.contains('misconception_detected'),
    };
  }

  String _summary({
    required Map<String, dynamic>? target,
    required String recommendedPath,
  }) {
    final title = _string(target?['title'], fallback: 'Target concept');
    return switch (recommendedPath) {
      'review_only' => 'Kamu sudah siap di $title; cukup review singkat.',
      'target_reinforcement' =>
        'Kamu paham dasar $title, tapi perlu latihan versi lebih sulit.',
      'target_from_basics' =>
        '$title mulai terbentuk, tapi belum stabil di level sedang.',
      'target_intro' =>
        '$title masih menjadi gap utama; mulai dari pengantar konsep.',
      'repair_prerequisites' =>
        'Beberapa prasyarat $title perlu diperkuat dulu.',
      'full_foundation_path' =>
        'Fondasi sebelum $title perlu dibangun ulang dari prasyarat terdalam.',
      _ => 'Diagnosis $title selesai.',
    };
  }

  List<String> _recommendedFocus(String recommendedPath) {
    return switch (recommendedPath) {
      'review_only' => const <String>[
        'Ringkas ulang konsep target',
        'Kerjakan 1-2 soal penguatan ringan',
      ],
      'target_reinforcement' => const <String>[
        'Latihan menengah menuju sulit pada target',
        'Perbaiki kualitas reasoning tertulis',
      ],
      'target_from_basics' => const <String>[
        'Ulang fondasi langsung sebelum target',
        'Latihan bertahap easy -> medium',
      ],
      'target_intro' => const <String>[
        'Mulai dari pengantar konsep target',
        'Gunakan contoh konkret sebelum simbolik',
      ],
      'repair_prerequisites' => const <String>[
        'Perkuat node prasyarat yang fragile/gap',
        'Kembali ke target setelah prasyarat stabil',
      ],
      'full_foundation_path' => const <String>[
        'Bangun ulang dari prasyarat terdalam',
        'Naik bertahap berdasarkan depth graph',
      ],
      _ => const <String>[],
    };
  }
}

class _DiagnosisNarrative {
  const _DiagnosisNarrative({
    required this.summary,
    required this.strengths,
    required this.gaps,
    required this.evidenceNotes,
    required this.recommendedFocus,
    required this.auditPatch,
  });

  final String? summary;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> evidenceNotes;
  final List<String> recommendedFocus;
  final Map<String, dynamic> auditPatch;
}

String localMasteryStatusFromDiagnosisNodeStatus(String status) {
  return switch (status) {
    'ready' || 'probably_ready' => 'ready',
    'gap' || 'probably_gap' => 'gap',
    'partial' || 'fragile' => 'review_due',
    _ => 'review_due',
  };
}

double _mastery(String status) {
  return switch (status) {
    'ready' => 0.9,
    'partial' => 0.62,
    'fragile' => 0.45,
    'gap' => 0.18,
    'probably_ready' => 0.72,
    'probably_gap' => 0.28,
    _ => 0.0,
  };
}

double _nodeConfidence(List<Map<String, dynamic>> attempts) {
  if (attempts.isEmpty) {
    return 0;
  }
  final values = attempts
      .map((item) => _double(item['confidence']))
      .toList(growable: false);
  return _round4(values.reduce((left, right) => left + right) / values.length);
}

String? _difficultyReached(Map<String, dynamic> result) {
  for (final difficulty in const <String>['hard', 'medium', 'easy']) {
    final value = _string(result[difficulty]);
    if (value == 'correct' || value == 'wrong') {
      return difficulty;
    }
  }
  return null;
}

String _reasoningQuality(double? score) {
  if (score == null) {
    return 'not_provided';
  }
  if (score >= 0.75) {
    return 'strong';
  }
  if (score >= 0.45) {
    return 'partial';
  }
  return 'weak';
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

List<String> _sanitizeNarrativeList(
  Object? value, {
  int maxLength = 320,
  int maxItems = 5,
}) {
  if (value is! List) {
    return const <String>[];
  }
  final unique = <String>{};
  final result = <String>[];
  for (final item in value) {
    final normalized = _trimToNull(item, maxLength: maxLength);
    if (normalized == null || unique.contains(normalized)) {
      continue;
    }
    unique.add(normalized);
    result.add(normalized);
    if (result.length >= maxItems) {
      break;
    }
  }
  return result;
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

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

Map<String, dynamic>? _firstWhereOrNull(
  List<Map<String, dynamic>> items,
  bool Function(Map<String, dynamic>) test,
) {
  for (final item in items) {
    if (test(item)) {
      return item;
    }
  }
  return null;
}

double _round4(double value) => (value * 10000).round() / 10000;

double _double(Object? value, {double fallback = 0}) {
  return switch (value) {
    final int number => number.toDouble(),
    final double number => number,
    final String text => double.tryParse(text) ?? fallback,
    _ => fallback,
  };
}

int _int(Object? value, {int fallback = 0}) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text) ?? fallback,
    _ => fallback,
  };
}

String _string(Object? value, {String fallback = ''}) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}
