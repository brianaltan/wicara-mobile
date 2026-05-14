class PretestQuestion {
  const PretestQuestion({
    this.id = '',
    required this.stepLabel,
    required this.topic,
    required this.prompt,
    required this.helper,
    required this.options,
  });

  final String id;
  final String stepLabel;
  final String topic;
  final String prompt;
  final String helper;
  final List<PretestOption> options;
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
  });

  final String questionId;
  final String optionId;
  final int confidence;
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
  });

  final String skill;
  final String gapLabel;
  final String message;
  final String pathTitle;
  final String pathMeta;
  final String pathDescription;
}
