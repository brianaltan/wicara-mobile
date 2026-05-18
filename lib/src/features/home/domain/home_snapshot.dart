import '../../../core/utils/learning_level_resolver.dart';
import '../../pretest/domain/pretest_models.dart';
import '../../workspace/domain/workspace_models.dart';

class HomeSnapshot {
  const HomeSnapshot({
    required this.displayName,
    required this.streakDays,
    required this.country,
    required this.educationLevel,
    required this.gradeLevel,
    required this.preferredLanguage,
    required this.studyGoal,
    required this.dailyStudyTime,
    required this.selectedSubjects,
    required this.availableSubjects,
    required this.onboardingCompleted,
    this.nextQueueItem,
    this.activeTracks = const [],
    this.mediaArtifacts = const [],
  });

  final String displayName;
  final int streakDays;
  final String country;
  final String educationLevel;
  final String gradeLevel;
  final String preferredLanguage;
  final String studyGoal;
  final String dailyStudyTime;
  final List<String> selectedSubjects;
  final List<String> availableSubjects;
  final bool onboardingCompleted;
  final LearningQueueItem? nextQueueItem;
  final List<LearningTrackSummary> activeTracks;
  final List<HomeMediaArtifact> mediaArtifacts;

  String get firstName {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return 'Learner';
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final words = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return 'L';
    }
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }

  String get subjectSummary {
    if (selectedSubjects.isEmpty) {
      return 'No subjects selected';
    }
    return selectedSubjects.join(', ');
  }

  String get gradeSummary {
    final parts = [
      educationLevel,
      gradeLevel,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Not set' : parts.join(' - ');
  }

  WorkspaceRouteArguments? get firstWorkspaceTarget {
    final queueItem = nextQueueItem;
    if (queueItem != null && queueItem.hasWorkspaceTarget) {
      return WorkspaceRouteArguments(
        trackId: queueItem.trackId!,
        moduleId: queueItem.moduleId!,
        moduleTitle: queueItem.title,
      );
    }

    for (final track in activeTracks) {
      for (final module in track.modules) {
        if (module.status == 'ready' || module.status == 'active') {
          return WorkspaceRouteArguments(
            trackId: track.id,
            moduleId: module.id,
            moduleTitle: module.title,
          );
        }
      }
    }

    if (isElementaryLevel(
      educationLevel: educationLevel,
      gradeLevel: gradeLevel,
    )) {
      return const WorkspaceRouteArguments(
        trackId: 'demo-track-sd',
        moduleId: 'demo-module-perkalian',
        moduleTitle: 'Perkalian',
      );
    }

    return const WorkspaceRouteArguments(
      trackId: 'demo-track-smp',
      moduleId: 'demo-module-aljabar',
      moduleTitle: 'Aljabar dan pembuktian Al-Khawarizmi',
    );
  }
}

class HomeMediaArtifact {
  const HomeMediaArtifact({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.durationSeconds,
    required this.durationLabel,
    required this.transcript,
    required this.notes,
    required this.artifactType,
    this.thumbnailUrl,
    this.videoUrl,
    this.playbackUrl,
    this.trackId,
    this.moduleId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String status;
  final int durationSeconds;
  final String durationLabel;
  final String transcript;
  final List<String> notes;
  final String artifactType;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? playbackUrl;
  final String? trackId;
  final String? moduleId;
  final String? createdAt;

  String get effectiveVideoUrl => videoUrl ?? playbackUrl ?? '';

  bool get isReady => status.toLowerCase() == 'ready';
}

class LearningQueueItem {
  const LearningQueueItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    this.trackId,
    this.moduleId,
  });

  final String id;
  final String? trackId;
  final String? moduleId;
  final String title;
  final String subtitle;
  final String status;

  bool get hasWorkspaceTarget =>
      trackId != null &&
      trackId!.isNotEmpty &&
      moduleId != null &&
      moduleId!.isNotEmpty;
}

class LearningTrackSummary {
  const LearningTrackSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.progressPercent,
    required this.modules,
  });

  final String id;
  final String title;
  final String status;
  final int progressPercent;
  final List<LearningTrackModuleSummary> modules;
}

class LearningTrackModuleSummary {
  const LearningTrackModuleSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.estimatedMinutes,
  });

  final String id;
  final String title;
  final String description;
  final String status;
  final int estimatedMinutes;
}

class DailyEvaluationSession {
  const DailyEvaluationSession({
    required this.sessionId,
    required this.questions,
    this.title = 'Daily Evaluation',
    this.status = '',
    this.language = 'en',
    this.source = '',
    this.reviewDue = const ReviewDueSummary(),
    this.progress = const DailyEvaluationProgress(),
    this.currentQuestion,
    this.retentionForecast = const RetentionForecast(),
    this.recommendationCallout = const RecommendationCallout(),
  });

  final String sessionId;
  final String title;
  final String status;
  final String language;
  final String source;
  final ReviewDueSummary reviewDue;
  final DailyEvaluationProgress progress;
  final PretestQuestion? currentQuestion;
  final List<PretestQuestion> questions;
  final RetentionForecast retentionForecast;
  final RecommendationCallout recommendationCallout;
}

class ReviewDueSummary {
  const ReviewDueSummary({
    this.title = 'Review due',
    this.dueCount = 0,
    this.summary = '',
    this.actionLabel = 'Start',
  });

  final String title;
  final int dueCount;
  final String summary;
  final String actionLabel;
}

class DailyEvaluationProgress {
  const DailyEvaluationProgress({
    this.current = 0,
    this.total = 0,
    this.completed = 0,
    this.label = '0 of 0',
  });

  final int current;
  final int total;
  final int completed;
  final String label;

  double get ratio =>
      total <= 0 ? 0.0 : current.clamp(0, total).toDouble() / total;
}

class RetentionForecastPoint {
  const RetentionForecastPoint({
    required this.label,
    required this.retentionPercent,
    this.projected = false,
  });

  final String label;
  final int retentionPercent;
  final bool projected;
}

class RetentionForecast {
  const RetentionForecast({
    this.title = 'Your retention forecast',
    this.basis = '',
    this.points = const [],
  });

  final String title;
  final String basis;
  final List<RetentionForecastPoint> points;
}

class RecommendationCallout {
  const RecommendationCallout({
    this.title = 'Review now',
    this.message = '',
    this.impactLabel = '',
    this.actionLabel = 'Review now',
  });

  final String title;
  final String message;
  final String impactLabel;
  final String actionLabel;
}

class DailyEvaluationAnswerResult {
  const DailyEvaluationAnswerResult({
    required this.attemptId,
    required this.isCorrect,
    required this.nextReviewLabel,
    required this.masteryDelta,
    required this.sessionStatus,
    required this.completed,
  });

  final String attemptId;
  final bool isCorrect;
  final String nextReviewLabel;
  final double masteryDelta;
  final String sessionStatus;
  final bool completed;
}

class DailyEvaluationResult {
  const DailyEvaluationResult({
    required this.sessionId,
    required this.title,
    required this.status,
    required this.source,
    required this.scorePercent,
    required this.reviewedCount,
    required this.correctCount,
    required this.reviewAgainCount,
    required this.reviewedConcepts,
    required this.spacedRepetitionImpact,
    required this.nextReview,
    required this.recommendedNextActions,
    required this.backToHome,
  });

  final String sessionId;
  final String title;
  final String status;
  final String source;
  final int scorePercent;
  final int reviewedCount;
  final int correctCount;
  final int reviewAgainCount;
  final List<ReviewedConcept> reviewedConcepts;
  final SpacedRepetitionImpact spacedRepetitionImpact;
  final DailyEvaluationNextReview nextReview;
  final List<RecommendedNextAction> recommendedNextActions;
  final ActionTarget backToHome;
}

class ReviewedConcept {
  const ReviewedConcept({
    this.conceptId,
    required this.title,
    required this.statusLabel,
    required this.masteryScore,
  });

  final String? conceptId;
  final String title;
  final String statusLabel;
  final double masteryScore;
}

class SpacedRepetitionImpact {
  const SpacedRepetitionImpact({
    this.retentionLiftPercent = 0,
    this.daysUntilNextReview = 0,
    this.summary = '',
  });

  final int retentionLiftPercent;
  final int daysUntilNextReview;
  final String summary;
}

class DailyEvaluationNextReview {
  const DailyEvaluationNextReview({
    this.label = '',
    this.dueDate = '',
    this.intervalDays = 0,
  });

  final String label;
  final String dueDate;
  final int intervalDays;
}

class RecommendedNextAction {
  const RecommendedNextAction({
    required this.title,
    required this.actionType,
    required this.reason,
    this.dueDate,
    this.priority = 0,
    this.dueLabel,
  });

  final String title;
  final String actionType;
  final String reason;
  final String? dueDate;
  final int priority;
  final String? dueLabel;
}

class ActionTarget {
  const ActionTarget({
    required this.label,
    required this.actionType,
    this.target,
  });

  final String label;
  final String actionType;
  final String? target;
}

class AssessmentDashboard {
  const AssessmentDashboard({
    required this.learningGoalId,
    required this.targetTitle,
    required this.state,
    required this.comparison,
    required this.primaryAction,
    this.pretest,
    this.posttest,
    this.recommendations = const [],
  });

  final String learningGoalId;
  final String targetTitle;
  final String state;
  final AssessmentDashboardPretest? pretest;
  final AssessmentDashboardPosttest? posttest;
  final AssessmentDashboardComparison comparison;
  final ActionTarget primaryAction;
  final List<String> recommendations;
}

class AssessmentDashboardPretest {
  const AssessmentDashboardPretest({
    this.sessionId,
    required this.status,
    required this.scorePercent,
    required this.overallMasteryPercent,
    required this.confidencePercent,
    required this.recommendedPath,
    required this.summary,
    this.strengths = const [],
    this.gaps = const [],
    this.evidenceNotes = const [],
  });

  final String? sessionId;
  final String status;
  final double scorePercent;
  final double overallMasteryPercent;
  final double confidencePercent;
  final String recommendedPath;
  final String summary;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> evidenceNotes;
}

class AssessmentDashboardPosttest {
  const AssessmentDashboardPosttest({
    this.sessionId,
    required this.status,
    required this.answerPercent,
    required this.evidencePercent,
    required this.scorePercent,
    required this.confidencePercent,
    required this.passedNodeCount,
    required this.totalNodeCount,
    required this.passed,
    this.retakeRequiredConcepts = const [],
    this.nodes = const [],
  });

  final String? sessionId;
  final String status;
  final double answerPercent;
  final double evidencePercent;
  final double scorePercent;
  final double confidencePercent;
  final int passedNodeCount;
  final int totalNodeCount;
  final bool passed;
  final List<String> retakeRequiredConcepts;
  final List<PosttestNodeResult> nodes;
}

class AssessmentDashboardComparison {
  const AssessmentDashboardComparison({
    required this.available,
    this.pretestScorePercent,
    this.posttestScorePercent,
    this.learningGainPercent,
    this.pairedConceptCount = 0,
  });

  final bool available;
  final int? pretestScorePercent;
  final int? posttestScorePercent;
  final int? learningGainPercent;
  final int pairedConceptCount;
}

class PosttestNodeResult {
  const PosttestNodeResult({
    this.conceptId,
    required this.conceptCode,
    required this.conceptTitle,
    required this.totalQuestions,
    required this.answeredCount,
    required this.correctCount,
    required this.answerPercent,
    required this.evidencePercent,
    required this.scorePercent,
    required this.confidencePercent,
    required this.scaledScore,
    required this.passed,
    required this.retakeRequired,
    this.metricSource = 'adaptive_posttest_evidence',
  });

  final String? conceptId;
  final String conceptCode;
  final String conceptTitle;
  final int totalQuestions;
  final int answeredCount;
  final int correctCount;
  final double answerPercent;
  final double evidencePercent;
  final double scorePercent;
  final double confidencePercent;
  final double scaledScore;
  final bool passed;
  final bool retakeRequired;
  final String metricSource;
}

class AdaptivePosttestResult {
  const AdaptivePosttestResult({
    required this.sessionId,
    required this.status,
    required this.nodeResults,
    required this.retakeRequiredConcepts,
  });

  final String sessionId;
  final String status;
  final List<PosttestNodeResult> nodeResults;
  final List<String> retakeRequiredConcepts;

  int get totalNodeCount => nodeResults.length;

  int get passedNodeCount => nodeResults.where((node) => node.passed).length;

  bool get passed => totalNodeCount > 0 && passedNodeCount == totalNodeCount;

  double get answerPercent =>
      _averagePercent(nodeResults.map((node) => node.answerPercent));

  double get evidencePercent =>
      _averagePercent(nodeResults.map((node) => node.evidencePercent));

  double get scorePercent =>
      _averagePercent(nodeResults.map((node) => node.scorePercent));

  double get confidencePercent =>
      _averagePercent(nodeResults.map((node) => node.confidencePercent));
}

class WeeklyLearningReport {
  const WeeklyLearningReport({
    required this.rangeLabel,
    required this.rangeStart,
    required this.rangeEnd,
    required this.status,
    required this.source,
    required this.score,
    this.pretestScorePercent,
    this.posttestScorePercent,
    this.learningGainPercent,
    this.pairedConceptCount = 0,
    required this.fixedGaps,
    required this.fixedGapsDelta,
    required this.remainingGaps,
    required this.remainingGapsDelta,
    required this.retentionMinutes,
    required this.concepts,
    required this.summaryNotes,
    required this.performanceGroups,
    required this.gapMetrics,
    required this.unlockedThisWeek,
    required this.upcomingRecommendations,
    required this.consistencySummary,
  });

  final String rangeLabel;
  final String rangeStart;
  final String rangeEnd;
  final String status;
  final String source;
  final int score;
  final int? pretestScorePercent;
  final int? posttestScorePercent;
  final int? learningGainPercent;
  final int pairedConceptCount;
  final int fixedGaps;
  final int fixedGapsDelta;
  final int remainingGaps;
  final int remainingGapsDelta;
  final int retentionMinutes;
  final String concepts;
  final List<String> summaryNotes;
  final List<ReportPerformanceGroup> performanceGroups;
  final Map<String, GapMetric> gapMetrics;
  final UnlockedConceptSummary unlockedThisWeek;
  final List<RecommendedNextAction> upcomingRecommendations;
  final ConsistencySummary consistencySummary;
}

class ReportPerformanceGroup {
  const ReportPerformanceGroup({
    required this.label,
    required this.preTestPercent,
    required this.postTestPercent,
  });

  final String label;
  final int preTestPercent;
  final int postTestPercent;

  double get preTestRatio => preTestPercent.clamp(0, 100).toDouble() / 100;

  double get postTestRatio => postTestPercent.clamp(0, 100).toDouble() / 100;
}

class GapMetric {
  const GapMetric({
    required this.count,
    required this.weeklyDelta,
    required this.deltaLabel,
  });

  final int count;
  final int weeklyDelta;
  final String deltaLabel;
}

class UnlockedConceptSummary {
  const UnlockedConceptSummary({required this.count, required this.concepts});

  final int count;
  final List<String> concepts;
}

class ConsistencySummary {
  const ConsistencySummary({
    required this.title,
    required this.narrative,
    required this.signal,
  });

  final String title;
  final String narrative;
  final String signal;
}

double _averagePercent(Iterable<double> values) {
  final rows = values.toList(growable: false);
  if (rows.isEmpty) {
    return 0;
  }
  return rows.reduce((value, element) => value + element) / rows.length;
}
