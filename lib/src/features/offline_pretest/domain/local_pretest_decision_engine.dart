import 'dart:collection';

class LocalPretestDecisionEngine {
  Map<String, dynamic> recordAttempt(
    Map<String, dynamic> state, {
    required String attemptId,
    required String conceptCode,
    required String difficulty,
    required bool isCorrect,
    required String questionStem,
    required String correctOptionText,
    required String selectedOptionText,
    required String typedReasoning,
    required String expectedReasoning,
    required double evidenceScore,
    required double confidence,
    double? answerScore,
    double? reasoningScore,
    double? canvasScore,
    bool canvasUsed = false,
    int? canvasStrokeCount,
    String? canvasSnapshotPath,
    String diagnosticSignal = '',
    String reasoningSignal = '',
    String reasoningSource = '',
  }) {
    final nextState = Map<String, dynamic>.from(state);
    final nodeResults =
        (nextState['node_results'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final nodeState =
        (nodeResults[conceptCode] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{
          'status': 'not_asked',
          'attempts': <Map<String, dynamic>>[],
        };

    final attempts =
        (nodeState['attempts'] as List?)
            ?.whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList(growable: true) ??
        <Map<String, dynamic>>[];

    nodeState[difficulty] = isCorrect ? 'correct' : 'wrong';
    attempts.add(<String, dynamic>{
      'attempt_id': attemptId,
      'difficulty': difficulty,
      'is_correct': isCorrect,
      'question_stem': questionStem,
      'correct_option_text': correctOptionText,
      'selected_option_text': selectedOptionText,
      'typed_reasoning': typedReasoning,
      'expected_reasoning': expectedReasoning,
      'answer_score': _round4(answerScore ?? (isCorrect ? 1.0 : 0.0)),
      'reasoning_score': reasoningScore == null
          ? null
          : _round4(reasoningScore),
      'canvas_score': canvasScore == null ? null : _round4(canvasScore),
      'canvas_used': canvasUsed,
      'canvas_stroke_count': canvasStrokeCount,
      'canvas_snapshot_path': canvasSnapshotPath,
      'evidence_score': _round4(evidenceScore),
      'confidence': _round4(confidence),
      'diagnostic_signal': diagnosticSignal,
      'reasoning_signal': reasoningSignal,
      'reasoning_source': reasoningSource,
    });
    nodeState['attempts'] = attempts;
    nodeState['status'] = _nodeStatus(nodeState);

    nodeResults[conceptCode] = nodeState;
    nextState['node_results'] = nodeResults;
    nextState['confidence'] = [
      _double(nextState['confidence']),
      confidence,
    ].reduce((left, right) => left > right ? left : right);
    return nextState;
  }

  ({Map<String, dynamic> state, Map<String, dynamic> action}) decide(
    Map<String, dynamic> state, {
    required String lastConceptCode,
    required String lastDifficulty,
    required bool lastIsCorrect,
    required Map<String, dynamic> graphScope,
  }) {
    final nextState = Map<String, dynamic>.from(state);
    final limitAction = _limitAction(nextState);
    if (limitAction != null) {
      nextState['stop_reason'] = limitAction['reason'];
      return (state: nextState, action: limitAction);
    }

    final targetCode = _string(nextState['target_concept_code']);
    if (lastConceptCode == targetCode) {
      return _decideTarget(
        nextState,
        lastDifficulty: lastDifficulty,
        lastIsCorrect: lastIsCorrect,
        graphScope: graphScope,
      );
    }
    return _decidePrerequisite(
      nextState,
      lastConceptCode: lastConceptCode,
      lastDifficulty: lastDifficulty,
      lastIsCorrect: lastIsCorrect,
      graphScope: graphScope,
    );
  }

  ({Map<String, dynamic> state, Map<String, dynamic> action}) _decideTarget(
    Map<String, dynamic> state, {
    required String lastDifficulty,
    required bool lastIsCorrect,
    required Map<String, dynamic> graphScope,
  }) {
    final target = _string(state['target_concept_code']);
    if (lastDifficulty == 'medium') {
      return (
        state: state,
        action: _ask(
          target,
          lastIsCorrect ? 'hard' : 'easy',
          lastIsCorrect ? 'target_medium_correct' : 'target_medium_wrong',
        ),
      );
    }
    if (lastDifficulty == 'hard') {
      final reason = lastIsCorrect ? 'target_ready' : 'target_reinforcement';
      state['stop_reason'] = reason;
      return (state: state, action: {'type': 'finalize', 'reason': reason});
    }
    if (lastDifficulty == 'easy') {
      return _askNextPrerequisite(
        state,
        graphScope: graphScope,
        fallbackReason: 'target_basic_checked',
      );
    }
    state['stop_reason'] = 'unsupported_target_difficulty';
    return (
      state: state,
      action: {'type': 'finalize', 'reason': 'unsupported_target_difficulty'},
    );
  }

  ({Map<String, dynamic> state, Map<String, dynamic> action})
  _decidePrerequisite(
    Map<String, dynamic> state, {
    required String lastConceptCode,
    required String lastDifficulty,
    required bool lastIsCorrect,
    required Map<String, dynamic> graphScope,
  }) {
    if (lastDifficulty == 'medium') {
      return (
        state: state,
        action: _ask(
          lastConceptCode,
          lastIsCorrect ? 'hard' : 'easy',
          lastIsCorrect
              ? 'prerequisite_medium_correct'
              : 'prerequisite_medium_wrong',
        ),
      );
    }
    if (lastDifficulty == 'hard') {
      return _askNextPrerequisite(
        state,
        graphScope: graphScope,
        fallbackReason: 'prerequisite_strength_checked',
      );
    }
    if (lastDifficulty == 'easy') {
      if (!lastIsCorrect) {
        _boostDirectPrerequisites(
          state,
          graphScope: graphScope,
          conceptCode: lastConceptCode,
        );
      }
      return _askNextPrerequisite(
        state,
        graphScope: graphScope,
        fallbackReason: lastIsCorrect
            ? 'root_fragility_found'
            : 'root_gap_found',
      );
    }
    state['stop_reason'] = 'unsupported_prerequisite_difficulty';
    return (
      state: state,
      action: {
        'type': 'finalize',
        'reason': 'unsupported_prerequisite_difficulty',
      },
    );
  }

  ({Map<String, dynamic> state, Map<String, dynamic> action})
  _askNextPrerequisite(
    Map<String, dynamic> state, {
    required Map<String, dynamic> graphScope,
    required String fallbackReason,
  }) {
    final queue =
        (state['probe_queue'] as List?)
            ?.whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
            )
            .toList(growable: true) ??
        <Map<String, dynamic>>[];
    final visited =
        ((state['node_results'] as Map?)?.keys.map(
                  (value) => value.toString(),
                ) ??
                const <String>[])
            .toSet();
    visited.add(_string(state['target_concept_code']));

    while (queue.isNotEmpty) {
      queue.sort((left, right) {
        final byPriority = _double(
          right['priority'],
        ).compareTo(_double(left['priority']));
        if (byPriority != 0) {
          return byPriority;
        }
        final byDepth = _int(left['depth']).compareTo(_int(right['depth']));
        if (byDepth != 0) {
          return byDepth;
        }
        return _string(
          left['concept_code'],
        ).compareTo(_string(right['concept_code']));
      });
      final candidate = queue.removeAt(0);
      final conceptCode = _string(candidate['concept_code']);
      if (visited.contains(conceptCode)) {
        continue;
      }
      if (visited.length >= _int(state['max_nodes_visited'], fallback: 5)) {
        state['probe_queue'] = queue;
        state['stop_reason'] = 'max_nodes_visited';
        return (
          state: state,
          action: {'type': 'finalize', 'reason': 'max_nodes_visited'},
        );
      }
      state['probe_queue'] = queue;
      return (
        state: state,
        action: _ask(conceptCode, 'medium', 'enter_prerequisite_node'),
      );
    }

    state['probe_queue'] = <Map<String, dynamic>>[];
    state['stop_reason'] = (graphScope['nodes'] as List?)?.isNotEmpty == true
        ? fallbackReason
        : 'graph_exhausted';
    return (
      state: state,
      action: {'type': 'finalize', 'reason': _string(state['stop_reason'])},
    );
  }

  void _boostDirectPrerequisites(
    Map<String, dynamic> state, {
    required Map<String, dynamic> graphScope,
    required String conceptCode,
  }) {
    final queue =
        (state['probe_queue'] as List?)
            ?.whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
            )
            .toList(growable: true) ??
        <Map<String, dynamic>>[];
    final queued = HashMap<String, Map<String, dynamic>>.fromEntries(
      queue.map((entry) => MapEntry(_string(entry['concept_code']), entry)),
    );
    final visited =
        ((state['node_results'] as Map?)?.keys.map(
                  (value) => value.toString(),
                ) ??
                const <String>[])
            .toSet();
    for (final prereq in directPrerequisites(
      graphScope,
      conceptCode: conceptCode,
    )) {
      final code = _string(prereq['concept_code']);
      if (visited.contains(code)) {
        continue;
      }
      final existing = queued[code];
      if (existing == null) {
        queue.add(prereq);
      } else {
        existing['priority'] = [
          _double(existing['priority']),
          _double(prereq['priority']),
        ].reduce((left, right) => left > right ? left : right);
      }
    }
    state['probe_queue'] = queue;
  }

  Map<String, dynamic>? _limitAction(Map<String, dynamic> state) {
    if (_int(state['question_count']) >=
        _int(state['max_questions'], fallback: 3)) {
      return {'type': 'finalize', 'reason': 'max_questions_reached'};
    }
    if (_double(state['confidence']) >=
        _double(state['confidence_threshold'], fallback: 0.95)) {
      if (_string(state['current_concept_code']) !=
          _string(state['target_concept_code'])) {
        return {'type': 'finalize', 'reason': 'confidence_threshold_reached'};
      }
    }
    return null;
  }
}

Map<String, dynamic> _ask(
  String conceptCode,
  String difficulty,
  String reason,
) {
  return {
    'type': 'next_question',
    'concept_code': conceptCode,
    'difficulty': difficulty,
    'reason': reason,
  };
}

List<Map<String, dynamic>> directPrerequisites(
  Map<String, dynamic> graphScope, {
  required String conceptCode,
}) {
  final nodeByCode = <String, Map<String, dynamic>>{};
  for (final node in (graphScope['nodes'] as List?) ?? const <dynamic>[]) {
    if (node is! Map) {
      continue;
    }
    final mapped = node.cast<String, dynamic>();
    nodeByCode[_string(mapped['concept_code'])] = mapped;
  }
  final results = <Map<String, dynamic>>[];
  for (final edge in (graphScope['edges'] as List?) ?? const <dynamic>[]) {
    if (edge is! Map) {
      continue;
    }
    final mapped = edge.cast<String, dynamic>();
    if (_string(mapped['from']) != conceptCode) {
      continue;
    }
    final node = nodeByCode[_string(mapped['to'])];
    if (node == null) {
      continue;
    }
    final depth = _int(node['depth'], fallback: 1);
    final weight = _double(mapped['weight'], fallback: 1);
    results.add({
      'concept_code': _string(node['concept_code']),
      'concept_id': _string(node['concept_id']),
      'depth': depth,
      'priority': _round4(weight - (depth * 0.2) + 0.35),
      'parent': conceptCode,
    });
  }
  results.sort((left, right) {
    final byPriority = _double(
      right['priority'],
    ).compareTo(_double(left['priority']));
    if (byPriority != 0) {
      return byPriority;
    }
    final byDepth = _int(left['depth']).compareTo(_int(right['depth']));
    if (byDepth != 0) {
      return byDepth;
    }
    return _string(
      left['concept_code'],
    ).compareTo(_string(right['concept_code']));
  });
  return results;
}

String _nodeStatus(Map<String, dynamic> nodeState) {
  final medium = _string(nodeState['medium']);
  final hard = _string(nodeState['hard']);
  final easy = _string(nodeState['easy']);
  if (medium == 'correct' && hard == 'correct') {
    return 'ready';
  }
  if (medium == 'correct' && hard == 'wrong') {
    return 'partial';
  }
  if (medium == 'wrong' && easy == 'correct') {
    return 'fragile';
  }
  if (medium == 'wrong' && easy == 'wrong') {
    return 'gap';
  }
  if (medium == 'correct') {
    return 'probably_ready';
  }
  if (medium == 'wrong') {
    return 'probably_gap';
  }
  return 'not_asked';
}

double _round4(double value) => (value * 10000).round() / 10000;

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

String _string(Object? value) => (value ?? '').toString().trim();
