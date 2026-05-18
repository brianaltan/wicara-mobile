import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../pretest/data/pretest_session_store.dart';
import '../data/litert_gemma_runtime.dart';
import '../domain/edge_ai_runtime.dart';

enum _ReadinessAction { cancel, openSettings }

class EdgeAiReadinessGuard extends StatefulWidget {
  const EdgeAiReadinessGuard({
    required this.child,
    this.runtime = defaultEdgeAiRuntime,
    super.key,
  });

  final Widget child;
  final EdgeAiRuntime runtime;

  static Future<bool> ensureReady(
    BuildContext context, {
    EdgeAiRuntime runtime = defaultEdgeAiRuntime,
  }) async {
    if (await _isRuntimeReady(runtime) || await _tryAutoInitialize(runtime)) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }
    final action = await showDialog<_ReadinessAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Model lokal belum siap'),
          content: const Text(
            'Model AI lokal belum siap. Install & initialize dulu sebelum mulai pretest.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_ReadinessAction.cancel);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_ReadinessAction.openSettings);
              },
              child: const Text('Buka Pengaturan Edge AI'),
            ),
          ],
        );
      },
    );
    if (action != _ReadinessAction.openSettings) {
      return false;
    }
    if (!context.mounted) {
      return false;
    }
    await Navigator.of(context).pushNamed(AppRoutes.edgeAiSettings);
    if (!context.mounted) {
      return false;
    }
    if (await _isRuntimeReady(runtime)) {
      return true;
    }
    return _tryAutoInitialize(runtime);
  }

  static Future<bool> _isRuntimeReady(EdgeAiRuntime runtime) async {
    try {
      final status = await runtime.getStatus();
      return status.isReady;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _tryAutoInitialize(EdgeAiRuntime runtime) async {
    try {
      final status = await runtime.getStatus();
      if (!status.available) {
        return false;
      }
      if (status.isReady) {
        return true;
      }
      final modelPath = status.modelPath ?? status.defaultModelPath;
      final hasModel =
          status.defaultModelExists ||
          (modelPath != null && modelPath.trim().isNotEmpty);
      if (!hasModel) {
        return false;
      }
      final initialized = await runtime
          .initialize(modelPath: modelPath)
          .timeout(const Duration(seconds: 45));
      return initialized.isReady;
    } catch (_) {
      return false;
    }
  }

  @override
  State<EdgeAiReadinessGuard> createState() => _EdgeAiReadinessGuardState();
}

class _EdgeAiReadinessGuardState extends State<EdgeAiReadinessGuard> {
  bool _isChecking = true;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runCheck();
    });
  }

  Future<void> _runCheck() async {
    if (!mounted) {
      return;
    }
    final targetConceptCode = (pretestSessionStore.targetConceptCode ?? '')
        .trim();
    if (targetConceptCode.isEmpty) {
      _redirectToLearningGoal(
        'Pilih node target dulu di Learning Goal sebelum mulai pretest.',
      );
      return;
    }
    final ready = await EdgeAiReadinessGuard.ensureReady(
      context,
      runtime: widget.runtime,
    );
    if (!mounted) {
      return;
    }
    if (ready) {
      setState(() {
        _isReady = true;
        _isChecking = false;
      });
      return;
    }

    _redirectToLearningGoal(
      'Model lokal belum siap. Selesaikan install/initialize dulu lalu mulai pretest lagi.',
    );
  }

  void _redirectToLearningGoal(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.learningGoal, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return widget.child;
    }
    if (!_isChecking) {
      return const SizedBox.shrink();
    }
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text(
                  'Memeriksa kesiapan model AI lokal...',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
