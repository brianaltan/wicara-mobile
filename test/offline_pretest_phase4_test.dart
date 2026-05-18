import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wicara_mobile/src/features/edge_ai/domain/edge_ai_models.dart';
import 'package:wicara_mobile/src/features/edge_ai/domain/edge_ai_runtime.dart';
import 'package:wicara_mobile/src/features/offline_learning/data/local_curriculum_repository.dart';
import 'package:wicara_mobile/src/features/offline_learning/data/local_mastery_repository.dart';
import 'package:wicara_mobile/src/features/offline_learning/data/local_session_repository.dart';
import 'package:wicara_mobile/src/features/offline_learning/data/local_wicara_database.dart';
import 'package:wicara_mobile/src/features/offline_pretest/data/local_pretest_repository.dart';
import 'package:wicara_mobile/src/features/offline_learning/data/sync_outbox_repository.dart';
import 'package:wicara_mobile/src/features/offline_pretest/domain/local_evidence_evaluator.dart';
import 'package:wicara_mobile/src/features/pretest/data/pretest_session_store.dart';
import 'package:wicara_mobile/src/features/pretest/domain/pretest_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalWicaraDatabase database;
  late Future<String> Function(String path) assetLoader;

  setUp(() async {
    sqfliteFfiInit();
    tempDir = await Directory.systemTemp.createTemp('wicara_phase4_test_');
    database = LocalWicaraDatabase(
      databaseFactoryOverride: databaseFactoryFfi,
      databasePathProvider: () async => tempDir.path,
      databaseName: 'offline_phase4_test.db',
      enforcePlatformSupport: false,
    );
    assetLoader = (assetPath) async {
      final file = File(p.join(Directory.current.path, assetPath));
      return file.readAsString();
    };
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'runs local adaptive pretest and finalizes diagnosis without backend',
    () async {
      final curriculum = LocalCurriculumRepository(
        database: database,
        assetLoader: assetLoader,
      );
      final sessions = LocalSessionRepository(database: database);
      final mastery = LocalMasteryRepository(database: database);
      final outbox = SyncOutboxRepository(database: database);
      final repository = LocalPretestRepository(
        localDatabase: database,
        pretestSessionStore: PretestSessionStore()
          ..learningGoalId = 'local-goal-1',
        localCurriculumRepository: curriculum,
        localSessionRepository: sessions,
        localMasteryRepository: mastery,
        syncOutboxRepository: outbox,
        evidenceEvaluator: LocalEvidenceEvaluator(
          runtime: const _FakeRuntime(ready: false),
        ),
        forceLocalForPilot: true,
        allowBackendFallback: false,
      );

      var question = await repository.fetchCurrentQuestion();
      PretestAnswerResult? answerResult;
      for (var i = 0; i < 12; i++) {
        answerResult = await repository.submitAnswer(
          PretestAnswer(
            questionId: question.id,
            optionId: question.options.first.id,
            confidence: 6,
            typedReasoning: 'Saya coba hitung dari data soal.',
          ),
        );
        if (answerResult.completed) {
          break;
        }
        question = answerResult.nextQuestion!;
      }

      expect(answerResult, isNotNull);
      expect(answerResult!.completed, isTrue);
      expect(answerResult.diagnosis, isNotNull);
      expect(answerResult.diagnosis!.recommendedPath.isNotEmpty, isTrue);
      expect(answerResult.diagnosis!.nodeReports.isNotEmpty, isTrue);

      final persistedSessions = await sessions.listSessions();
      expect(
        persistedSessions.any(
          (session) =>
              session.sessionType == 'offline_pretest_pilot' &&
              session.status == 'completed',
        ),
        isTrue,
      );
      final masteryStates = await mastery.listStates();
      expect(masteryStates.isNotEmpty, isTrue);

      final pendingOutbox = await outbox.listPending();
      expect(pendingOutbox.isNotEmpty, isTrue);
    },
  );
}

class _FakeRuntime implements EdgeAiRuntime {
  const _FakeRuntime({required this.ready});

  final bool ready;

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<EdgeGenerationResult> generate(EdgeGenerationRequest request) async {
    return EdgeGenerationResult(
      requestId: request.requestId,
      text: 'ok',
      finishReason: 'completed',
      metrics: const EdgeGenerationMetrics(
        totalMs: 20,
        inputChars: 10,
        outputChars: 2,
        outputCharsPerSecond: 100,
      ),
      runtime: 'litert_lm',
      executionLocation: 'device',
      fallbackUsed: false,
      raw: const {},
    );
  }

  @override
  Future<EdgeJsonGenerationResult> generateJson(
    EdgeJsonGenerationRequest request,
  ) async {
    final base = await generate(
      EdgeGenerationRequest(requestId: request.requestId, prompt: request.user),
    );
    return EdgeJsonGenerationResult(
      rawText: '{}',
      parsedJsonString: '{}',
      base: base,
    );
  }

  @override
  Future<EdgeRuntimeStatus> getStatus() async {
    return EdgeRuntimeStatus(
      available: true,
      loaded: ready,
      runtime: 'litert_lm',
      backend: 'cpu',
      executionLocation: ready ? 'device' : 'not_ready',
      defaultModelExists: true,
    );
  }

  @override
  Future<EdgeRuntimeStatus> initialize({
    String? modelPath,
    EdgeRuntimeBackend backend = EdgeRuntimeBackend.cpu,
    int maxTokens = 256,
  }) async {
    return getStatus();
  }

  @override
  Future<EdgeModelInstallResult> installModel({
    required String url,
    String? sha256,
    bool overwrite = false,
    String? modelPath,
  }) async {
    return const EdgeModelInstallResult(
      success: true,
      skipped: true,
      modelPath: '/tmp/model.litertlm',
      bytesDownloaded: 0,
      sha256: '',
    );
  }

  @override
  Future<void> unload() async {}
}
