import '../domain/pretest_models.dart';
import '../domain/pretest_repository.dart';

class MockPretestRepository implements PretestRepository {
  const MockPretestRepository({this.delay = const Duration(milliseconds: 450)});

  final Duration delay;

  @override
  Future<PretestQuestion> fetchCurrentQuestion() async {
    await Future<void>.delayed(delay);

    return const PretestQuestion(
      id: 'multiplication-medium',
      packId: 'multiplication-pack',
      stepLabel: 'Question 1 of 10',
      topic: 'Perkalian',
      prompt:
          'Rina punya 4 kotak. Setiap kotak berisi 3 pensil. Berapa pensil semuanya?',
      helper: 'Pilih jawaban yang paling tepat.',
      progressCurrent: 1,
      progressMax: 10,
      options: [
        PretestOption(id: 'A', label: 'A', text: '7'),
        PretestOption(id: 'B', label: 'B', text: '12'),
        PretestOption(id: 'C', label: 'C', text: '14'),
        PretestOption(id: 'D', label: 'D', text: '16'),
      ],
    );
  }

  @override
  Future<PretestAnswerResult> submitAnswer(PretestAnswer answer) async {
    await Future<void>.delayed(delay);

    if (answer.optionId.isEmpty) {
      throw const PretestException('Choose an answer before continuing.');
    }
    if (answer.questionId == 'multiplication-medium') {
      return const PretestAnswerResult(
        completed: false,
        nextQuestion: PretestQuestion(
          id: 'multiplication-hard',
          packId: 'multiplication-pack',
          stepLabel: 'Question 2 of 10',
          topic: 'Perkalian',
          prompt:
              'Sebuah kelas punya 6 meja. Tiap meja dipakai 4 siswa. Jika 2 siswa tidak hadir, berapa siswa yang hadir?',
          helper: 'Hitung total lalu kurangi siswa yang tidak hadir.',
          progressCurrent: 2,
          progressMax: 10,
          options: [
            PretestOption(id: 'A', label: 'A', text: '20'),
            PretestOption(id: 'B', label: 'B', text: '22'),
            PretestOption(id: 'C', label: 'C', text: '24'),
            PretestOption(id: 'D', label: 'D', text: '26'),
          ],
        ),
      );
    }
    return const PretestAnswerResult(
      completed: true,
      diagnosis: KnowledgeState(
        skill: 'Perkalian siap',
        gapLabel: 'READY',
        message: 'Kamu sudah siap di Perkalian; cukup review singkat.',
        pathTitle: 'Review perkalian siap',
        pathMeta: 'Adaptive pretest complete',
        pathDescription: 'Mulai dari review singkat lalu lanjut ke latihan.',
        recommendedPath: 'review_only',
        pathOptions: ['review_only', 'target_reinforcement'],
      ),
    );
  }

  @override
  Future<KnowledgeState> selectPath(String pathOption) async {
    await Future<void>.delayed(delay);

    return const KnowledgeState(
      skill: 'Perkalian siap',
      gapLabel: 'READY',
      message: 'Path selected.',
      pathTitle: 'Personalized path generated',
      pathMeta: '12-15 min   •   3 skills',
      pathDescription: 'Start with the selected adaptive path.',
      recommendedPath: 'review_only',
      pathOptions: ['review_only', 'target_reinforcement'],
    );
  }
}
