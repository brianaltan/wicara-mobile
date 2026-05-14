import '../../pretest/domain/pretest_models.dart';

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
}

class DailyEvaluationSession {
  const DailyEvaluationSession({
    required this.sessionId,
    required this.questions,
  });

  final String sessionId;
  final List<PretestQuestion> questions;
}
