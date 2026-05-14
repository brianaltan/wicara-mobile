class OnboardingProfile {
  const OnboardingProfile({
    required this.fullName,
    required this.country,
    required this.educationLevel,
    required this.gradeLevel,
    required this.preferredLanguage,
    required this.selectedSubjects,
    required this.studyGoal,
    required this.dailyStudyTime,
  });

  final String fullName;
  final String country;
  final String educationLevel;
  final String gradeLevel;
  final String preferredLanguage;
  final List<String> selectedSubjects;
  final String studyGoal;
  final String dailyStudyTime;

  OnboardingProfile copyWith({
    String? fullName,
    String? country,
    String? educationLevel,
    String? gradeLevel,
    String? preferredLanguage,
    List<String>? selectedSubjects,
    String? studyGoal,
    String? dailyStudyTime,
  }) {
    return OnboardingProfile(
      fullName: fullName ?? this.fullName,
      country: country ?? this.country,
      educationLevel: educationLevel ?? this.educationLevel,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      selectedSubjects: selectedSubjects ?? this.selectedSubjects,
      studyGoal: studyGoal ?? this.studyGoal,
      dailyStudyTime: dailyStudyTime ?? this.dailyStudyTime,
    );
  }
}
