import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ExerciseMediaView extends StatelessWidget {
  const ExerciseMediaView({
    super.key,
    required this.mediaUrl,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.compact = false,
    this.backgroundColor,
    this.iconColor,
  });

  final String mediaUrl;
  final double width;
  final double height;
  final double borderRadius;
  final bool compact;
  final Color? backgroundColor;
  final Color? iconColor;

  bool get _isVideo {
    final lower = mediaUrl.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv');
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.blueGrey.shade50;
    final fg = iconColor ?? Colors.blueGrey.shade700;

    if (mediaUrl.trim().isEmpty) {
      return _placeholder(bg, fg, Icons.fitness_center);
    }

    if (_isVideo) {
      if (compact) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            width: width,
            height: height,
            color: bg,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.video_library_outlined, color: fg, size: 28),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return _VideoPreview(
        mediaUrl: mediaUrl,
        width: width,
        height: height,
        borderRadius: borderRadius,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          mediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _placeholder(bg, fg, Icons.broken_image_outlined),
        ),
      ),
    );
  }

  Widget _placeholder(Color bg, Color fg, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: bg,
        alignment: Alignment.center,
        child: Icon(icon, color: fg, size: compact ? 28 : 56),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({
    required this.mediaUrl,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final String mediaUrl;
  final double width;
  final double height;
  final double borderRadius;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));
    _initializeFuture = _controller!.initialize();
    _controller!.setLooping(true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: FutureBuilder<void>(
          future: _initializeFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_controller == null || !_controller!.value.isInitialized) {
              return const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white),
              );
            }

            return Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _togglePlayback,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.38),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _controller!.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
