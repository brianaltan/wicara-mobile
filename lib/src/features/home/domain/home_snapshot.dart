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

class WeeklyLearningReport {
  const WeeklyLearningReport({
    required this.rangeLabel,
    required this.rangeStart,
    required this.rangeEnd,
    required this.status,
    required this.source,
    required this.score,
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
