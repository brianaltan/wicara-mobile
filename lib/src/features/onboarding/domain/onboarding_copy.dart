import 'onboarding_options.dart';

class OnboardingCopy {
  const OnboardingCopy._(this.isIndonesian);

  factory OnboardingCopy.forLanguage(String preferredLanguage) {
    final normalized = preferredLanguage.trim().toLowerCase().replaceAll(
      '_',
      '-',
    );
    final isIndonesian =
        normalized == 'id' ||
        normalized == 'id-id' ||
        normalized == 'ind' ||
        normalized == 'indo' ||
        normalized == 'indonesian' ||
        normalized == 'bahasa' ||
        normalized == 'bahasa indonesia' ||
        normalized.contains('indo');
    return OnboardingCopy._(isIndonesian);
  }

  final bool isIndonesian;

  String get letsSetYouUpTitle =>
      isIndonesian ? 'Mari kita siapkan akunmu' : "Let's set you up";
  String get letsSetYouUpSubtitle => isIndonesian
      ? 'Ceritakan sedikit tentang dirimu agar\npengalaman belajarmu lebih personal.'
      : 'Tell us a bit about yourself to personalize\nyour learning.';
  String get fullNameLabel => isIndonesian ? 'Nama lengkap' : 'Full name';
  String get countryLabel => isIndonesian ? 'Negara' : 'Country';
  String get gradeLevelLabel => isIndonesian ? 'Tingkat kelas' : 'Grade level';
  String get preferredLanguageLabel =>
      isIndonesian ? 'Bahasa pilihan' : 'Preferred language';
  String get continueLabel => isIndonesian ? 'Lanjutkan' : 'Continue';
  String get improveExperienceNote => isIndonesian
      ? 'Kami akan terus meningkatkan pengalaman ini\nkhusus untukmu.'
      : "We'll keep improving this experience\njust for you.";
  String get chooseSubjectsTitle =>
      isIndonesian ? 'Pilih mata pelajaranmu' : 'Choose your subjects';
  String get chooseSubjectsSubtitle => isIndonesian
      ? 'Pilih mata pelajaran yang ingin kamu pelajari.\nKamu bisa mengubahnya kapan saja.'
      : 'Select the subjects you want to learn.\nYou can adjust these anytime.';
  String get customizeLaterNote => isIndonesian
      ? 'Kamu bisa mengatur lebih banyak nanti.'
      : 'You can customize more later.';
  String get preferencesTitle => isIndonesian
      ? 'Bagaimana kamu ingin belajar?'
      : 'How would you like to learn?';
  String get preferencesSubtitle => isIndonesian
      ? 'Pilih preferensimu. Kamu bisa mengubahnya\nkapan saja.'
      : 'Pick your preferences. You can change\nthem anytime.';
  String get studyGoalLabel => isIndonesian ? 'Tujuan belajar' : 'Study goal';
  String get studyGoalOptionalLabel =>
      isIndonesian ? 'Tujuan belajar (opsional)' : 'Study goal (optional)';
  String get dailyStudyTimeLabel =>
      isIndonesian ? 'Waktu belajar harian' : 'Daily study time';
  String get dailyStudyTimeOptionalLabel => isIndonesian
      ? 'Waktu belajar harian (opsional)'
      : 'Daily study time (optional)';
  String get adaptivePretestLabel => isIndonesian
      ? 'Lanjut ke pretest adaptif'
      : 'Continue to adaptive pretest';
  String get personalizePathNote => isIndonesian
      ? 'Ini membantu kami mempersonalisasi jalur belajarmu.'
      : 'This helps us personalize your learning path.';
  String get preferenceCallout => isIndonesian
      ? 'WICARA menyesuaikan denganmu, ritmemu, gayamu,\ndan tujuanmu.'
      : 'WICARA adapts to you, your pace, your style,\nand your goals.';
  String get profileTitle => isIndonesian ? 'Profil' : 'Profile';
  String get profileSubtitle => isIndonesian
      ? 'Kelola preferensi belajar dan akunmu.'
      : 'Manage your learning preferences and account.';
  String get homeLabel => isIndonesian ? 'Beranda' : 'Home';
  String get learnLabel => isIndonesian ? 'Belajar' : 'Learn';
  String get progressLabel => isIndonesian ? 'Progres' : 'Progress';
  String get learningSetupTitle =>
      isIndonesian ? 'Pengaturan belajar' : 'Learning setup';
  String get preferencesSectionTitle =>
      isIndonesian ? 'Preferensi' : 'Preferences';
  String get subjectsLabel => isIndonesian ? 'Mata pelajaran' : 'Subjects';
  String get logoutLabel => isIndonesian ? 'Keluar' : 'Log out';
  String get welcomeBack =>
      isIndonesian ? 'Selamat datang,\n' : 'Welcome back,\n';
  String get homeSubtitle => isIndonesian
      ? 'Siap melanjutkan belajar dan membangun sesuatu yang hebat hari ini?'
      : 'Ready to continue learning and build something great today?';
  String get learnSubtitleRecommended => isIndonesian
      ? 'Rekomendasi track untuk membantumu mencapai tujuan belajar.'
      : 'Suggested tracks to help you reach your goals.';
  String get learnSubtitleTracks => isIndonesian
      ? 'Jelajahi track belajarmu atau buat track baru di sini.'
      : 'Explore your learning tracks or create a new one here.';
  String get learnSubtitleGallery => isIndonesian
      ? 'Tinjau ulang video dan ringkasan dari perjalanan belajarmu.'
      : 'Review the videos and summaries from your learning journey.';
  String get recommendedLabel => isIndonesian ? 'Rekomendasi' : 'Recommended';
  String get tracksLabel => isIndonesian ? 'Track' : 'Tracks';
  String get galleryLabel => isIndonesian ? 'Galeri' : 'Gallery';
  String get todaysLearningQueueLabel =>
      isIndonesian ? 'Antrian belajar hari ini' : "Today's learning queue";
  String get viewAllLabel => isIndonesian ? 'Lihat semua' : 'View all';
  String get nextUpLabel => isIndonesian ? 'Berikutnya' : 'Next up';
  String get continueSessionLabel =>
      isIndonesian ? 'Lanjutkan sesi' : 'Continue session';
  String get wantToLearnSomethingNewLabel =>
      isIndonesian ? 'Ingin belajar hal baru?' : 'Want to learn something new?';
  String get exploreTracksDescription => isIndonesian
      ? 'Jelajahi track yang sudah kamu buat atau mulai track lainnya.'
      : 'Explore tracks you have created or start another one.';
  String get exploreLabel => isIndonesian ? 'Jelajahi' : 'Explore';
  String get currentStreakLabel =>
      isIndonesian ? 'Streak saat ini' : 'Current streak';
  String streakDaysLabel(int days) =>
      isIndonesian ? '$days hari' : '$days days';
  String get dailyEvaluationLabel =>
      isIndonesian ? 'Evaluasi harian' : 'Daily evaluation';
  String get todaysTopicLabel =>
      isIndonesian ? 'Topik hari ini: ' : "Today's topic: ";
  String get dailyEvaluationPrompt => isIndonesian
      ? '. Pilih skor keyakinan jika kamu mau, lalu kerjakan cek harianmu.'
      : '. Pick a confidence score if you want, then take your daily check.';
  String get notConfidentLabel =>
      isIndonesian ? 'Belum yakin' : 'Not confident';
  String get veryConfidentLabel =>
      isIndonesian ? 'Sangat yakin' : 'Very confident';
  String get takeDailyEvaluationLabel =>
      isIndonesian ? 'Mulai Evaluasi Harian' : 'Take Daily Evaluation';
  String get dailyEvalsWordmark =>
      isIndonesian ? 'Evaluasi Harian' : 'Daily Evals';
  String get dailyEvalsQuickCheckin => isIndonesian
      ? 'Cek cepat untuk jalur belajar hari ini.'
      : 'Quick check-in for today’s learning path.';
  String get finishDailyEvalsLabel =>
      isIndonesian ? 'Selesaikan Evaluasi' : 'Finish Daily Evals';
  String get nextQuestionLabel =>
      isIndonesian ? 'Soal berikutnya' : 'Next question';
  String get evaluationCompleteLabel =>
      isIndonesian ? 'Evaluasi Selesai 🎉' : 'Evaluation Complete 🎉';
  String get evaluationCompleteSubtitle => isIndonesian
      ? 'Kerja bagus! Kamu sedang membangun pemahaman yang bertahan lama.'
      : "Great work! You're building lasting knowledge.";
  String get reviewedLabel => isIndonesian ? 'Ditinjau' : 'Reviewed';
  String get correctLabel => isIndonesian ? 'Benar' : 'Correct';
  String get toReviewAgainLabel =>
      isIndonesian ? 'Ulangi lagi' : 'To review again';
  String get scoreLabel => isIndonesian ? 'Skor' : 'Score';
  String get reviewedConceptsLabel =>
      isIndonesian ? 'Konsep yang ditinjau' : 'Reviewed concepts';
  String get statusGoodLabel => isIndonesian ? 'Bagus' : 'Good';
  String get statusStrongLabel => isIndonesian ? 'Kuat' : 'Strong';
  String get statusReviewLabel => isIndonesian ? 'Tinjau' : 'Review';
  String get spacedRepetitionImpactLabel =>
      isIndonesian ? 'Dampak pengulangan berspasi' : 'Spaced repetition impact';
  String get memoryStrengthenedLabel => isIndonesian
      ? 'Memorimu makin kuat.'
      : "You've strengthened your memory.";
  String get retentionLiftLabel =>
      isIndonesian ? 'Peningkatan Retensi' : 'Retention Lift';
  String get daysUntilNextReviewLabel => isIndonesian
      ? 'Hari Hingga Tinjauan Berikutnya'
      : 'Days Until Next Review';
  String get backToHomeLabel =>
      isIndonesian ? 'Kembali ke Beranda' : 'Back to Home';
  String get continueLearningLabel =>
      isIndonesian ? 'Lanjutkan Belajar' : 'Continue Learning';
  String get learnSomethingNewLabel =>
      isIndonesian ? 'Pelajari hal baru' : 'Learn something new';
  String get newTrackDescription => isIndonesian
      ? 'Buat track baru di luar daftar yang sedang kamu jalani.'
      : 'Create a new track outside your current list.';
  String get newTrackLabel => isIndonesian ? 'Track baru' : 'New track';
  String get contentGalleryLabel =>
      isIndonesian ? 'Galeri Konten' : 'Content Gallery';
  String get contentGalleryDescription => isIndonesian
      ? 'Semua video yang pernah dibuat ada di sini, siap diputar ulang bersama catatan yang WICARA susun untukmu.'
      : 'All videos generated before are here, ready to replay with the notes that WICARA compiled for you.';
  String get notesLabel => isIndonesian ? 'Catatan' : 'Notes';
  String get cheatsheetSummaryLabel =>
      isIndonesian ? 'Ringkasan catatan' : 'Cheatsheet summary';
  String get recommendedForCurrentReadinessLabel => isIndonesian
      ? 'Direkomendasikan untuk Calculus I berdasarkan\ngap dan kesiapanmu saat ini.'
      : 'Recommended for Calculus I based on\nyour current gaps and readiness.';
  String get progressSubtitle => isIndonesian
      ? 'Mulai dari laporan belajar, lalu jelajahi peta pengetahuan.'
      : 'Start with your learning report, then explore the knowledge map.';
  String get learningReportLabel =>
      isIndonesian ? 'Laporan Belajar' : 'Learning Report';
  String get learningReportDescription => isIndonesian
      ? 'Performa mingguan, gap yang tertutup, dan konsep yang terbuka.'
      : 'Weekly performance, fixed gaps, unlocked concepts.';
  String get fixedShortLabel => isIndonesian ? '+4 tertutup' : '+4 fixed';
  String get overallLabel => isIndonesian ? 'Keseluruhan' : 'Overall';
  String get applicationLabel => isIndonesian ? 'Penerapan' : 'Application';
  String get analysisLabel => isIndonesian ? 'Analisis' : 'Analysis';
  String get fixedGapsLabel => isIndonesian ? 'Gap tertutup' : 'Fixed gaps';
  String get remainingGapsLabel => isIndonesian ? 'Sisa gap' : 'Remaining gaps';
  String get thisWeekFixedDelta =>
      isIndonesian ? '+4 minggu ini' : '+4 this week';
  String get thisWeekRemainingDelta =>
      isIndonesian ? '-2 minggu ini' : '-2 this week';
  String get learningReportHint => isIndonesian
      ? 'Arahkan kursor atau ketuk satu minggu untuk melihat pertumbuhan, gap yang tertutup, dan peningkatan memori.'
      : 'Hover or tap a week to preview growth, fixed gaps, and memory lift.';
  String get completeLabel => isIndonesian ? 'Selesai' : 'Complete';
  String get skillGrowthLabel =>
      isIndonesian ? 'Pertumbuhan skill' : 'Skill growth';
  String retentionDeltaLabel(int retention) =>
      isIndonesian ? '+$retention% retensi' : '+$retention% retention';
  String remainingCountLabel(int count) =>
      isIndonesian ? '$count tersisa' : '$count left';
  String weekLabel(int weekNumber) =>
      isIndonesian ? 'M$weekNumber' : 'W$weekNumber';
  String get knowledgeMapLabel =>
      isIndonesian ? 'Peta Pengetahuan' : 'Knowledge Map';
  String get knowledgeMapDescription => isIndonesian
      ? 'Jelajahi domain mata pelajaran dan jalur prasyarat.'
      : 'Explore subject domains and prerequisite paths.';
  String get loadingCurriculumLabel => isIndonesian
      ? 'Memuat kurikulum dari backend...'
      : 'Loading curriculum from backend...';
  String get fallbackGraphLabel =>
      isIndonesian ? 'Graf fallback statis' : 'Static fallback graph';
  String get liveCurriculumGraphLabel => isIndonesian
      ? 'Graf pengetahuan langsung'
      : 'Live knowledge graph';
  String nodeCountLabel(int count) =>
      isIndonesian ? '$count node' : '$count nodes';
  String get prerequisiteLayerLabel =>
      isIndonesian ? 'Lapisan prasyarat' : 'Prerequisite layer';
  String combinedLayerLabel(String first, int extraCount) =>
      isIndonesian ? '$first + $extraCount lainnya' : '$first + $extraCount';
  String get masteryConfidenceLabel =>
      isIndonesian ? 'Kepercayaan penguasaan' : 'Mastery confidence';
  String get aboutThisConceptLabel =>
      isIndonesian ? 'Tentang konsep ini' : 'About this concept';
  String get prerequisitesLabel => isIndonesian ? 'Prasyarat' : 'Prerequisites';
  String get relatedConceptsLabel =>
      isIndonesian ? 'Konsep terkait' : 'Related concepts';
  String get noDirectPrerequisiteLabel =>
      isIndonesian ? 'Tidak ada prasyarat langsung' : 'No direct prerequisite';
  String get noDirectRelatedConceptLabel => isIndonesian
      ? 'Tidak ada konsep terkait langsung'
      : 'No direct related concept';
  String get crossSubjectConnectionsLabel => isIndonesian
      ? 'Koneksi antar mata pelajaran'
      : 'Cross-subject connections';
  String get graphOfGraphsHint => isIndonesian
      ? 'Tautan Graph of Graphs akan terlihat saat tersedia.'
      : 'Graph of Graphs links are visible when available.';
  String get conceptBridgeFallbackLabel => isIndonesian
      ? 'Jembatan konsep'
      : 'Concept bridge';
  String get relatedBadgeLabel => isIndonesian ? 'TERKAIT' : 'RELATED';
  String get conceptFallbackDescription => isIndonesian
      ? 'Konsep dalam graf prasyarat.'
      : 'Concept in the prerequisite graph.';
  String get languageLabel => isIndonesian ? 'Bahasa' : 'Language';
  String get appTitle => 'Wicara';
  String get getStartedLabel => isIndonesian ? 'Mulai' : 'Get started';
  String get alreadyHaveAccountLabel =>
      isIndonesian ? 'Saya sudah punya akun' : 'I already have an account';
  String get signInTitle =>
      isIndonesian ? 'Selamat datang kembali' : 'Welcome back';
  String get signInSubtitle => isIndonesian
      ? 'Masuk untuk melanjutkan belajarmu'
      : 'Sign in to continue your learning';
  String get registerTitle =>
      isIndonesian ? 'Buat akunmu' : 'Create your account';
  String get registerSubtitle => isIndonesian
      ? 'Daftar sekali, lalu lanjutkan perjalanan belajarmu'
      : 'Register once, then continue with your learning path';
  String get emailOrPhoneLabel =>
      isIndonesian ? 'Email atau nomor telepon' : 'Email or phone';
  String get emailOrPhoneHint => isIndonesian
      ? 'Masukkan email atau nomor telepon'
      : 'Enter your email or phone';
  String get emailLabel => isIndonesian ? 'Email' : 'Email';
  String get emailHint =>
      isIndonesian ? 'Masukkan emailmu' : 'Enter your email';
  String get passwordLabel => isIndonesian ? 'Kata sandi' : 'Password';
  String get passwordHint =>
      isIndonesian ? 'Masukkan kata sandi' : 'Enter your password';
  String get fullNameHint =>
      isIndonesian ? 'Masukkan nama lengkapmu' : 'Enter your full name';
  String get forgotPasswordLabel =>
      isIndonesian ? 'Lupa kata sandi?' : 'Forgot password?';
  String get signInLabel => isIndonesian ? 'Masuk' : 'Sign in';
  String get registerLabel => isIndonesian ? 'Daftar' : 'Register';
  String get logInLabel => isIndonesian ? 'Masuk' : 'Log in';
  String get orContinueWithLabel =>
      isIndonesian ? 'atau lanjut dengan' : 'or continue with';
  String get bypassForWebDevLabel =>
      isIndonesian ? 'Lewati untuk dev web' : 'Bypass for web dev';
  String get passwordResetMockedMessage => isIndonesian
      ? 'Reset kata sandi masih dimock untuk sekarang.'
      : 'Password reset is mocked for now.';
  String get emailRequiredMessage =>
      isIndonesian ? 'Masukkan emailmu' : 'Enter your email';
  String get fullNameRequiredMessage =>
      isIndonesian ? 'Masukkan nama lengkapmu' : 'Enter your full name';
  String get registrationEmailValidationMessage => isIndonesian
      ? 'Gunakan alamat email untuk pendaftaran'
      : 'Use an email address for registration';
  String get passwordMinLengthMessage => isIndonesian
      ? 'Kata sandi minimal 6 karakter'
      : 'Password must be at least 6 characters';
  String get securityNoteLabel => isIndonesian
      ? 'Datamu aman dan bersifat pribadi.'
      : 'Your data is private and secure.';
  String get learningGoalTitle => isIndonesian
      ? 'Apa yang ingin kamu pelajari?'
      : 'What would you like to learn?';
  String get learningGoalSubtitle => isIndonesian
      ? 'Tulis tujuanmu dulu. WICARA akan mencari node materi yang cocok, lalu pretest baru mulai setelah kamu setuju.'
      : 'Type your goal first. WICARA will find the matching material node, then the pretest starts after you confirm it.';
  String get learningTopicLabel =>
      isIndonesian ? 'Topik belajar' : 'Learning topic';
  String get generatePretestLabel =>
      isIndonesian ? 'Buat Pretest' : 'Generate Pretest';
  String get typeATopicHint => isIndonesian ? 'Ketik topik' : 'Type a topic';
  String get adaptivePretestReadyNextLabel => isIndonesian
      ? 'Pretest adaptif siap berikutnya'
      : 'Adaptive pretest ready next';
  String get adaptivePretestReadyDescription => isIndonesian
      ? 'Beberapa pertanyaan akan mengkalibrasi titik awalmu.'
      : 'A few questions will calibrate your starting point.';
  String get pretestGeneratedCompleteLabel =>
      isIndonesian ? 'Pretest berhasil dibuat!' : 'Pretest generated complete!';
  String get openingAdaptivePretestLabel => isIndonesian
      ? 'Membuka pretest adaptifmu sekarang.'
      : 'Opening your adaptive pretest now.';
  String get confidenceQuestionLabel =>
      isIndonesian ? 'Seberapa yakin kamu?' : 'How confident are you?';
  String get lowLabel => isIndonesian ? 'Rendah' : 'Low';
  String get highLabel => isIndonesian ? 'Tinggi' : 'High';
  String get yourKnowledgeStateLabel =>
      isIndonesian ? 'Kondisi pengetahuanmu' : 'Your knowledge state';
  String get basedOnYourResponsesLabel =>
      isIndonesian ? 'Berdasarkan responsmu.' : 'Based on your responses.';
  String get whatsNextLabel => isIndonesian ? 'Selanjutnya' : "What's next";
  String get personalizedPathGeneratedLabel => isIndonesian
      ? 'Jalur personal berhasil dibuat'
      : 'Personalized path generated';
  String get personalizedPathDescription => isIndonesian
      ? 'Mulai dari prasyarat, lalu lanjut berlatih pertanyaan akar masalah.'
      : 'Start with prerequisites, then practice root-cause questions.';
  String get continueToMyPathLabel =>
      isIndonesian ? 'Lanjut ke jalur saya' : 'Continue to my path';
  String get retakePretestAnytimeLabel => isIndonesian
      ? 'Kamu bisa mengulang pretest kapan saja.'
      : 'You can retake the pretest anytime.';
  String get missingPrerequisiteGapsLabel => isIndonesian
      ? 'Gap prasyarat yang belum terpenuhi'
      : 'Missing prerequisite gaps';
  String get currentTopicLabel =>
      isIndonesian ? 'Topik saat ini' : 'Current topic';
  String get askOrReflectHereHint => isIndonesian
      ? 'Tanya atau refleksikan di sini...'
      : 'Ask or reflect here...';
  String get learnerLabel => isIndonesian ? 'Siswa' : 'Learner';
  String get searchLabel => isIndonesian ? 'Cari' : 'Search';
  String get applyLabel => isIndonesian ? 'Terapkan' : 'Apply';
  String get cancelLabel => isIndonesian ? 'Batal' : 'Cancel';

  String gradeValue(String level) =>
      isIndonesian ? 'Kelas $level' : 'Grade $level';

  String subjectLabel(String key) => switch (key) {
    'Math' => isIndonesian ? 'Matematika' : 'Math',
    'Matematika' => isIndonesian ? 'Matematika' : 'Math',
    'Physics' => isIndonesian ? 'Fisika' : 'Physics',
    'Fisika' => isIndonesian ? 'Fisika' : 'Physics',
    'Chemistry' => isIndonesian ? 'Kimia' : 'Chemistry',
    'Kimia' => isIndonesian ? 'Kimia' : 'Chemistry',
    'Biology' => isIndonesian ? 'Biologi' : 'Biology',
    'Biologi' => isIndonesian ? 'Biologi' : 'Biology',
    _ => key,
  };

  String subjectDescription(String key) => switch (key) {
    'Math' =>
      isIndonesian
          ? 'Aljabar, Geometri, Kalkulus'
          : 'Algebra, Geometry, Calculus',
    'Physics' =>
      isIndonesian
          ? 'Mekanika, Gelombang, Termodinamika'
          : 'Mechanics, Waves, Thermo',
    'Chemistry' =>
      isIndonesian ? 'Stoikiometri, Reaksi' : 'Stoichiometry, Reactions',
    'Biology' =>
      isIndonesian ? 'Sel, Genetika, Ekologi' : 'Cell, Genetics, Ecology',
    _ => key,
  };

  String languageDisplay(String value) => value;

  String studyGoalDisplay(String value) => switch (value) {
    'Build strong foundations' =>
      isIndonesian ? 'Bangun fondasi yang kuat' : 'Build strong foundations',
    'Improve understanding' =>
      isIndonesian ? 'Perdalam pemahaman' : 'Improve understanding',
    'Prepare for exams' =>
      isIndonesian ? 'Persiapan ujian' : 'Prepare for exams',
    'Learn faster' => isIndonesian ? 'Belajar lebih cepat' : 'Learn faster',
    'Stay consistent' => isIndonesian ? 'Tetap konsisten' : 'Stay consistent',
    _ => value,
  };

  String dailyStudyTimeDisplay(String value) => switch (value) {
    '15-30 minutes' => isIndonesian ? '15-30 menit' : '15-30 minutes',
    '30-45 minutes' => isIndonesian ? '30-45 menit' : '30-45 minutes',
    '45-60 minutes' => isIndonesian ? '45-60 menit' : '45-60 minutes',
    '1-2 hours' => isIndonesian ? '1-2 jam' : '1-2 hours',
    '2+ hours' => isIndonesian ? '2+ jam' : '2+ hours',
    _ => value,
  };

  List<String> get localizedStudyGoalOptions =>
      onboardingStudyGoalOptions.map(studyGoalDisplay).toList();

  List<String> get localizedDailyStudyTimeOptions =>
      onboardingDailyStudyTimeOptions.map(dailyStudyTimeDisplay).toList();

  String difficultyLabel(String value) => switch (value.toLowerCase()) {
    'easy' => isIndonesian ? 'Mudah' : 'Easy',
    'medium' => isIndonesian ? 'Menengah' : 'Medium',
    'hard' => isIndonesian ? 'Sulit' : 'Hard',
    _ => value,
  };

  String estimatedDurationLabel(String value, String difficulty) => isIndonesian
      ? 'Estimasi $value   •   ${difficultyLabel(difficulty)}'
      : 'Estimated $value   •   ${difficultyLabel(difficulty)}';

  String weeklyScoreDate(String value) => value;

  List<String> get weekShortLabels => isIndonesian
      ? const ['M', 'S', 'S', 'R', 'K', 'J', 'S']
      : const ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  String nodeStatusLabel(String value) => switch (value) {
    'MASTERED' => isIndonesian ? 'MENGUASAI' : 'MASTERED',
    'IN PROGRESS' => isIndonesian ? 'SEDANG BELAJAR' : 'IN PROGRESS',
    'REVIEW' => isIndonesian ? 'TINJAU' : 'REVIEW',
    'READY' => isIndonesian ? 'SIAP' : 'READY',
    'GAP' => isIndonesian ? 'GAP' : 'GAP',
    'LOCKED' => isIndonesian ? 'TERKUNCI' : 'LOCKED',
    _ => value,
  };
}
