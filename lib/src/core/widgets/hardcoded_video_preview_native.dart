import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class HardcodedVideoPreview extends StatelessWidget {
  const HardcodedVideoPreview({
    required this.videoUrl,
    required this.title,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    super.key,
  });

  final String videoUrl;
  final String title;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111722),
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  _HardcodedVideoNativePage(videoUrl: videoUrl, title: title),
            ),
          );
        },
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2D7BD9).withValues(alpha: 0.28),
                      const Color(0xFF111722),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 58,
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Tap to open',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HardcodedVideoNativePage extends StatefulWidget {
  const _HardcodedVideoNativePage({
    required this.videoUrl,
    required this.title,
  });

  final String videoUrl;
  final String title;

  @override
  State<_HardcodedVideoNativePage> createState() =>
      _HardcodedVideoNativePageState();
}

class _HardcodedVideoNativePageState extends State<_HardcodedVideoNativePage> {
  late final VideoPlayerController _controller;
  final TransformationController _zoomController = TransformationController();
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _lockLandscape();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(true);
    _initializeController();
  }

  Future<void> _lockLandscape() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _restoreOrientation() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  Future<void> _initializeController() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _hasError = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _controller.dispose();
    _restoreOrientation();
    super.dispose();
  }

  void _togglePlayback() {
    if (!_isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  void _resetZoom() {
    _zoomController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildBody()),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            if (_isInitialized)
              Positioned(
                top: 12,
                right: 12,
                child: FilledButton.tonalIcon(
                  onPressed: _resetZoom,
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
                  label: const Text('Reset zoom'),
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white70,
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                'Video gagal dimuat. Coba ulang.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = null;
                  });
                  _initializeController();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: InteractiveViewer(
              transformationController: _zoomController,
              minScale: 1,
              maxScale: 4,
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
          if (!_controller.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 76,
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final durationMs = value.duration.inMilliseconds;
                final positionMs = value.position.inMilliseconds.clamp(
                  0,
                  durationMs <= 0 ? 1 : durationMs,
                );
                final sliderValue = durationMs <= 0
                    ? 0.0
                    : positionMs.toDouble();
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _togglePlayback,
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  trackHeight: 3,
                                ),
                                child: Slider(
                                  min: 0,
                                  max: durationMs <= 0
                                      ? 1
                                      : durationMs.toDouble(),
                                  value: sliderValue,
                                  onChanged: durationMs <= 0
                                      ? null
                                      : (next) {
                                          _controller.seekTo(
                                            Duration(
                                              milliseconds: next.round(),
                                            ),
                                          );
                                        },
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(value.position),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _formatDuration(value.duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
