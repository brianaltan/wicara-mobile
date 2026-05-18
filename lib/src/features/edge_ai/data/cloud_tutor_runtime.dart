import '../domain/edge_model_router.dart';

class CloudTutorRuntime {
  const CloudTutorRuntime();

  Future<String> generate({
    required EdgeTaskType task,
    required String prompt,
    required CloudTextGenerator cloudGenerator,
  }) async {
    final cloudText = (await cloudGenerator())?.trim() ?? '';
    if (cloudText.isEmpty) {
      throw StateError(
        'Cloud tutor fallback returned empty text for task $task.',
      );
    }
    return cloudText;
  }
}
