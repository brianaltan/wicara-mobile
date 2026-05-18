int? parseGradeLevel(String gradeLevel) {
  final normalized = gradeLevel.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  return int.tryParse(normalized.replaceAll(RegExp(r'[^0-9]'), ''));
}

String normalizeEducationLevel({
  required String educationLevel,
  required String gradeLevel,
}) {
  final parsedGrade = parseGradeLevel(gradeLevel);
  if (parsedGrade != null) {
    if (parsedGrade <= 6) {
      return 'elementary';
    }
    if (parsedGrade <= 9) {
      return 'junior_high';
    }
    return 'senior_high';
  }

  final normalizedEducation = educationLevel.trim().toLowerCase();
  if (_isElementaryEducation(normalizedEducation)) {
    return 'elementary';
  }
  if (_isJuniorHighEducation(normalizedEducation)) {
    return 'junior_high';
  }
  if (_isSeniorHighEducation(normalizedEducation)) {
    return 'senior_high';
  }
  if (normalizedEducation.contains('university') ||
      normalizedEducation.contains('college') ||
      normalizedEducation.contains('kampus')) {
    return 'university';
  }

  return normalizedEducation.isEmpty ? 'senior_high' : normalizedEducation;
}

bool isElementaryLevel({
  required String educationLevel,
  required String gradeLevel,
}) {
  return normalizeEducationLevel(
        educationLevel: educationLevel,
        gradeLevel: gradeLevel,
      ) ==
      'elementary';
}

bool _isElementaryEducation(String value) {
  return value.contains('elementary') ||
      value == 'sd' ||
      value.contains('sekolah dasar') ||
      value.contains('primary');
}

bool _isJuniorHighEducation(String value) {
  return value == 'smp' ||
      value.contains('junior_high') ||
      value.contains('junior high') ||
      value.contains('middle');
}

bool _isSeniorHighEducation(String value) {
  return value == 'sma' ||
      value.contains('senior_high') ||
      value.contains('senior high') ||
      value.contains('high school');
}
