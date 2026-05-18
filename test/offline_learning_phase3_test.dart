import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wicara_mobile/src/features/offline_learning/data/local_curriculum_repository.dart';
import 'package:wicara_mobile/src/features/offline_learning/data/local_mastery_repository.dart';
import 'package:wicara_mobile/src/features/offline_learning/data/local_session_repository.dart';
import 'package:wicara_mobile/src/features/offline_learning/data/local_wicara_database.dart';
import 'package:wicara_mobile/src/features/offline_learning/data/sync_outbox_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalWicaraDatabase database;
  late Future<String> Function(String path) assetLoader;

  setUp(() async {
    sqfliteFfiInit();
    tempDir = await Directory.systemTemp.createTemp('wicara_phase3_test_');
    database = LocalWicaraDatabase(
      databaseFactoryOverride: databaseFactoryFfi,
      databasePathProvider: () async => tempDir.path,
      databaseName: 'offline_phase3_test.db',
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

  test('loads BE-aligned pilot curriculum slice into local database', () async {
    final curriculum = LocalCurriculumRepository(
      database: database,
      assetLoader: assetLoader,
    );

    final result = await curriculum.loadPilotSlice(clearExisting: true);

    expect(result.seeded, isTrue);
    expect(result.conceptsCount, greaterThan(0));
    expect(result.edgesCount, greaterThan(0));

    final concepts = await curriculum.listConcepts(subjectCode: 'matematika');
    expect(
      concepts.any((concept) => concept.id == 'km_d_matematika_bilangan_bulat'),
      isTrue,
    );
    expect(
      concepts.any((concept) => concept.id == 'km_d_matematika_fungsi_dasar'),
      isTrue,
    );

    final edges = await curriculum.listEdges();
    expect(
      edges.any(
        (edge) =>
            edge.fromConceptId == 'km_d_matematika_bentuk_aljabar' &&
            edge.toConceptId ==
                'km_d_matematika_sifat_komutatif_asosiatif_distributif',
      ),
      isTrue,
    );
  });

  test(
    'persists local session and mastery state after database reopen',
    () async {
      final sessionRepository = LocalSessionRepository(database: database);
      final masteryRepository = LocalMasteryRepository(database: database);

      final session = await sessionRepository.createLearningSession(
        targetConceptId: 'km_d_matematika_fungsi_dasar',
        sessionType: 'offline_pretest_pilot',
        currentStage: 'diagnose',
        metadata: const {'source': 'phase3_test'},
      );

      await masteryRepository.upsertState(
        const LocalMasteryStateRecord(
          conceptId: 'km_d_matematika_fungsi_dasar',
          status: 'ready',
          masteryScore: 0.42,
          confidenceScore: 0.61,
          evidenceCount: 3,
          dirty: true,
        ),
      );

      await database.close();

      final reopenedDatabase = LocalWicaraDatabase(
        databaseFactoryOverride: databaseFactoryFfi,
        databasePathProvider: () async => tempDir.path,
        databaseName: 'offline_phase3_test.db',
        enforcePlatformSupport: false,
      );
      final reopenedSessions = LocalSessionRepository(
        database: reopenedDatabase,
      );
      final reopenedMastery = LocalMasteryRepository(
        database: reopenedDatabase,
      );

      final restoredSession = await reopenedSessions.getSessionById(session.id);
      final restoredMastery = await reopenedMastery.getState(
        'km_d_matematika_fungsi_dasar',
      );

      expect(restoredSession, isNotNull);
      expect(restoredSession?.sessionType, 'offline_pretest_pilot');
      expect(restoredMastery, isNotNull);
      expect(restoredMastery?.masteryScore, closeTo(0.42, 0.0001));
      expect(restoredMastery?.dirty, isTrue);

      await reopenedDatabase.close();
    },
  );

  test('records unsynced local input events in sync outbox', () async {
    final sessionRepository = LocalSessionRepository(database: database);
    final outboxRepository = SyncOutboxRepository(database: database);

    final session = await sessionRepository.createLearningSession(
      targetConceptId: 'km_d_matematika_laju_perubahan_sederhana',
      sessionType: 'offline_tutoring_pilot',
    );
    final event = await sessionRepository.appendInputEvent(
      sessionId: session.id,
      conceptId: 'km_d_matematika_laju_perubahan_sederhana',
      eventType: 'text',
      textPayload: 'Saya masih bingung kenapa laju bisa negatif.',
      aiAudit: const {'runtime_target': 'deterministic_local'},
    );

    await outboxRepository.enqueue(
      entityType: 'local_input_events',
      entityId: event.id,
      operation: 'insert',
      payload: {
        'session_id': session.id,
        'event_id': event.id,
        'event_type': event.eventType,
      },
    );

    final pending = await outboxRepository.listPending();
    expect(pending, hasLength(1));
    expect(pending.first.entityType, 'local_input_events');
    expect(pending.first.entityId, event.id);
    expect(pending.first.status, 'pending');
  });
}
