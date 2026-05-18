import 'dart:async';

import '../../edge_ai/domain/edge_ai_models.dart';
import '../../offline_learning/data/local_curriculum_repository.dart';
import '../../offline_learning/data/local_mastery_repository.dart';
import '../../offline_learning/data/local_session_repository.dart';
import '../../offline_learning/data/local_wicara_database.dart';
import '../../offline_learning/data/sync_outbox_repository.dart';
import 'local_evidence_evaluator.dart';
import 'local_graph_scope_builder.dart';
import 'local_pretest_decision_engine.dart';
import 'local_pretest_diagnosis_service.dart';
import 'local_pretest_models.dart';
import 'local_pretest_question_generator.dart';
import '../../pretest/domain/pretest_models.dart';
import '../../pretest/domain/pretest_repository.dart';
import '../../pretest/data/api_pretest_repository.dart';
import '../../pretest/data/pretest_session_store.dart';

class LocalPretestEngine {
  LocalPretestEngine({
    required LocalWicaraDatabase localDatabase,
    required PretestSessionStore pretestSessionStore,
    LocalCurriculumRepository? localCurriculumRepository,
    LocalMasteryRepository? localMasteryRepository,
    LocalSessionRepository? localSessionRepository,
    SyncOutboxRepository? syncOutboxRepository,
    LocalPretestDecisionEngine? decisionEngine,
    LocalEvidenceEvaluator? evidenceEvaluator,
    LocalPretestDiagnosisService? diagnosisService,
    LocalPretestQuestionGenerator? questionGenerator,
    LocalGraphScopeBuilder? graphScopeBuilder,
    ApiPretestRepository? backendRepository,
    this.forceLocalForPilot = true,
    this.allowBackendFallback = false,
    this.maxDepth = 2,
    this.maxQuestions = 3,
    this.maxNodesVisited = 5,
  }) : _database = localDatabase,
       _pretestSessionStore = pretestSessionStore,
       _localCurriculum =
           localCurriculumRepository ??
           LocalCurriculumRepository(database: localDatabase),
       _localMastery =
           localMasteryRepository ??
           LocalMasteryRepository(database: localDatabase),
       _localSessions =
           localSessionRepository ??
           LocalSessionRepository(database: localDatabase),
       _syncOutbox =
           syncOutboxRepository ??
           SyncOutboxRepository(database: localDatabase),
       _graphScopeBuilder = graphScopeBuilder ?? const LocalGraphScopeBuilder(),
       _decisionEngine = decisionEngine ?? LocalPretestDecisionEngine(),
       _evidenceEvaluator = evidenceEvaluator ?? const LocalEvidenceEvaluator(),
       _diagnosisService = diagnosisService ?? LocalPretestDiagnosisService(),
       _questionGenerator =
           questionGenerator ?? const LocalPretestQuestionGenerator(),
       _backendRepository = backendRepository;

  final LocalWicaraDatabase _database;
  final PretestSessionStore _pretestSessionStore;
  final LocalCurriculumRepository _localCurriculum;
  final LocalMasteryRepository _localMastery;
  final LocalSessionRepository _localSessions;
  final SyncOutboxRepository _syncOutbox;
  final LocalGraphScopeBuilder _graphScopeBuilder;
  final LocalPretestDecisionEngine _decisionEngine;
  final LocalEvidenceEvaluator _evidenceEvaluator;
  final LocalPretestDiagnosisService _diagnosisService;
  final LocalPretestQuestionGenerator _questionGenerator;
  final ApiPretestRepository? _backendRepository;
  final bool forceLocalForPilot;
  final bool allowBackendFallback;
  final int maxDepth;
  final int maxQuestions;
  final int maxNodesVisited;

  String? _activeLocalSessionId;
  String? _lastCompletedLocalSessionId;
  Map<String, dynamic>? _latestDiagnosis;
  Future<PretestQuestion> fetchCurrentQuestion() async {
    if (!_canUseLocal) {
      return _fetchBackendQuestionOrThrow();
    }
    if (forceLocalForPilot) {
      return _withFallback(
        _fetchCurrentQuestionLocal,
        _fetchBackendQuestionOrThrow,
      );
    }
    if (_backendRepository != null) {
      final backend = _backendRepository;
      try {
        return await backend.fetchCurrentQuestion();
      } on Exception {
        return _fetchCurrentQuestionLocal();
      }
    }
    return _fetchCurrentQuestionLocal();
  }

  Future<PretestAnswerResult> submitAnswer(PretestAnswer answer) async {
    if (!_canUseLocal) {
      return _submitAnswerBackendOrThrow(answer);
    }
    if (forceLocalForPilot) {
      return _withFallback(
        () => _submitAnswerLocal(answer),
        () => _submitAnswerBackendOrThrow(answer),
      );
    }
    if (_backendRepository != null) {
      final backend = _backendRepository;
      try {
        return await backend.submitAnswer(answer);
      } on Exception {
        return _submitAnswerLocal(answer);
      }
    }
    return _submitAnswerLocal(answer);
  }

  Future<KnowledgeState> selectPath(String pathOption) async {
    if (pathOption.trim().isEmpty) {
      throw const PretestException('Path option tidak boleh kosong.');
    }
    if (_latestDiagnosis != null) {
      final diagnosis = <String, dynamic>{
        ..._latestDiagnosis!,
        'recommended_path': pathOption.trim(),
      };
      final localKnowledgeState = knowledgeStateFromDiagnosis(diagnosis);
      await _persistPathSelection(pathOption.trim(), diagnosis: diagnosis);
      if (_backendRepository != null && allowBackendFallback) {
        final backend = _backendRepository;
        try {
          return await backend.selectPath(pathOption.trim());
        } on Exception {
          return localKnowledgeState;
        }
      }
      return localKnowledgeState;
    }
    if (forceLocalForPilot) {
      throw const PretestException(
        'Diagnosis lokal belum tersedia. Selesaikan pretest terlebih dahulu.',
      );
    }
    if (_backendRepository != null) {
      final backend = _backendRepository;
      return backend.selectPath(pathOption.trim());
    }
    throw const PretestException(
      'Diagnosis lokal belum tersedia. Selesaikan pretest terlebih dahulu.',
    );
  }

  bool get _canUseLocal => _database.isPlatformSupported;

  Future<PretestQuestion> _fetchCurrentQuestionLocal() async {
    final active = await _findOrCreateActiveLocalSession();
    final metadata = _sessionMetadata(active.metadata);
    final state = _map(metadata['decision_state']);
    if (state.isEmpty) {
      throw const PretestException('State pretest lokal tidak valid.');
    }
    final graphScope = _map(metadata['graph_scope']);
    final generatedPackCountBefore = _generatedPackCount(state);
    final question = await _questionFromState(
      state: state,
      graphScope: graphScope,
    );
    if (_generatedPackCount(state) != generatedPackCountBefore) {
      final nextMetadata = <String, dynamic>{
        ...metadata,
        'decision_state': state,
      };
      await _localSessions.updateSession(
        sessionId: active.id,
        metadata: nextMetadata,
        dirty: true,
      );
    }
    _activeLocalSessionId = active.id;
    return _toPretestQuestion(question);
  }

  Future<PretestAnswerResult> _submitAnswerLocal(PretestAnswer answer) async {
    if (answer.optionId.trim().isEmpty) {
      throw const PretestException('Choose an answer before continuing.');
    }
    final active = await _requireActiveLocalSession();
    final metadata = _sessionMetadata(active.metadata);
    final state = _map(metadata['decision_state']);
    final graphScope = _map(metadata['graph_scope']);
    if (state.isEmpty || graphScope.isEmpty) {
      throw const PretestException('Session pretest lokal tidak valid.');
    }

    final question = await _questionFromState(
      state: state,
      graphScope: graphScope,
    );
    if (answer.questionId.trim() != question.id) {
      throw const PretestException(
        'Question mismatch. Muat ulang pretest dan coba lagi.',
      );
    }
    final selectedOption = question.options.firstWhere(
      (option) => option.id == answer.optionId,
      orElse: () => throw const PretestException(
        'Selected option was not found for this question.',
      ),
    );

    final knownConceptCodes =
        ((graphScope['nodes'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (node) => _string((node).cast<String, dynamic>()['concept_code']),
            )
            .where((code) => code.isNotEmpty)
            .toSet();
    final evaluation = await _evidenceEvaluator.evaluate(
      question: question,
      selectedOption: selectedOption,
      typedReasoning: answer.typedReasoning,
      usedCanvas: answer.usedCanvas,
      knownConceptCodes: knownConceptCodes,
    );

    final attemptId = 'local_attempt_${DateTime.now().microsecondsSinceEpoch}';
    final event = await _localSessions.appendInputEvent(
      sessionId: active.id,
      conceptId: question.conceptCode,
      eventType: 'quiz_answer',
      actorType: 'learner',
      textPayload: answer.typedReasoning.trim(),
      selectedOptionId: answer.optionId,
      aiAudit: <String, dynamic>{
        'runtime_target': 'litert_gemma4',
        'execution_location': 'device',
        'reasoning_source': evaluation.reasoningEvaluationSource,
        'reasoning_signal': evaluation.reasoningSignal,
        'diagnostic_signal': evaluation.diagnosticSignal,
        'confidence': evaluation.confidence,
      },
    );
    await _syncOutbox.enqueue(
      entityType: 'local_input_events',
      entityId: event.id,
      operation: 'insert',
      payload: <String, dynamic>{
        'session_id': active.id,
        'concept_code': question.conceptCode,
        'event_type': event.eventType,
      },
    );

    final nextDecisionState = _decisionEngine.recordAttempt(
      state,
      conceptCode: question.conceptCode,
      difficulty: question.difficulty,
      isCorrect: evaluation.isCorrect,
      questionStem: question.prompt,
      correctOptionText: question.options
          .firstWhere((option) => option.isCorrect)
          .text,
      selectedOptionText: selectedOption.text,
      typedReasoning: answer.typedReasoning.trim(),
      expectedReasoning: question.expectedReasoning,
      evidenceScore: evaluation.evidenceScore,
      confidence: evaluation.confidence,
      answerScore: evaluation.answerScore,
      reasoningScore: evaluation.reasoningScore,
      canvasScore: evaluation.canvasScore,
      diagnosticSignal: evaluation.diagnosticSignal,
      reasoningSignal: evaluation.reasoningSignal,
      reasoningSource: evaluation.reasoningEvaluationSource,
    );
    final decision = _decisionEngine.decide(
      nextDecisionState,
      lastConceptCode: question.conceptCode,
      lastDifficulty: question.difficulty,
      lastIsCorrect: evaluation.isCorrect,
      graphScope: graphScope,
    );
    final stateAfterDecision = decision.state;
    final nextAction = decision.action;
    if (_string(nextAction['type']) == 'finalize') {
      final stopReason = _string(nextAction['reason'], fallback: 'completed');
      final runtimeAuditBase = _buildRuntimeAudit(stateAfterDecision);
      final diagnosis = await _diagnosisService.finalize(
        graphScope: graphScope,
        decisionState: stateAfterDecision,
        stopReason: stopReason,
        runtimeAudit: runtimeAuditBase,
      );
      final runtimeAudit =
          (diagnosis['runtime_audit'] as Map?)?.cast<String, dynamic>() ??
          runtimeAuditBase;
      final completedMetadata = <String, dynamic>{
        ...metadata,
        'status': 'completed',
        'decision_state': <String, dynamic>{
          ...stateAfterDecision,
          'stop_reason': stopReason,
        },
        'diagnosis': diagnosis,
        'runtime_audit': runtimeAudit,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _localSessions.updateSession(
        sessionId: active.id,
        status: 'completed',
        currentStage: 'diagnosed',
        metadata: completedMetadata,
        dirty: true,
      );
      await _syncOutbox.enqueue(
        entityType: 'local_learning_sessions',
        entityId: active.id,
        operation: 'update',
        payload: <String, dynamic>{
          'status': 'completed',
          'stop_reason': stopReason,
        },
      );
      await _upsertMasteryFromDiagnosis(diagnosis);
      _latestDiagnosis = diagnosis;
      _lastCompletedLocalSessionId = active.id;
      _activeLocalSessionId = null;
      return PretestAnswerResult(
        completed: true,
        diagnosis: knowledgeStateFromDiagnosis(diagnosis),
      );
    }

    final nextConceptCode = _string(nextAction['concept_code']);
    final nextDifficulty = _string(nextAction['difficulty']);
    final nextQuestionCount = _int(stateAfterDecision['question_count']) + 1;
    final progressedState = <String, dynamic>{
      ...stateAfterDecision,
      'current_concept_code': nextConceptCode,
      'current_difficulty': nextDifficulty,
      'current_question_id': _localQuestionId(nextConceptCode, nextDifficulty),
      'question_count': nextQuestionCount,
    };
    final nextQuestion = await _buildQuestion(
      decisionState: progressedState,
      conceptCode: nextConceptCode,
      difficulty: nextDifficulty,
      graphScope: graphScope,
      progressCurrent: nextQuestionCount,
      progressMax: _int(
        progressedState['max_questions'],
        fallback: maxQuestions,
      ),
    );
    final nextMetadata = <String, dynamic>{
      ...metadata,
      'decision_state': progressedState,
      'last_attempt_id': attemptId,
      'last_evaluation': evaluation.toJson(),
    };
    await _localSessions.updateSession(
      sessionId: active.id,
      status: 'active',
      currentStage: 'diagnose',
      metadata: nextMetadata,
      dirty: true,
    );
    _activeLocalSessionId = active.id;
    return PretestAnswerResult(
      completed: false,
      nextQuestion: _toPretestQuestion(nextQuestion),
    );
  }

  Future<void> _persistPathSelection(
    String pathOption, {
    required Map<String, dynamic> diagnosis,
  }) async {
    final activeId = _activeLocalSessionId ?? _lastCompletedLocalSessionId;
    if (activeId == null || activeId.isEmpty) {
      return;
    }
    final session = await _localSessions.getSessionById(activeId);
    if (session == null) {
      return;
    }
    final metadata = _sessionMetadata(session.metadata);
    metadata['selected_path'] = pathOption;
    metadata['diagnosis'] = diagnosis;
    metadata['selected_path_at'] = DateTime.now().toUtc().toIso8601String();
    await _localSessions.updateSession(
      sessionId: activeId,
      metadata: metadata,
      dirty: true,
    );
    await _syncOutbox.enqueue(
      entityType: 'learning_goal_path_selection',
      entityId: activeId,
      operation: 'insert',
      payload: <String, dynamic>{'path_option': pathOption},
    );
  }

  Future<void> _upsertMasteryFromDiagnosis(
    Map<String, dynamic> diagnosis,
  ) async {
    final now = DateTime.now().toUtc();
    final nodes = (diagnosis['nodes'] as List?) ?? const <dynamic>[];
    for (final rawNode in nodes) {
      if (rawNode is! Map) {
        continue;
      }
      final node = rawNode.cast<String, dynamic>();
      final status = _string(node['status']);
      if (status == 'not_tested') {
        continue;
      }
      final conceptId = _string(node['concept_id']);
      if (conceptId.isEmpty) {
        continue;
      }
      final summary =
          (node['evidence_summary'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final attempts = _int(summary['attempt_count']);
      final existing = await _localMastery.getState(conceptId);
      final evidenceCount = (existing?.evidenceCount ?? 0) + attempts;
      final localStatus = localMasteryStatusFromDiagnosisNodeStatus(status);
      final nextReview = now.add(
        localStatus == 'ready'
            ? const Duration(days: 3)
            : const Duration(days: 1),
      );
      await _localMastery.upsertState(
        LocalMasteryStateRecord(
          conceptId: conceptId,
          status: localStatus,
          masteryScore: _double(node['mastery_score']).clamp(0, 1).toDouble(),
          confidenceScore: _double(node['confidence']).clamp(0, 1).toDouble(),
          evidenceCount: evidenceCount,
          lastEvaluatedAt: now.toIso8601String(),
          nextReviewAt: nextReview.toIso8601String(),
          dirty: true,
        ),
      );
      await _syncOutbox.enqueue(
        entityType: 'local_mastery_states',
        entityId: conceptId,
        operation: 'upsert',
        payload: <String, dynamic>{
          'status': localStatus,
          'mastery_score': _double(node['mastery_score']),
          'confidence_score': _double(node['confidence']),
          'evidence_count': evidenceCount,
        },
      );
    }
  }

  Map<String, dynamic> _buildRuntimeAudit(Map<String, dynamic> decisionState) {
    final nodeResults =
        (decisionState['node_results'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final generatedPacks = _map(decisionState['generated_packs']);
    final generatedPackSources = <String>[];
    var readyPackCount = 0;
    var partialPackCount = 0;
    var failedPackCount = 0;
    var droppedDifficultyCount = 0;
    var maxRetryUsed = 0;
    for (final rawPack in generatedPacks.values) {
      final wrapped = _map(rawPack);
      final source = _string(wrapped['source']);
      final status = _string(wrapped['status']);
      final attemptCount = _int(wrapped['attempt_count']);
      final droppedDifficulties = _stringList(wrapped['dropped_difficulties']);
      if (source.isNotEmpty) {
        generatedPackSources.add(source);
      }
      if (status == 'ready') {
        readyPackCount += 1;
      } else if (status == 'partial') {
        partialPackCount += 1;
      } else if (status == 'failed') {
        failedPackCount += 1;
      }
      droppedDifficultyCount += droppedDifficulties.length;
      if (attemptCount > maxRetryUsed) {
        maxRetryUsed = attemptCount;
      }
    }
    final generatedByLiteRt = generatedPackSources.any(
      (source) => source.toLowerCase().contains('litert'),
    );
    var usesLiteRt = false;
    for (final rawNode in nodeResults.values) {
      if (rawNode is! Map) {
        continue;
      }
      final node = rawNode.cast<String, dynamic>();
      final attempts =
          (node['attempts'] as List?)
              ?.whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList(growable: false) ??
          const <Map<String, dynamic>>[];
      for (final attempt in attempts) {
        final source = _string(attempt['reasoning_source']).toLowerCase();
        if (source.contains('litert') || source.contains('litert_lm')) {
          usesLiteRt = true;
          break;
        }
      }
      if (usesLiteRt) {
        break;
      }
    }
    return <String, dynamic>{
      'primary_ai_runtime': usesLiteRt || generatedByLiteRt
          ? 'litert_gemma4'
          : 'deterministic_local_heuristic',
      'cloud_calls_used': 0,
      'execution_location': 'device',
      'question_pack_generation': generatedByLiteRt
          ? 'litert_gemma4'
          : (generatedPackSources.isEmpty ? 'deterministic_template' : 'mixed'),
      'generated_pack_count': generatedPacks.length,
      'generated_pack_ready_count': readyPackCount,
      'generated_pack_partial_count': partialPackCount,
      'generated_pack_failed_count': failedPackCount,
      'generated_pack_dropped_difficulty_count': droppedDifficultyCount,
      'question_pack_retry_max_attempts_used': maxRetryUsed,
    };
  }

  Future<LocalLearningSessionRecord> _requireActiveLocalSession() async {
    if (_activeLocalSessionId != null && _activeLocalSessionId!.isNotEmpty) {
      final existing = await _localSessions.getSessionById(
        _activeLocalSessionId!,
      );
      if (existing != null &&
          existing.status != 'completed' &&
          _sessionMatchesCurrentGoal(existing)) {
        return existing;
      }
    }
    final active = await _findActiveLocalSession();
    if (active != null) {
      _activeLocalSessionId = active.id;
      return active;
    }
    return _createLocalSession();
  }

  Future<LocalLearningSessionRecord> _findOrCreateActiveLocalSession() async {
    final active = await _findActiveLocalSession();
    if (active != null) {
      _activeLocalSessionId = active.id;
      return active;
    }
    return _createLocalSession();
  }

  Future<LocalLearningSessionRecord?> _findActiveLocalSession() async {
    final sessions = await _localSessions.listSessions();
    for (final session in sessions) {
      if (session.sessionType != 'offline_pretest_pilot') {
        continue;
      }
      if ((session.status == 'active' || session.status == 'awaiting_answer') &&
          _sessionMatchesCurrentGoal(session)) {
        return session;
      }
    }
    return null;
  }

  Future<LocalLearningSessionRecord> _createLocalSession() async {
    await _localCurriculum.ensurePilotSliceSeeded();
    final preferredSubjectCode = _string(
      _pretestSessionStore.targetSubjectCode,
      fallback: 'matematika',
    );
    var concepts = await _localCurriculum.listConcepts(
      subjectCode: preferredSubjectCode,
    );
    if (concepts.isEmpty && preferredSubjectCode != 'matematika') {
      concepts = await _localCurriculum.listConcepts(subjectCode: 'matematika');
    }
    if (concepts.isEmpty) {
      throw const PretestException(
        'Offline curriculum belum tersedia di device.',
      );
    }
    final edges = await _localCurriculum.listEdges();
    final target = _resolveTargetConcept(
      concepts,
      preferredConceptCode: _pretestSessionStore.targetConceptCode,
    );
    final graphScope = _graphScopeBuilder.build(
      concepts: concepts,
      edges: edges,
      targetConceptCode: target.code,
      maxDepth: maxDepth,
    );
    final decisionState = <String, dynamic>{
      'target_concept_code': target.code,
      'current_concept_code': target.code,
      'current_difficulty': 'medium',
      'current_question_id': _localQuestionId(target.code, 'medium'),
      'question_count': 1,
      'max_questions': maxQuestions,
      'max_depth': maxDepth,
      'max_nodes_visited': maxNodesVisited,
      'max_questions_per_node': 2,
      'confidence_threshold': 0.95,
      'probe_queue': _graphScopeBuilder.buildProbeQueue(graphScope),
      'generated_packs': <String, dynamic>{},
      'node_results': <String, dynamic>{},
      'confidence': 0.0,
      'stop_reason': null,
    };
    final metadata = <String, dynamic>{
      'engine': 'local_pretest_v1',
      'source': 'offline_pretest_phase4',
      'learning_goal_id': _pretestSessionStore.learningGoalId,
      'target_concept': <String, dynamic>{
        'concept_id': target.id,
        'concept_code': target.code,
        'title': target.title,
      },
      'graph_scope': graphScope,
      'decision_state': decisionState,
      'status': 'active',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    final created = await _localSessions.createLearningSession(
      targetConceptId: target.id,
      sessionType: 'offline_pretest_pilot',
      status: 'active',
      currentStage: 'diagnose',
      metadata: metadata,
    );
    _activeLocalSessionId = created.id;
    return created;
  }

  _TargetConcept _resolveTargetConcept(
    List<LocalConceptRecord> concepts, {
    String? preferredConceptCode,
  }) {
    final byCode = <String, LocalConceptRecord>{
      for (final concept in concepts) concept.code: concept,
    };
    final targetCode = _string(preferredConceptCode);
    if (targetCode.isEmpty) {
      throw const PretestException(
        'Target concept belum dipilih. Buka Learning Goal dan pilih node target dulu.',
      );
    }
    final concept = byCode[targetCode];
    if (concept == null) {
      throw PretestException(
        'Target concept "$targetCode" tidak ditemukan di kurikulum lokal.',
      );
    }
    return _TargetConcept(
      id: concept.id,
      code: concept.code,
      title: concept.title,
    );
  }

  bool _sessionMatchesCurrentGoal(LocalLearningSessionRecord session) {
    final currentGoalId = _string(_pretestSessionStore.learningGoalId);
    if (currentGoalId.isEmpty) {
      return true;
    }
    final metadata = _sessionMetadata(session.metadata);
    final sessionGoalId = _string(metadata['learning_goal_id']);
    return sessionGoalId == currentGoalId;
  }

  Future<LocalPretestQuestion> _questionFromState({
    required Map<String, dynamic> state,
    required Map<String, dynamic> graphScope,
  }) async {
    return _buildQuestion(
      decisionState: state,
      conceptCode: _string(state['current_concept_code']),
      difficulty: _string(state['current_difficulty'], fallback: 'medium'),
      graphScope: graphScope,
      progressCurrent: _int(state['question_count'], fallback: 1),
      progressMax: _int(state['max_questions'], fallback: maxQuestions),
    );
  }

  Future<LocalPretestQuestion> _buildQuestion({
    required Map<String, dynamic> decisionState,
    required String conceptCode,
    required String difficulty,
    required Map<String, dynamic> graphScope,
    required int progressCurrent,
    required int progressMax,
  }) async {
    final node = ((graphScope['nodes'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .firstWhere(
          (item) => _string(item['concept_code']) == conceptCode,
          orElse: () => const <String, dynamic>{},
        );
    final conceptTitle = _string(node['title'], fallback: conceptCode);
    final conceptDescription = _string(node['description']);
    final fallbackSeed = _templateForConcept(
      conceptCode: conceptCode,
      title: conceptTitle,
    );
    final generatedPack = await _ensureGeneratedPack(
      decisionState: decisionState,
      conceptCode: conceptCode,
      conceptTitle: conceptTitle,
      conceptDescription: conceptDescription,
    );
    final packQuestionCount = _packQuestionCount(generatedPack);
    final effectiveProgressMax = packQuestionCount <= 0
        ? progressMax
        : packQuestionCount;
    decisionState['max_questions'] = effectiveProgressMax;
    final item = _questionSeedForDifficulty(
      difficulty: difficulty,
      fallbackSeed: fallbackSeed,
      generatedPack: generatedPack,
    );
    final options = <LocalPretestOption>[];
    final labels = <String>['A', 'B', 'C', 'D'];
    for (var index = 0; index < item.options.length; index++) {
      final optionText = item.options[index];
      options.add(
        LocalPretestOption(
          id: labels[index],
          label: labels[index],
          text: optionText,
          isCorrect: optionText == item.correctOption,
        ),
      );
    }
    return LocalPretestQuestion(
      id: _localQuestionId(conceptCode, difficulty),
      packId: 'local_pack_$conceptCode',
      conceptCode: conceptCode,
      conceptTitle: conceptTitle,
      difficulty: difficulty,
      prompt: item.prompt,
      helper: item.helper.isNotEmpty
          ? item.helper
          : 'Pilih jawaban yang paling tepat untuk $conceptTitle.',
      expectedReasoning: item.explanation,
      options: options,
      progressCurrent: progressCurrent,
      progressMax: effectiveProgressMax,
    );
  }

  Future<Map<String, dynamic>?> _ensureGeneratedPack({
    required Map<String, dynamic> decisionState,
    required String conceptCode,
    required String conceptTitle,
    required String conceptDescription,
  }) async {
    final generatedPacks = _map(decisionState['generated_packs']);
    final existingRaw = _map(generatedPacks[conceptCode]);
    if (existingRaw.isNotEmpty) {
      final existingPack = _extractGeneratedPack(existingRaw);
      if (existingPack != null && existingPack.isNotEmpty) {
        return existingPack;
      }
      // If previously cached pack has no valid question at all, clear it so
      // a future fetch can re-attempt LiteRT generation after runtime warms up.
      generatedPacks.remove(conceptCode);
      decisionState['generated_packs'] = generatedPacks;
    }

    await _ensureRuntimeReadyOrThrow(conceptCode: conceptCode);
    final generated = await _questionGenerator.generatePack(
      conceptCode: conceptCode,
      conceptTitle: conceptTitle,
      conceptDescription: conceptDescription,
    );
    if (generated == null) {
      throw PretestException(
        'PretestGenerationError: model lokal gagal membuat soal untuk $conceptCode.',
      );
    }
    final generatedPack = _extractGeneratedPack(generated);
    if (generatedPack == null || generatedPack.isEmpty) {
      throw PretestException(
        'PretestGenerationError: output model lokal tidak valid untuk $conceptCode.',
      );
    }
    generatedPacks[conceptCode] = generated;
    decisionState['generated_packs'] = generatedPacks;
    return generatedPack;
  }

  Future<void> _ensureRuntimeReadyOrThrow({required String conceptCode}) async {
    final runtime = _questionGenerator.runtime;
    EdgeRuntimeStatus status;
    try {
      status = await runtime.getStatus();
    } catch (error) {
      throw PretestException(
        'PretestGenerationError: gagal membaca status runtime lokal ($error).',
      );
    }
    if (!status.available) {
      throw const PretestException(
        'PretestGenerationError: LiteRT tidak tersedia di device ini. Jalankan pretest di Android fisik.',
      );
    }
    final modelPath = status.modelPath ?? status.defaultModelPath;
    if (!status.defaultModelExists &&
        (modelPath == null || modelPath.isEmpty)) {
      throw const PretestException(
        'PretestGenerationError: model belum terpasang. Buka Pengaturan AI Lokal untuk install model dulu.',
      );
    }
    if (status.loaded) {
      return;
    }
    try {
      status = await runtime
          .initialize(modelPath: modelPath)
          .timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw const PretestException(
        'PretestGenerationError: initialize model timeout (120s).',
      );
    } catch (error) {
      throw PretestException(
        'PretestGenerationError: initialize model gagal ($error).',
      );
    }
    if (!status.isReady) {
      throw PretestException(
        'PretestGenerationError: runtime belum siap (status=${status.executionLocation}).',
      );
    }
  }

  Map<String, dynamic>? _extractGeneratedPack(Object? raw) {
    final wrapped = _map(raw);
    if (wrapped.isEmpty) {
      return null;
    }
    final nested = _map(wrapped['pack']);
    final candidate = nested.isNotEmpty ? nested : wrapped;
    final valid = <String, dynamic>{};
    for (final difficulty in const <String>['easy', 'medium', 'hard']) {
      if (_seedFromDynamic(candidate[difficulty]) != null) {
        valid[difficulty] = candidate[difficulty];
      }
    }
    return valid;
  }

  _QuestionSeed _questionSeedForDifficulty({
    required String difficulty,
    required _QuestionTemplate fallbackSeed,
    required Map<String, dynamic>? generatedPack,
  }) {
    final generated = generatedPack == null
        ? null
        : _seedFromDynamic(generatedPack[difficulty.toLowerCase()]);
    if (generated != null) {
      return generated;
    }
    return switch (difficulty.toLowerCase()) {
      'easy' => fallbackSeed.easy,
      'hard' => fallbackSeed.hard,
      _ => fallbackSeed.medium,
    };
  }

  _QuestionSeed? _seedFromDynamic(Object? raw) {
    final node = _map(raw);
    if (node.isEmpty) {
      return null;
    }
    final prompt = _string(node['prompt']);
    final options = _stringList(node['options']);
    final correctOption = _string(node['correct_option']);
    final explanation = _string(node['explanation']);
    final helper = _string(node['helper_text']);
    if (prompt.isEmpty || options.length != 4 || correctOption.isEmpty) {
      return null;
    }
    if (!options.contains(correctOption)) {
      return null;
    }
    return _QuestionSeed(
      prompt: prompt,
      correctOption: correctOption,
      options: options,
      explanation: explanation.isEmpty
          ? 'Tinjau langkah pengerjaan untuk memastikan pilihan jawaban.'
          : explanation,
      helper: helper,
    );
  }

  int _generatedPackCount(Map<String, dynamic> decisionState) {
    final generatedPacks = _map(decisionState['generated_packs']);
    return generatedPacks.length;
  }

  int _packQuestionCount(Map<String, dynamic>? generatedPack) {
    if (generatedPack == null || generatedPack.isEmpty) {
      return 3;
    }
    var count = 0;
    for (final difficulty in const <String>['easy', 'medium', 'hard']) {
      if (_seedFromDynamic(generatedPack[difficulty]) != null) {
        count += 1;
      }
    }
    return count <= 0 ? 3 : count;
  }

  Future<T> _withFallback<T>(
    Future<T> Function() localFn,
    Future<T> Function() backendFn,
  ) async {
    try {
      return await localFn();
    } on Exception {
      if (_backendRepository == null || !allowBackendFallback) {
        rethrow;
      }
      return backendFn();
    }
  }

  Future<PretestQuestion> _fetchBackendQuestionOrThrow() async {
    final backend = _backendRepository;
    if (backend == null) {
      throw const PretestException(
        'Backend pretest repository belum dikonfigurasi.',
      );
    }
    return backend.fetchCurrentQuestion();
  }

  Future<PretestAnswerResult> _submitAnswerBackendOrThrow(
    PretestAnswer answer,
  ) async {
    final backend = _backendRepository;
    if (backend == null) {
      throw const PretestException(
        'Backend pretest repository belum dikonfigurasi.',
      );
    }
    return backend.submitAnswer(answer);
  }

  Map<String, dynamic> _sessionMetadata(Map<String, dynamic> metadata) {
    return metadata.map((key, value) {
      if (value is Map) {
        return MapEntry(key, value.map((k, v) => MapEntry(k.toString(), v)));
      }
      return MapEntry(key, value);
    });
  }

  static PretestQuestion _toPretestQuestion(LocalPretestQuestion value) {
    return PretestQuestion(
      id: value.id,
      packId: value.packId,
      stepLabel: 'Question ${value.progressCurrent} of ${value.progressMax}',
      topic: value.conceptTitle,
      prompt: value.prompt,
      helper: value.helper,
      progressCurrent: value.progressCurrent,
      progressMax: value.progressMax,
      options: value.options
          .map(
            (option) => PretestOption(
              id: option.id,
              label: option.label,
              text: option.text,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _QuestionTemplate {
  const _QuestionTemplate({
    required this.easy,
    required this.medium,
    required this.hard,
  });

  final _QuestionSeed easy;
  final _QuestionSeed medium;
  final _QuestionSeed hard;
}

class _QuestionSeed {
  const _QuestionSeed({
    required this.prompt,
    required this.correctOption,
    required this.options,
    required this.explanation,
    this.helper = '',
  });

  final String prompt;
  final String correctOption;
  final List<String> options;
  final String explanation;
  final String helper;
}

class _TargetConcept {
  const _TargetConcept({
    required this.id,
    required this.code,
    required this.title,
  });

  final String id;
  final String code;
  final String title;
}

_QuestionTemplate _templateForConcept({
  required String conceptCode,
  required String title,
}) {
  final text = '$conceptCode $title'.toLowerCase();
  if (text.contains('laju_perubahan') || text.contains('turunan')) {
    return const _QuestionTemplate(
      easy: _QuestionSeed(
        prompt:
            'Kecepatan berubah dari 10 km/jam menjadi 16 km/jam dalam 3 jam. Laju perubahan rata-ratanya adalah ...',
        correctOption: '2 km/jam per jam',
        options: <String>[
          '6 km/jam per jam',
          '2 km/jam per jam',
          '3 km/jam per jam',
          '26 km/jam per jam',
        ],
        explanation:
            'Laju perubahan rata-rata = (16 - 10) / 3 = 2 km/jam per jam.',
      ),
      medium: _QuestionSeed(
        prompt: 'Jika f(x)=3x^2-4x+5, maka turunan pertamanya adalah ...',
        correctOption: '6x - 4',
        options: <String>['3x - 4', '6x - 4', '6x + 5', 'x^2 - 4'],
        explanation:
            'Turunkan tiap suku: 3x^2 menjadi 6x, -4x menjadi -4, konstanta 5 menjadi 0.',
      ),
      hard: _QuestionSeed(
        prompt:
            'Kemiringan garis singgung kurva f(x)=x^3-2x pada x=2 adalah ...',
        correctOption: '10',
        options: <String>['6', '8', '10', '12'],
        explanation: 'f\'(x)=3x^2-2. Saat x=2, f\'(2)=12-2=10.',
      ),
    );
  }
  if (text.contains('fungsi')) {
    return const _QuestionTemplate(
      easy: _QuestionSeed(
        prompt: 'Jika f(x)=2x+1, maka nilai f(3) adalah ...',
        correctOption: '7',
        options: <String>['5', '6', '7', '8'],
        explanation: 'Substitusi x=3: 2(3)+1 = 7.',
      ),
      medium: _QuestionSeed(
        prompt: 'Jika g(x)=x^2-1, maka nilai g(4) adalah ...',
        correctOption: '15',
        options: <String>['7', '12', '15', '17'],
        explanation: 'Substitusi x=4: 4^2 - 1 = 15.',
      ),
      hard: _QuestionSeed(
        prompt: 'Jika f(x)=3x-2 dan g(x)=x+5, maka f(g(2)) adalah ...',
        correctOption: '19',
        options: <String>['7', '13', '19', '21'],
        explanation: 'g(2)=7, lalu f(7)=3(7)-2=19.',
      ),
    );
  }
  if (text.contains('aljabar')) {
    return const _QuestionTemplate(
      easy: _QuestionSeed(
        prompt: 'Hasil dari 2x + 3x adalah ...',
        correctOption: '5x',
        options: <String>['5', '5x', '6x', 'x^2'],
        explanation: 'Gabungkan suku sejenis: 2x + 3x = 5x.',
      ),
      medium: _QuestionSeed(
        prompt: 'Bentuk sederhana dari 3(x+2)-x adalah ...',
        correctOption: '2x + 6',
        options: <String>['2x + 6', '3x + 2', '2x + 2', 'x + 6'],
        explanation: '3(x+2)=3x+6, lalu dikurangi x menjadi 2x+6.',
      ),
      hard: _QuestionSeed(
        prompt: 'Faktorkan x^2 + 5x + 6.',
        correctOption: '(x+2)(x+3)',
        options: <String>[
          '(x+1)(x+6)',
          '(x+2)(x+3)',
          '(x-2)(x-3)',
          '(x+5)(x+1)',
        ],
        explanation:
            'Dua angka yang jumlahnya 5 dan hasil kali 6 adalah 2 dan 3.',
      ),
    );
  }
  if (text.contains('proporsi') || text.contains('rasio')) {
    return const _QuestionTemplate(
      easy: _QuestionSeed(
        prompt:
            'Jika rasio buku:pena = 2:3 dan jumlah buku 8, maka jumlah pena adalah ...',
        correctOption: '12',
        options: <String>['10', '12', '14', '16'],
        explanation: '2 ke 8 berarti dikali 4, jadi pena 3x4=12.',
      ),
      medium: _QuestionSeed(
        prompt:
            'Peta berskala 1:100.000. Jarak pada peta 4 cm. Jarak sebenarnya adalah ...',
        correctOption: '4 km',
        options: <String>['400 m', '4 km', '40 km', '0.4 km'],
        explanation: '4 cm x 100.000 = 400.000 cm = 4 km.',
      ),
      hard: _QuestionSeed(
        prompt:
            'Campuran sirup:air = 1:5. Jika total campuran 18 liter, volume sirup adalah ...',
        correctOption: '3 liter',
        options: <String>['2 liter', '3 liter', '4 liter', '5 liter'],
        explanation: 'Total bagian 6. Sirup 1/6 x 18 = 3 liter.',
      ),
    );
  }
  return _QuestionTemplate(
    easy: _QuestionSeed(
      prompt: 'Dalam topik $title, nilai 12 ditambah 5 menjadi ...',
      correctOption: '17',
      options: const <String>['15', '16', '17', '18'],
      explanation: 'Perhitungan langsung: 12+5=17.',
    ),
    medium: _QuestionSeed(
      prompt: 'Dalam konteks $title, selisih tetap antara 18 dan 24 adalah ...',
      correctOption: '6',
      options: const <String>['4', '6', '8', '12'],
      explanation: 'Selisih 24-18=6.',
    ),
    hard: _QuestionSeed(
      prompt:
          'Untuk latihan $title, jika 6 kelompok masing-masing 4 lalu dikurangi 2, hasilnya ...',
      correctOption: '22',
      options: const <String>['20', '22', '24', '26'],
      explanation: '6x4=24, kemudian 24-2=22.',
    ),
  );
}

String _localQuestionId(String conceptCode, String difficulty) {
  return 'local_${conceptCode}_$difficulty';
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

double _double(Object? value, {double fallback = 0}) {
  return switch (value) {
    final int number => number.toDouble(),
    final double number => number,
    final String text => double.tryParse(text) ?? fallback,
    _ => fallback,
  };
}

int _int(Object? value, {int fallback = 0}) {
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text) ?? fallback,
    _ => fallback,
  };
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => _string(item))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _string(Object? value, {String fallback = ''}) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}
