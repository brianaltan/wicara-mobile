import '../../pretest/data/pretest_session_store.dart';
import '../domain/learning_goal_repository.dart';
import '../../offline_learning/data/local_curriculum_repository.dart';

class LocalLearningGoalRepository implements LearningGoalRepository {
  LocalLearningGoalRepository({
    required LocalCurriculumRepository localCurriculumRepository,
    required PretestSessionStore pretestSessionStore,
  }) : _localCurriculumRepository = localCurriculumRepository,
       _pretestSessionStore = pretestSessionStore;

  final LocalCurriculumRepository _localCurriculumRepository;
  final PretestSessionStore _pretestSessionStore;

  static final Map<String, LearningGoalResolution> _resolutionCache =
      <String, LearningGoalResolution>{};
  static ActiveLearningGoal? _activeGoalCache;

  @override
  Future<ActiveLearningGoal?> fetchActiveGoal() async {
    final cached = _activeGoalCache;
    if (cached != null) {
      return cached;
    }
    final goalId = (_pretestSessionStore.learningGoalId ?? '').trim();
    final conceptCode = (_pretestSessionStore.targetConceptCode ?? '').trim();
    if (goalId.isEmpty || conceptCode.isEmpty) {
      return null;
    }
    final concepts = await _localCurriculumRepository.listConcepts();
    if (concepts.isEmpty) {
      return null;
    }
    final concept = concepts.firstWhere(
      (item) => item.code == conceptCode,
      orElse: () => concepts.first,
    );
    final suggestion = _toSuggestion(concept);
    _activeGoalCache = ActiveLearningGoal(
      id: goalId,
      status: 'active',
      rawTopic: concept.title,
      nextAction: 'take_pretest',
      targetConcept: suggestion,
      pretestSessionId: _pretestSessionStore.pretestSessionId,
      trackId: _pretestSessionStore.trackId,
    );
    return _activeGoalCache;
  }

  @override
  Future<LearningGoalResolution> resolveLearningGoal({
    required String rawQuery,
    String? subjectCode,
    String? educationLevel,
    String? gradeLevel,
    String? language,
  }) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      throw const LearningGoalException('Topik belajar tidak boleh kosong.');
    }
    final ranked = await _searchRankedConcepts(
      query: query,
      subjectCode: subjectCode,
    );
    if (ranked.isEmpty) {
      final emptyResolution = LearningGoalResolution(
        resolutionId: _resolutionId(),
        status: 'needs_clarification',
        confidence: 0,
        suggestedConcept: null,
        clarificationQuestion:
            'Belum ketemu konsep yang pas. Coba tambahkan kata kunci yang lebih spesifik.',
      );
      _resolutionCache[emptyResolution.resolutionId] = emptyResolution;
      return emptyResolution;
    }
    final suggestions = ranked
        .map((item) => item.suggestion)
        .toList(growable: false);
    final confidence = ranked.first.score.clamp(0, 1).toDouble();
    final selected = suggestions.first;
    final resolution = LearningGoalResolution(
      resolutionId: _resolutionId(),
      status: 'resolved',
      confidence: confidence,
      suggestedConcept: selected,
      clarificationQuestion: null,
      alternatives: suggestions.skip(1).take(5).toList(growable: false),
      searchScope: (subjectCode ?? '').trim().isEmpty
          ? 'all_subjects'
          : 'subject',
      searchScopeReason: (subjectCode ?? '').trim().isEmpty
          ? 'Pencarian lintas semua subject lokal.'
          : 'Pencarian dibatasi ke subject yang dipilih.',
      graphFocusCodes: suggestions
          .take(5)
          .map((item) => item.conceptCode)
          .toList(growable: false),
      graphSubjectCode: selected.subjectCode,
    );
    _resolutionCache[resolution.resolutionId] = resolution;
    return resolution;
  }

  @override
  Future<LearningGoalBootstrap> confirmResolvedGoal({
    required String resolutionId,
    String? targetConceptCode,
    String? targetSubjectCode,
  }) async {
    final resolution = _resolutionCache[resolutionId];
    if (resolution == null) {
      throw const LearningGoalException(
        'Resolution tidak ditemukan. Cari node goal lagi.',
      );
    }
    final selectedConcept = resolution.suggestedConcept;
    if (selectedConcept == null) {
      throw const LearningGoalException(
        'Belum ada node target yang dipilih untuk pretest.',
      );
    }
    final existing = await fetchActiveGoal();
    if (existing != null && existing.id.isNotEmpty) {
      throw ActiveGoalConflictException(
        existingGoalId: existing.id,
        existingTopic: existing.rawTopic,
        existingStatus: existing.status,
        existingNextAction: existing.nextAction,
      );
    }

    final goalId = 'local_goal_${DateTime.now().microsecondsSinceEpoch}';
    final resolvedConceptCode = (targetConceptCode ?? '').trim().isEmpty
        ? selectedConcept.conceptCode
        : targetConceptCode!.trim();
    final resolvedSubjectCode = (targetSubjectCode ?? '').trim().isEmpty
        ? selectedConcept.subjectCode
        : targetSubjectCode!.trim();

    _pretestSessionStore.saveBootstrap(
      learningGoalId: goalId,
      targetConceptCode: resolvedConceptCode,
      targetSubjectCode: resolvedSubjectCode,
    );
    _activeGoalCache = ActiveLearningGoal(
      id: goalId,
      status: 'active',
      rawTopic: selectedConcept.title,
      nextAction: 'take_pretest',
      targetConcept: selectedConcept,
      pretestSessionId: null,
      trackId: null,
    );
    return LearningGoalBootstrap(learningGoalId: goalId);
  }

  @override
  Future<LearningGoalResolution> selectResolvedConcept({
    required String resolutionId,
    required String conceptId,
  }) async {
    final resolution = _resolutionCache[resolutionId];
    if (resolution == null) {
      throw const LearningGoalException('Resolution tidak ditemukan.');
    }
    final suggestions = <LearningConceptSuggestion>[
      if (resolution.suggestedConcept != null) resolution.suggestedConcept!,
      ...resolution.alternatives,
    ];
    final selected = suggestions.firstWhere(
      (item) => item.conceptId == conceptId || item.conceptCode == conceptId,
      orElse: () => suggestions.first,
    );
    final next = LearningGoalResolution(
      resolutionId: resolution.resolutionId,
      status: resolution.status,
      confidence: resolution.confidence,
      suggestedConcept: selected,
      clarificationQuestion: resolution.clarificationQuestion,
      alternatives: suggestions
          .where((item) => item.conceptId != selected.conceptId)
          .toList(growable: false),
      searchScope: resolution.searchScope,
      searchScopeReason: resolution.searchScopeReason,
      graphFocusCodes: resolution.graphFocusCodes,
      graphSubjectCode: selected.subjectCode,
    );
    _resolutionCache[resolutionId] = next;
    return next;
  }

  @override
  Future<LearningGoalBootstrap> createLearningGoal({
    required String rawTopic,
  }) async {
    final resolution = await resolveLearningGoal(rawQuery: rawTopic);
    if (resolution.suggestedConcept == null) {
      throw LearningGoalException(
        resolution.clarificationQuestion ??
            'Belum ketemu konsep yang tepat. Coba query lain.',
      );
    }
    return confirmResolvedGoal(
      resolutionId: resolution.resolutionId,
      targetConceptCode: resolution.suggestedConcept!.conceptCode,
      targetSubjectCode: resolution.suggestedConcept!.subjectCode,
    );
  }

  @override
  Future<LearningGoalBootstrap> createLearningGoalFromConcept({
    String? conceptId,
    String? conceptCode,
    String? subjectCode,
    String? language,
  }) async {
    final existing = await fetchActiveGoal();
    if (existing != null && existing.id.isNotEmpty) {
      throw ActiveGoalConflictException(
        existingGoalId: existing.id,
        existingTopic: existing.rawTopic,
        existingStatus: existing.status,
        existingNextAction: existing.nextAction,
        pretestSessionId: existing.pretestSessionId,
        trackId: existing.trackId,
      );
    }

    var concepts = await _localCurriculumRepository.listConcepts(
      subjectCode: subjectCode,
    );
    if (concepts.isEmpty) {
      concepts = await _localCurriculumRepository.listConcepts();
    }
    if (concepts.isEmpty) {
      throw const LearningGoalException(
        'Kurikulum lokal belum tersedia. Coba sync kurikulum dulu.',
      );
    }

    final normalizedId = (conceptId ?? '').trim().toLowerCase();
    final normalizedCode = (conceptCode ?? '').trim().toLowerCase();
    final selected = concepts.firstWhere(
      (item) =>
          (normalizedId.isNotEmpty &&
              (item.id.toLowerCase() == normalizedId ||
                  item.code.toLowerCase() == normalizedId)) ||
          (normalizedCode.isNotEmpty &&
              (item.code.toLowerCase() == normalizedCode ||
                  item.id.toLowerCase() == normalizedCode)),
      orElse: () => concepts.first,
    );

    if (normalizedId.isNotEmpty || normalizedCode.isNotEmpty) {
      final matched =
          selected.id.toLowerCase() == normalizedId ||
          selected.code.toLowerCase() == normalizedId ||
          selected.code.toLowerCase() == normalizedCode ||
          selected.id.toLowerCase() == normalizedCode;
      if (!matched) {
        final targetRef = normalizedCode.isNotEmpty
            ? normalizedCode
            : normalizedId;
        throw LearningGoalException(
          'Node "$targetRef" tidak ditemukan di kurikulum lokal.',
        );
      }
    }

    final goalId = 'local_goal_${DateTime.now().microsecondsSinceEpoch}';
    _pretestSessionStore.saveBootstrap(
      learningGoalId: goalId,
      targetConceptCode: selected.code,
      targetSubjectCode: selected.subjectCode,
    );
    final suggestion = _toSuggestion(selected);
    _activeGoalCache = ActiveLearningGoal(
      id: goalId,
      status: 'active',
      rawTopic: suggestion.title,
      nextAction: 'take_pretest',
      targetConcept: suggestion,
      pretestSessionId: null,
      trackId: null,
    );
    return LearningGoalBootstrap(learningGoalId: goalId);
  }

  @override
  Future<List<LearningConceptSuggestion>> searchMaterials({
    required String query,
    String? subjectCode,
  }) async {
    final ranked = await _searchRankedConcepts(
      query: query.trim(),
      subjectCode: subjectCode,
    );
    return ranked
        .map((item) => item.suggestion)
        .take(20)
        .toList(growable: false);
  }

  @override
  Future<void> cancelGoal({required String learningGoalId}) async {
    final active = await fetchActiveGoal();
    if (active == null || active.id != learningGoalId) {
      _pretestSessionStore.clear();
      _activeGoalCache = null;
      return;
    }
    _pretestSessionStore.clear();
    _activeGoalCache = null;
  }

  Future<List<_RankedSuggestion>> _searchRankedConcepts({
    required String query,
    String? subjectCode,
  }) async {
    var concepts = await _localCurriculumRepository.listConcepts(
      subjectCode: subjectCode,
    );
    if (concepts.isEmpty) {
      concepts = await _localCurriculumRepository.listConcepts();
    }
    if (concepts.isEmpty) {
      return const <_RankedSuggestion>[];
    }
    final normalizedTokens = _tokens(query);
    final ranked = <_RankedSuggestion>[];
    for (final concept in concepts) {
      final suggestion = _toSuggestion(concept);
      final haystack =
          '${suggestion.title} ${suggestion.description} ${suggestion.idDesc} ${suggestion.enDesc} ${suggestion.subject}'
              .toLowerCase();
      final score = _score(haystack, normalizedTokens);
      if (score <= 0) {
        continue;
      }
      ranked.add(_RankedSuggestion(suggestion: suggestion, score: score));
    }
    ranked.sort((left, right) {
      final byScore = right.score.compareTo(left.score);
      if (byScore != 0) {
        return byScore;
      }
      return left.suggestion.title.compareTo(right.suggestion.title);
    });
    if (ranked.isNotEmpty) {
      return ranked;
    }
    final fallback = concepts
        .take(10)
        .map(
          (concept) =>
              _RankedSuggestion(suggestion: _toSuggestion(concept), score: 0.2),
        )
        .toList(growable: false);
    return fallback;
  }

  LearningConceptSuggestion _toSuggestion(LocalConceptRecord concept) {
    final metadata = concept.metadata;
    final subjectLabel = _subjectLabel(concept.subjectCode);
    return LearningConceptSuggestion(
      conceptId: concept.id,
      conceptCode: concept.code,
      title: _pickText(
        metadata['label_id'],
        metadata['label_en'],
        concept.title,
      ),
      description: _pickText(
        metadata['description_id'],
        metadata['description_en'],
        concept.description ?? concept.title,
      ),
      idDesc: _pickText(
        metadata['description_id'],
        metadata['description_en'],
        concept.description ?? concept.title,
      ),
      enDesc: _pickText(
        metadata['description_en'],
        metadata['description_id'],
        concept.description ?? concept.title,
      ),
      subjectCode: concept.subjectCode,
      subject: subjectLabel,
      gradeBand: concept.gradeBand,
      gradeRelation: null,
      levelNote: null,
      confidence: null,
    );
  }

  static List<String> _tokens(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .map((item) => item.trim())
        .where((item) => item.length >= 2)
        .toList(growable: false);
  }

  static double _score(String haystack, List<String> tokens) {
    if (tokens.isEmpty) {
      return 0;
    }
    var matched = 0;
    for (final token in tokens) {
      if (haystack.contains(token)) {
        matched += 1;
      }
    }
    if (matched == 0) {
      return 0;
    }
    return matched / tokens.length;
  }

  static String _pickText(
    Object? primary,
    Object? fallback,
    String defaultValue,
  ) {
    final first = (primary ?? '').toString().trim();
    if (first.isNotEmpty) {
      return first;
    }
    final second = (fallback ?? '').toString().trim();
    if (second.isNotEmpty) {
      return second;
    }
    return defaultValue;
  }

  static String _resolutionId() {
    return 'local_resolution_${DateTime.now().microsecondsSinceEpoch}';
  }

  static String _subjectLabel(String code) {
    final normalized = code.toLowerCase();
    if (normalized.contains('math') || normalized.contains('matematika')) {
      return 'Matematika';
    }
    if (normalized.contains('fisika') || normalized.contains('physics')) {
      return 'Fisika';
    }
    if (normalized.contains('kimia') || normalized.contains('chemistry')) {
      return 'Kimia';
    }
    if (normalized.contains('biologi') || normalized.contains('biology')) {
      return 'Biologi';
    }
    if (normalized == 'ipa' || normalized == 'science') {
      return 'IPA';
    }
    if (normalized == 'ipas') {
      return 'IPAS';
    }
    return code;
  }
}

class _RankedSuggestion {
  const _RankedSuggestion({required this.suggestion, required this.score});

  final LearningConceptSuggestion suggestion;
  final double score;
}
