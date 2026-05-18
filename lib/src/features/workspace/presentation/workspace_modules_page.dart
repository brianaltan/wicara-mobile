import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/wicara_colors.dart';
import '../../home/domain/home_repository.dart';
import '../../home/domain/home_snapshot.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/domain/onboarding_copy.dart';
import '../../pretest/domain/multiplication_assessment_bank.dart';
import '../../pretest/presentation/widgets/fishbone_canvas.dart';
import '../domain/workspace_models.dart';
import '../domain/workspace_repository.dart';

enum _WorkspaceContentMode {
  choosing,
  videoProcessing,
  videoReady,
  videoFailed,
}

enum _WorkspaceQuizState { unanswered, correct, review }

class WorkspaceModulesPage extends StatefulWidget {
  const WorkspaceModulesPage({
    required this.onboardingController,
    required this.workspaceRepository,
    this.homeRepository,
    this.routeArguments,
    super.key,
  });

  final OnboardingController onboardingController;
  final WorkspaceRepository workspaceRepository;

  /// Optional: when provided the latest weekly report is fetched and shown
  /// as a summary card at the top of the chat history.
  final HomeRepository? homeRepository;
  final WorkspaceRouteArguments? routeArguments;

  @override
  State<WorkspaceModulesPage> createState() => _WorkspaceModulesPageState();
}

class _WorkspaceModulesPageState extends State<WorkspaceModulesPage> {
  static const _videoPollingInterval = Duration(seconds: 3);
  static const _videoPollingTimeout = Duration(minutes: 5);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_WorkspaceChatEntry> _chatEntries = [];
  final List<CanvasWorkSnapshot> _canvasSnapshots = [];

  _WorkspaceContentMode _contentMode = _WorkspaceContentMode.choosing;
  _WorkspaceQuizState _quizState = _WorkspaceQuizState.unanswered;
  String? _selectedQuizAnswer;
  WorkspaceSession? _workspace;
  bool _isLoadingWorkspace = true;
  bool _isAppendingEvent = false;
  bool _moduleCompleted = false;
  String? _workspaceError;
  bool _isVideoGenerating = false;
  bool _stopVideoPolling = false;
  WorkspaceAnimationJobStatus? _latestVideoStatus;
  WorkspaceMediaArtifact? _latestVideoArtifact;
  String? _videoStatusMessage;
  String? _videoErrorMessage;
  List<WorkspaceSessionSummary> _sessionHistory = const [];
  String? _activeSessionId;
  int _workspaceRequestSerial = 0;

  /// Latest weekly report fetched from HomeRepository. Null while loading or
  /// if no HomeRepository was provided.
  WeeklyLearningReport? _weeklyReport;
  bool _reportCardDismissed = false;

  HardcodedAssessmentPack get _assessmentPack {
    return HardcodedAssessmentBank.packForEducation(
      educationLevel: widget.onboardingController.profile.educationLevel,
      gradeLevel: widget.onboardingController.profile.gradeLevel,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
    _loadWeeklyReport();
  }

  Future<void> _loadWeeklyReport() async {
    final repo = widget.homeRepository;
    if (repo == null) return;
    try {
      final report = await repo.fetchWeeklyLearningReport();
      if (!mounted) return;
      setState(() => _weeklyReport = report);
    } catch (_) {
      // Best-effort: silently ignore report fetch failures.
    }
  }

  @override
  void dispose() {
    _stopVideoPolling = true;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspace({
    String? workspaceSessionId,
    bool startNewSession = false,
  }) async {
    final requestSerial = ++_workspaceRequestSerial;
    final arguments = widget.routeArguments;
    if (arguments == null || !arguments.isValid) {
      setState(() {
        _isLoadingWorkspace = false;
        _workspaceError =
            'Open a track module from Home or Queue before using workspace.';
      });
      return;
    }

    setState(() {
      _isLoadingWorkspace = true;
      _workspaceError = null;
      if (startNewSession || workspaceSessionId != null) {
        _resetCurrentChatState(nextActiveSessionId: workspaceSessionId);
      }
    });
    try {
      final storedHistory = widget.workspaceRepository.sessionHistory(
        trackId: arguments.trackId,
        moduleId: arguments.moduleId,
      );
      final resolvedWorkspaceSessionId =
          workspaceSessionId ??
          (startNewSession ? null : storedHistory.activeWorkspaceId);
      final workspace = await widget.workspaceRepository
          .createOrResumeWorkspace(
            trackId: arguments.trackId,
            moduleId: arguments.moduleId,
            workspaceSessionId: resolvedWorkspaceSessionId,
            startNewSession: startNewSession,
          );
      await widget.workspaceRepository.updateModuleState(
        trackId: arguments.trackId,
        moduleId: arguments.moduleId,
        status: 'active',
      );
      var history = _sessionHistory;
      try {
        history = await widget.workspaceRepository.fetchSessionHistory(
          trackId: arguments.trackId,
          moduleId: arguments.moduleId,
        );
      } on WorkspaceException {
        history = _sessionHistory;
      }
      if (!mounted || requestSerial != _workspaceRequestSerial) return;
      setState(() {
        _workspace = workspace;
        _activeSessionId = workspace.id;
        _chatEntries
          ..clear()
          ..addAll(_entriesFromEvents(workspace.events));
        _latestVideoArtifact = _withResolvedArtifactUrls(workspace.latestMedia);
        _sessionHistory = history;
        _isLoadingWorkspace = false;
      });
      _scrollToBottom();
    } on WorkspaceException catch (error) {
      if (!mounted || requestSerial != _workspaceRequestSerial) return;
      setState(() {
        _isLoadingWorkspace = false;
        _workspaceError = error.message;
      });
    }
  }

  Future<void> _startNewChatSession() async {
    await _loadWorkspace(startNewSession: true);
  }

  Future<void> _switchToSession(String workspaceId) async {
    final requestSerial = ++_workspaceRequestSerial;
    final arguments = widget.routeArguments;
    if (arguments == null || !arguments.isValid) {
      return;
    }
    if (workspaceId == (_workspace?.id ?? '')) {
      return;
    }
    setState(() {
      _isLoadingWorkspace = true;
      _workspaceError = null;
      _resetCurrentChatState(nextActiveSessionId: workspaceId);
    });
    try {
      final workspace = await widget.workspaceRepository.fetchWorkspace(
        workspaceId,
      );
      await widget.workspaceRepository.setActiveSession(
        trackId: arguments.trackId,
        moduleId: arguments.moduleId,
        workspaceId: workspaceId,
      );
      var history = _sessionHistory;
      try {
        history = await widget.workspaceRepository.fetchSessionHistory(
          trackId: arguments.trackId,
          moduleId: arguments.moduleId,
        );
      } on WorkspaceException {
        history = _sessionHistory;
      }
      if (!mounted || requestSerial != _workspaceRequestSerial) {
        return;
      }
      setState(() {
        _workspace = workspace;
        _activeSessionId = workspace.id;
        _chatEntries
          ..clear()
          ..addAll(_entriesFromEvents(workspace.events));
        _latestVideoArtifact = _withResolvedArtifactUrls(workspace.latestMedia);
        _sessionHistory = history;
        _isLoadingWorkspace = false;
      });
      _scrollToBottom();
    } on WorkspaceException catch (error) {
      if (!mounted || requestSerial != _workspaceRequestSerial) {
        return;
      }
      setState(() {
        _isLoadingWorkspace = false;
        _workspaceError = error.message;
      });
    }
  }

  void _resetCurrentChatState({String? nextActiveSessionId}) {
    _workspace = null;
    _activeSessionId = nextActiveSessionId;
    _isAppendingEvent = false;
    _isVideoGenerating = false;
    _stopVideoPolling = true;
    _chatEntries.clear();
    _canvasSnapshots.clear();
    _contentMode = _WorkspaceContentMode.choosing;
    _quizState = _WorkspaceQuizState.unanswered;
    _selectedQuizAnswer = null;
    _latestVideoStatus = null;
    _latestVideoArtifact = null;
    _videoStatusMessage = null;
    _videoErrorMessage = null;
  }

  Future<void> _openSessionHistorySheet() async {
    final arguments = widget.routeArguments;
    if (arguments == null || !arguments.isValid) {
      return;
    }
    List<WorkspaceSessionSummary> sessions = _sessionHistory;
    try {
      sessions = await widget.workspaceRepository.fetchSessionHistory(
        trackId: arguments.trackId,
        moduleId: arguments.moduleId,
      );
      if (mounted) {
        setState(() => _sessionHistory = sessions);
      }
    } on WorkspaceException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _workspaceError = error.message);
      return;
    }
    if (!mounted || sessions.isEmpty) {
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _WorkspaceHistorySheet(
          sessions: sessions,
          activeSessionId: _activeSessionId,
        );
      },
    );
    if (selected != null) {
      await _switchToSession(selected);
    }
  }

  Future<void> _generateVideo() async {
    if (_isVideoGenerating) {
      return;
    }
    final workspace = _workspace;
    if (workspace == null) {
      setState(() {
        _workspaceError = 'Workspace is not ready yet.';
      });
      return;
    }

    final language = _resolveGenerationLanguageCode();
    final chatTurnCount = _chatEntries
        .where(
          (entry) =>
              !entry.isCanvas && (entry.text?.trim().isNotEmpty ?? false),
        )
        .length;
    _stopVideoPolling = true;
    setState(() {
      _isVideoGenerating = true;
      _contentMode = _WorkspaceContentMode.videoProcessing;
      _quizState = _WorkspaceQuizState.unanswered;
      _selectedQuizAnswer = null;
      _latestVideoStatus = null;
      _videoStatusMessage = 'Queueing video generation...';
      _videoErrorMessage = null;
      _workspaceError = null;
    });
    _scrollToBottom();

    try {
      debugPrint(
        '[video-generate] workspace_id=${workspace.id} generation_mode=context_auto language=$language',
      );
      final result = await widget.workspaceRepository.generateVideo(
        workspaceId: workspace.id,
        generationMode: 'context_auto',
        language: language,
        qualityProfile: 'standard',
        metadata: {
          'triggered_by': 'workspace_mid_chat_button',
          'chat_turn_count': chatTurnCount,
          'workspace_content_mode': _contentMode.name,
        },
      );

      if (!mounted) return;
      setState(() {
        _workspace = result.workspace;
        _latestVideoArtifact =
            _withResolvedArtifactUrls(result.workspace.latestMedia) ??
            _latestVideoArtifact;
        _videoStatusMessage = 'Video queued. Waiting for worker...';
      });

      await _pollVideoStatus(jobId: result.queue.jobId);
    } on WorkspaceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isVideoGenerating = false;
        _contentMode = _WorkspaceContentMode.videoFailed;
        _videoErrorMessage = error.message;
      });
      _scrollToBottom();
    }
  }

  Future<void> _pollVideoStatus({required String jobId}) async {
    _stopVideoPolling = false;
    final startedAt = DateTime.now();

    while (mounted && !_stopVideoPolling) {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed >= _videoPollingTimeout) {
        if (!mounted) return;
        setState(() {
          _isVideoGenerating = false;
          _contentMode = _WorkspaceContentMode.videoFailed;
          _videoErrorMessage =
              'Video generation timed out after ${_videoPollingTimeout.inMinutes} minutes.';
          _videoStatusMessage = 'Generation timeout.';
        });
        _scrollToBottom();
        return;
      }

      try {
        final status = await widget.workspaceRepository.getAnimationStatus(
          jobId: jobId,
        );
        if (!mounted || _stopVideoPolling) return;

        setState(() {
          _latestVideoStatus = status;
          _videoStatusMessage = status.message;
          if (status.isReady) {
            _isVideoGenerating = false;
            _contentMode = _WorkspaceContentMode.videoReady;
            _videoErrorMessage = null;
            _latestVideoArtifact = _latestVideoArtifactFromStatus(
              status,
              fallback: _workspace,
            );
          } else if (status.isFailed) {
            _isVideoGenerating = false;
            _contentMode = _WorkspaceContentMode.videoFailed;
            _videoErrorMessage = status.error ?? status.message;
          } else {
            _contentMode = _WorkspaceContentMode.videoProcessing;
          }
        });

        if (status.isFinal) {
          if (status.isReady) {
            await _refreshWorkspaceAfterReady();
          }
          _scrollToBottom();
          return;
        }
      } on WorkspaceException catch (error) {
        if (!mounted || _stopVideoPolling) return;
        setState(() {
          _isVideoGenerating = false;
          _contentMode = _WorkspaceContentMode.videoFailed;
          _videoErrorMessage = error.message;
        });
        _scrollToBottom();
        return;
      }

      await Future<void>.delayed(_videoPollingInterval);
    }
  }

  Future<void> _refreshWorkspaceAfterReady() async {
    final workspace = _workspace;
    if (workspace == null) {
      return;
    }
    try {
      final refreshed = await widget.workspaceRepository.fetchWorkspace(
        workspace.id,
      );
      if (!mounted) return;
      setState(() {
        _workspace = refreshed;
        _latestVideoArtifact =
            _withResolvedArtifactUrls(refreshed.latestMedia) ??
            _latestVideoArtifact;
      });
    } on WorkspaceException {
      // Best effort refresh; preserve ready state and fallback artifact.
    }
  }

  // ignore: unused_element
  _VideoGenerationPayload? _buildPayloadForWorkspace(
    WorkspaceSession workspace,
  ) {
    final language = _normalizedLanguageCode();
    final match = _matchTemplateForTopic(workspace.currentTopic);
    if (match == null) {
      return null;
    }
    final topic = workspace.currentTopic.trim();
    final title = topic.isEmpty
        ? (language == 'id' ? 'Penjelasan Konsep' : 'Concept Explanation')
        : topic;

    final payloadByTemplate = <String, Map<String, dynamic>>{
      'manim.graph_explanation.v1': _graphExplanationSpec(
        workspaceId: workspace.id,
        language: language,
        title: title,
      ),
      'manim.equation_balance.v1': _equationBalanceSpec(
        workspaceId: workspace.id,
        language: language,
        title: title,
      ),
      'manim.force_diagram.v1': _forceDiagramSpec(
        workspaceId: workspace.id,
        language: language,
        title: title,
      ),
      'manim.fraction_bar_partition.v1': _fractionSpec(
        workspaceId: workspace.id,
        language: language,
        title: title,
      ),
      'manim.ratio_proportion.v1': _ratioSpec(
        workspaceId: workspace.id,
        language: language,
        title: title,
      ),
      'manim.number_line_quantity.v1': _numberLineSpec(
        workspaceId: workspace.id,
        language: language,
        title: title,
      ),
      'manim.sequence_pattern.v1': _sequenceSpec(
        workspaceId: workspace.id,
        language: language,
        title: title,
      ),
      'manim.motion_kinematics.v1': _motionSpec(
        workspaceId: workspace.id,
        language: language,
        title: title,
      ),
      'manim.geometry_area_volume.v1': _geometrySpec(
        workspaceId: workspace.id,
        language: language,
        title: title,
      ),
      'manim.elementary_arithmetic_blocks.v1': _arithmeticSpec(
        workspaceId: workspace.id,
        language: language,
        title: title,
      ),
    };

    final specJson = payloadByTemplate[match.templateId];
    if (specJson == null) {
      return null;
    }

    return _VideoGenerationPayload(
      templateId: match.templateId,
      language: language,
      specJson: specJson,
    );
  }

  bool _canGenerateVideoForCurrentTopic() {
    return _workspace != null;
  }

  String? _videoTemplateHintMessage() {
    return null;
  }

  _VideoTemplateMatch? _matchTemplateForTopic(String topic) {
    final normalized = topic.toLowerCase();
    const mappings = <_VideoTemplateMatch>[
      _VideoTemplateMatch(
        templateId: 'manim.equation_balance.v1',
        keywords: ['persamaan', 'equation', 'aljabar', 'linear'],
      ),
      _VideoTemplateMatch(
        templateId: 'manim.force_diagram.v1',
        keywords: ['gaya', 'force', 'resultan', 'newton'],
      ),
      _VideoTemplateMatch(
        templateId: 'manim.fraction_bar_partition.v1',
        keywords: ['pecahan', 'fraction'],
      ),
      _VideoTemplateMatch(
        templateId: 'manim.ratio_proportion.v1',
        keywords: ['rasio', 'ratio', 'proporsi', 'proportion'],
      ),
      _VideoTemplateMatch(
        templateId: 'manim.number_line_quantity.v1',
        keywords: [
          'garis bilangan',
          'number line',
          'bilangan bulat',
          'integer',
        ],
      ),
      _VideoTemplateMatch(
        templateId: 'manim.sequence_pattern.v1',
        keywords: ['pola', 'sequence', 'deret'],
      ),
      _VideoTemplateMatch(
        templateId: 'manim.motion_kinematics.v1',
        keywords: ['gerak', 'kinematics', 'motion', 'kecepatan', 'velocity'],
      ),
      _VideoTemplateMatch(
        templateId: 'manim.geometry_area_volume.v1',
        keywords: ['luas', 'volume', 'geometri', 'geometry'],
      ),
      _VideoTemplateMatch(
        templateId: 'manim.elementary_arithmetic_blocks.v1',
        keywords: ['penjumlahan', 'addition', 'aritmetika', 'arithmetic'],
      ),
      _VideoTemplateMatch(
        templateId: 'manim.graph_explanation.v1',
        keywords: ['grafik', 'graph', 'fungsi', 'function', 'limit', 'turunan'],
      ),
    ];

    for (final match in mappings) {
      for (final keyword in match.keywords) {
        if (normalized.contains(keyword)) {
          return match;
        }
      }
    }
    return null;
  }

  String _normalizedLanguageCode() {
    final preferredLanguage = widget
        .onboardingController
        .profile
        .preferredLanguage
        .toLowerCase();
    return switch (preferredLanguage) {
      'indonesian' || 'id' || 'id-id' => 'id',
      'english' || 'en' || 'en-us' => 'en',
      _ => 'id',
    };
  }

  String _resolveGenerationLanguageCode() {
    return _inferConversationLanguage() ?? _normalizedLanguageCode();
  }

  String? _inferConversationLanguage() {
    final learnerTexts = <String>[];
    for (final event
        in _workspace?.events.reversed ?? const <WorkspaceEvent>[]) {
      if (event.actorType != 'learner') {
        continue;
      }
      final text = event.textPayload.trim();
      if (text.isNotEmpty) {
        learnerTexts.add(text);
      }
      if (learnerTexts.length >= 4) {
        break;
      }
    }
    if (learnerTexts.isEmpty) {
      return null;
    }

    final merged = learnerTexts.join(' ').toLowerCase();
    final tokens = merged
        .split(RegExp(r'[^a-z]+'))
        .where((token) => token.isNotEmpty);

    const idMarkers = {
      'yang',
      'dan',
      'dengan',
      'untuk',
      'pada',
      'garis',
      'bilangan',
      'lebih',
      'kurang',
      'adalah',
      'saya',
      'aku',
      'tolong',
      'kenapa',
      'bagaimana',
      'jelasin',
      'contoh',
    };
    const enMarkers = {
      'the',
      'and',
      'with',
      'for',
      'number',
      'line',
      'greater',
      'less',
      'is',
      'please',
      'why',
      'how',
      'explain',
      'example',
    };

    var idScore = 0;
    var enScore = 0;
    for (final token in tokens) {
      if (idMarkers.contains(token)) {
        idScore++;
      }
      if (enMarkers.contains(token)) {
        enScore++;
      }
    }
    if (idScore == 0 && enScore == 0) {
      return null;
    }
    return idScore >= enScore ? 'id' : 'en';
  }

  Map<String, dynamic> _graphExplanationSpec({
    required String workspaceId,
    required String language,
    required String title,
  }) {
    final isId = language == 'id';
    final subtitle = isId
        ? 'Parabola menunjukkan perubahan nilai fungsi.'
        : 'A parabola shows how function values change.';
    final intro = isId
        ? 'Fungsi kuadrat membentuk parabola. Kita bisa membaca nilai fungsi dari titik pada grafik.'
        : 'A quadratic function forms a parabola. We can read values from points on the graph.';
    final step1 = isId
        ? 'Bentuk parabola. Grafik fungsi kuadrat berbentuk parabola.'
        : 'Parabola shape. A quadratic function graph is a parabola.';
    final step2 = isId
        ? 'Nilai berubah. Saat x berubah, nilai f(x) berubah mengikuti kurva.'
        : 'Values change. As x changes, f(x) changes along the curve.';
    final summary = isId
        ? 'Grafik membantu melihat sifat fungsi secara visual.'
        : 'A graph helps us understand function behavior visually.';

    return {
      'id': 'mobile_graph_explanation_$workspaceId',
      'template_id': 'manim.graph_explanation.v1',
      'language': language,
      'title': title,
      'subtitle': subtitle,
      'function': {
        'type': 'quadratic',
        'params': {'a': 1, 'b': 0, 'c': 0},
      },
      'x_range': [-3, 3, 1],
      'y_range': [-1, 9, 1],
      'graph_features': [
        {'type': 'vertex', 'label': isId ? 'Titik puncak' : 'Vertex'},
        {'type': 'slope', 'label': isId ? 'Kemiringan lokal' : 'Local slope'},
      ],
      'highlight_points': [
        {'x': 1, 'label': 'x = 1'},
      ],
      'formula_latex': 'f(x)=x^2',
      'steps': [
        {
          'title': isId ? 'Bentuk parabola' : 'Parabola shape',
          'body': isId
              ? 'Grafik fungsi kuadrat berbentuk parabola.'
              : 'A quadratic graph forms a parabola.',
          'narration': step1,
        },
        {
          'title': isId ? 'Nilai berubah' : 'Values change',
          'body': isId
              ? 'Saat x berubah, nilai f(x) berubah mengikuti kurva.'
              : 'As x changes, f(x) changes along the curve.',
          'narration': step2,
        },
      ],
      'summary': summary,
      'voiceover_script': intro,
      'intro_narration': intro,
      'summary_narration': summary,
      'narration_segments': _segments(
        intro: intro,
        step1: step1,
        step2: step2,
        summary: summary,
      ),
    };
  }

  Map<String, dynamic> _equationBalanceSpec({
    required String workspaceId,
    required String language,
    required String title,
  }) {
    final isId = language == 'id';
    final intro = isId
        ? 'Bayangkan persamaan seperti timbangan. Jika satu sisi diubah, sisi lainnya juga harus diubah.'
        : 'Think of an equation as a balance scale. Any change on one side must also happen on the other side.';
    final step1 = isId
        ? 'Jaga seimbang. Setiap operasi harus dilakukan pada kedua ruas.'
        : 'Keep it balanced. Every operation must be applied on both sides.';
    final step2 = isId
        ? 'Isolasi x. Tujuannya membuat x berdiri sendiri.'
        : 'Isolate x. The goal is to leave x on its own.';
    final summary = isId
        ? 'Nilai x ditemukan dengan menjaga kedua ruas tetap setara.'
        : 'We find x by keeping both sides equivalent.';

    return {
      'id': 'mobile_equation_balance_$workspaceId',
      'template_id': 'manim.equation_balance.v1',
      'language': language,
      'title': title,
      'subtitle': isId
          ? 'Operasi di kiri juga dilakukan di kanan.'
          : 'Any operation on the left must be done on the right.',
      'equation': '2x + 3 = 11',
      'left_expression': '2x + 3',
      'right_expression': '11',
      'solution_steps': [
        {
          'operation': isId ? 'Kurangi 3' : 'Subtract 3',
          'value': 3,
          'left_result': '2x',
          'right_result': '8',
          'explanation': isId
              ? 'Kurangi 3 di kedua sisi.'
              : 'Subtract 3 on both sides.',
          'narration': isId
              ? 'Kurangi tiga di kedua sisi agar persamaan tetap seimbang.'
              : 'Subtract three from both sides to keep the equation balanced.',
        },
        {
          'operation': isId ? 'Bagi 2' : 'Divide by 2',
          'value': 2,
          'left_result': 'x',
          'right_result': '4',
          'explanation': isId
              ? 'Bagi kedua sisi dengan 2.'
              : 'Divide both sides by 2.',
          'narration': isId
              ? 'Bagi kedua sisi dengan dua supaya x berdiri sendiri.'
              : 'Divide both sides by two so x stands alone.',
        },
      ],
      'final_solution': 'x = 4',
      'steps': [
        {
          'title': isId ? 'Jaga seimbang' : 'Keep balanced',
          'body': isId
              ? 'Setiap operasi harus dilakukan pada kedua ruas.'
              : 'Every operation must be done on both sides.',
          'narration': step1,
        },
        {
          'title': isId ? 'Isolasi x' : 'Isolate x',
          'body': isId
              ? 'Tujuannya membuat x berdiri sendiri.'
              : 'The goal is to leave x by itself.',
          'narration': step2,
        },
      ],
      'summary': summary,
      'voiceover_script': intro,
      'intro_narration': intro,
      'summary_narration': summary,
      'narration_segments': _segments(
        intro: intro,
        step1: step1,
        step2: step2,
        summary: summary,
      ),
    };
  }

  Map<String, dynamic> _forceDiagramSpec({
    required String workspaceId,
    required String language,
    required String title,
  }) {
    final isId = language == 'id';
    final intro = isId
        ? 'Kotak mendapat gaya ke kanan dan ke kiri. Karena gaya kanan lebih besar, resultannya ke kanan.'
        : 'The box has forces to the right and left. Because the right force is larger, the resultant points right.';
    final step1 = isId
        ? 'Dua gaya berlawanan. Gaya kanan lebih besar daripada gaya kiri.'
        : 'Two opposite forces. The right force is larger than the left.';
    final step2 = isId
        ? 'Cari selisih. Resultan gaya adalah 6 N ke kanan.'
        : 'Find the difference. The resultant force is 6 N to the right.';
    final summary = isId
        ? 'Arah resultan gaya menentukan kecenderungan gerak benda.'
        : 'The resultant force direction determines the object motion tendency.';

    return {
      'id': 'mobile_force_diagram_$workspaceId',
      'template_id': 'manim.force_diagram.v1',
      'language': language,
      'title': title,
      'subtitle': isId
          ? 'Gaya berlawanan saling mengurangi.'
          : 'Opposite forces subtract from each other.',
      'object': {'type': 'box', 'label': isId ? 'Kotak' : 'Box'},
      'forces': [
        {'label': 'F1', 'magnitude': 10, 'unit': 'N', 'direction': 'right'},
        {'label': 'F2', 'magnitude': 4, 'unit': 'N', 'direction': 'left'},
      ],
      'resultant': {'magnitude': 6, 'unit': 'N', 'direction': 'right'},
      'motion_response': isId
          ? 'Benda cenderung bergerak ke kanan.'
          : 'The object tends to move to the right.',
      'force_scale': 0.25,
      'steps': [
        {
          'title': isId ? 'Dua gaya berlawanan' : 'Two opposite forces',
          'body': isId
              ? 'Gaya kanan lebih besar daripada gaya kiri.'
              : 'The right force is larger than the left force.',
          'narration': step1,
        },
        {
          'title': isId ? 'Cari selisih' : 'Find the difference',
          'body': isId
              ? 'Resultan gaya adalah 6 N ke kanan.'
              : 'The resultant force is 6 N to the right.',
          'narration': step2,
        },
      ],
      'summary': summary,
      'voiceover_script': intro,
      'intro_narration': intro,
      'summary_narration': summary,
      'narration_segments': _segments(
        intro: intro,
        step1: step1,
        step2: step2,
        summary: summary,
      ),
    };
  }

  Map<String, dynamic> _fractionSpec({
    required String workspaceId,
    required String language,
    required String title,
  }) {
    final isId = language == 'id';
    final intro = isId
        ? 'Satu per dua dan dua per empat terlihat berbeda, tetapi bagian yang diwarnai sama besar.'
        : 'One-half and two-fourths look different, but they represent the same shaded part.';
    final step1 = isId
        ? 'Lihat bagian berwarna. Setengah bar berwarna pada kedua gambar.'
        : 'Look at the shaded parts. Half of each bar is shaded.';
    final step2 = isId
        ? 'Nilainya sama. 1/2 dan 2/4 menunjukkan bagian yang sama besar.'
        : 'Same value. 1/2 and 2/4 represent equal portions.';
    final summary = isId
        ? 'Pecahan senilai punya nilai sama walau tulisannya berbeda.'
        : 'Equivalent fractions have the same value even with different forms.';

    return {
      'id': 'mobile_fraction_$workspaceId',
      'template_id': 'manim.fraction_bar_partition.v1',
      'language': language,
      'title': title,
      'subtitle': isId
          ? 'Bagian yang sama bisa ditulis berbeda.'
          : 'The same part can be written in different ways.',
      'representations': ['fraction'],
      'fractions': [
        {'numerator': 1, 'denominator': 2, 'label': '1/2'},
        {'numerator': 2, 'denominator': 4, 'label': '2/4'},
      ],
      'partition_count': 4,
      'highlight_parts': [1, 2],
      'equivalences': [
        {'left': '1/2', 'right': '2/4'},
      ],
      'steps': [
        {
          'title': isId ? 'Lihat bagian berwarna' : 'Observe shaded parts',
          'body': isId
              ? 'Setengah bar berwarna pada kedua gambar.'
              : 'Half of the bar is shaded in both figures.',
          'narration': step1,
        },
        {
          'title': isId ? 'Nilainya sama' : 'Equivalent value',
          'body': isId
              ? '1/2 dan 2/4 menunjukkan bagian yang sama besar.'
              : '1/2 and 2/4 represent the same amount.',
          'narration': step2,
        },
      ],
      'summary': summary,
      'voiceover_script': intro,
      'intro_narration': intro,
      'summary_narration': summary,
      'narration_segments': _segments(
        intro: intro,
        step1: step1,
        step2: step2,
        summary: summary,
      ),
    };
  }

  Map<String, dynamic> _ratioSpec({
    required String workspaceId,
    required String language,
    required String title,
  }) {
    final isId = language == 'id';
    final intro = isId
        ? 'Rasio dua banding lima berarti dua sendok gula dipasangkan dengan lima gelas air.'
        : 'A ratio of two to five means two spoonfuls of sugar are paired with five glasses of water.';
    final step1 = isId
        ? 'Rasio awal. Gula dan air dibandingkan 2 banding 5.'
        : 'Initial ratio. Sugar and water are compared as 2 to 5.';
    final step2 = isId
        ? 'Skalakan bersama. Jika gula dikali 2, air juga dikali 2.'
        : 'Scale together. If sugar is multiplied by 2, water must also be multiplied by 2.';
    final summary = isId
        ? 'Proporsi terjaga jika kedua kuantitas dikalikan faktor yang sama.'
        : 'Proportion is preserved when both quantities are scaled by the same factor.';

    return {
      'id': 'mobile_ratio_$workspaceId',
      'template_id': 'manim.ratio_proportion.v1',
      'language': language,
      'title': title,
      'subtitle': isId
          ? 'Rasio menjaga perbandingan dua kuantitas.'
          : 'Ratios preserve the relationship between two quantities.',
      'context': isId ? 'Membuat sirup' : 'Making syrup',
      'quantities': [
        {
          'label': isId ? 'Gula' : 'Sugar',
          'value': 2,
          'unit': isId ? 'sendok' : 'spoons',
        },
        {
          'label': isId ? 'Air' : 'Water',
          'value': 5,
          'unit': isId ? 'gelas' : 'glasses',
        },
      ],
      'ratio_pairs': [
        [isId ? 'Gula' : 'Sugar', isId ? 'Air' : 'Water'],
      ],
      'scale_factor': 2,
      'scaling_steps': [
        {
          'from': '2:5',
          'to': '4:10',
          'label': isId ? 'Dikali 2' : 'Multiply by 2',
        },
      ],
      'steps': [
        {
          'title': isId ? 'Rasio awal' : 'Initial ratio',
          'body': isId
              ? 'Gula dan air dibandingkan 2 banding 5.'
              : 'Sugar and water are compared as 2 to 5.',
          'narration': step1,
        },
        {
          'title': isId ? 'Skalakan bersama' : 'Scale together',
          'body': isId
              ? 'Jika gula dikali 2, air juga dikali 2.'
              : 'If sugar doubles, water must also double.',
          'narration': step2,
        },
      ],
      'summary': summary,
      'voiceover_script': intro,
      'intro_narration': intro,
      'summary_narration': summary,
      'narration_segments': _segments(
        intro: intro,
        step1: step1,
        step2: step2,
        summary: summary,
      ),
    };
  }

  Map<String, dynamic> _numberLineSpec({
    required String workspaceId,
    required String language,
    required String title,
  }) {
    final isId = language == 'id';
    final intro = isId
        ? 'Perhatikan garis bilangan ini. Angka minus tiga berada di kiri, sedangkan angka dua berada di kanan.'
        : 'Observe this number line. Negative three is on the left while two is on the right.';
    final step1 = isId
        ? 'Lihat posisi angka. -3 berada di kiri, sedangkan 2 berada di kanan.'
        : 'Check positions. -3 is on the left and 2 is on the right.';
    final step2 = isId
        ? 'Bandingkan nilainya. Angka yang lebih kanan di garis bilangan bernilai lebih besar.'
        : 'Compare values. The number farther right is greater.';
    final summary = isId
        ? 'Pada garis bilangan, angka di kanan bernilai lebih besar.'
        : 'On a number line, values on the right are greater.';

    return {
      'id': 'mobile_number_line_$workspaceId',
      'template_id': 'manim.number_line_quantity.v1',
      'language': language,
      'title': title,
      'subtitle': isId
          ? 'Semakin ke kanan, nilainya semakin besar.'
          : 'The farther right, the greater the value.',
      'number_range': {'min': -5, 'max': 5, 'step': 1},
      'markers': [
        {'value': -3, 'label': '-3'},
        {'value': 2, 'label': '2'},
      ],
      'highlight_values': [-3, 2],
      'operation': {
        'type': 'compare',
        'from': -3,
        'to': 2,
        'label': isId ? '2 lebih besar dari -3' : '2 is greater than -3',
      },
      'steps': [
        {
          'title': isId ? 'Lihat posisi angka' : 'Read the positions',
          'body': isId
              ? '-3 berada di kiri, sedangkan 2 berada di kanan.'
              : '-3 is on the left while 2 is on the right.',
          'narration': step1,
        },
        {
          'title': isId ? 'Bandingkan nilainya' : 'Compare values',
          'body': isId
              ? 'Angka yang lebih kanan bernilai lebih besar.'
              : 'The value farther right is greater.',
          'narration': step2,
        },
      ],
      'summary': summary,
      'voiceover_script': intro,
      'intro_narration': intro,
      'summary_narration': summary,
      'narration_segments': _segments(
        intro: intro,
        step1: step1,
        step2: step2,
        summary: summary,
      ),
    };
  }

  Map<String, dynamic> _sequenceSpec({
    required String workspaceId,
    required String language,
    required String title,
  }) {
    final isId = language == 'id';
    final intro = isId
        ? 'Lihat deret dua, empat, enam, delapan. Setiap langkah bertambah dua.'
        : 'Look at the sequence two, four, six, eight. Each step increases by two.';
    final step1 = isId
        ? 'Amati suku. Setiap suku bertambah dua.'
        : 'Observe terms. Each term increases by two.';
    final step2 = isId
        ? 'Terapkan aturan. Suku berikutnya adalah 10.'
        : 'Apply the rule. The next term is 10.';
    final summary = isId
        ? 'Pola dapat diteruskan jika aturan perubahannya diketahui.'
        : 'A pattern can continue when the change rule is known.';

    return {
      'id': 'mobile_sequence_$workspaceId',
      'template_id': 'manim.sequence_pattern.v1',
      'language': language,
      'title': title,
      'subtitle': isId
          ? 'Cari aturan dari perubahan suku.'
          : 'Find the rule behind term changes.',
      'terms': [2, 4, 6, 8],
      'visual_pattern_type': 'growing_dots',
      'rule': isId ? 'Tambah 2 setiap langkah' : 'Add 2 each step',
      'table_values': [
        {'n': 1, 'value': 2},
        {'n': 2, 'value': 4},
        {'n': 3, 'value': 6},
      ],
      'target_term': {'n': 5, 'value': 10},
      'steps': [
        {
          'title': isId ? 'Amati suku' : 'Observe terms',
          'body': isId
              ? 'Setiap suku bertambah dua.'
              : 'Each term increases by two.',
          'narration': step1,
        },
        {
          'title': isId ? 'Terapkan aturan' : 'Apply the rule',
          'body': isId ? 'Suku berikutnya adalah 10.' : 'The next term is 10.',
          'narration': step2,
        },
      ],
      'summary': summary,
      'voiceover_script': intro,
      'intro_narration': intro,
      'summary_narration': summary,
      'narration_segments': _segments(
        intro: intro,
        step1: step1,
        step2: step2,
        summary: summary,
      ),
    };
  }

  Map<String, dynamic> _motionSpec({
    required String workspaceId,
    required String language,
    required String title,
  }) {
    final isId = language == 'id';
    final intro = isId
        ? 'Pada gerak lurus beraturan, posisi bertambah secara teratur setiap waktu.'
        : 'In uniform linear motion, position increases regularly over time.';
    final step1 = isId
        ? 'Kecepatan tetap. Benda menempuh jarak yang sama tiap detik.'
        : 'Constant speed. The object travels equal distances each second.';
    final step2 = isId
        ? 'Grafik lurus. Posisi terhadap waktu membentuk garis lurus.'
        : 'Straight graph. Position versus time forms a straight line.';
    final summary = isId
        ? 'GLB memiliki kecepatan tetap dan percepatan nol.'
        : 'Uniform motion has constant speed and zero acceleration.';

    return {
      'id': 'mobile_motion_$workspaceId',
      'template_id': 'manim.motion_kinematics.v1',
      'language': language,
      'title': title,
      'subtitle': isId
          ? 'Posisi bertambah sama setiap selang waktu.'
          : 'Position increases equally at each time interval.',
      'scenario': isId ? 'Gerak lurus beraturan' : 'Uniform linear motion',
      'time_points': [0, 1, 2, 3, 4],
      'position_data': [0, 2, 4, 6, 8],
      'velocity_data': [2, 2, 2, 2, 2],
      'acceleration': 0,
      'graph_type': 'position_time',
      'steps': [
        {
          'title': isId ? 'Kecepatan tetap' : 'Constant speed',
          'body': isId
              ? 'Benda menempuh jarak yang sama tiap detik.'
              : 'The object travels equal distance each second.',
          'narration': step1,
        },
        {
          'title': isId ? 'Grafik lurus' : 'Straight graph',
          'body': isId
              ? 'Posisi terhadap waktu membentuk garis lurus.'
              : 'Position versus time forms a straight line.',
          'narration': step2,
        },
      ],
      'summary': summary,
      'voiceover_script': intro,
      'intro_narration': intro,
      'summary_narration': summary,
      'narration_segments': _segments(
        intro: intro,
        step1: step1,
        step2: step2,
        summary: summary,
      ),
    };
  }

  Map<String, dynamic> _geometrySpec({
    required String workspaceId,
    required String language,
    required String title,
  }) {
    final isId = language == 'id';
    final intro = isId
        ? 'Untuk mencari luas persegi panjang, kita melihat panjang dan lebarnya.'
        : 'To find the area of a rectangle, we look at its length and width.';
    final step1 = isId
        ? 'Ukur dua sisi. Persegi panjang punya panjang dan lebar.'
        : 'Measure two sides. A rectangle has length and width.';
    final step2 = isId
        ? 'Kalikan. Luas diperoleh dari panjang dikali lebar.'
        : 'Multiply. Area equals length times width.';
    final summary = isId
        ? 'Luas persegi panjang adalah panjang dikali lebar.'
        : 'Rectangle area is length multiplied by width.';

    return {
      'id': 'mobile_geometry_$workspaceId',
      'template_id': 'manim.geometry_area_volume.v1',
      'language': language,
      'title': title,
      'subtitle': isId
          ? 'Luas dapat dihitung dari panjang dan lebar.'
          : 'Area can be computed from length and width.',
      'shape_type': 'rectangle',
      'dimensions': {'length': 6, 'width': 4, 'unit': isId ? 'cm' : 'cm'},
      'transformations': [
        {
          'type': 'fill_unit_squares',
          'label': isId
              ? 'Isi dengan persegi satuan'
              : 'Fill with unit squares',
        },
      ],
      'formula_latex': 'L = p \\times l',
      'highlight_features': ['length', 'width', 'area'],
      'steps': [
        {
          'title': isId ? 'Ukur dua sisi' : 'Measure two sides',
          'body': isId
              ? 'Persegi panjang punya panjang dan lebar.'
              : 'A rectangle has length and width.',
          'narration': step1,
        },
        {
          'title': isId ? 'Kalikan' : 'Multiply',
          'body': isId
              ? 'Luas diperoleh dari panjang dikali lebar.'
              : 'Area comes from length times width.',
          'narration': step2,
        },
      ],
      'summary': summary,
      'voiceover_script': intro,
      'intro_narration': intro,
      'summary_narration': summary,
      'narration_segments': _segments(
        intro: intro,
        step1: step1,
        step2: step2,
        summary: summary,
      ),
    };
  }

  Map<String, dynamic> _arithmeticSpec({
    required String workspaceId,
    required String language,
    required String title,
  }) {
    final isId = language == 'id';
    final intro = isId
        ? 'Kita punya dua kelompok blok. Saat digabung, semua blok dihitung bersama.'
        : 'We have two groups of blocks. When combined, all blocks are counted together.';
    final step1 = isId
        ? 'Ada dua kelompok. Kelompok pertama berisi 12, kelompok kedua berisi 8.'
        : 'There are two groups. The first has 12 and the second has 8.';
    final step2 = isId
        ? 'Gabungkan. Setelah digabung, jumlahnya menjadi 20.'
        : 'Combine them. After combining, the total is 20.';
    final summary = isId
        ? 'Penjumlahan berarti menggabungkan dua kelompok.'
        : 'Addition means combining two groups.';

    return {
      'id': 'mobile_arithmetic_$workspaceId',
      'template_id': 'manim.elementary_arithmetic_blocks.v1',
      'language': language,
      'title': title,
      'subtitle': isId
          ? 'Gabungkan dua kelompok benda.'
          : 'Combine two groups of objects.',
      'operation_type': 'addition',
      'operands': [12, 8],
      'blocks': {'model': 'counters'},
      'grouping_steps': [
        {
          'label': isId ? 'Gabungkan semua blok' : 'Combine all blocks',
          'value': 20,
        },
      ],
      'result': 20,
      'steps': [
        {
          'title': isId ? 'Ada dua kelompok' : 'Two groups',
          'body': isId
              ? 'Kelompok pertama berisi 12, kelompok kedua berisi 8.'
              : 'The first group has 12, and the second has 8.',
          'narration': step1,
        },
        {
          'title': isId ? 'Gabungkan' : 'Combine',
          'body': isId
              ? 'Setelah digabung, jumlahnya menjadi 20.'
              : 'After combining, the total becomes 20.',
          'narration': step2,
        },
      ],
      'summary': summary,
      'voiceover_script': intro,
      'intro_narration': intro,
      'summary_narration': summary,
      'narration_segments': _segments(
        intro: intro,
        step1: step1,
        step2: step2,
        summary: summary,
      ),
    };
  }

  List<Map<String, dynamic>> _segments({
    required String intro,
    required String step1,
    required String step2,
    required String summary,
  }) {
    return [
      {'slot': 'intro', 'text': intro},
      {'slot': 'step', 'step_index': 1, 'text': step1},
      {'slot': 'step', 'step_index': 2, 'text': step2},
      {'slot': 'summary', 'text': summary},
    ];
  }

  WorkspaceMediaArtifact _latestVideoArtifactFromStatus(
    WorkspaceAnimationJobStatus status, {
    WorkspaceSession? fallback,
  }) {
    final existing = _workspace?.latestMedia;
    if (existing != null && existing.id == status.artifactId) {
      return existing;
    }
    return WorkspaceMediaArtifact(
      id: status.artifactId,
      title: fallback?.currentTopic ?? 'Generated video',
      subtitle: 'Video generated from workspace session.',
      status: status.status,
      durationSeconds: 0,
      durationLabel: '--:--',
      transcript: '',
      notes: const [],
      thumbnailUrl: _resolveMediaUrl(status.thumbnailUrl),
      videoUrl: _resolveMediaUrl(status.videoUrl),
      playbackUrl: _resolveMediaUrl(status.videoUrl),
    );
  }

  String? _resolveMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(rawUrl);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      return rawUrl;
    }
    final baseUri = Uri.parse(ApiClient.defaultBaseUrl);
    if (rawUrl.startsWith('/')) {
      return baseUri.resolve(rawUrl).toString();
    }
    return baseUri.resolve('/$rawUrl').toString();
  }

  WorkspaceMediaArtifact? _withResolvedArtifactUrls(
    WorkspaceMediaArtifact? artifact,
  ) {
    if (artifact == null) {
      return null;
    }
    return WorkspaceMediaArtifact(
      id: artifact.id,
      title: artifact.title,
      subtitle: artifact.subtitle,
      status: artifact.status,
      durationSeconds: artifact.durationSeconds,
      durationLabel: artifact.durationLabel,
      transcript: artifact.transcript,
      notes: artifact.notes,
      thumbnailUrl: _resolveMediaUrl(artifact.thumbnailUrl),
      videoUrl: _resolveMediaUrl(artifact.videoUrl),
      playbackUrl: _resolveMediaUrl(artifact.playbackUrl),
      createdAt: artifact.createdAt,
    );
  }

  Future<void> _answerQuiz(String answer) async {
    final assessmentPack = _assessmentPack;
    final isCorrect = answer == assessmentPack.workspaceQuizCorrectAnswer;
    setState(() {
      _selectedQuizAnswer = answer;
      _quizState = isCorrect
          ? _WorkspaceQuizState.correct
          : _WorkspaceQuizState.review;
    });
    await _appendWorkspaceEvent(
      eventType: 'quiz_answer',
      textPayload: answer,
      metadata: {
        'selected_answer': answer,
        'correct_answer': assessmentPack.workspaceQuizCorrectAnswer,
        'is_correct': isCorrect,
        'confidence': isCorrect ? 8 : 4,
      },
    );
    final arguments = widget.routeArguments;
    if (isCorrect && arguments != null && arguments.isValid) {
      await widget.workspaceRepository.updateModuleState(
        trackId: arguments.trackId,
        moduleId: arguments.moduleId,
        status: 'completed',
      );
    }
    if (isCorrect && mounted) {
      setState(() => _moduleCompleted = true);
      _openPosttestFromWorkspace(
        moduleCompleted: true,
        requestedEarlyPosttest: false,
      );
      return;
    }
    _scrollToBottom();
  }

  Future<void> _requestPosttest() async {
    if (_moduleCompleted) {
      _openPosttestFromWorkspace(
        moduleCompleted: true,
        requestedEarlyPosttest: false,
      );
      return;
    }

    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Workspace not finished yet'),
          content: const Text(
            'You have not finished this workspace module. Starting the posttest now may skip practice evidence for this concept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep learning'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start posttest'),
            ),
          ],
        );
      },
    );
    if (shouldStart == true && mounted) {
      _openPosttestFromWorkspace(
        moduleCompleted: false,
        requestedEarlyPosttest: true,
      );
    }
  }

  void _openPosttestFromWorkspace({
    required bool moduleCompleted,
    required bool requestedEarlyPosttest,
  }) {
    final arguments = widget.routeArguments;
    final assessmentPack = _assessmentPack;
    Navigator.of(context).pop(
      WorkspaceCompletionResult(
        trackId: arguments?.trackId ?? _workspace?.trackId ?? '',
        moduleId: arguments?.moduleId ?? _workspace?.moduleId ?? '',
        moduleTitle: assessmentPack.topicTitle,
        moduleCompleted: moduleCompleted,
        requestedEarlyPosttest: requestedEarlyPosttest,
      ),
    );
  }

  Future<void> _handleCanvasSentToChat(CanvasWorkSnapshot snapshot) async {
    setState(() {
      _canvasSnapshots.add(snapshot);
      _chatEntries.add(_WorkspaceChatEntry.canvas(snapshot));
    });
    await _appendWorkspaceEvent(
      eventType: 'canvas_sent',
      metadata: {
        'version': snapshot.version,
        'element_count': snapshot.elementCount,
        'has_attachment': snapshot.hasAttachment,
        'show_grid': snapshot.showGrid,
        'canvas_width': snapshot.canvasSize.width,
        'canvas_height': snapshot.canvasSize.height,
      },
    );
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    if (_isLoadingWorkspace || _workspace == null) {
      setState(() {
        _workspaceError = 'Chat session is still loading.';
      });
      return;
    }

    _messageController.clear();
    setState(() {
      _chatEntries.add(_WorkspaceChatEntry.text(text: message, isUser: true));
    });
    await _appendWorkspaceEvent(eventType: 'text', textPayload: message);
    _scrollToBottom();
  }

  Future<void> _startLearningChat() async {
    if (_chatEntries.isNotEmpty) {
      return;
    }
    if (_isLoadingWorkspace || _workspace == null) {
      setState(() {
        _workspaceError = 'Chat session is still loading.';
      });
      return;
    }

    final topic = _assessmentPack.topicTitle;
    final message = _normalizedLanguageCode() == 'id'
        ? 'Saya siap mulai belajar $topic.'
        : "I'm ready to start learning $topic.";
    setState(() {
      _chatEntries.add(_WorkspaceChatEntry.text(text: message, isUser: true));
    });
    await _appendWorkspaceEvent(
      eventType: 'text',
      textPayload: message,
      metadata: const {
        'triggered_by': 'workspace_start_chat_button',
        'stage_intent': 'engage',
      },
    );
    _scrollToBottom();
  }

  Future<void> _appendWorkspaceEvent({
    required String eventType,
    String textPayload = '',
    Map<String, dynamic> metadata = const {},
  }) async {
    final workspace = _workspace;
    if (workspace == null) {
      setState(() {
        _workspaceError = 'Workspace is not ready yet.';
      });
      return;
    }
    setState(() {
      _isAppendingEvent = true;
      _workspaceError = null;
    });
    try {
      final result = await widget.workspaceRepository.appendEvent(
        workspaceId: workspace.id,
        eventType: eventType,
        textPayload: textPayload,
        metadata: metadata,
      );
      if (!mounted || _workspace?.id != workspace.id) return;
      final arguments = widget.routeArguments;
      var history = _sessionHistory;
      if (arguments != null && arguments.isValid) {
        try {
          history = await widget.workspaceRepository.fetchSessionHistory(
            trackId: arguments.trackId,
            moduleId: arguments.moduleId,
          );
        } on WorkspaceException {
          history = _sessionHistory;
        }
      }
      if (!mounted || _workspace?.id != workspace.id) return;
      setState(() {
        _workspace = result.workspace;
        _sessionHistory = history;
        if (result.tutorResponse != null &&
            result.tutorResponse!.text.trim().isNotEmpty) {
          _chatEntries.add(
            _WorkspaceChatEntry.text(
              text: result.tutorResponse!.text,
              isUser: false,
            ),
          );
        }
        _isAppendingEvent = false;
      });
    } on WorkspaceException catch (error) {
      if (!mounted || _workspace?.id != workspace.id) return;
      setState(() {
        _isAppendingEvent = false;
        _workspaceError = error.message;
        _chatEntries.add(
          _WorkspaceChatEntry.text(
            text: 'Workspace sync failed: ${error.message}',
            isUser: false,
          ),
        );
      });
    }
  }

  List<_WorkspaceChatEntry> _entriesFromEvents(List<WorkspaceEvent> events) {
    return events
        .map((event) {
          if (event.eventType == 'canvas_sent') {
            final count = event.metadata['element_count'];
            return _WorkspaceChatEntry.text(
              text:
                  'Canvas snapshot sent${count == null ? '' : ' ($count marks)'}',
              isUser: true,
            );
          }
          if (event.textPayload.trim().isEmpty) {
            return null;
          }
          return _WorkspaceChatEntry.text(
            text: event.textPayload,
            isUser: event.isLearner,
          );
        })
        .whereType<_WorkspaceChatEntry>()
        .toList(growable: false);
  }

  void _openCanvas() {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Canvas workspace',
      barrierDismissible: true,
      barrierColor: WicaraColors.ink.withValues(alpha: 0.14),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _WorkspaceCanvasDialog(
          onCanvasSent: (snapshot) {
            _handleCanvasSentToChat(snapshot);
            Navigator.of(context).pop();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = OnboardingCopy.forLanguage(
      widget.onboardingController.profile.preferredLanguage,
    );
    return Scaffold(
      backgroundColor: WicaraColors.pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pageWidth = math.min(constraints.maxWidth, 430.0);

            return Center(
              child: SizedBox(
                width: pageWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.chevron_left_rounded),
                                iconSize: 33,
                                color: WicaraColors.ink,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 38,
                                  height: 38,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Image.asset(
                                'lib/src/assets/workspaceIcon.png',
                                width: 84,
                                height: 84,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Workspace',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _WorkspaceTopicCard(
                            copy: copy,
                            title:
                                _workspace?.currentTopic ??
                                widget.routeArguments?.moduleTitle ??
                                'Workspace module',
                            description: _workspace == null
                                ? 'Connect this module to backend workspace evidence before chatting, sketching, or answering.'
                                : 'Your messages, canvas snapshots, and quiz answers are synced to backend workspace evidence.',
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoadingWorkspace
                                      ? null
                                      : () {
                                          unawaited(_startNewChatSession());
                                        },
                                  icon: const Icon(Icons.add_comment_outlined),
                                  label: const Text('New chat'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    unawaited(_openSessionHistorySheet());
                                  },
                                  icon: const Icon(Icons.history_rounded),
                                  label: Text(
                                    'History (${_sessionHistory.length})',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _isLoadingWorkspace
                                ? null
                                : () {
                                    unawaited(_requestPosttest());
                                  },
                            icon: const Icon(
                              Icons.assignment_turned_in_outlined,
                            ),
                            label: const Text('Start Posttest'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, viewportConstraints) {
                          return SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: viewportConstraints.maxHeight - 12,
                              ),
                              child: _WorkspaceChatPanel(
                                contentMode: _contentMode,
                                quizState: _quizState,
                                selectedQuizAnswer: _selectedQuizAnswer,
                                chatEntries: _chatEntries,
                                canvasSnapshots: _canvasSnapshots,
                                assessmentPack: _assessmentPack,
                                isLoadingWorkspace: _isLoadingWorkspace,
                                isAppendingEvent: _isAppendingEvent,
                                isVideoGenerating: _isVideoGenerating,
                                workspaceError: _workspaceError,
                                latestVideoStatus: _latestVideoStatus,
                                latestVideoArtifact: _latestVideoArtifact,
                                videoStatusMessage: _videoStatusMessage,
                                videoErrorMessage: _videoErrorMessage,
                                canGenerateVideo:
                                    _canGenerateVideoForCurrentTopic(),
                                videoTemplateHint: _videoTemplateHintMessage(),
                                weeklyReport: _reportCardDismissed
                                    ? null
                                    : _weeklyReport,
                                onDismissReport: () {
                                  setState(() => _reportCardDismissed = true);
                                },
                                onGenerateVideo: () {
                                  unawaited(_generateVideo());
                                },
                                onAnswerQuiz: _answerQuiz,
                                onStartChat: () {
                                  unawaited(_startLearningChat());
                                },
                                onOpenCanvas: _openCanvas,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _WorkspaceFooter(
                      controller: _messageController,
                      onSend: _sendMessage,
                      onGenerateVideo: () {
                        unawaited(_generateVideo());
                      },
                      isVideoGenerating: _isVideoGenerating,
                      canGenerateVideo: _canGenerateVideoForCurrentTopic(),
                      contentMode: _contentMode,
                      videoStatusMessage: _videoStatusMessage,
                      videoErrorMessage: _videoErrorMessage,
                      copy: copy,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WorkspaceChatEntry {
  const _WorkspaceChatEntry.text({required this.text, required this.isUser})
    : snapshot = null;

  const _WorkspaceChatEntry.canvas(this.snapshot) : text = null, isUser = true;

  final String? text;
  final bool isUser;
  final CanvasWorkSnapshot? snapshot;

  bool get isCanvas => snapshot != null;
}

class _WorkspaceHistorySheet extends StatelessWidget {
  const _WorkspaceHistorySheet({
    required this.sessions,
    required this.activeSessionId,
  });

  final List<WorkspaceSessionSummary> sessions;
  final String? activeSessionId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                'Chat history',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: WicaraColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sessions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final isActive = session.id == activeSessionId;
                  return ListTile(
                    leading: Icon(
                      isActive
                          ? Icons.chat_bubble_rounded
                          : Icons.chat_bubble_outline_rounded,
                      color: isActive
                          ? WicaraColors.primary
                          : WicaraColors.muted,
                    ),
                    title: Text(
                      session.title.isEmpty ? 'New chat' : session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      _historySubtitle(session),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isActive
                        ? const Icon(Icons.check_rounded)
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(session.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _historySubtitle(WorkspaceSessionSummary session) {
    final parts = <String>[];
    if (session.preview.isNotEmpty) {
      parts.add(session.preview);
    }
    final countLabel = session.messageCount == 1
        ? '1 message'
        : '${session.messageCount} messages';
    parts.add(countLabel);
    final timeLabel = _compactDate(session.updatedAt);
    if (timeLabel.isNotEmpty) {
      parts.add(timeLabel);
    }
    return parts.join(' | ');
  }

  String _compactDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return '';
    }
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} $hour:$minute';
  }
}

class _VideoGenerationPayload {
  const _VideoGenerationPayload({
    required this.templateId,
    required this.specJson,
    required this.language,
  });

  final String templateId;
  final Map<String, dynamic> specJson;
  final String language;
}

class _VideoTemplateMatch {
  const _VideoTemplateMatch({required this.templateId, required this.keywords});

  final String templateId;
  final List<String> keywords;
}

class _WorkspaceChatPanel extends StatelessWidget {
  const _WorkspaceChatPanel({
    required this.contentMode,
    required this.quizState,
    required this.selectedQuizAnswer,
    required this.chatEntries,
    required this.canvasSnapshots,
    required this.assessmentPack,
    required this.isLoadingWorkspace,
    required this.isAppendingEvent,
    required this.isVideoGenerating,
    required this.workspaceError,
    required this.latestVideoStatus,
    required this.latestVideoArtifact,
    required this.videoStatusMessage,
    required this.videoErrorMessage,
    required this.canGenerateVideo,
    required this.videoTemplateHint,
    required this.onGenerateVideo,
    required this.onAnswerQuiz,
    required this.onStartChat,
    required this.onOpenCanvas,
    this.weeklyReport,
    this.onDismissReport,
  });

  final _WorkspaceContentMode contentMode;
  final _WorkspaceQuizState quizState;
  final String? selectedQuizAnswer;
  final List<_WorkspaceChatEntry> chatEntries;
  final List<CanvasWorkSnapshot> canvasSnapshots;
  final HardcodedAssessmentPack assessmentPack;
  final bool isLoadingWorkspace;
  final bool isAppendingEvent;
  final bool isVideoGenerating;
  final String? workspaceError;
  final WorkspaceAnimationJobStatus? latestVideoStatus;
  final WorkspaceMediaArtifact? latestVideoArtifact;
  final String? videoStatusMessage;
  final String? videoErrorMessage;
  final bool canGenerateVideo;
  final String? videoTemplateHint;
  final VoidCallback onGenerateVideo;
  final ValueChanged<String> onAnswerQuiz;
  final VoidCallback onStartChat;
  final VoidCallback onOpenCanvas;
  final WeeklyLearningReport? weeklyReport;
  final VoidCallback? onDismissReport;

  @override
  Widget build(BuildContext context) {
    return _WorkspacePanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Weekly report card (dismissible, shown at top of chat) ────────
          if (weeklyReport != null) ...[
            _WeeklyReportChatCard(
              report: weeklyReport!,
              onDismiss: onDismissReport,
            ),
            const SizedBox(height: 14),
          ],
          _AssistantMessageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WorkspaceBubble(
                  text: assessmentPack.workspaceIntroLine1,
                  isUser: false,
                ),
                const SizedBox(height: 9),
                _WorkspaceBubble(
                  text: assessmentPack.workspaceIntroLine2,
                  isUser: false,
                ),
              ],
            ),
          ),
          if (isLoadingWorkspace) ...[
            const SizedBox(height: 10),
            const _WorkspaceSyncNotice(
              icon: Icons.cloud_sync_outlined,
              text: 'Connecting to backend workspace...',
            ),
          ] else if (workspaceError != null) ...[
            const SizedBox(height: 10),
            _WorkspaceSyncNotice(
              icon: Icons.error_outline_rounded,
              text: workspaceError!,
              isError: true,
            ),
          ] else if (isAppendingEvent) ...[
            const SizedBox(height: 10),
            const _WorkspaceSyncNotice(
              icon: Icons.sync_rounded,
              text: 'Saving workspace evidence...',
            ),
          ],
          if (videoTemplateHint != null) ...[
            const SizedBox(height: 10),
            _WorkspaceSyncNotice(
              icon: Icons.info_outline_rounded,
              text: videoTemplateHint!,
              isError: true,
            ),
          ],
          if (!isLoadingWorkspace &&
              workspaceError == null &&
              chatEntries.isEmpty) ...[
            const SizedBox(height: 14),
            _WorkspaceStartChatCard(onStartChat: onStartChat),
          ],
          if (!isLoadingWorkspace &&
              workspaceError == null &&
              chatEntries.isNotEmpty) ...[
            const SizedBox(height: 14),
            _WorkspaceQuizCard(
              quizState: quizState,
              selectedAnswer: selectedQuizAnswer,
              onAnswer: onAnswerQuiz,
              assessmentPack: assessmentPack,
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _WorkspaceCanvasPromptBubble(
              hasCanvasWork: canvasSnapshots.isNotEmpty,
              onUseCanvas: onOpenCanvas,
            ),
          ),
          for (final entry in chatEntries) ...[
            const SizedBox(height: 9),
            if (entry.isCanvas)
              Align(
                alignment: Alignment.centerRight,
                child: _CanvasSnapshotBubble(snapshot: entry.snapshot!),
              )
            else if (entry.isUser)
              _WorkspaceBubble(text: entry.text!, isUser: true)
            else
              _AssistantMessageFrame(
                child: _WorkspaceBubble(text: entry.text!, isUser: false),
              ),
          ],
          if (contentMode == _WorkspaceContentMode.videoProcessing) ...[
            const SizedBox(height: 14),
            _WorkspaceVideoLoadingCard(
              progress: latestVideoStatus?.progress ?? 0,
              message:
                  videoStatusMessage ??
                  'Building scenes, narration, and rendering...',
            ),
          ] else if (contentMode == _WorkspaceContentMode.videoReady) ...[
            const SizedBox(height: 14),
            _GeneratedWorkspaceVideoCard(
              artifact: latestVideoArtifact,
              status: latestVideoStatus,
            ),
          ] else if (contentMode == _WorkspaceContentMode.videoFailed) ...[
            const SizedBox(height: 14),
            _WorkspaceVideoFailedCard(
              errorMessage:
                  videoErrorMessage ??
                  latestVideoStatus?.error ??
                  'Video generation failed.',
              onRetry: onGenerateVideo,
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceCanvasDialog extends StatelessWidget {
  const _WorkspaceCanvasDialog({required this.onCanvasSent});

  final ValueChanged<CanvasWorkSnapshot> onCanvasSent;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: WicaraColors.pageBackground,
      surfaceTintColor: WicaraColors.pageBackground,
      child: SizedBox.expand(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth > 640
                  ? 28.0
                  : 12.0;
              final verticalPadding = constraints.maxHeight > 700 ? 24.0 : 12.0;
              final canvasWidth = math.min(
                constraints.maxWidth - horizontalPadding * 2,
                860.0,
              );
              final canvasHeight = math.max(
                420.0,
                constraints.maxHeight - verticalPadding * 2,
              );

              return Center(
                child: SizedBox(
                  width: canvasWidth,
                  height: canvasHeight,
                  child: FishboneCanvas(
                    height: canvasHeight,
                    isLargePanel: true,
                    onOpenLargePanel: () => Navigator.of(context).pop(),
                    onSendToChat: onCanvasSent,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WorkspaceSyncNotice extends StatelessWidget {
  const _WorkspaceSyncNotice({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? WicaraColors.accentCoral : WicaraColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF2EF) : WicaraColors.secondarySoft,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceBubble extends StatelessWidget {
  const _WorkspaceBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 250),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isUser ? WicaraColors.speechBlue : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isUser ? WicaraColors.primaryLight : WicaraColors.line,
            ),
            boxShadow: [
              BoxShadow(
                color: WicaraColors.shadowBlue.withValues(alpha: 0.18),
                blurRadius: 15,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WicaraColors.text,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantMessageFrame extends StatelessWidget {
  const _AssistantMessageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AgentAvatar(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agent',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: WicaraColors.secondaryDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WicaraColors.secondary, WicaraColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: WicaraColors.secondary.withValues(alpha: 0.26),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Image.asset(
          'lib/src/assets/waveIcon.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _WorkspaceTopicCard extends StatelessWidget {
  const _WorkspaceTopicCard({
    required this.copy,
    required this.title,
    required this.description,
  });

  final OnboardingCopy copy;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: WicaraColors.line),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: WicaraColors.secondarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              copy.currentTopicLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: WicaraColors.secondaryDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: WicaraColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCanvasPromptBubble extends StatelessWidget {
  const _WorkspaceCanvasPromptBubble({
    required this.hasCanvasWork,
    required this.onUseCanvas,
  });

  final bool hasCanvasWork;
  final VoidCallback onUseCanvas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: WicaraColors.line),
            boxShadow: [
              BoxShadow(
                color: WicaraColors.shadowBlue.withValues(alpha: 0.16),
                blurRadius: 15,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Text(
            hasCanvasWork
                ? 'Canvas work is attached. Add another sketch if needed.'
                : 'Need a whiteboard? Open canvas and send your sketch here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _WorkspaceCanvasQuickActionButton(
          label: hasCanvasWork ? 'Open canvas' : 'Use canvas',
          onPressed: onUseCanvas,
        ),
      ],
    );
  }
}

class _WorkspaceCanvasQuickActionButton extends StatelessWidget {
  const _WorkspaceCanvasQuickActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: WicaraColors.secondary,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: WicaraColors.secondary.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.draw_outlined, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceVideoLoadingCard extends StatelessWidget {
  const _WorkspaceVideoLoadingCard({
    required this.progress,
    required this.message,
  });

  final int progress;
  final String message;

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = (progress.clamp(0, 100)) / 100;
    return _WorkspaceRichBubble(
      icon: Icons.movie_creation_outlined,
      title: 'Generating video',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: normalizedProgress == 0 ? null : normalizedProgress,
              minHeight: 7,
              color: WicaraColors.primaryDeep,
              backgroundColor: WicaraColors.primarySoft,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            '$progress%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.secondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedWorkspaceVideoCard extends StatelessWidget {
  const _GeneratedWorkspaceVideoCard({this.artifact, this.status});

  final WorkspaceMediaArtifact? artifact;
  final WorkspaceAnimationJobStatus? status;

  @override
  Widget build(BuildContext context) {
    final title = artifact?.title ?? 'Generated video';
    final subtitle =
        artifact?.subtitle ??
        'Video rendering finished and is ready in your workspace.';
    final durationLabel = artifact?.durationLabel.isNotEmpty == true
        ? artifact!.durationLabel
        : '--:--';
    final playbackUrl = artifact?.videoUrl ?? status?.videoUrl ?? '';
    final thumbnailUrl = artifact?.thumbnailUrl ?? status?.thumbnailUrl;
    final canPlay = playbackUrl.isNotEmpty;

    return _WorkspaceRichBubble(
      icon: Icons.video_collection_outlined,
      title: 'Saved generated video',
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WicaraColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                      Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return CustomPaint(
                            painter: _WorkspaceVideoPreviewPainter(),
                          );
                        },
                      )
                    else
                      CustomPaint(painter: _WorkspaceVideoPreviewPainter()),
                    Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: WicaraColors.shadowBlue.withValues(
                                alpha: 0.32,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: WicaraColors.secondary,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: WicaraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WicaraColors.muted,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      _GeneratedVideoChip(durationLabel),
                      const SizedBox(width: 7),
                      const _GeneratedVideoChip('AI video'),
                      if (playbackUrl.isNotEmpty) ...[
                        const SizedBox(width: 7),
                        const _GeneratedVideoChip('Ready URL'),
                      ],
                      const Spacer(),
                      Icon(
                        Icons.check_circle_rounded,
                        color: WicaraColors.accentMint,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canPlay
                          ? () {
                              showDialog<void>(
                                context: context,
                                builder: (context) {
                                  return _WorkspaceVideoPlayerDialog(
                                    title: title,
                                    videoUrl: playbackUrl,
                                    durationLabel: durationLabel,
                                  );
                                },
                              );
                            }
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        canPlay
                            ? 'Play generated video'
                            : 'Video URL unavailable',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceVideoPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEAF4FF), Color(0xFFDCEEFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final circlePaint = Paint()
      ..color = const Color(0xFFBBD8FF).withValues(alpha: 0.45);
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.28),
      size.shortestSide * 0.16,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.76),
      size.shortestSide * 0.2,
      circlePaint,
    );

    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF9EC3F8);
    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.14,
        size.height * 0.2,
        size.width * 0.72,
        size.height * 0.6,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(frameRect, framePaint);

    final playPath = Path()
      ..moveTo(size.width * 0.46, size.height * 0.39)
      ..lineTo(size.width * 0.46, size.height * 0.61)
      ..lineTo(size.width * 0.62, size.height * 0.5)
      ..close();
    final playPaint = Paint()..color = const Color(0xFF6FA3EA);
    canvas.drawPath(playPath, playPaint);
  }

  @override
  bool shouldRepaint(covariant _WorkspaceVideoPreviewPainter oldDelegate) =>
      false;
}

class _WorkspaceVideoFailedCard extends StatelessWidget {
  const _WorkspaceVideoFailedCard({
    required this.errorMessage,
    required this.onRetry,
  });

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceRichBubble(
      icon: Icons.error_outline_rounded,
      title: 'Video generation failed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            errorMessage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.accentCoral,
              fontWeight: FontWeight.w700,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry generate video'),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceVideoPlayerDialog extends StatefulWidget {
  const _WorkspaceVideoPlayerDialog({
    required this.title,
    required this.videoUrl,
    this.durationLabel,
    this.isFullscreen = false,
    this.initialPosition,
  });

  final String title;
  final String videoUrl;
  final String? durationLabel;
  final bool isFullscreen;
  final Duration? initialPosition;

  @override
  State<_WorkspaceVideoPlayerDialog> createState() =>
      _WorkspaceVideoPlayerDialogState();
}

class _WorkspaceVideoPlayerDialogState
    extends State<_WorkspaceVideoPlayerDialog> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  double _zoomScale = 1.0;
  double? _timelineHoverFraction;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await controller.initialize();
      final requestedPosition = widget.initialPosition;
      if (requestedPosition != null && requestedPosition > Duration.zero) {
        final maxPosition = controller.value.duration;
        final clampedPosition = requestedPosition > maxPosition
            ? maxPosition
            : requestedPosition;
        await controller.seekTo(clampedPosition);
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isLoading = false;
      });
      await controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load video from backend URL.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _setZoomScale(double value) {
    setState(() {
      _zoomScale = value.clamp(1.0, 3.0);
    });
  }

  Future<void> _openFullscreenPlayer(VideoPlayerController controller) async {
    final currentPosition = controller.value.position;
    final wasPlaying = controller.value.isPlaying;
    await controller.pause();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (_) {
        return _WorkspaceVideoPlayerDialog(
          title: widget.title,
          videoUrl: widget.videoUrl,
          durationLabel: widget.durationLabel,
          isFullscreen: true,
          initialPosition: currentPosition,
        );
      },
    );

    if (!mounted || !wasPlaying) return;
    await controller.play();
  }

  void _updateTimelineHover({
    required double localDx,
    required double trackWidth,
  }) {
    if (trackWidth <= 0) return;
    final fraction = (localDx / trackWidth).clamp(0.0, 1.0);
    if (_timelineHoverFraction == fraction) return;
    setState(() {
      _timelineHoverFraction = fraction;
    });
  }

  void _clearTimelineHover() {
    if (_timelineHoverFraction == null) return;
    setState(() {
      _timelineHoverFraction = null;
    });
  }

  String _formatTimelineTime(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isFullscreen = widget.isFullscreen;
    final foreground = isFullscreen ? Colors.white : WicaraColors.text;
    final card = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isFullscreen &&
                  !_isLoading &&
                  _errorMessage == null &&
                  controller != null)
                IconButton(
                  onPressed: () => _openFullscreenPlayer(controller),
                  icon: const Icon(Icons.open_in_full_rounded),
                  color: foreground,
                  tooltip: 'Open fullscreen',
                ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.close_rounded,
                ),
                color: foreground,
              ),
            ],
          ),
          if ((widget.durationLabel ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: _GeneratedVideoChip('Duration ${widget.durationLabel}'),
            ),
          ],
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: controller?.value.isInitialized == true
                ? controller!.value.aspectRatio
                : 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                    : InteractiveViewer(
                        minScale: 1,
                        maxScale: 3,
                        panEnabled: true,
                        scaleEnabled: true,
                        child: Center(
                          child: Transform.scale(
                            scale: _zoomScale,
                            child: VideoPlayer(controller!),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!_isLoading && _errorMessage == null && controller != null)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final totalDuration = value.duration > Duration.zero
                    ? value.duration
                    : const Duration(seconds: 1);
                final maxMs = totalDuration.inMilliseconds;
                final positionMs = value.position.inMilliseconds
                    .clamp(0, maxMs)
                    .toInt();
                final sliderValue = maxMs <= 0 ? 0.0 : positionMs / maxMs;
                final currentLabel = _formatTimelineTime(
                  Duration(milliseconds: positionMs),
                );
                final totalLabel = _formatTimelineTime(totalDuration);

                return Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (value.isPlaying) {
                                controller.pause();
                              } else {
                                controller.play();
                              }
                            });
                          },
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          color: foreground,
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final trackWidth = constraints.maxWidth;
                              final hoverFraction = _timelineHoverFraction;
                              final showHover =
                                  hoverFraction != null && trackWidth > 0;
                              final safeHoverFraction = hoverFraction ?? 0.0;
                              final hoverMs = showHover
                                  ? (maxMs * safeHoverFraction).round()
                                  : 0;
                              final hoverLabel = showHover
                                  ? _formatTimelineTime(
                                      Duration(milliseconds: hoverMs),
                                    )
                                  : '';
                              final bubbleWidth = 64.0;
                              final hoverLeft = showHover
                                  ? ((trackWidth * safeHoverFraction) -
                                            (bubbleWidth / 2))
                                        .clamp(
                                          0.0,
                                          math.max(
                                            0.0,
                                            trackWidth - bubbleWidth,
                                          ),
                                        )
                                        .toDouble()
                                  : 0.0;

                              return MouseRegion(
                                onHover: (event) {
                                  _updateTimelineHover(
                                    localDx: event.localPosition.dx,
                                    trackWidth: trackWidth,
                                  );
                                },
                                onExit: (_) => _clearTimelineHover(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: showHover ? 22 : 0,
                                      child: showHover
                                          ? Stack(
                                              children: [
                                                Positioned(
                                                  left: hoverLeft,
                                                  width: bubbleWidth,
                                                  child: Container(
                                                    height: 20,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: Colors.black87,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      hoverLabel,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 5,
                                        ),
                                        overlayShape:
                                            SliderComponentShape.noOverlay,
                                        activeTrackColor:
                                            WicaraColors.secondary,
                                        inactiveTrackColor: WicaraColors.line,
                                        thumbColor: WicaraColors.secondary,
                                      ),
                                      child: Slider(
                                        value: sliderValue.clamp(0.0, 1.0),
                                        min: 0,
                                        max: 1,
                                        onChanged: (nextValue) {
                                          final target = Duration(
                                            milliseconds: (maxMs * nextValue)
                                                .round(),
                                          );
                                          controller.seekTo(target);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () => _setZoomScale(_zoomScale - 0.25),
                          icon: const Icon(Icons.zoom_out_rounded),
                          color: foreground,
                        ),
                        IconButton(
                          onPressed: () => _setZoomScale(1.0),
                          icon: const Icon(Icons.filter_center_focus_rounded),
                          color: foreground,
                        ),
                        IconButton(
                          onPressed: () => _setZoomScale(_zoomScale + 0.25),
                          icon: const Icon(Icons.zoom_in_rounded),
                          color: foreground,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          currentLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: foreground.withValues(alpha: 0.82),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          totalLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: foreground.withValues(alpha: 0.82),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );

    if (isFullscreen) {
      return Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: ColoredBox(color: Colors.black, child: card),
        ),
      );
    }

    return Dialog(insetPadding: const EdgeInsets.all(16), child: card);
  }
}

class _GeneratedVideoChip extends StatelessWidget {
  const _GeneratedVideoChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: WicaraColors.line),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: WicaraColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WorkspaceQuizCard extends StatelessWidget {
  const _WorkspaceQuizCard({
    required this.quizState,
    required this.selectedAnswer,
    required this.onAnswer,
    required this.assessmentPack,
  });

  final _WorkspaceQuizState quizState;
  final String? selectedAnswer;
  final ValueChanged<String> onAnswer;
  final HardcodedAssessmentPack assessmentPack;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceRichBubble(
      icon: Icons.quiz_outlined,
      title: 'Check understanding',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WorkspaceMaterialRecap(
            explanationText: assessmentPack.workspaceExplanation,
          ),
          const SizedBox(height: 12),
          Text(
            assessmentPack.workspaceQuizQuestion,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.text,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          for (final answer in assessmentPack.workspaceQuizOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WorkspaceQuizOption(
                label: answer,
                isSelected: selectedAnswer == answer,
                isCorrect: answer == assessmentPack.workspaceQuizCorrectAnswer,
                hasAnswered: quizState != _WorkspaceQuizState.unanswered,
                onPressed: () => onAnswer(answer),
              ),
            ),
          if (quizState != _WorkspaceQuizState.unanswered) ...[
            const SizedBox(height: 3),
            Text(
              quizState == _WorkspaceQuizState.correct
                  ? assessmentPack.workspaceQuizCorrectFeedback
                  : assessmentPack.workspaceQuizReviewFeedback,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: quizState == _WorkspaceQuizState.correct
                    ? WicaraColors.accentMint
                    : WicaraColors.accentCoral,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceStartChatCard extends StatelessWidget {
  const _WorkspaceStartChatCard({required this.onStartChat});

  final VoidCallback onStartChat;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceRichBubble(
      icon: Icons.auto_awesome_rounded,
      title: 'Start the 5E chat',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Begin with the tutor opening question. This starts the Engage step and creates the first workspace evidence.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.text,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onStartChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Start learning chat'),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceMaterialRecap extends StatelessWidget {
  const _WorkspaceMaterialRecap({required this.explanationText});

  final String explanationText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WicaraColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Material recap',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: WicaraColors.primaryDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            explanationText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.text,
              fontWeight: FontWeight.w600,
              height: 1.38,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceQuizOption extends StatelessWidget {
  const _WorkspaceQuizOption({
    required this.label,
    required this.isSelected,
    required this.isCorrect,
    required this.hasAnswered,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final bool isCorrect;
  final bool hasAnswered;
  final VoidCallback onPressed;

  Color get _borderColor {
    if (!hasAnswered || !isSelected) return WicaraColors.line;
    return isCorrect ? WicaraColors.accentMint : WicaraColors.accentCoral;
  }

  Color get _background {
    if (!hasAnswered || !isSelected) return Colors.white;
    return isCorrect
        ? WicaraColors.speechGreen
        : WicaraColors.glowPeach.withValues(alpha: 0.62);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _background,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _borderColor, width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hasAnswered && isSelected)
                Icon(
                  isCorrect
                      ? Icons.check_circle_rounded
                      : Icons.refresh_rounded,
                  color: isCorrect
                      ? WicaraColors.accentMint
                      : WicaraColors.accentCoral,
                  size: 19,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasSnapshotBubble extends StatelessWidget {
  const _CanvasSnapshotBubble({required this.snapshot});

  final CanvasWorkSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 270),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: WicaraColors.primaryLight),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.18),
            blurRadius: 15,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.draw_outlined,
                color: WicaraColors.primaryDeep,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Canvas sent',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CanvasWorkPreview(snapshot: snapshot),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${snapshot.elementCount} marks${snapshot.hasAttachment ? ' • paper attached' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceFooter extends StatelessWidget {
  const _WorkspaceFooter({
    required this.controller,
    required this.onSend,
    required this.onGenerateVideo,
    required this.isVideoGenerating,
    required this.canGenerateVideo,
    required this.contentMode,
    required this.videoStatusMessage,
    required this.videoErrorMessage,
    required this.copy,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onGenerateVideo;
  final bool isVideoGenerating;
  final bool canGenerateVideo;
  final _WorkspaceContentMode contentMode;
  final String? videoStatusMessage;
  final String? videoErrorMessage;
  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WicaraColors.pageBackground.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: WicaraColors.line)),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 11, 28, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: !isVideoGenerating && canGenerateVideo
                  ? onGenerateVideo
                  : null,
              icon: Icon(
                isVideoGenerating
                    ? Icons.hourglass_bottom_rounded
                    : Icons.smart_display_rounded,
              ),
              label: Text(
                isVideoGenerating
                    ? 'Generating video...'
                    : 'Generate video from this chat',
              ),
            ),
            if (contentMode == _WorkspaceContentMode.videoProcessing) ...[
              const SizedBox(height: 8),
              _WorkspaceSyncNotice(
                icon: Icons.movie_creation_outlined,
                text:
                    videoStatusMessage ??
                    'Generating video from your latest conversation context...',
              ),
            ] else if (contentMode == _WorkspaceContentMode.videoFailed &&
                (videoErrorMessage?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              _WorkspaceSyncNotice(
                icon: Icons.error_outline_rounded,
                text: videoErrorMessage!,
                isError: true,
              ),
            ] else if (contentMode == _WorkspaceContentMode.videoReady) ...[
              const SizedBox(height: 8),
              const _WorkspaceSyncNotice(
                icon: Icons.check_circle_rounded,
                text: 'Video ready. You can play it from the latest chat card.',
              ),
            ],
            const SizedBox(height: 10),
            _WorkspaceComposerInput(
              controller: controller,
              onSend: onSend,
              copy: copy,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceComposerInput extends StatelessWidget {
  const _WorkspaceComposerInput({
    required this.controller,
    required this.onSend,
    required this.copy,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final OnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 2,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: copy.askOrReflectHereHint,
              filled: true,
              fillColor: WicaraColors.fieldFill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: WicaraColors.secondaryLight,
                  width: 1.4,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: WicaraColors.secondary,
                  width: 1.7,
                ),
              ),
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: WicaraColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 53,
          height: 53,
          decoration: BoxDecoration(
            color: WicaraColors.secondary,
            borderRadius: BorderRadius.circular(27),
            boxShadow: [
              BoxShadow(
                color: WicaraColors.secondary.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.arrow_upward_rounded),
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceRichBubble extends StatelessWidget {
  const _WorkspaceRichBubble({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WicaraColors.line, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: WicaraColors.secondary, size: 19),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            child,
          ],
        ),
      ),
    );
  }
}

class _WorkspacePanel extends StatelessWidget {
  const _WorkspacePanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: WicaraColors.line, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.12),
            blurRadius: 17,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Weekly Report Chat Card
// ────────────────────────────────────────────────────────────────────────────

/// A compact, dismissible summary card shown at the top of the workspace
/// chatbot whenever the HomeRepository is configured. It displays the user's
/// latest weekly learning progress so they can pick up where they left off.
class _WeeklyReportChatCard extends StatelessWidget {
  const _WeeklyReportChatCard({required this.report, this.onDismiss});

  final WeeklyLearningReport report;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final score = report.score;
    final fixed = report.fixedGaps;
    final remaining = report.remainingGaps;
    final minutes = report.retentionMinutes;
    final notes = report.summaryNotes.take(3).toList();
    final consistency = report.consistencySummary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WicaraColors.primary.withValues(alpha: 0.10),
            WicaraColors.primaryDeep.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: WicaraColors.primary.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: WicaraColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: 16,
                  color: WicaraColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Report',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: WicaraColors.primary,
                        height: 1.1,
                      ),
                    ),
                    if (report.rangeLabel.isNotEmpty)
                      Text(
                        report.rangeLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: WicaraColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: WicaraColors.muted,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Stat row ────────────────────────────────────────────────────
          Row(
            children: [
              _ReportStat(
                value: score > 0 ? '$score%' : '--',
                label: 'Score',
                color: WicaraColors.primary,
              ),
              const SizedBox(width: 8),
              _ReportStat(
                value: '+$fixed',
                label: 'Fixed gaps',
                color: WicaraColors.accentMint,
              ),
              const SizedBox(width: 8),
              _ReportStat(
                value: '$remaining',
                label: 'Remaining',
                color: remaining > 0
                    ? const Color(0xFFF4A44E)
                    : WicaraColors.accentMint,
              ),
              const SizedBox(width: 8),
              _ReportStat(
                value: '${minutes}m',
                label: 'Retention',
                color: WicaraColors.primaryDeep,
              ),
            ],
          ),

          // ── Summary notes ───────────────────────────────────────────────
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: WicaraColors.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        note,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: WicaraColors.text,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Consistency summary ─────────────────────────────────────────
          if (consistency.narrative.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              decoration: BoxDecoration(
                color: WicaraColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                consistency.narrative,
                style: TextStyle(
                  fontSize: 11,
                  color: WicaraColors.primaryDeep,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  const _ReportStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                color: WicaraColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
