import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WorkspaceSessionHistory {
  const WorkspaceSessionHistory({
    required this.activeWorkspaceId,
    required this.workspaceIds,
  });

  final String? activeWorkspaceId;
  final List<String> workspaceIds;
}

class WorkspaceSessionStore {
  static const _legacyTrackIdKey = 'workspace.track_id';
  static const _legacyModuleIdKey = 'workspace.module_id';
  static const _legacyWorkspaceIdKey = 'workspace.workspace_id';
  static const _legacySessionsMapKey = 'workspace.sessions_map';
  static const _sessionsStateKey = 'workspace.sessions_state_v2';

  final Map<String, _SessionHistoryState> _sessions = {};

  Future<void> read() async {
    final preferences = await SharedPreferences.getInstance();

    final legacyTrack = preferences.getString(_legacyTrackIdKey)?.trim();
    final legacyModule = preferences.getString(_legacyModuleIdKey)?.trim();
    final legacyWorkspace =
        preferences.getString(_legacyWorkspaceIdKey)?.trim();
    if (legacyTrack != null &&
        legacyTrack.isNotEmpty &&
        legacyModule != null &&
        legacyModule.isNotEmpty &&
        legacyWorkspace != null &&
        legacyWorkspace.isNotEmpty) {
      final key = _key(legacyTrack, legacyModule);
      _sessions[key] = _SessionHistoryState.fromWorkspaceId(legacyWorkspace);
      await preferences.remove(_legacyTrackIdKey);
      await preferences.remove(_legacyModuleIdKey);
      await preferences.remove(_legacyWorkspaceIdKey);
    }

    final legacyMapRaw = preferences.getString(_legacySessionsMapKey);
    if (legacyMapRaw != null && legacyMapRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(legacyMapRaw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final workspaceId = (entry.value ?? '').toString().trim();
          if (workspaceId.isEmpty) {
            continue;
          }
          _sessions.putIfAbsent(
            entry.key,
            () => _SessionHistoryState.fromWorkspaceId(workspaceId),
          );
        }
      } catch (_) {
        // Ignore invalid legacy data.
      }
      await preferences.remove(_legacySessionsMapKey);
    }

    final raw = preferences.getString(_sessionsStateKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            _sessions[entry.key] = _SessionHistoryState.fromJson(
              entry.value as Map<String, dynamic>,
            );
          }
        }
      } catch (_) {
        // Ignore corrupt payload and continue with migrated in-memory state.
      }
    }

    await _persist();
  }

  String? workspaceIdFor({
    required String trackId,
    required String moduleId,
  }) {
    final id = _sessions[_key(trackId, moduleId)]?.activeWorkspaceId;
    return (id == null || id.isEmpty) ? null : id;
  }

  WorkspaceSessionHistory sessionHistoryFor({
    required String trackId,
    required String moduleId,
  }) {
    final state = _sessions[_key(trackId, moduleId)];
    return WorkspaceSessionHistory(
      activeWorkspaceId: state?.activeWorkspaceId,
      workspaceIds: List.unmodifiable(state?.workspaceIds ?? const <String>[]),
    );
  }

  Future<void> saveAndSetActive({
    required String trackId,
    required String moduleId,
    required String workspaceId,
  }) async {
    final k = _key(trackId, moduleId);
    final state = _sessions[k] ?? _SessionHistoryState.empty();
    _sessions[k] = state.withActiveWorkspace(workspaceId);
    await _persist();
  }

  Future<void> setActiveWorkspaceId({
    required String trackId,
    required String moduleId,
    required String workspaceId,
  }) async {
    final k = _key(trackId, moduleId);
    final current = _sessions[k] ?? _SessionHistoryState.empty();
    _sessions[k] = current.withActiveWorkspace(workspaceId);
    await _persist();
  }

  Future<void> clearSession({
    required String trackId,
    required String moduleId,
  }) async {
    _sessions.remove(_key(trackId, moduleId));
    await _persist();
  }

  Future<void> clearAll() async {
    _sessions.clear();
    await _persist();
  }

  static String _key(String trackId, String moduleId) =>
      '${trackId}__$moduleId';

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    final payload = _sessions.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await preferences.setString(_sessionsStateKey, jsonEncode(payload));
  }
}

final workspaceSessionStore = WorkspaceSessionStore();

class _SessionHistoryState {
  const _SessionHistoryState({
    required this.activeWorkspaceId,
    required this.workspaceIds,
  });

  factory _SessionHistoryState.empty() {
    return const _SessionHistoryState(activeWorkspaceId: null, workspaceIds: []);
  }

  factory _SessionHistoryState.fromWorkspaceId(String workspaceId) {
    return _SessionHistoryState(
      activeWorkspaceId: workspaceId,
      workspaceIds: [workspaceId],
    );
  }

  factory _SessionHistoryState.fromJson(Map<String, dynamic> json) {
    final active = (json['active_workspace_id'] ?? '').toString().trim();
    final rawList = json['workspace_ids'];
    final ids = <String>[];
    if (rawList is List) {
      for (final value in rawList) {
        final id = (value ?? '').toString().trim();
        if (id.isNotEmpty && !ids.contains(id)) {
          ids.add(id);
        }
      }
    }
    if (active.isNotEmpty && !ids.contains(active)) {
      ids.insert(0, active);
    }
    return _SessionHistoryState(
      activeWorkspaceId: active.isEmpty ? null : active,
      workspaceIds: ids,
    );
  }

  final String? activeWorkspaceId;
  final List<String> workspaceIds;

  _SessionHistoryState withActiveWorkspace(String workspaceId) {
    final normalized = workspaceId.trim();
    if (normalized.isEmpty) {
      return this;
    }
    final nextIds = <String>[normalized];
    for (final id in workspaceIds) {
      if (id != normalized) {
        nextIds.add(id);
      }
    }
    return _SessionHistoryState(
      activeWorkspaceId: normalized,
      workspaceIds: nextIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active_workspace_id': activeWorkspaceId ?? '',
      'workspace_ids': workspaceIds,
    };
  }
}
