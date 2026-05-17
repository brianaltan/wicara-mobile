import '../domain/edge_model_router.dart';

class DeterministicLocalRuntime {
  const DeterministicLocalRuntime();

  String generate({required EdgeTaskType task, required String prompt}) {
    final normalizedPrompt = prompt.toLowerCase();

    return switch (task) {
      EdgeTaskType.intentParse => _intentParse(normalizedPrompt),
      EdgeTaskType.tutorHint => _hint(normalizedPrompt),
      EdgeTaskType.tutorEvaluate => _evaluate(normalizedPrompt),
      EdgeTaskType.pretestReasoningGrade => _reasoningGrade(normalizedPrompt),
      EdgeTaskType.quizGenerate => _quizPrompt(normalizedPrompt),
      EdgeTaskType.summaryGenerate => _summary(normalizedPrompt),
      EdgeTaskType.tutorExplain => _explainFallback(normalizedPrompt),
    };
  }

  String _intentParse(String prompt) {
    if (prompt.contains('?')) {
      return 'intent=ask_question';
    }
    if (prompt.contains('bantu') || prompt.contains('tolong')) {
      return 'intent=request_help';
    }
    return 'intent=general_reflection';
  }

  String _hint(String prompt) {
    if (prompt.contains('turunan') || prompt.contains('derivative')) {
      return 'Petunjuk: lihat perubahan nilai fungsi saat x berubah sedikit, lalu coba bandingkan dua titik yang sangat dekat.';
    }
    return 'Petunjuk: pecah masalah jadi tiga langkah kecil, cek asumsi setiap langkah, lalu lanjutkan satu per satu.';
  }

  String _evaluate(String prompt) {
    if (prompt.contains('2x') || prompt.contains('benar')) {
      return 'Langkahmu sudah mendekati benar. Sekarang jelaskan kenapa aturan itu berlaku pada bentuk soalnya.';
    }
    return 'Jawabanmu belum konsisten. Coba cek kembali langkah pertama, lalu tulis ulang alasan untuk setiap transformasi.';
  }

  String _reasoningGrade(String prompt) {
    if (prompt.length < 30) {
      return 'Reasoning masih terlalu singkat; tambahkan alasan kenapa memilih operasi tersebut.';
    }
    return 'Reasoning cukup jelas secara struktur; sekarang perkuat dengan satu contoh numerik singkat.';
  }

  String _quizPrompt(String prompt) {
    return 'Coba jawab: jika f(x)=x^2, berapa turunan f\'(x), dan kenapa?';
  }

  String _summary(String prompt) {
    return 'Ringkas: fokus ke konsep inti, satu aturan utama, dan satu kesalahan umum yang perlu dihindari.';
  }

  String _explainFallback(String prompt) {
    if (prompt.contains('turunan') || prompt.contains('derivative')) {
      return 'Turunan menggambarkan seberapa cepat nilai fungsi berubah terhadap perubahan x. Bayangkan sebagai kemiringan garis singgung pada kurva di satu titik.';
    }
    return 'Kita mulai dari definisi inti, lanjut ke contoh singkat, lalu cek kembali dengan pertanyaan verifikasi.';
  }
}
