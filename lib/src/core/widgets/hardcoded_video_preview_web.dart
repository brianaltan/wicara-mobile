import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
                  _HardcodedVideoWebPage(videoUrl: videoUrl, title: title),
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

class _HardcodedVideoWebPage extends StatefulWidget {
  const _HardcodedVideoWebPage({required this.videoUrl, required this.title});

  final String videoUrl;
  final String title;

  @override
  State<_HardcodedVideoWebPage> createState() => _HardcodedVideoWebPageState();
}

class _HardcodedVideoWebPageState extends State<_HardcodedVideoWebPage> {
  static int _nextId = 0;

  late final String _viewType;
  late final web.HTMLVideoElement _videoElement;

  @override
  void initState() {
    super.initState();
    _viewType = 'hardcoded-video-${_nextId++}';
    _videoElement = web.HTMLVideoElement()
      ..src = widget.videoUrl
      ..controls = true
      ..autoplay = true
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true');

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _videoElement,
    );
  }

  @override
  void dispose() {
    _videoElement.pause();
    _videoElement.src = '';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: HtmlElementView(viewType: _viewType),
                ),
              ),
            ),
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
          ],
        ),
      ),
    );
  }
}
