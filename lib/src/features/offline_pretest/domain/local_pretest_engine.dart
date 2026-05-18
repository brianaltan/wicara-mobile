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

class LocalDiagnosisGenerationProgress {
  const LocalDiagnosisGenerationProgress({
    required this.active,
    required this.sessionId,
    required this.status,
    this.message = '',
    this.knowledgeState,
  });

  final bool active;
  final String sessionId;
  final String status;
  final String message;
  final KnowledgeState? knowledgeState;
}

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
  static final _diagnosisProgressController =
      StreamController<LocalDiagnosisGenerationProgress>.broadcast();

  static Stream<LocalDiagnosisGenerationProgress> get diagnosisProgressStream =>
      _diagnosisProgressController.stream;

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
    final attemptId = 'local_attempt_${DateTime.now().microsecondsSinceEpoch}';
    final canvasSnapshotPath = _nullableString(answer.canvasAssetId);
    final canvasStrokeCount = null;
    final evaluation = await _evidenceEvaluator.evaluate(
      question: question,
      selectedOption: selectedOption,
      typedReasoning: answer.typedReasoning,
      usedCanvas: answer.usedCanvas,
      canvasSnapshotPath: canvasSnapshotPath,
      canvasStrokeCount: canvasStrokeCount,
      knownConceptCodes: knownConceptCodes,
      allowLiteRtReasoning: false,
    );

    final event = await _localSessions.appendInputEvent(
      sessionId: active.id,
      conceptId: question.conceptCode,
      eventType: 'quiz_answer',
      actorType: 'learner',
      textPayload: answer.typedReasoning.trim(),
      selectedOptionId: answer.optionId,
      canvasSnapshot: answer.usedCanvas
          ? <String, dynamic>{
              'path': canvasSnapshotPath,
              'stroke_count': canvasStrokeCount,
            }
          : null,
      aiAudit: <String, dynamic>{
        'runtime_target': 'litert_gemma4',
        'execution_location': 'device',
        'reasoning_source': evaluation.reasoningEvaluationSource,
        'reasoning_status': answer.typedReasoning.trim().isEmpty
            ? 'no_reasoning_provided'
            : 'quick_heuristic_pending_litert',
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
      attemptId: attemptId,
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
      canvasUsed: answer.usedCanvas,
      canvasStrokeCount: evaluation.canvasStrokeCount,
      canvasSnapshotPath: evaluation.canvasSnapshotPath,
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
      final diagnosis = _diagnosisService.deterministicDiagnosis(
        graphScope: graphScope,
        decisionState: stateAfterDecision,
        stopReason: stopReason,
        runtimeAudit: runtimeAuditBase,
      );
      final runtimeAudit = <String, dynamic>{
        ...(diagnosis['runtime_audit'] as Map?)?.cast<String, dynamic>() ??
            runtimeAuditBase,
        'diagnosis_report_source': 'pending_local_generation',
      };
      diagnosis['runtime_audit'] = runtimeAudit;
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
      _scheduleReasoningEvaluationUpdate(
        sessionId: active.id,
        graphScope: graphScope,
        stopReason: stopReason,
        attemptId: attemptId,
        conceptCode: question.conceptCode,
        difficulty: question.difficulty,
        question: question,
        selectedOption: selectedOption,
        typedReasoning: answer.typedReasoning.trim(),
        usedCanvas: answer.usedCanvas,
        canvasSnapshotPath: canvasSnapshotPath,
        canvasStrokeCount: canvasStrokeCount,
        knownConceptCodes: knownConceptCodes,
      );
      _scheduleDiagnosisNarrative(
        sessionId: active.id,
        graphScope: graphScope,
        stopReason: stopReason,
      );
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
    _scheduleReasoningEvaluationUpdate(
      sessionId: active.id,
      graphScope: graphScope,
      stopReason: _string(progressedState['stop_reason'], fallback: 'ongoing'),
      attemptId: attemptId,
      conceptCode: question.conceptCode,
      difficulty: question.difficulty,
      question: question,
      selectedOption: selectedOption,
      typedReasoning: answer.typedReasoning.trim(),
      usedCanvas: answer.usedCanvas,
      canvasSnapshotPath: canvasSnapshotPath,
      canvasStrokeCount: canvasStrokeCount,
      knownConceptCodes: knownConceptCodes,
    );
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
    final goalId = _string(_pretestSessionStore.learningGoalId);
    final conceptCode = _string(_pretestSessionStore.targetConceptCode);
    final subjectCode = _string(_pretestSessionStore.targetSubjectCode);
    final target =
        (diagnosis['target'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final conceptTitle = _string(
      target['title'],
      fallback: _string(metadata['target_title'], fallback: conceptCode),
    );
    final trackId = _ensureLocalTrackId(
      existingTrackId: _pretestSessionStore.trackId,
      goalId: goalId,
      sessionId: activeId,
      conceptCode: conceptCode,
    );
    _pretestSessionStore.trackId = trackId;
    final module = _fallbackModuleForSubject(subjectCode);
    _pretestSessionStore.upsertLocalTrack(
      LocalTrackDraft(
        trackId: trackId,
        learningGoalId: goalId,
        conceptCode: conceptCode,
        conceptTitle: conceptTitle,
        subjectCode: subjectCode,
        moduleId: module.moduleId,
        moduleTitle: module.moduleTitle,
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
      ),
    );

    metadata['selected_path'] = pathOption;
    metadata['diagnosis'] = diagnosis;
    metadata['selected_path_at'] = DateTime.now().toUtc().toIso8601String();
    metadata['track_id'] = trackId;
    metadata['module_id'] = module.moduleId;
    metadata['module_title'] = module.moduleTitle;
    await _localSessions.updateSession(
      sessionId: activeId,
      metadata: metadata,
      dirty: true,
    );
    await _syncOutbox.enqueue(
      entityType: 'learning_goal_path_selection',
      entityId: activeId,
      operation: 'insert',
      payload: <String, dynamic>{
        'path_option': pathOption,
        'track_id': trackId,
        'module_id': module.moduleId,
      },
    );
  }

  String _ensureLocalTrackId({
    required String? existingTrackId,
    required String goalId,
    required String sessionId,
    required String conceptCode,
  }) {
    final existing = _string(existingTrackId);
    if (existing.isNotEmpty) {
      return existing;
    }
    final safeGoal = goalId.isNotEmpty ? goalId : 'local_goal';
    final safeConcept = conceptCode.isNotEmpty
        ? conceptCode.replaceAll(RegExp(r'[^a-zA-Z0-9_]+'), '_')
        : 'concept';
    return 'local_track_${safeGoal}_${safeConcept}_${sessionId.substring(0, sessionId.length > 8 ? 8 : sessionId.length)}';
  }

  _LocalModuleFallback _fallbackModuleForSubject(String subjectCode) {
    final normalized = subjectCode.trim().toLowerCase();
    if (normalized.contains('sd') || normalized.contains('mi')) {
      return const _LocalModuleFallback(
        moduleId: 'demo-module-perkalian',
        moduleTitle: 'Perkalian',
      );
    }
    return const _LocalModuleFallback(
      moduleId: 'demo-module-aljabar',
      moduleTitle: 'Aljabar dan pembuktian Al-Khawarizmi',
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

  void _scheduleReasoningEvaluationUpdate({
    required String sessionId,
    required Map<String, dynamic> graphScope,
    required String stopReason,
    required String attemptId,
    required String conceptCode,
    required String difficulty,
    required LocalPretestQuestion question,
    required LocalPretestOption selectedOption,
    required String typedReasoning,
    required bool usedCanvas,
    required String? canvasSnapshotPath,
    required int? canvasStrokeCount,
    required Set<String> knownConceptCodes,
  }) {
    if (typedReasoning.trim().isEmpty) {
      return;
    }
    unawaited(
      _runReasoningEvaluationUpdate(
        sessionId: sessionId,
        graphScope: graphScope,
        stopReason: stopReason,
        attemptId: attemptId,
        conceptCode: conceptCode,
        difficulty: difficulty,
        question: question,
        selectedOption: selectedOption,
        typedReasoning: typedReasoning,
        usedCanvas: usedCanvas,
        canvasSnapshotPath: canvasSnapshotPath,
        canvasStrokeCount: canvasStrokeCount,
        knownConceptCodes: knownConceptCodes,
      ),
    );
  }

  Future<void> _runReasoningEvaluationUpdate({
    required String sessionId,
    required Map<String, dynamic> graphScope,
    required String stopReason,
    required String attemptId,
    required String conceptCode,
    required String difficulty,
    required LocalPretestQuestion question,
    required LocalPretestOption selectedOption,
    required String typedReasoning,
    required bool usedCanvas,
    required String? canvasSnapshotPath,
    required int? canvasStrokeCount,
    required Set<String> knownConceptCodes,
  }) async {
    try {
      final refinedEvaluation = await _evidenceEvaluator.evaluate(
        question: question,
        selectedOption: selectedOption,
        typedReasoning: typedReasoning,
        usedCanvas: usedCanvas,
        canvasSnapshotPath: canvasSnapshotPath,
        canvasStrokeCount: canvasStrokeCount,
        knownConceptCodes: knownConceptCodes,
        allowLiteRtReasoning: true,
      );
      final reasoningSource = refinedEvaluation.reasoningEvaluationSource
          .toLowerCase();
      if (!reasoningSource.contains('litert')) {
        return;
      }

      final session = await _localSessions.getSessionById(sessionId);
      if (session == null) {
        return;
      }
      final metadata = _sessionMetadata(session.metadata);
      final state = _map(metadata['decision_state']);
      if (state.isEmpty) {
        return;
      }
      final updated = _replaceAttemptEvaluation(
        decisionState: state,
        conceptCode: conceptCode,
        difficulty: difficulty,
        attemptId: attemptId,
        evaluation: refinedEvaluation,
      );
      if (!updated) {
        return;
      }
      metadata['decision_state'] = state;
      metadata['last_evaluation'] = refinedEvaluation.toJson();

      if (session.status == 'completed') {
        final effectiveStopReason = _string(
          state['stop_reason'],
          fallback: stopReason,
        );
        final runtimeAudit = _buildRuntimeAudit(state);
        final previousDiagnosis = _map(metadata['diagnosis']);
        final recomputed = _diagnosisService.deterministicDiagnosis(
          graphScope: graphScope,
          decisionState: state,
          stopReason: effectiveStopReason,
          runtimeAudit: runtimeAudit,
        );
        final previousSummary = _string(previousDiagnosis['summary']);
        if (previousSummary.isNotEmpty) {
          recomputed['summary'] = previousSummary;
        }
        final previousAnalysis = _map(previousDiagnosis['analysis']);
        if (previousAnalysis.isNotEmpty) {
          recomputed['analysis'] = previousAnalysis;
        }
        final previousAudit = _map(previousDiagnosis['runtime_audit']);
        if (_string(previousAudit['diagnosis_report_source']) ==
            'litert_gemma4') {
          recomputed['runtime_audit'] = <String, dynamic>{
            ...runtimeAudit,
            ...previousAudit,
          };
        } else {
          recomputed['runtime_audit'] = <String, dynamic>{
            ...runtimeAudit,
            'diagnosis_report_source': 'pending_local_generation',
          };
        }
        metadata['diagnosis'] = recomputed;
        metadata['runtime_audit'] = recomputed['runtime_audit'];
        _latestDiagnosis = recomputed;
      }

      await _localSessions.updateSession(
        sessionId: sessionId,
        metadata: metadata,
        dirty: true,
      );
    } catch (_) {
      // Background refinement failure should not block user progression.
    }
  }

  void _scheduleDiagnosisNarrative({
    required String sessionId,
    required Map<String, dynamic> graphScope,
    required String stopReason,
  }) {
    _emitDiagnosisProgress(
      LocalDiagnosisGenerationProgress(
        active: true,
        sessionId: sessionId,
        status: 'running',
        message: 'AI sedang menulis catatan personal...',
      ),
    );
    unawaited(
      _runDiagnosisNarrative(
        sessionId: sessionId,
        graphScope: graphScope,
        stopReason: stopReason,
      ),
    );
  }

  Future<void> _runDiagnosisNarrative({
    required String sessionId,
    required Map<String, dynamic> graphScope,
    required String stopReason,
  }) async {
    try {
      final session = await _localSessions.getSessionById(sessionId);
      if (session == null) {
        _emitDiagnosisProgress(
          LocalDiagnosisGenerationProgress(
            active: false,
            sessionId: sessionId,
            status: 'failed',
            message: 'Session pretest tidak ditemukan.',
          ),
        );
        return;
      }

      final metadata = _sessionMetadata(session.metadata);
      final state = _map(metadata['decision_state']);
      if (state.isEmpty) {
        _emitDiagnosisProgress(
          LocalDiagnosisGenerationProgress(
            active: false,
            sessionId: sessionId,
            status: 'failed',
            message: 'State pretest tidak valid.',
          ),
        );
        return;
      }

      final effectiveStopReason = _string(
        state['stop_reason'],
        fallback: stopReason,
      );
      final baseDiagnosis = (_map(metadata['diagnosis']).isEmpty
          ? _diagnosisService.deterministicDiagnosis(
              graphScope: graphScope,
              decisionState: state,
              stopReason: effectiveStopReason,
              runtimeAudit: _buildRuntimeAudit(state),
            )
          : _map(metadata['diagnosis']));
      final enriched = await _diagnosisService.enrichNarrative(baseDiagnosis);
      final runtimeAudit = _map(enriched['runtime_audit']);
      if (_string(runtimeAudit['diagnosis_report_source']) ==
          'pending_local_generation') {
        enriched['runtime_audit'] = <String, dynamic>{
          ...runtimeAudit,
          'diagnosis_report_source': 'deterministic_local',
        };
      }
      metadata['diagnosis'] = enriched;
      metadata['runtime_audit'] = _map(enriched['runtime_audit']);
      await _localSessions.updateSession(
        sessionId: sessionId,
        metadata: metadata,
        dirty: true,
      );
      _latestDiagnosis = enriched;
      _emitDiagnosisProgress(
        LocalDiagnosisGenerationProgress(
          active: false,
          sessionId: sessionId,
          status: 'completed',
          message: 'Catatan personal AI selesai.',
          knowledgeState: knowledgeStateFromDiagnosis(enriched),
        ),
      );
    } catch (_) {
      _emitDiagnosisProgress(
        LocalDiagnosisGenerationProgress(
          active: false,
          sessionId: sessionId,
          status: 'failed',
          message: 'AI belum bisa menulis catatan personal untuk sesi ini.',
        ),
      );
    }
  }

  bool _replaceAttemptEvaluation({
    required Map<String, dynamic> decisionState,
    required String conceptCode,
    required String difficulty,
    required String attemptId,
    required LocalPretestEvaluation evaluation,
  }) {
    final nodeResults = _map(decisionState['node_results']);
    final node = _map(nodeResults[conceptCode]);
    if (node.isEmpty) {
      return false;
    }
    final attempts =
        (node['attempts'] as List?)
            ?.whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList(growable: true) ??
        <Map<String, dynamic>>[];
    final index = attempts.lastIndexWhere((attempt) {
      final byAttemptId = _string(attempt['attempt_id']);
      if (byAttemptId.isNotEmpty) {
        return byAttemptId == attemptId;
      }
      return _string(attempt['difficulty']) == difficulty;
    });
    if (index < 0) {
      return false;
    }
    final existing = attempts[index];
    attempts[index] = <String, dynamic>{
      ...existing,
      'reasoning_score': evaluation.reasoningScore == null
          ? null
          : _round4(evaluation.reasoningScore!),
      'reasoning_signal': evaluation.reasoningSignal,
      'reasoning_feedback': evaluation.reasoningFeedback,
      'reasoning_source': evaluation.reasoningEvaluationSource,
      'canvas_score': evaluation.canvasScore == null
          ? null
          : _round4(evaluation.canvasScore!),
      'canvas_status': evaluation.canvasStatus,
      'canvas_snapshot_path': evaluation.canvasSnapshotPath,
      'canvas_stroke_count': evaluation.canvasStrokeCount,
      'evidence_score': _round4(evaluation.evidenceScore),
      'confidence': _round4(evaluation.confidence),
      'diagnostic_signal': evaluation.diagnosticSignal,
      'prerequisite_gap_candidate': evaluation.prerequisiteGapCandidate,
    };
    node['attempts'] = attempts;
    nodeResults[conceptCode] = node;
    decisionState['node_results'] = nodeResults;
    return true;
  }

  void _emitDiagnosisProgress(LocalDiagnosisGenerationProgress progress) {
    if (_diagnosisProgressController.isClosed) {
      return;
    }
    _diagnosisProgressController.add(progress);
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

class _LocalModuleFallback {
  const _LocalModuleFallback({
    required this.moduleId,
    required this.moduleTitle,
  });

  final String moduleId;
  final String moduleTitle;
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
            '1) Hitung selisih kecepatan: 16-10=6. 2) Bagi dengan selang waktu 3 jam: 6/3=2. 3) Jadi laju perubahan 2 km/jam per jam.',
      ),
      medium: _QuestionSeed(
        prompt: 'Jika f(x)=3x^2-4x+5, maka turunan pertamanya adalah ...',
        correctOption: '6x - 4',
        options: <String>['3x - 4', '6x - 4', '6x + 5', 'x^2 - 4'],
        explanation:
            '1) Turunkan 3x^2 menjadi 6x. 2) Turunkan -4x menjadi -4. 3) Turunkan konstanta 5 menjadi 0, jadi hasil 6x-4.',
      ),
      hard: _QuestionSeed(
        prompt:
            'Kemiringan garis singgung kurva f(x)=x^3-2x pada x=2 adalah ...',
        correctOption: '10',
        options: <String>['6', '8', '10', '12'],
        explanation:
            '1) Turunan f(x)=x^3-2x adalah f\'(x)=3x^2-2. 2) Substitusi x=2: 3(2^2)-2=12-2. 3) Hasilnya 10.',
      ),
    );
  }
  if (text.contains('fungsi')) {
    return const _QuestionTemplate(
      easy: _QuestionSeed(
        prompt: 'Jika f(x)=2x+1, maka nilai f(3) adalah ...',
        correctOption: '7',
        options: <String>['5', '6', '7', '8'],
        explanation:
            '1) Tulis fungsi f(x)=2x+1. 2) Ganti x dengan 3: 2(3)+1. 3) Hitung hasilnya 7.',
      ),
      medium: _QuestionSeed(
        prompt: 'Jika g(x)=x^2-1, maka nilai g(4) adalah ...',
        correctOption: '15',
        options: <String>['7', '12', '15', '17'],
        explanation:
            '1) Substitusi x=4 ke g(x)=x^2-1. 2) Hitung 4^2=16. 3) Kurangi 1 sehingga hasilnya 15.',
      ),
      hard: _QuestionSeed(
        prompt: 'Jika f(x)=3x-2 dan g(x)=x+5, maka f(g(2)) adalah ...',
        correctOption: '19',
        options: <String>['7', '13', '19', '21'],
        explanation:
            '1) Hitung g(2)=2+5=7. 2) Masukkan ke f: f(7)=3(7)-2. 3) Hasil akhirnya 19.',
      ),
    );
  }
  if (text.contains('aljabar')) {
    return const _QuestionTemplate(
      easy: _QuestionSeed(
        prompt: 'Hasil dari 2x + 3x adalah ...',
        correctOption: '5x',
        options: <String>['5', '5x', '6x', 'x^2'],
        explanation:
            '1) Identifikasi suku sejenis: 2x dan 3x. 2) Jumlahkan koefisien 2+3=5. 3) Tulis hasil 5x.',
      ),
      medium: _QuestionSeed(
        prompt: 'Bentuk sederhana dari 3(x+2)-x adalah ...',
        correctOption: '2x + 6',
        options: <String>['2x + 6', '3x + 2', '2x + 2', 'x + 6'],
        explanation:
            '1) Distribusikan 3 ke (x+2): 3x+6. 2) Kurangi dengan x: (3x+6)-x. 3) Gabungkan menjadi 2x+6.',
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
            '1) Cari dua angka yang hasil kalinya 6. 2) Pilih pasangan yang jumlahnya 5: 2 dan 3. 3) Bentuk faktornya (x+2)(x+3).',
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
        explanation:
            '1) Dari 2 menjadi 8 artinya dikali 4. 2) Terapkan faktor yang sama ke bagian pena: 3x4. 3) Hasilnya 12.',
      ),
      medium: _QuestionSeed(
        prompt:
            'Peta berskala 1:100.000. Jarak pada peta 4 cm. Jarak sebenarnya adalah ...',
        correctOption: '4 km',
        options: <String>['400 m', '4 km', '40 km', '0.4 km'],
        explanation:
            '1) Kalikan 4 cm dengan 100.000 menjadi 400.000 cm. 2) Ubah 400.000 cm ke meter: 4.000 m. 3) Ubah ke kilometer: 4 km.',
      ),
      hard: _QuestionSeed(
        prompt:
            'Campuran sirup:air = 1:5. Jika total campuran 18 liter, volume sirup adalah ...',
        correctOption: '3 liter',
        options: <String>['2 liter', '3 liter', '4 liter', '5 liter'],
        explanation:
            '1) Total rasio 1+5=6 bagian. 2) Sirup adalah 1 dari 6 bagian, jadi 1/6x18. 3) Hasilnya 3 liter.',
      ),
    );
  }
  return _QuestionTemplate(
    easy: _QuestionSeed(
      prompt: 'Dalam topik $title, nilai 12 ditambah 5 menjadi ...',
      correctOption: '17',
      options: const <String>['15', '16', '17', '18'],
      explanation: '1) Ambil angka 12. 2) Tambahkan 5. 3) Hasil akhirnya 17.',
    ),
    medium: _QuestionSeed(
      prompt: 'Dalam konteks $title, selisih tetap antara 18 dan 24 adalah ...',
      correctOption: '6',
      options: const <String>['4', '6', '8', '12'],
      explanation:
          '1) Tentukan dua angka: 24 dan 18. 2) Kurangi 24-18. 3) Selisihnya 6.',
    ),
    hard: _QuestionSeed(
      prompt:
          'Untuk latihan $title, jika 6 kelompok masing-masing 4 lalu dikurangi 2, hasilnya ...',
      correctOption: '22',
      options: const <String>['20', '22', '24', '26'],
      explanation:
          '1) Hitung 6x4=24. 2) Kurangi hasilnya dengan 2. 3) Nilai akhir 22.',
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

String? _nullableString(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

double _round4(double value) => (value * 10000).round() / 10000;
