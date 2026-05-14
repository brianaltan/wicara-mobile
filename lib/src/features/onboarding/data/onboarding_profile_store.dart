import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/onboarding_profile.dart';

class OnboardingProfileStore {
  static const _profileKey = 'onboarding.profile';

  Future<OnboardingProfile?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final rawProfile = preferences.getString(_profileKey);
    if (rawProfile == null || rawProfile.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawProfile);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final selectedSubjects = (decoded['selectedSubjects'] as List<dynamic>? ?? [])
        .map((subject) => subject.toString())
        .toList();

    return OnboardingProfile(
      fullName: (decoded['fullName'] ?? '').toString(),
      country: (decoded['country'] ?? '').toString(),
      educationLevel: (decoded['educationLevel'] ?? '').toString(),
      gradeLevel: (decoded['gradeLevel'] ?? '').toString(),
      preferredLanguage: (decoded['preferredLanguage'] ?? '').toString(),
      selectedSubjects: selectedSubjects,
      studyGoal: (decoded['studyGoal'] ?? '').toString(),
      dailyStudyTime: (decoded['dailyStudyTime'] ?? '').toString(),
    );
  }

  Future<void> save(OnboardingProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(<String, dynamic>{
      'fullName': profile.fullName,
      'country': profile.country,
      'educationLevel': profile.educationLevel,
      'gradeLevel': profile.gradeLevel,
      'preferredLanguage': profile.preferredLanguage,
      'selectedSubjects': profile.selectedSubjects,
      'studyGoal': profile.studyGoal,
      'dailyStudyTime': profile.dailyStudyTime,
    });
    await preferences.setString(_profileKey, encoded);
  }
}
