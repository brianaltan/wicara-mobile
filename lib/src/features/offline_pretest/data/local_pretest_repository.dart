import '../../offline_learning/data/local_curriculum_repository.dart';
import '../../offline_learning/data/local_mastery_repository.dart';
import '../../offline_learning/data/local_session_repository.dart';
import '../../offline_learning/data/local_wicara_database.dart';
import '../../offline_learning/data/sync_outbox_repository.dart';
import '../../pretest/data/api_pretest_repository.dart';
import '../../pretest/data/pretest_session_store.dart';
import '../../pretest/domain/pretest_models.dart';
import '../../pretest/domain/pretest_repository.dart';
import '../domain/local_evidence_evaluator.dart';
import '../domain/local_graph_scope_builder.dart';
import '../domain/local_pretest_decision_engine.dart';
import '../domain/local_pretest_diagnosis_service.dart';
import '../domain/local_pretest_engine.dart';

class LocalPretestRepository implements PretestRepository {
  LocalPretestRepository({
    required LocalWicaraDatabase localDatabase,
    required PretestSessionStore pretestSessionStore,
    LocalCurriculumRepository? localCurriculumRepository,
    LocalMasteryRepository? localMasteryRepository,
    LocalSessionRepository? localSessionRepository,
    SyncOutboxRepository? syncOutboxRepository,
    LocalPretestDecisionEngine? decisionEngine,
    LocalEvidenceEvaluator? evidenceEvaluator,
    LocalPretestDiagnosisService? diagnosisService,
    LocalGraphScopeBuilder? graphScopeBuilder,
    ApiPretestRepository? backendRepository,
    bool forceLocalForPilot = true,
    bool allowBackendFallback = false,
    int maxDepth = 2,
    int maxQuestions = 10,
    int maxNodesVisited = 5,
    String preferredTargetConceptCode =
        'km_d_matematika_laju_perubahan_sederhana',
  }) : _engine = LocalPretestEngine(
         localDatabase: localDatabase,
         pretestSessionStore: pretestSessionStore,
         localCurriculumRepository: localCurriculumRepository,
         localMasteryRepository: localMasteryRepository,
         localSessionRepository: localSessionRepository,
         syncOutboxRepository: syncOutboxRepository,
         decisionEngine: decisionEngine,
         evidenceEvaluator: evidenceEvaluator,
         diagnosisService: diagnosisService,
         graphScopeBuilder: graphScopeBuilder,
         backendRepository: backendRepository,
         forceLocalForPilot: forceLocalForPilot,
         allowBackendFallback: allowBackendFallback,
         maxDepth: maxDepth,
         maxQuestions: maxQuestions,
         maxNodesVisited: maxNodesVisited,
         preferredTargetConceptCode: preferredTargetConceptCode,
       );

  final LocalPretestEngine _engine;

  @override
  Future<PretestQuestion> fetchCurrentQuestion() {
    return _engine.fetchCurrentQuestion();
  }

  @override
  Future<PretestAnswerResult> submitAnswer(PretestAnswer answer) {
    return _engine.submitAnswer(answer);
  }

  @override
  Future<KnowledgeState> selectPath(String pathOption) {
    return _engine.selectPath(pathOption);
  }
}
