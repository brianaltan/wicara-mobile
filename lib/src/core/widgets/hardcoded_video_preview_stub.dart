import 'package:flutter/material.dart';

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
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Video preview is available on web demo build.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        },
        child: const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 58,
            ),
          ),
        ),
      ),
    );
  }
}
