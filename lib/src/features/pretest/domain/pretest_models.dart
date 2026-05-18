class PretestQuestion {
  const PretestQuestion({
    this.id = '',
    this.packId = '',
    required this.stepLabel,
    required this.topic,
    required this.prompt,
    required this.helper,
    required this.options,
    this.progressCurrent = 1,
    this.progressMax = 10,
  });

  final String id;
  final String packId;
  final String stepLabel;
  final String topic;
  final String prompt;
  final String helper;
  final List<PretestOption> options;
  final int progressCurrent;
  final int progressMax;
}

class PretestOption {
  const PretestOption({
    required this.id,
    required this.label,
    required this.text,
  });

  final String id;
  final String label;
  final String text;
}

class PretestAnswer {
  const PretestAnswer({
    required this.questionId,
    required this.optionId,
    required this.confidence,
    this.typedReasoning = '',
    this.canvasAssetId,
    this.canvasStrokeCount,
    this.usedCanvas = false,
  });

  final String questionId;
  final String optionId;
  final int confidence;
  final String typedReasoning;
  final String? canvasAssetId;
  final int? canvasStrokeCount;
  final bool usedCanvas;
}

class PretestReasoning {
  const PretestReasoning({
    required this.answer,
    required this.explanation,
    required this.usedCanvas,
  });

  final PretestAnswer answer;
  final String explanation;
  final bool usedCanvas;
}

class KnowledgeState {
  const KnowledgeState({
    required this.skill,
    required this.gapLabel,
    required this.message,
    required this.pathTitle,
    required this.pathMeta,
    required this.pathDescription,
    this.recommendedPath = 'target_from_basics',
    this.pathOptions = const [],
    this.masteryScore,
    this.confidence,
    this.overallMasteryPercent,
    this.strengths = const [],
    this.gaps = const [],
    this.evidenceNotes = const [],
    this.recommendedFocus = const [],
    this.nodeReports = const [],
  });

  final String skill;
  final String gapLabel;
  final String message;
  final String pathTitle;
  final String pathMeta;
  final String pathDescription;
  final String recommendedPath;
  final List<String> pathOptions;
  final double? masteryScore;
  final double? confidence;
  final int? overallMasteryPercent;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> evidenceNotes;
  final List<String> recommendedFocus;
  final List<PretestNodeReport> nodeReports;
}

class PretestNodeReport {
  const PretestNodeReport({
    required this.title,
    required this.role,
    required this.status,
    required this.difficultyReached,
    this.masteryScore,
    this.confidence,
    this.reasoningQuality = 'not_provided',
    this.avgReasoningScore,
    this.attemptCount = 0,
    this.correctCount = 0,
    this.diagnosticSignals = const [],
    this.hasCanvasEvidence = false,
    this.canvasStrokeCount,
    this.canvasSnapshotPath,
    this.carelessMistakePossible = false,
    this.misconceptionDetected = false,
  });

  final String title;
  final String role;
  final String status;
  final String difficultyReached;
  final double? masteryScore;
  final double? confidence;
  final String reasoningQuality;
  final double? avgReasoningScore;
  final int attemptCount;
  final int correctCount;
  final List<String> diagnosticSignals;
  final bool hasCanvasEvidence;
  final int? canvasStrokeCount;
  final String? canvasSnapshotPath;
  final bool carelessMistakePossible;
  final bool misconceptionDetected;
}

class PretestAnswerResult {
  const PretestAnswerResult({
    required this.completed,
    this.nextQuestion,
    this.diagnosis,
  });

  final bool completed;
  final PretestQuestion? nextQuestion;
  final KnowledgeState? diagnosis;
}
