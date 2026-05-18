import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/wicara_colors.dart';
import '../data/litert_gemma_runtime.dart';
import '../domain/edge_ai_models.dart';
import '../domain/edge_ai_runtime.dart';

class EdgeRuntimeStatusPanel extends StatefulWidget {
  const EdgeRuntimeStatusPanel({
    this.runtime = defaultEdgeAiRuntime,
    this.testPrompt = _defaultTestPrompt,
    this.initialModelUrl = _defaultModelUrl,
    this.initiallyExpanded = false,
    super.key,
  });

  static const _defaultModelUrl = String.fromEnvironment(
    'WICARA_EDGE_MODEL_URL',
    defaultValue:
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
  );

  static const _defaultTestPrompt =
      'Jawab dalam Bahasa Indonesia. Jelaskan konsep turunan sebagai laju perubahan dalam 2 kalimat, lalu berikan 1 pertanyaan cek pemahaman.';

  final EdgeAiRuntime runtime;
  final String testPrompt;
  final String initialModelUrl;
  final bool initiallyExpanded;

  @override
  State<EdgeRuntimeStatusPanel> createState() => _EdgeRuntimeStatusPanelState();
}

class _EdgeRuntimeStatusPanelState extends State<EdgeRuntimeStatusPanel> {
  late final TextEditingController _modelUrlController;
  late final ScrollController _expandedScrollController;
  Timer? _installProgressPoller;
  bool _installPollInFlight = false;

  EdgeRuntimeStatus? _status;
  String? _lastOutput;
  String? _errorText;
  String? _installSummary;
  bool _expanded = false;
  bool _isLoading = true;
  bool _isInstalling = false;
  bool _isInitializing = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _modelUrlController = TextEditingController(text: widget.initialModelUrl);
    _expandedScrollController = ScrollController();
    _expanded = widget.initiallyExpanded;
    _refreshStatus();
  }

  @override
  void dispose() {
    _installProgressPoller?.cancel();
    _modelUrlController.dispose();
    _expandedScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }
    try {
      final status = await widget.runtime.getStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        if (showLoading) {
          _isLoading = false;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (showLoading) {
          _isLoading = false;
        }
        _errorText = 'Failed to read edge runtime status: $error';
      });
    }
  }

  void _startInstallProgressPolling() {
    _installProgressPoller?.cancel();
    _installProgressPoller = Timer.periodic(const Duration(milliseconds: 700), (
      _,
    ) async {
      if (_installPollInFlight || !mounted) {
        return;
      }
      _installPollInFlight = true;
      try {
        await _refreshStatus(showLoading: false);
      } finally {
        _installPollInFlight = false;
      }
    });
  }

  void _stopInstallProgressPolling() {
    _installProgressPoller?.cancel();
    _installProgressPoller = null;
    _installPollInFlight = false;
  }

  Future<void> _installModel({bool overwrite = false}) async {
    final url = _modelUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _errorText = 'Isi URL model terlebih dahulu.';
      });
      return;
    }

    setState(() {
      _isInstalling = true;
      _errorText = null;
      _installSummary = null;
    });
    _startInstallProgressPolling();
    try {
      final installed = await widget.runtime.installModel(
        url: url,
        overwrite: overwrite,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isInstalling = false;
        _installSummary = installed.skipped && !overwrite
            ? 'Model sudah ada di device (${installed.modelPath}).'
            : overwrite
            ? 'Model di-reinstall (${_formatBytes(installed.bytesDownloaded)} dalam ${installed.downloadMs ?? 0} ms).'
            : 'Model terpasang (${_formatBytes(installed.bytesDownloaded)} dalam ${installed.downloadMs ?? 0} ms).';
      });
      _stopInstallProgressPolling();
      await _refreshStatus(showLoading: false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInstalling = false;
        _errorText = 'Install model gagal: $error';
      });
      _stopInstallProgressPolling();
      await _refreshStatus(showLoading: false);
    }
  }

  Future<void> _initialize() async {
    setState(() {
      _isInitializing = true;
      _errorText = null;
    });
    try {
      final status = await widget.runtime.initialize();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _errorText = _friendlyInitializeError(error.toString());
      });
    }
  }

  String _friendlyInitializeError(String raw) {
    if (raw.contains('INITIALIZE_FAILED')) {
      return 'Initialize gagal. Biasanya karena file model korup/tidak cocok dengan runtime di device ini. Coba "Reinstall model" lalu initialize ulang.';
    }
    return 'Initialize failed: $raw';
  }

  Future<void> _runTestPrompt() async {
    setState(() {
      _isGenerating = true;
      _errorText = null;
      _lastOutput = null;
    });

    try {
      final request = EdgeGenerationRequest(
        requestId: 'litert_test_${DateTime.now().millisecondsSinceEpoch}',
        prompt: widget.testPrompt,
        temperature: 0.3,
        maxTokens: 180,
      );
      final result = await widget.runtime.generate(request);
      if (!mounted) {
        return;
      }
      setState(() {
        _isGenerating = false;
        _lastOutput =
            '${result.text}\n\n(totalMs=${result.metrics.totalMs}, execution=${result.executionLocation}, fallback=${result.fallbackUsed})';
      });
      await _refreshStatus();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isGenerating = false;
        _errorText = 'Local generation failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final statusLabel = _isLoading
        ? 'checking'
        : status == null
        ? 'unknown'
        : status.isReady
        ? 'ready'
        : status.available
        ? 'available_not_loaded'
        : 'unavailable';

    final badgeColor = switch (statusLabel) {
      'ready' => WicaraColors.accentMint,
      'available_not_loaded' => const Color(0xFFF4A44E),
      'unavailable' => WicaraColors.accentCoral,
      _ => WicaraColors.secondary,
    };
    final download = status?.download ?? const EdgeModelDownloadStatus();
    final showProgress = _isInstalling || download.inProgress;
    final progressValue = download.progressValue;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: WicaraColors.line, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.memory_rounded,
                    size: 18,
                    color: WicaraColors.primaryDeep,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edge AI (LiteRT-LM)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: WicaraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: WicaraColors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: Scrollbar(
                controller: _expandedScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _expandedScrollController,
                  padding: const EdgeInsets.only(right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (status != null)
                        Text(
                          'runtime=${status.runtime}  backend=${status.backend}  execution=${status.executionLocation}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: WicaraColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      if (status != null)
                        Text(
                          'model=${status.modelPath ?? status.defaultModelPath ?? '-'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: WicaraColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      if (status != null &&
                          status.raw['modelFileBytes'] is int) ...[
                        Text(
                          'model_size=${_formatBytes(status.raw['modelFileBytes'] as int)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: WicaraColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextField(
                        controller: _modelUrlController,
                        minLines: 1,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Model URL (.litertlm)',
                          hintText: 'https://...',
                          filled: true,
                          fillColor: WicaraColors.fieldFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: WicaraColors.line,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: WicaraColors.line,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: WicaraColors.secondary,
                            ),
                          ),
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: WicaraColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _isInstalling
                                ? null
                                : () => _installModel(overwrite: false),
                            child: Text(
                              _isInstalling ? 'Installing...' : 'Install model',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _isInstalling
                                ? null
                                : () => _installModel(overwrite: true),
                            child: const Text('Reinstall model'),
                          ),
                          OutlinedButton(
                            onPressed: _isLoading ? null : _refreshStatus,
                            child: const Text('Refresh'),
                          ),
                          FilledButton(
                            onPressed: _isInitializing ? null : _initialize,
                            child: Text(
                              _isInitializing
                                  ? 'Initializing...'
                                  : 'Initialize',
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: _isGenerating ? null : _runTestPrompt,
                            child: Text(
                              _isGenerating ? 'Running...' : 'Run test prompt',
                            ),
                          ),
                        ],
                      ),
                      if (showProgress) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: WicaraColors.fieldFill,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: WicaraColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Download model: ${download.status}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: WicaraColors.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: progressValue),
                              const SizedBox(height: 8),
                              Text(
                                download.hasKnownTotal
                                    ? '${_formatBytes(download.receivedBytes)} / ${_formatBytes(download.totalBytes ?? 0)}${progressValue == null ? '' : ' (${(progressValue * 100).toStringAsFixed(1)}%)'}'
                                    : '${_formatBytes(download.receivedBytes)} downloaded',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: WicaraColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_installSummary != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _installSummary!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: WicaraColors.secondaryDeep,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      if (_errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorText!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: WicaraColors.accentCoral,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      if (_lastOutput != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: WicaraColors.fieldFill,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: WicaraColors.line),
                          ),
                          child: Text(
                            _lastOutput!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: WicaraColors.text,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }
}
