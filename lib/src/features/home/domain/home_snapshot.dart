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
    return null;
  }
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
  });

  final String sessionId;
  final List<PretestQuestion> questions;
}
