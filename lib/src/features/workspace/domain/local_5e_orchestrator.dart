class Local5ETransitionDecision {
  const Local5ETransitionDecision({
    required this.phaseBefore,
    required this.phaseAfter,
    required this.nextPhaseReady,
    required this.phaseTransitionPending,
    required this.autoAdvanced,
    required this.transitionReason,
    required this.state,
  });

  final String phaseBefore;
  final String phaseAfter;
  final bool nextPhaseReady;
  final bool phaseTransitionPending;
  final bool autoAdvanced;
  final String transitionReason;
  final Local5EState state;
}

class Local5EPhaseHistoryEntry {
  const Local5EPhaseHistoryEntry({
    required this.phase,
    required this.enteredAtIso8601,
    this.exitedAtIso8601,
    this.turnCount = 0,
  });

  final String phase;
  final String enteredAtIso8601;
  final String? exitedAtIso8601;
  final int turnCount;

  Local5EPhaseHistoryEntry copyWith({
    String? phase,
    String? enteredAtIso8601,
    String? exitedAtIso8601,
    int? turnCount,
    bool clearExitedAt = false,
  }) {
    return Local5EPhaseHistoryEntry(
      phase: phase ?? this.phase,
      enteredAtIso8601: enteredAtIso8601 ?? this.enteredAtIso8601,
      exitedAtIso8601: clearExitedAt
          ? null
          : (exitedAtIso8601 ?? this.exitedAtIso8601),
      turnCount: turnCount ?? this.turnCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phase': phase,
      'entered_at': enteredAtIso8601,
      'exited_at': exitedAtIso8601,
      'turn_count': turnCount,
    };
  }
}

class Local5EState {
  const Local5EState({
    required this.workspaceId,
    required this.currentPhase,
    required this.phaseTransitionPending,
    required this.posttestEligible,
    required this.visitedPhases,
    required this.phaseMinTurns,
    required this.phaseHistory,
  });

  final String workspaceId;
  final String currentPhase;
  final bool phaseTransitionPending;
  final bool posttestEligible;
  final List<String> visitedPhases;
  final Map<String, int> phaseMinTurns;
  final List<Local5EPhaseHistoryEntry> phaseHistory;

  int get currentPhaseTurnCount {
    if (phaseHistory.isEmpty) {
      return 0;
    }
    return phaseHistory.last.turnCount;
  }

  Map<String, dynamic> toClientMetadata() {
    return {
      'current_phase': currentPhase,
      'phase_transition_pending': phaseTransitionPending,
      'posttest_eligible': posttestEligible,
      'visited_5e_phases': visitedPhases,
      'phase_min_turns': phaseMinTurns,
      'phase_history': phaseHistory.map((item) => item.toJson()).toList(),
    };
  }

  Local5EState copyWith({
    String? workspaceId,
    String? currentPhase,
    bool? phaseTransitionPending,
    bool? posttestEligible,
    List<String>? visitedPhases,
    Map<String, int>? phaseMinTurns,
    List<Local5EPhaseHistoryEntry>? phaseHistory,
  }) {
    return Local5EState(
      workspaceId: workspaceId ?? this.workspaceId,
      currentPhase: currentPhase ?? this.currentPhase,
      phaseTransitionPending:
          phaseTransitionPending ?? this.phaseTransitionPending,
      posttestEligible: posttestEligible ?? this.posttestEligible,
      visitedPhases: visitedPhases ?? this.visitedPhases,
      phaseMinTurns: phaseMinTurns ?? this.phaseMinTurns,
      phaseHistory: phaseHistory ?? this.phaseHistory,
    );
  }
}

class Local5EOrchestrator {
  const Local5EOrchestrator();

  static const List<String> phaseSequence = <String>[
    'engage',
    'explore',
    'explain',
    'elaborate',
    'evaluate',
  ];

  static const Map<String, int> defaultPhaseMinTurns = <String, int>{
    'engage': 1,
    'explore': 1,
    'explain': 1,
    'elaborate': 1,
    'evaluate': 1,
  };

  static final Map<String, Local5EState> _statesByWorkspace =
      <String, Local5EState>{};

  Local5EState ensureState({
    required String workspaceId,
    required String backendCurrentPhase,
    required bool backendPhaseTransitionPending,
    required bool backendPosttestEligible,
  }) {
    final key = workspaceId.trim();
    if (key.isEmpty) {
      throw ArgumentError('workspaceId must not be empty.');
    }
    final normalizedPhase = normalizePhase(backendCurrentPhase);
    final existing = _statesByWorkspace[key];
    if (existing == null) {
      final now = _nowIso();
      final initial = Local5EState(
        workspaceId: key,
        currentPhase: normalizedPhase,
        phaseTransitionPending: backendPhaseTransitionPending,
        posttestEligible:
            backendPosttestEligible || normalizedPhase == 'evaluate',
        visitedPhases: <String>[normalizedPhase],
        phaseMinTurns: Map<String, int>.from(defaultPhaseMinTurns),
        phaseHistory: <Local5EPhaseHistoryEntry>[
          Local5EPhaseHistoryEntry(
            phase: normalizedPhase,
            enteredAtIso8601: now,
            exitedAtIso8601: null,
            turnCount: 0,
          ),
        ],
      );
      _statesByWorkspace[key] = initial;
      return initial;
    }

    final synced = _syncPhaseFromBackend(
      existing,
      backendPhase: normalizedPhase,
      backendPending: backendPhaseTransitionPending,
      backendPosttestEligible: backendPosttestEligible,
    );
    _statesByWorkspace[key] = synced;
    return synced;
  }

  Local5EState? getState(String workspaceId) {
    final key = workspaceId.trim();
    if (key.isEmpty) {
      return null;
    }
    return _statesByWorkspace[key];
  }

  void removeWorkspace(String workspaceId) {
    final key = workspaceId.trim();
    if (key.isEmpty) {
      return;
    }
    _statesByWorkspace.remove(key);
  }

  void clearAll() {
    _statesByWorkspace.clear();
  }

  Local5ETransitionDecision applyTutorSignal({
    required String workspaceId,
    required bool nextPhaseReady,
    String? phaseReasoning,
    bool countLearnerTurn = true,
  }) {
    final current = _statesByWorkspace[workspaceId.trim()];
    if (current == null) {
      throw ArgumentError(
        'Workspace state is missing. Call ensureState() first.',
      );
    }
    final phaseBefore = normalizePhase(current.currentPhase);
    final nextPhase = nextPhaseCandidate(phaseBefore);

    var history = List<Local5EPhaseHistoryEntry>.from(current.phaseHistory);
    if (history.isEmpty) {
      history = <Local5EPhaseHistoryEntry>[
        Local5EPhaseHistoryEntry(
          phase: phaseBefore,
          enteredAtIso8601: _nowIso(),
          turnCount: 0,
        ),
      ];
    }
    if (countLearnerTurn) {
      final last = history.last;
      history[history.length - 1] = last.copyWith(
        turnCount: last.turnCount + 1,
      );
    }

    final minTurns = current.phaseMinTurns[phaseBefore] ?? 1;
    final currentTurns = history.last.turnCount;
    final finalPhase = phaseBefore == 'evaluate' || nextPhase == null;
    final effectiveNextReady = finalPhase ? false : nextPhaseReady;

    var phaseAfter = phaseBefore;
    var transitionPending = false;
    var autoAdvanced = false;
    var transitionReason = 'not_ready';

    if (finalPhase) {
      transitionReason = 'final_phase_no_advance';
    } else if (!effectiveNextReady) {
      transitionReason = (phaseReasoning ?? '').trim().isEmpty
          ? 'tutor_not_ready'
          : phaseReasoning!.trim();
    } else if (currentTurns < minTurns) {
      transitionPending = true;
      transitionReason = 'min_turns_not_reached($currentTurns/$minTurns)';
    } else {
      autoAdvanced = true;
      phaseAfter = nextPhase;
      transitionReason = (phaseReasoning ?? '').trim().isEmpty
          ? 'auto_advance_ready'
          : phaseReasoning!.trim();

      final now = _nowIso();
      history[history.length - 1] = history.last.copyWith(exitedAtIso8601: now);
      history.add(
        Local5EPhaseHistoryEntry(
          phase: phaseAfter,
          enteredAtIso8601: now,
          exitedAtIso8601: null,
          turnCount: 0,
        ),
      );
    }

    final visited = List<String>.from(current.visitedPhases);
    if (!visited.contains(phaseAfter)) {
      visited.add(phaseAfter);
    }

    final nextState = current.copyWith(
      currentPhase: phaseAfter,
      phaseTransitionPending: transitionPending,
      posttestEligible: current.posttestEligible || phaseAfter == 'evaluate',
      visitedPhases: visited,
      phaseHistory: history,
    );
    _statesByWorkspace[current.workspaceId] = nextState;

    return Local5ETransitionDecision(
      phaseBefore: phaseBefore,
      phaseAfter: phaseAfter,
      nextPhaseReady: effectiveNextReady,
      phaseTransitionPending: transitionPending,
      autoAdvanced: autoAdvanced,
      transitionReason: transitionReason,
      state: nextState,
    );
  }

  Local5EState _syncPhaseFromBackend(
    Local5EState current, {
    required String backendPhase,
    required bool backendPending,
    required bool backendPosttestEligible,
  }) {
    if (backendPhase == current.currentPhase &&
        backendPending == current.phaseTransitionPending &&
        backendPosttestEligible == current.posttestEligible) {
      return current;
    }

    var history = List<Local5EPhaseHistoryEntry>.from(current.phaseHistory);
    if (history.isEmpty) {
      history = <Local5EPhaseHistoryEntry>[
        Local5EPhaseHistoryEntry(
          phase: backendPhase,
          enteredAtIso8601: _nowIso(),
          turnCount: 0,
        ),
      ];
    } else if (history.last.phase != backendPhase) {
      final now = _nowIso();
      history[history.length - 1] = history.last.copyWith(exitedAtIso8601: now);
      history.add(
        Local5EPhaseHistoryEntry(
          phase: backendPhase,
          enteredAtIso8601: now,
          exitedAtIso8601: null,
          turnCount: 0,
        ),
      );
    } else {
      history[history.length - 1] = history.last.copyWith(clearExitedAt: true);
    }

    final visited = List<String>.from(current.visitedPhases);
    if (!visited.contains(backendPhase)) {
      visited.add(backendPhase);
    }

    return current.copyWith(
      currentPhase: backendPhase,
      phaseTransitionPending: backendPending,
      posttestEligible: backendPosttestEligible || backendPhase == 'evaluate',
      visitedPhases: visited,
      phaseHistory: history,
    );
  }

  static String normalizePhase(String phase) {
    final normalized = phase.trim().toLowerCase();
    if (phaseSequence.contains(normalized)) {
      return normalized;
    }
    return 'engage';
  }

  static String? nextPhaseCandidate(String phase) {
    final normalized = normalizePhase(phase);
    final index = phaseSequence.indexOf(normalized);
    if (index < 0 || index >= phaseSequence.length - 1) {
      return null;
    }
    return phaseSequence[index + 1];
  }

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();
}
