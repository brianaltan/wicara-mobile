class LocalPretestOption {
  const LocalPretestOption({
    required this.id,
    required this.label,
    required this.text,
    required this.isCorrect,
  });

  final String id;
  final String label;
  final String text;
  final bool isCorrect;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'text': text,
  };
}

class LocalPretestQuestion {
  const LocalPretestQuestion({
    required this.id,
    required this.packId,
    required this.conceptCode,
    required this.conceptTitle,
    required this.difficulty,
    required this.prompt,
    required this.helper,
    required this.expectedReasoning,
    required this.options,
    required this.progressCurrent,
    required this.progressMax,
  });

  final String id;
  final String packId;
  final String conceptCode;
  final String conceptTitle;
  final String difficulty;
  final String prompt;
  final String helper;
  final String expectedReasoning;
  final List<LocalPretestOption> options;
  final int progressCurrent;
  final int progressMax;

  Map<String, dynamic> toApiJson() => {
    'id': id,
    'pack_id': packId,
    'concept_code': conceptCode,
    'concept_title': conceptTitle,
    'topic': conceptTitle,
    'difficulty': difficulty,
    'step_label': 'Question $progressCurrent of $progressMax',
    'prompt': prompt,
    'helper': helper,
    'options': options.map((option) => option.toJson()).toList(growable: false),
    'progress': {
      'current': progressCurrent,
      'max': progressMax,
    },
  };
}

class LocalPretestEvaluation {
  const LocalPretestEvaluation({
    required this.isCorrect,
    required this.answerScore,
    required this.reasoningScore,
    required this.reasoningSignal,
    required this.reasoningFeedback,
    required this.reasoningEvaluationSource,
    required this.canvasScore,
    required this.evidenceScore,
    required this.confidence,
    required this.diagnosticSignal,
    required this.canvasStatus,
    required this.prerequisiteGapCandidate,
  });

  final bool isCorrect;
  final double answerScore;
  final double? reasoningScore;
  final String reasoningSignal;
  final String reasoningFeedback;
  final String reasoningEvaluationSource;
  final double? canvasScore;
  final double evidenceScore;
  final double confidence;
  final String diagnosticSignal;
  final String? canvasStatus;
  final String? prerequisiteGapCandidate;

  Map<String, dynamic> toJson() => {
    'is_correct': isCorrect,
    'answer_score': answerScore,
    'reasoning_score': reasoningScore,
    'reasoning_signal': reasoningSignal,
    'reasoning_feedback': reasoningFeedback,
    'reasoning_evaluation_source': reasoningEvaluationSource,
    'canvas_score': canvasScore,
    'evidence_score': evidenceScore,
    'confidence': confidence,
    'diagnostic_signal': diagnosticSignal,
    'canvas_status': canvasStatus,
    'prerequisite_gap_candidate': prerequisiteGapCandidate,
  };
}

class LocalPretestAnswerResult {
  const LocalPretestAnswerResult({
    required this.attemptId,
    required this.evaluation,
    required this.nextAction,
    this.nextQuestion,
    this.diagnosis,
  });

  final String attemptId;
  final LocalPretestEvaluation evaluation;
  final Map<String, dynamic> nextAction;
  final LocalPretestQuestion? nextQuestion;
  final Map<String, dynamic>? diagnosis;

  bool get completed => diagnosis != null;
}

class LocalPretestSessionSnapshot {
  const LocalPretestSessionSnapshot({
    required this.sessionId,
    required this.status,
    required this.targetConcept,
    required this.graphScope,
    required this.decisionState,
    required this.currentQuestion,
    required this.questionCount,
    required this.maxQuestions,
  });

  final String sessionId;
  final String status;
  final Map<String, dynamic> targetConcept;
  final Map<String, dynamic> graphScope;
  final Map<String, dynamic> decisionState;
  final LocalPretestQuestion? currentQuestion;
  final int questionCount;
  final int maxQuestions;
}
