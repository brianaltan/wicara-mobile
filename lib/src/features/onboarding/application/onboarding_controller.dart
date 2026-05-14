import 'package:flutter/foundation.dart';

import '../data/onboarding_profile_store.dart';
import '../domain/onboarding_options.dart';
import '../domain/onboarding_profile.dart';
import '../domain/onboarding_repository.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required OnboardingRepository onboardingRepository,
    required OnboardingProfileStore profileStore,
  }) : _onboardingRepository = onboardingRepository,
       _profileStore = profileStore;

  final OnboardingRepository _onboardingRepository;
  final OnboardingProfileStore _profileStore;

  OnboardingProfile _profile = _defaultProfile();

  OnboardingProfile get profile => _profile;

  Future<void> initialize({required String displayName}) async {
    final persisted = await _profileStore.read();
    if (persisted == null) {
      _profile = _defaultProfile(fullName: displayName);
    } else {
      _profile = persisted.copyWith(
        fullName: displayName,
        country: persisted.country.isEmpty ? 'United States' : null,
        educationLevel: persisted.educationLevel.isEmpty ? 'senior_high' : null,
        gradeLevel: persisted.gradeLevel.isEmpty ? '11' : null,
        preferredLanguage: persisted.preferredLanguage.isEmpty
            ? 'English'
            : null,
        selectedSubjects: persisted.selectedSubjects.isEmpty
            ? const ['Math', 'Physics', 'Chemistry', 'Biology']
            : null,
        studyGoal: persisted.studyGoal.isEmpty ? 'Improve understanding' : null,
        dailyStudyTime: persisted.dailyStudyTime.isEmpty
            ? '30-45 minutes'
            : null,
      );
    }
    await _profileStore.save(_profile);
    notifyListeners();
  }

  void syncDisplayName(String displayName) {
    final currentName = _profile.fullName.trim();
    if (displayName.trim().isEmpty) {
      return;
    }
    if (currentName.isNotEmpty &&
        currentName != 'Learner' &&
        currentName != 'Dev Learner' &&
        currentName != 'Siswa' &&
        currentName != 'Dev Siswa') {
      return;
    }

    _profile = _profile.copyWith(fullName: displayName);
    _profileStore.save(_profile);
    notifyListeners();
  }

  Future<void> saveProfile() async {
    await _onboardingRepository.saveProfile(_profile);
    await _profileStore.save(_profile);
    notifyListeners();
  }

  Future<void> updateFullName(String fullName) async {
    await _updateProfile(_profile.copyWith(fullName: fullName.trim()));
  }

  Future<void> updateCountry(String country) async {
    await _updateProfile(_profile.copyWith(country: country));
  }

  Future<void> updateGradeLevel(String gradeLevel) async {
    await _updateProfile(_profile.copyWith(gradeLevel: gradeLevel));
  }

  Future<void> updatePreferredLanguage(String preferredLanguage) async {
    await _updateProfile(
      _profile.copyWith(preferredLanguage: preferredLanguage),
    );
  }

  Future<void> updateStudyGoal(String studyGoal) async {
    await _updateProfile(_profile.copyWith(studyGoal: studyGoal));
  }

  Future<void> updateDailyStudyTime(String dailyStudyTime) async {
    await _updateProfile(_profile.copyWith(dailyStudyTime: dailyStudyTime));
  }

  Future<void> updateSelectedSubjects(List<String> selectedSubjects) async {
    await _updateProfile(_profile.copyWith(selectedSubjects: selectedSubjects));
  }

  Future<void> replaceProfile(OnboardingProfile profile) async {
    await _updateProfile(profile);
  }

  Future<void> _updateProfile(OnboardingProfile profile) async {
    _profile = profile;
    await _profileStore.save(_profile);
    notifyListeners();
  }

  static OnboardingProfile _defaultProfile({String fullName = 'Learner'}) {
    return OnboardingProfile(
      fullName: fullName,
      country: 'United States',
      educationLevel: 'senior_high',
      gradeLevel: '11',
      preferredLanguage: 'English',
      selectedSubjects: onboardingSubjectOptions
          .map((subject) => subject.key)
          .toList(),
      studyGoal: 'Improve understanding',
      dailyStudyTime: '30-45 minutes',
    );
  }
}
