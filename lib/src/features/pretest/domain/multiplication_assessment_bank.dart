import 'pretest_models.dart';

enum HardcodedAssessmentKind { pretest, posttest }

enum HardcodedAssessmentLevel { elementary, juniorHigh }

class AssessmentFocusArea {
  const AssessmentFocusArea({
    required this.title,
    required this.description,
    required this.severity,
  });

  final String title;
  final String description;
  final String severity;
}

class HardcodedAssessmentPack {
  const HardcodedAssessmentPack({
    required this.id,
    required this.level,
    required this.levelLabel,
    required this.topicTitle,
    required this.pretestTitle,
    required this.posttestTitle,
    required this.pretestQuestions,
    required this.posttestQuestions,
    required this.pretestCorrectAnswers,
    required this.posttestCorrectAnswers,
    required this.focusAreas,
    required this.readyPathDescription,
    required this.reviewPathDescription,
    required this.workspaceIntroLine1,
    required this.workspaceIntroLine2,
    required this.workspaceExplanation,
    required this.workspaceVideoTitle,
    required this.workspaceQuizQuestion,
    required this.workspaceQuizOptions,
    required this.workspaceQuizCorrectAnswer,
    required this.workspaceQuizCorrectFeedback,
    required this.workspaceQuizReviewFeedback,
  });

  final String id;
  final HardcodedAssessmentLevel level;
  final String levelLabel;
  final String topicTitle;
  final String pretestTitle;
  final String posttestTitle;
  final List<PretestQuestion> pretestQuestions;
  final List<PretestQuestion> posttestQuestions;
  final Map<String, String> pretestCorrectAnswers;
  final Map<String, String> posttestCorrectAnswers;
  final List<AssessmentFocusArea> focusAreas;
  final String readyPathDescription;
  final String reviewPathDescription;
  final String workspaceIntroLine1;
  final String workspaceIntroLine2;
  final String workspaceExplanation;
  final String workspaceVideoTitle;
  final String workspaceQuizQuestion;
  final List<String> workspaceQuizOptions;
  final String workspaceQuizCorrectAnswer;
  final String workspaceQuizCorrectFeedback;
  final String workspaceQuizReviewFeedback;

  List<PretestQuestion> questionsFor(HardcodedAssessmentKind kind) {
    return switch (kind) {
      HardcodedAssessmentKind.pretest => pretestQuestions,
      HardcodedAssessmentKind.posttest => posttestQuestions,
    };
  }

  Map<String, String> answersFor(HardcodedAssessmentKind kind) {
    return switch (kind) {
      HardcodedAssessmentKind.pretest => pretestCorrectAnswers,
      HardcodedAssessmentKind.posttest => posttestCorrectAnswers,
    };
  }

  int correctCount({
    required HardcodedAssessmentKind kind,
    required Map<int, String> selectedAnswers,
  }) {
    final questions = questionsFor(kind);
    final answerKey = answersFor(kind);
    var count = 0;
    for (var index = 0; index < questions.length; index++) {
      if (selectedAnswers[index] == answerKey[questions[index].id]) {
        count += 1;
      }
    }
    return count;
  }
}

class HardcodedAssessmentBank {
  const HardcodedAssessmentBank._();

  static HardcodedAssessmentPack packForEducation({
    required String educationLevel,
    required String gradeLevel,
  }) {
    final normalizedEducation = educationLevel.trim().toLowerCase();
    final normalizedGrade = gradeLevel.trim().toLowerCase();
    final parsedGrade = int.tryParse(
      normalizedGrade.replaceAll(RegExp(r'[^0-9]'), ''),
    );

    if (normalizedEducation.contains('elementary') ||
        normalizedEducation == 'sd' ||
        normalizedEducation.contains('sekolah dasar') ||
        (parsedGrade != null && parsedGrade <= 6)) {
      return multiplication;
    }

    return algebra;
  }

  static const multiplication = HardcodedAssessmentPack(
    id: 'multiplication',
    level: HardcodedAssessmentLevel.elementary,
    levelLabel: 'SD',
    topicTitle: 'Perkalian',
    pretestTitle: 'Pretest Perkalian',
    posttestTitle: 'Posttest Perkalian',
    pretestQuestions: [
      PretestQuestion(
        id: 'multiplication-pretest-1',
        stepLabel: '1 / 3',
        topic: 'Pretest Perkalian',
        prompt:
            'Rani punya 4 kantong. Setiap kantong berisi 3 kelereng. Berapa jumlah semua kelereng Rani?',
        helper: 'Pilih jawaban yang paling tepat.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '7'),
          PretestOption(id: 'B', label: 'B', text: '12'),
          PretestOption(id: 'C', label: 'C', text: '14'),
          PretestOption(id: 'D', label: 'D', text: '16'),
        ],
      ),
      PretestQuestion(
        id: 'multiplication-pretest-2',
        stepLabel: '2 / 3',
        topic: 'Pretest Perkalian',
        prompt: 'Manakah yang sama dengan 5 x 4?',
        helper: 'Ingat bahwa perkalian dapat berarti penjumlahan berulang.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '5 + 4'),
          PretestOption(id: 'B', label: 'B', text: '4 + 4 + 4 + 4 + 4'),
          PretestOption(id: 'C', label: 'C', text: '5 + 5 + 5 + 5 + 5'),
          PretestOption(id: 'D', label: 'D', text: '4 - 4 - 4 - 4 - 4'),
        ],
      ),
      PretestQuestion(
        id: 'multiplication-pretest-3',
        stepLabel: '3 / 3',
        topic: 'Pretest Perkalian',
        prompt:
            'Ayah membeli 6 kotak pensil. Setiap kotak berisi 8 pensil. Lalu 5 pensil diberikan kepada adik. Berapa pensil yang tersisa?',
        helper: 'Kerjakan perkalian dulu, lalu kurangi pensil yang diberikan.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '43'),
          PretestOption(id: 'B', label: 'B', text: '48'),
          PretestOption(id: 'C', label: 'C', text: '53'),
          PretestOption(id: 'D', label: 'D', text: '58'),
        ],
      ),
    ],
    posttestQuestions: [
      PretestQuestion(
        id: 'multiplication-posttest-1',
        stepLabel: '1 / 10',
        topic: 'Posttest Perkalian',
        prompt:
            'Ada 7 piring. Setiap piring berisi 4 kue. Berapa jumlah semua kue?',
        helper: 'Gunakan perkalian untuk menghitung jumlah semua kue.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '11'),
          PretestOption(id: 'B', label: 'B', text: '24'),
          PretestOption(id: 'C', label: 'C', text: '28'),
          PretestOption(id: 'D', label: 'D', text: '32'),
        ],
      ),
      PretestQuestion(
        id: 'multiplication-posttest-2',
        stepLabel: '2 / 10',
        topic: 'Posttest Perkalian',
        prompt: 'Hasil dari 9 x 6 adalah ...',
        helper: 'Pilih hasil perkalian yang benar.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '45'),
          PretestOption(id: 'B', label: 'B', text: '54'),
          PretestOption(id: 'C', label: 'C', text: '56'),
          PretestOption(id: 'D', label: 'D', text: '63'),
        ],
      ),
      PretestQuestion(
        id: 'multiplication-posttest-3',
        stepLabel: '3 / 10',
        topic: 'Posttest Perkalian',
        prompt: 'Manakah bentuk penjumlahan berulang dari 3 x 7?',
        helper: 'Cari penjumlahan 7 sebanyak 3 kali.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '3 + 7'),
          PretestOption(id: 'B', label: 'B', text: '7 + 7 + 7'),
          PretestOption(id: 'C', label: 'C', text: '3 + 3 + 3'),
          PretestOption(id: 'D', label: 'D', text: '7 - 3'),
        ],
      ),
      PretestQuestion(
        id: 'multiplication-posttest-4',
        stepLabel: '4 / 10',
        topic: 'Posttest Perkalian',
        prompt:
            'Dina menyusun 5 baris kursi. Setiap baris ada 6 kursi. Jika 4 kursi dipindahkan, berapa kursi yang masih tersusun?',
        helper: 'Hitung total kursi, lalu kurangi kursi yang dipindahkan.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '26'),
          PretestOption(id: 'B', label: 'B', text: '30'),
          PretestOption(id: 'C', label: 'C', text: '34'),
          PretestOption(id: 'D', label: 'D', text: '36'),
        ],
      ),
      PretestQuestion(
        id: 'multiplication-posttest-5',
        stepLabel: '5 / 10',
        topic: 'Posttest Perkalian',
        prompt:
            'Tanpa menghitung dari awal, jika 8 x 5 = 40, maka 8 x 6 adalah ...',
        helper: 'Dari 8 x 5 ke 8 x 6, tambahkan satu kelompok berisi 8.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '41'),
          PretestOption(id: 'B', label: 'B', text: '45'),
          PretestOption(id: 'C', label: 'C', text: '48'),
          PretestOption(id: 'D', label: 'D', text: '50'),
        ],
      ),
      PretestQuestion(
        id: 'multiplication-posttest-6',
        stepLabel: '6 / 10',
        topic: 'Posttest Perkalian',
        prompt:
            'Budi punya 4 kotak. Setiap kotak berisi 9 mainan. Ibu menambahkan 6 mainan lagi. Berapa jumlah mainan Budi sekarang?',
        helper: 'Kalikan isi kotak, lalu tambahkan mainan dari Ibu.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '36'),
          PretestOption(id: 'B', label: 'B', text: '40'),
          PretestOption(id: 'C', label: 'C', text: '42'),
          PretestOption(id: 'D', label: 'D', text: '46'),
        ],
      ),
      PretestQuestion(
        id: 'multiplication-posttest-7',
        stepLabel: '7 / 10',
        topic: 'Posttest Perkalian',
        prompt: 'Manakah yang nilainya paling besar?',
        helper: 'Bandingkan hasil setiap perkalian.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '6 x 7'),
          PretestOption(id: 'B', label: 'B', text: '5 x 8'),
          PretestOption(id: 'C', label: 'C', text: '9 x 4'),
          PretestOption(id: 'D', label: 'D', text: '3 x 12'),
        ],
      ),
      PretestQuestion(
        id: 'multiplication-posttest-8',
        stepLabel: '8 / 10',
        topic: 'Posttest Perkalian',
        prompt:
            'Sebuah taman memiliki 6 baris pohon. Setiap baris ada 7 pohon. Jika 10 pohon ditebang, berapa pohon yang tersisa?',
        helper: 'Hitung semua pohon, lalu kurangi pohon yang ditebang.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '32'),
          PretestOption(id: 'B', label: 'B', text: '34'),
          PretestOption(id: 'C', label: 'C', text: '42'),
          PretestOption(id: 'D', label: 'D', text: '52'),
        ],
      ),
      PretestQuestion(
        id: 'multiplication-posttest-9',
        stepLabel: '9 / 10',
        topic: 'Posttest Perkalian',
        prompt:
            'Lihat pola berikut:\n4 x 3 = 12\n4 x 4 = 16\n4 x 5 = 20\nMaka 4 x 6 = ...',
        helper: 'Perhatikan bahwa hasilnya bertambah 4 setiap langkah.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '22'),
          PretestOption(id: 'B', label: 'B', text: '24'),
          PretestOption(id: 'C', label: 'C', text: '26'),
          PretestOption(id: 'D', label: 'D', text: '28'),
        ],
      ),
      PretestQuestion(
        id: 'multiplication-posttest-10',
        stepLabel: '10 / 10',
        topic: 'Posttest Perkalian',
        prompt:
            'Sinta membuat paket hadiah. Setiap paket berisi 3 pensil dan 2 penghapus. Jika Sinta membuat 8 paket, berapa jumlah semua benda di dalam paket?',
        helper: 'Hitung isi satu paket, lalu kalikan dengan jumlah paket.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '24'),
          PretestOption(id: 'B', label: 'B', text: '32'),
          PretestOption(id: 'C', label: 'C', text: '40'),
          PretestOption(id: 'D', label: 'D', text: '48'),
        ],
      ),
    ],
    pretestCorrectAnswers: {
      'multiplication-pretest-1': 'B',
      'multiplication-pretest-2': 'B',
      'multiplication-pretest-3': 'A',
    },
    posttestCorrectAnswers: {
      'multiplication-posttest-1': 'C',
      'multiplication-posttest-2': 'B',
      'multiplication-posttest-3': 'B',
      'multiplication-posttest-4': 'A',
      'multiplication-posttest-5': 'C',
      'multiplication-posttest-6': 'C',
      'multiplication-posttest-7': 'A',
      'multiplication-posttest-8': 'A',
      'multiplication-posttest-9': 'B',
      'multiplication-posttest-10': 'C',
    },
    focusAreas: [
      AssessmentFocusArea(
        title: 'Makna perkalian',
        description:
            'Hubungkan perkalian dengan kelompok benda dan penjumlahan berulang.',
        severity: 'Prasyarat penting',
      ),
      AssessmentFocusArea(
        title: 'Soal cerita',
        description:
            'Tentukan operasi dari kalimat: jumlah kelompok, isi tiap kelompok, lalu totalnya.',
        severity: 'Latihan inti',
      ),
      AssessmentFocusArea(
        title: 'Pola perkalian',
        description:
            'Gunakan pola hasil perkalian untuk menebak langkah berikutnya.',
        severity: 'Penguatan',
      ),
    ],
    readyPathDescription:
        'Lanjut ke materi perkalian, lalu kerjakan posttest setelah selesai belajar.',
    reviewPathDescription:
        'Mulai dari makna perkalian sebagai penjumlahan berulang sebelum latihan soal cerita.',
    workspaceIntroLine1:
        'Oke, sebelum mulai belajar perkalian, kamu mau belajar lewat penjelasan atau video singkat?',
    workspaceIntroLine2:
        'Kita akan fokus pada makna perkalian sebagai kelompok yang sama besar, lalu cek sebentar sebelum posttest.',
    workspaceExplanation:
        'Perkalian adalah cara cepat untuk menjumlahkan kelompok yang sama besar. Contohnya 4 x 3 berarti ada 4 kelompok, setiap kelompok berisi 3 benda. Jadi 4 x 3 sama dengan 3 + 3 + 3 + 3, hasilnya 12.',
    workspaceVideoTitle: 'Perkalian dari kelompok benda',
    workspaceQuizQuestion:
        'Jika ada 4 kelompok dan setiap kelompok berisi 3 benda, berapa jumlah semua benda?',
    workspaceQuizOptions: ['7', '12', '16'],
    workspaceQuizCorrectAnswer: '12',
    workspaceQuizCorrectFeedback:
        'Benar. 4 kelompok berisi 3 sama dengan 3 + 3 + 3 + 3 = 12.',
    workspaceQuizReviewFeedback: 'Hampir. Hitung 3 sebanyak 4 kali.',
  );

  static const algebra = HardcodedAssessmentPack(
    id: 'algebra',
    level: HardcodedAssessmentLevel.juniorHigh,
    levelLabel: 'SMP',
    topicTitle: 'Aljabar',
    pretestTitle: 'Pretest Aljabar',
    posttestTitle: 'Posttest Aljabar',
    pretestQuestions: [
      PretestQuestion(
        id: 'algebra-pretest-1',
        stepLabel: '1 / 3',
        topic: 'Pretest Aljabar',
        prompt: 'Hasil dari (-3) x 4 + 5 adalah ...',
        helper: 'Kerjakan perkalian bilangan negatif dulu, lalu tambahkan 5.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '-17'),
          PretestOption(id: 'B', label: 'B', text: '-7'),
          PretestOption(id: 'C', label: 'C', text: '7'),
          PretestOption(id: 'D', label: 'D', text: '17'),
        ],
      ),
      PretestQuestion(
        id: 'algebra-pretest-2',
        stepLabel: '2 / 3',
        topic: 'Pretest Aljabar',
        prompt: 'Manakah yang merupakan bentuk faktor dari x^2 + 5x + 6?',
        helper: 'Cari dua bilangan yang jumlahnya 5 dan hasil kalinya 6.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '(x + 1)(x + 6)'),
          PretestOption(id: 'B', label: 'B', text: '(x + 2)(x + 3)'),
          PretestOption(id: 'C', label: 'C', text: '(x - 2)(x - 3)'),
          PretestOption(id: 'D', label: 'D', text: '(x + 5)(x + 6)'),
        ],
      ),
      PretestQuestion(
        id: 'algebra-pretest-3',
        stepLabel: '3 / 3',
        topic: 'Pretest Aljabar',
        prompt: 'Jika x = 2, maka nilai dari x^2 - 3x + 2 adalah ...',
        helper: 'Substitusikan x = 2 ke setiap x pada bentuk aljabar.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '0'),
          PretestOption(id: 'B', label: 'B', text: '2'),
          PretestOption(id: 'C', label: 'C', text: '4'),
          PretestOption(id: 'D', label: 'D', text: '8'),
        ],
      ),
    ],
    posttestQuestions: [
      PretestQuestion(
        id: 'algebra-posttest-1',
        stepLabel: '1 / 10',
        topic: 'Posttest Aljabar',
        prompt:
            'Manakah pasangan bilangan yang jika dijumlahkan hasilnya 7 dan jika dikalikan hasilnya 12?',
        helper: 'Cari pasangan yang memenuhi jumlah dan hasil kali sekaligus.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '1 dan 12'),
          PretestOption(id: 'B', label: 'B', text: '2 dan 6'),
          PretestOption(id: 'C', label: 'C', text: '3 dan 4'),
          PretestOption(id: 'D', label: 'D', text: '-3 dan -4'),
        ],
      ),
      PretestQuestion(
        id: 'algebra-posttest-2',
        stepLabel: '2 / 10',
        topic: 'Posttest Aljabar',
        prompt: 'Faktor dari x^2 + 7x + 12 adalah ...',
        helper: 'Cari dua bilangan yang jumlahnya 7 dan hasil kalinya 12.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '(x + 3)(x + 4)'),
          PretestOption(id: 'B', label: 'B', text: '(x - 3)(x - 4)'),
          PretestOption(id: 'C', label: 'C', text: '(x + 2)(x + 6)'),
          PretestOption(id: 'D', label: 'D', text: '(x + 1)(x + 12)'),
        ],
      ),
      PretestQuestion(
        id: 'algebra-posttest-3',
        stepLabel: '3 / 10',
        topic: 'Posttest Aljabar',
        prompt: 'Akar-akar dari persamaan x^2 + 7x + 12 = 0 adalah ...',
        helper: 'Faktorkan dulu, lalu gunakan sifat hasil kali nol.',
        options: [
          PretestOption(id: 'A', label: 'A', text: 'x1 = 3 dan x2 = 4'),
          PretestOption(id: 'B', label: 'B', text: 'x1 = -3 dan x2 = -4'),
          PretestOption(id: 'C', label: 'C', text: 'x1 = 2 dan x2 = 6'),
          PretestOption(id: 'D', label: 'D', text: 'x1 = -2 dan x2 = -6'),
        ],
      ),
      PretestQuestion(
        id: 'algebra-posttest-4',
        stepLabel: '4 / 10',
        topic: 'Posttest Aljabar',
        prompt: 'Persamaan x^2 - 5x + 6 = 0 dapat difaktorkan menjadi ...',
        helper: 'Cari dua bilangan yang jumlahnya -5 dan hasil kalinya 6.',
        options: [
          PretestOption(id: 'A', label: 'A', text: '(x + 2)(x + 3) = 0'),
          PretestOption(id: 'B', label: 'B', text: '(x - 2)(x - 3) = 0'),
          PretestOption(id: 'C', label: 'C', text: '(x + 1)(x - 6) = 0'),
          PretestOption(id: 'D', label: 'D', text: '(x - 1)(x + 6) = 0'),
        ],
      ),
      PretestQuestion(
        id: 'algebra-posttest-5',
        stepLabel: '5 / 10',
        topic: 'Posttest Aljabar',
        prompt: 'Akar-akar dari persamaan x^2 - 5x + 6 = 0 adalah ...',
        helper: 'Setiap faktor dibuat sama dengan nol.',
        options: [
          PretestOption(id: 'A', label: 'A', text: 'x1 = -2 dan x2 = -3'),
          PretestOption(id: 'B', label: 'B', text: 'x1 = 2 dan x2 = 3'),
          PretestOption(id: 'C', label: 'C', text: 'x1 = 1 dan x2 = 6'),
          PretestOption(id: 'D', label: 'D', text: 'x1 = -1 dan x2 = -6'),
        ],
      ),
      PretestQuestion(
        id: 'algebra-posttest-6',
        stepLabel: '6 / 10',
        topic: 'Posttest Aljabar',
        prompt:
            'Jika (x - 4)(x + 2) = 0, maka nilai x yang memenuhi adalah ...',
        helper: 'Gunakan sifat hasil kali nol pada kedua faktor.',
        options: [
          PretestOption(id: 'A', label: 'A', text: 'x = 4 atau x = -2'),
          PretestOption(id: 'B', label: 'B', text: 'x = -4 atau x = 2'),
          PretestOption(id: 'C', label: 'C', text: 'x = 4 atau x = 2'),
          PretestOption(id: 'D', label: 'D', text: 'x = -4 atau x = -2'),
        ],
      ),
      PretestQuestion(
        id: 'algebra-posttest-7',
        stepLabel: '7 / 10',
        topic: 'Posttest Aljabar',
        prompt:
            'Manakah persamaan kuadrat yang memiliki akar x1 = 5 dan x2 = -1?',
        helper: 'Bentuk persamaan dari akar adalah (x - akar1)(x - akar2) = 0.',
        options: [
          PretestOption(id: 'A', label: 'A', text: 'x^2 - 4x - 5 = 0'),
          PretestOption(id: 'B', label: 'B', text: 'x^2 + 4x - 5 = 0'),
          PretestOption(id: 'C', label: 'C', text: 'x^2 - 5x - 1 = 0'),
          PretestOption(id: 'D', label: 'D', text: 'x^2 + 5x - 4 = 0'),
        ],
      ),
      PretestQuestion(
        id: 'algebra-posttest-8',
        stepLabel: '8 / 10',
        topic: 'Posttest Aljabar',
        prompt:
            'Untuk persamaan x^2 - 8x + 15 = 0, dua bilangan yang dicari saat faktorisasi harus ...',
        helper:
            'Pada x^2 + bx + c, cari dua bilangan berjumlah b dan berproduk c.',
        options: [
          PretestOption(
            id: 'A',
            label: 'A',
            text: 'jumlahnya -8 dan hasil kalinya 15',
          ),
          PretestOption(
            id: 'B',
            label: 'B',
            text: 'jumlahnya 8 dan hasil kalinya 15',
          ),
          PretestOption(
            id: 'C',
            label: 'C',
            text: 'jumlahnya -8 dan hasil kalinya -15',
          ),
          PretestOption(
            id: 'D',
            label: 'D',
            text: 'jumlahnya 15 dan hasil kalinya -8',
          ),
        ],
      ),
      PretestQuestion(
        id: 'algebra-posttest-9',
        stepLabel: '9 / 10',
        topic: 'Posttest Aljabar',
        prompt: 'Akar-akar dari persamaan x^2 - 8x + 15 = 0 adalah ...',
        helper:
            'Faktorkan persamaan, lalu tentukan nilai x dari setiap faktor.',
        options: [
          PretestOption(id: 'A', label: 'A', text: 'x1 = 3 dan x2 = 5'),
          PretestOption(id: 'B', label: 'B', text: 'x1 = -3 dan x2 = -5'),
          PretestOption(id: 'C', label: 'C', text: 'x1 = 1 dan x2 = 15'),
          PretestOption(id: 'D', label: 'D', text: 'x1 = -1 dan x2 = -15'),
        ],
      ),
      PretestQuestion(
        id: 'algebra-posttest-10',
        stepLabel: '10 / 10',
        topic: 'Posttest Aljabar',
        prompt:
            'Diketahui persamaan x^2 + 2x - 15 = 0. Langkah faktorisasi yang benar adalah ...',
        helper: 'Cari dua bilangan yang jumlahnya 2 dan hasil kalinya -15.',
        options: [
          PretestOption(
            id: 'A',
            label: 'A',
            text: '(x + 3)(x + 5) = 0, maka x = -3 atau x = -5',
          ),
          PretestOption(
            id: 'B',
            label: 'B',
            text: '(x - 3)(x - 5) = 0, maka x = 3 atau x = 5',
          ),
          PretestOption(
            id: 'C',
            label: 'C',
            text: '(x + 5)(x - 3) = 0, maka x = -5 atau x = 3',
          ),
          PretestOption(
            id: 'D',
            label: 'D',
            text: '(x - 5)(x + 3) = 0, maka x = 5 atau x = -3',
          ),
        ],
      ),
    ],
    pretestCorrectAnswers: {
      'algebra-pretest-1': 'B',
      'algebra-pretest-2': 'B',
      'algebra-pretest-3': 'A',
    },
    posttestCorrectAnswers: {
      'algebra-posttest-1': 'C',
      'algebra-posttest-2': 'A',
      'algebra-posttest-3': 'B',
      'algebra-posttest-4': 'B',
      'algebra-posttest-5': 'B',
      'algebra-posttest-6': 'A',
      'algebra-posttest-7': 'A',
      'algebra-posttest-8': 'A',
      'algebra-posttest-9': 'A',
      'algebra-posttest-10': 'C',
    },
    focusAreas: [
      AssessmentFocusArea(
        title: 'Operasi bilangan negatif',
        description:
            'Pastikan tanda negatif tetap benar sebelum masuk faktorisasi.',
        severity: 'Prasyarat penting',
      ),
      AssessmentFocusArea(
        title: 'Faktorisasi kuadrat',
        description:
            'Cari dua bilangan dari hubungan jumlah koefisien tengah dan hasil kali konstanta.',
        severity: 'Latihan inti',
      ),
      AssessmentFocusArea(
        title: 'Konsep akar persamaan',
        description:
            'Hubungkan faktor sama dengan nol ke nilai x1 dan x2 yang memenuhi.',
        severity: 'Penguatan',
      ),
    ],
    readyPathDescription:
        'Lanjut ke materi faktorisasi persamaan kuadrat, lalu kerjakan posttest aljabar.',
    reviewPathDescription:
        'Mulai dari operasi bilangan negatif, substitusi, dan makna faktor sebelum mencari x1 dan x2.',
    workspaceIntroLine1:
        'Oke, sebelum mulai aljabar persamaan kuadrat, kamu mau penjelasan atau video singkat?',
    workspaceIntroLine2:
        'Kita fokus ke cara mencari x1 dan x2 lewat faktorisasi, bukan sekadar hafal rumus.',
    workspaceExplanation:
        'Untuk x^2 + 7x + 12 = 0, cari dua bilangan yang jumlahnya 7 dan hasil kalinya 12, yaitu 3 dan 4. Maka bentuknya (x + 3)(x + 4) = 0. Karena hasil kali nol, salah satu faktor harus nol, jadi x = -3 atau x = -4.',
    workspaceVideoTitle: 'Mencari x1 dan x2 dengan faktorisasi',
    workspaceQuizQuestion:
        'Jika (x + 3)(x + 4) = 0, nilai x yang memenuhi adalah ...',
    workspaceQuizOptions: [
      'x = -3 atau x = -4',
      'x = 3 atau x = 4',
      'x = -7 atau x = 12',
    ],
    workspaceQuizCorrectAnswer: 'x = -3 atau x = -4',
    workspaceQuizCorrectFeedback:
        'Benar. Setiap faktor dibuat nol: x + 3 = 0 atau x + 4 = 0.',
    workspaceQuizReviewFeedback: 'Hampir. Ingat, jika x + 3 = 0 maka x = -3.',
  );
}
