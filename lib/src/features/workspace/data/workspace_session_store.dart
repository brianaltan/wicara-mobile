import 'package:shared_preferences/shared_preferences.dart';

class WorkspaceSessionStore {
  static const _trackIdKey = 'workspace.track_id';
  static const _moduleIdKey = 'workspace.module_id';
  static const _workspaceIdKey = 'workspace.workspace_id';

  String? trackId;
  String? moduleId;
  String? workspaceId;

  Future<void> read() async {
    final preferences = await SharedPreferences.getInstance();
    trackId = preferences.getString(_trackIdKey)?.trim();
    moduleId = preferences.getString(_moduleIdKey)?.trim();
    workspaceId = preferences.getString(_workspaceIdKey)?.trim();
  }

  Future<void> save({
    required String trackId,
    required String moduleId,
    required String workspaceId,
  }) async {
    this.trackId = trackId;
    this.moduleId = moduleId;
    this.workspaceId = workspaceId;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_trackIdKey, trackId);
    await preferences.setString(_moduleIdKey, moduleId);
    await preferences.setString(_workspaceIdKey, workspaceId);
  }
}

final workspaceSessionStore = WorkspaceSessionStore();
