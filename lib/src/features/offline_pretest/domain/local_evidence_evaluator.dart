import 'dart:convert';

import '../../edge_ai/data/litert_gemma_runtime.dart';
import '../../edge_ai/domain/edge_ai_models.dart';
import '../../edge_ai/domain/edge_ai_runtime.dart';
import 'local_pretest_models.dart';

class LocalEvidenceEvaluator {
  const LocalEvidenceEvaluator({this.runtime = defaultEdgeAiRuntime});

  final EdgeAiRuntime runtime;

  static const _reasoningSignals = <String>{
    'valid_reasoning',
    'partial_reasoning',
    'thin_reasoning',
    'possible_careless_mistake',
    'misconception',
    'unrelated',
  };

  Future<LocalPretestEvaluation> evaluate({
    required LocalPretestQuestion question,
    required LocalPretestOption selectedOption,
    required String typedReasoning,
    required bool usedCanvas,
    required Set<String> knownConceptCodes,
  }) async {
    final isCorrect = selectedOption.isCorrect;
    final answerScore = isCorrect ? 1.0 : 0.0;
    final reasoning = await _evaluateReasoning(
      question: question,
      selectedOption: selectedOption,
      typedReasoning: typedReasoning,
      isCorrect: isCorrect,
      knownConceptCodes: knownConceptCodes,
    );
    final canvasStatus = usedCanvas ? 'stored_not_evaluated' : null;
    final canvasScore = null;
    final evidenceScore = _evidenceScore(
      answerScore: answerScore,
      reasoningScore: reasoning.reasoningScore,
      canvasScore: canvasScore,
    );
    final diagnosticSignal = _diagnosticSignal(
      isCorrect: isCorrect,
      reasoningScore: reasoning.reasoningScore,
      canvasScore: canvasScore,
      reasoningSignal: reasoning.reasoningSignal,
    );
    final confidence = _confidence(
      isCorrect: isCorrect,
      evidenceScore: evidenceScore,
      reasoningScore: reasoning.reasoningScore,
      canvasScore: canvasScore,
    );

    return LocalPretestEvaluation(
      isCorrect: isCorrect,
      answerScore: answerScore,
      reasoningScore: reasoning.reasoningScore,
      reasoningSignal: reasoning.reasoningSignal,
      reasoningFeedback: reasoning.feedback,
      reasoningEvaluationSource: reasoning.source,
      canvasScore: canvasScore,
      evidenceScore: evidenceScore,
      confidence: confidence,
      diagnosticSignal: diagnosticSignal,
      canvasStatus: canvasStatus,
      prerequisiteGapCandidate: reasoning.prerequisiteGapCandidate,
    );
  }

  Future<_ReasoningResult> _evaluateReasoning({
    required LocalPretestQuestion question,
    required LocalPretestOption selectedOption,
    required String typedReasoning,
    required bool isCorrect,
    required Set<String> knownConceptCodes,
  }) async {
    final text = typedReasoning.trim();
    if (text.isEmpty) {
      return const _ReasoningResult(
        reasoningScore: null,
        reasoningSignal: 'not_provided',
        feedback: '',
        source: 'none',
        prerequisiteGapCandidate: null,
      );
    }
    final aiResult = await _evaluateWithLiteRt(
      question: question,
      selectedOption: selectedOption,
      typedReasoning: text,
      isCorrect: isCorrect,
      knownConceptCodes: knownConceptCodes,
    );
    if (aiResult != null) {
      return aiResult;
    }
    return _heuristicReasoning(
      typedReasoning: text,
      expectedReasoning: question.expectedReasoning,
      isCorrect: isCorrect,
    );
  }

  Future<_ReasoningResult?> _evaluateWithLiteRt({
    required LocalPretestQuestion question,
    required LocalPretestOption selectedOption,
    required String typedReasoning,
    required bool isCorrect,
    required Set<String> knownConceptCodes,
  }) async {
    try {
      final status = await runtime.getStatus();
      if (!status.isReady) {
        return null;
      }
      final response = await runtime.generateJson(
        EdgeJsonGenerationRequest(
          requestId: 'pretest_reasoning_${DateTime.now().microsecondsSinceEpoch}',
          schemaName: 'pretest_reasoning_v1',
          system:
              "You are WICARA's on-device assessment evaluator. Return valid JSON only. Do not reveal answers. Grade learner reasoning while keeping MCQ correctness as the anchor.",
          user: _liteRtPrompt(
            question: question,
            selectedOption: selectedOption,
            typedReasoning: typedReasoning,
            isCorrect: isCorrect,
          ),
        ),
      );
      final parsed = _parseJsonObject(response.parsedJsonString);
      final score = _boundedScore(parsed['reasoning_score']);
      if (score == null) {
        return null;
      }
      final signal = _string(parsed['reasoning_signal']);
      if (!_reasoningSignals.contains(signal)) {
        return null;
      }
      final candidate = _nullableString(parsed['prerequisite_gap_candidate']);
      final validatedCandidate =
          candidate != null && knownConceptCodes.contains(candidate)
          ? candidate
          : null;
      return _ReasoningResult(
        reasoningScore: score,
        reasoningSignal: signal,
        feedback: _string(parsed['feedback']),
        source: '${response.base.runtime}:litert_json',
        prerequisiteGapCandidate: validatedCandidate,
      );
    } catch (_) {
      return null;
    }
  }

  _ReasoningResult _heuristicReasoning({
    required String typedReasoning,
    required String expectedReasoning,
    required bool isCorrect,
  }) {
    final wordCount = typedReasoning.split(RegExp(r'\s+')).length;
    if (isCorrect) {
      final score = wordCount >= 3 ? 0.85 : 0.65;
      return _ReasoningResult(
        reasoningScore: score,
        reasoningSignal: score >= 0.75 ? 'valid_reasoning' : 'thin_reasoning',
        feedback:
            'Reasoning dinilai dengan heuristic lokal karena evaluasi LiteRT belum tersedia.',
        source: 'heuristic',
        prerequisiteGapCandidate: null,
      );
    }

    final userTerms = _terms(typedReasoning);
    final expectedTerms = _terms(expectedReasoning);
    final overlap = userTerms.intersection(expectedTerms).length;
    if (overlap >= 2 || wordCount >= 8) {
      return const _ReasoningResult(
        reasoningScore: 0.78,
        reasoningSignal: 'possible_careless_mistake',
        feedback: 'MCQ salah, tapi ada sinyal penalaran parsial yang cukup kuat.',
        source: 'heuristic',
        prerequisiteGapCandidate: null,
      );
    }
    if (overlap == 1) {
      return const _ReasoningResult(
        reasoningScore: 0.45,
        reasoningSignal: 'partial_reasoning',
        feedback: 'Penalaran parsial, tetapi belum cukup untuk mendukung jawaban.',
        source: 'heuristic',
        prerequisiteGapCandidate: null,
      );
    }
    return const _ReasoningResult(
      reasoningScore: 0.2,
      reasoningSignal: 'unrelated',
      feedback: 'Penalaran belum terkait langsung dengan konsep inti soal.',
      source: 'heuristic',
      prerequisiteGapCandidate: null,
    );
  }

  static double _evidenceScore({
    required double answerScore,
    required double? reasoningScore,
    required double? canvasScore,
  }) {
    final hasReasoning = reasoningScore != null;
    final hasCanvas = canvasScore != null;
    if (hasReasoning && hasCanvas) {
      return _round4(
        (0.60 * answerScore) +
            (0.25 * reasoningScore) +
            (0.15 * canvasScore),
      );
    }
    if (hasReasoning) {
      return _round4((0.70 * answerScore) + (0.30 * reasoningScore));
    }
    if (hasCanvas) {
      return _round4((0.70 * answerScore) + (0.30 * canvasScore));
    }
    return answerScore;
  }

  static String _diagnosticSignal({
    required bool isCorrect,
    required double? reasoningScore,
    required double? canvasScore,
    required String reasoningSignal,
  }) {
    final strongReasoning = reasoningScore != null && reasoningScore >= 0.75;
    final strongCanvas = canvasScore != null && canvasScore >= 0.75;
    if (!isCorrect && reasoningSignal == 'misconception') {
      return 'misconception_detected';
    }
    if (!isCorrect && reasoningSignal == 'possible_careless_mistake') {
      return 'possible_careless_mistake';
    }
    if (isCorrect && (strongReasoning || strongCanvas)) {
      return 'correct_with_evidence';
    }
    if (isCorrect) {
      return reasoningScore == null && canvasScore == null
          ? 'correct_mcq_only'
          : 'correct_low_evidence';
    }
    if (strongReasoning || strongCanvas) {
      return 'possible_careless_mistake';
    }
    return 'concept_gap_likely';
  }

  static double _confidence({
    required bool isCorrect,
    required double evidenceScore,
    required double? reasoningScore,
    required double? canvasScore,
  }) {
    if (isCorrect && (reasoningScore != null || canvasScore != null)) {
      return _round4((evidenceScore + 0.08).clamp(0.75, 0.92).toDouble());
    }
    if (isCorrect) {
      return 0.68;
    }
    if (reasoningScore != null && reasoningScore >= 0.75) {
      return 0.56;
    }
    return 0.82;
  }

  static Map<String, dynamic> _parseJsonObject(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const {};
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
          return const {};
        }
      }
    }
    return const {};
  }

  static Set<String> _terms(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((item) => item.length >= 2)
        .toSet();
  }

  static String _liteRtPrompt({
    required LocalPretestQuestion question,
    required LocalPretestOption selectedOption,
    required String typedReasoning,
    required bool isCorrect,
  }) {
    final correct = question.options.firstWhere(
      (option) => option.isCorrect,
      orElse: () => question.options.first,
    );
    return '''
Evaluate the learner's written reasoning for an adaptive pretest answer.

Return valid JSON only:
{
  "reasoning_score": 0.0,
  "reasoning_signal": "valid_reasoning|partial_reasoning|thin_reasoning|possible_careless_mistake|misconception|unrelated",
  "prerequisite_gap_candidate": "concept_code|null",
  "feedback": "short private diagnostic note"
}

Question prompt:
${question.prompt}

Selected option:
${selectedOption.label}. ${selectedOption.text}

Correct option:
${correct.label}. ${correct.text}

Backend MCQ correctness:
$isCorrect

Expected reasoning:
${question.expectedReasoning}

Learner reasoning:
$typedReasoning
''';
  }
}

class _ReasoningResult {
  const _ReasoningResult({
    required this.reasoningScore,
    required this.reasoningSignal,
    required this.feedback,
    required this.source,
    required this.prerequisiteGapCandidate,
  });

  final double? reasoningScore;
  final String reasoningSignal;
  final String feedback;
  final String source;
  final String? prerequisiteGapCandidate;
}

double? _boundedScore(Object? value) {
  final parsed = switch (value) {
    final int number => number.toDouble(),
    final double number => number,
    final String text => double.tryParse(text),
    _ => null,
  };
  if (parsed == null) {
    return null;
  }
  return _round4(parsed.clamp(0, 1).toDouble());
}

double _round4(double value) => (value * 10000).round() / 10000;

String _string(Object? value) => (value ?? '').toString().trim();

String? _nullableString(Object? value) {
  final text = _string(value);
  if (text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}
