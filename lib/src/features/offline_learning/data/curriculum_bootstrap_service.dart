import 'dart:convert';

import 'package:flutter/services.dart';

import 'local_curriculum_repository.dart';

class CurriculumBootstrapService {
  CurriculumBootstrapService({
    required LocalCurriculumRepository repository,
    Future<String> Function(String path)? assetLoader,
  }) : _repository = repository,
       _assetLoader = assetLoader ?? rootBundle.loadString;

  final LocalCurriculumRepository _repository;
  final Future<String> Function(String path) _assetLoader;

  Future<LocalCurriculumSeedResult> ensureBootstrapped({
    String assetPath = LocalCurriculumRepository.defaultFullCurriculumAssetPath,
    bool forceReload = false,
  }) async {
    String targetVersion = 'v0';
    try {
      final raw = await _assetLoader(assetPath);
      final payload = jsonDecode(raw);
      if (payload is Map<String, dynamic>) {
        final metadata = payload['metadata'];
        if (metadata is Map<String, dynamic>) {
          targetVersion =
              (metadata['curriculum_version'] ?? metadata['version'] ?? '')
                  .toString()
                  .trim();
        }
      }
    } catch (_) {
      // If asset read fails here, load call below will surface the actual error.
    }

    final storedVersion = await _repository.readCurriculumVersion();
    final hasCurriculum = await _repository.hasLocalCurriculum();
    if (!forceReload &&
        hasCurriculum &&
        storedVersion != null &&
        storedVersion.isNotEmpty &&
        storedVersion == targetVersion) {
      final concepts = await _repository.listConcepts();
      final edges = await _repository.listEdges();
      return LocalCurriculumSeedResult(
        seeded: false,
        assetPath: assetPath,
        conceptsCount: concepts.length,
        edgesCount: edges.length,
        curriculumVersion: storedVersion,
      );
    }

    return _repository.loadCurriculumFromAsset(
      assetPath: assetPath,
      clearExisting: true,
    );
  }
}
