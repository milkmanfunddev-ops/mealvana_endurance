import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';

/// Full-screen video player using chewie + video_player
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.title,
    required this.videoUrl,
    this.contentId,
  });

  final String title;
  final String videoUrl;

  /// Education content id, used to attribute `education_video_completed`.
  /// Nullable because not every construction site has one to give.
  final String? contentId;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;

  /// Resolved once in [initState]: `ref` is not safe to touch from [dispose],
  /// which is where the watch-completion event fires.
  AnalyticsTracker? _analytics;

  /// Furthest point reached, not the position at dispose. Scrubbing backwards
  /// before closing would otherwise report a lower `percent_watched` than the
  /// user actually watched.
  Duration _maxPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    try {
      _analytics = ref.read(appExternalDepsProvider).analytics;
    } catch (_) {}
    _initializePlayer();
  }

  void _onPlaybackTick() {
    final value = _videoController?.value;
    if (value == null || !value.isInitialized) return;
    if (value.position > _maxPosition) {
      _maxPosition = value.position;
    }
  }

  void _trackWatchCompleted() {
    final duration = _videoController?.value.duration;
    if (_analytics == null || duration == null || duration.inMilliseconds <= 0) {
      return;
    }

    // Only the education surface emits a matching `education_video_opened`
    // (keyed on the same contentId). Other surfaces — e.g. the activity-detail
    // transparency video — build this screen without a contentId, and firing
    // here would put a completion with `video_id: null` and no opener on the
    // board. Stay silent for them rather than pollute the funnel.
    final videoId = widget.contentId;
    if (videoId == null || videoId.isEmpty) return;

    final percent =
        (_maxPosition.inMilliseconds / duration.inMilliseconds * 100).clamp(
          0.0,
          100.0,
        );

    try {
      _analytics!.track(
        'education_video_completed',
        properties: {
          'video_id': videoId,
          'title': widget.title,
          'percent_watched': percent.round(),
          'watched_sec': _maxPosition.inSeconds,
          'duration_sec': duration.inSeconds,
        },
      );
    } catch (_) {}
  }

  Future<void> _initializePlayer() async {
    // Dispose prior controllers so retry does not leak native player resources.
    _chewieController?.dispose();
    await _videoController?.dispose();
    _chewieController = null;
    _videoController = null;

    final videoUrl = widget.videoUrl.trim();
    if (videoUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _videoController = controller;

    try {
      await controller.initialize();
      controller.addListener(_onPlaybackTick);
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        // Respect source video orientation (portrait or landscape).
        aspectRatio: controller.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.orange,
          handleColor: AppColors.orange,
          bufferedColor: AppColors.orange.withValues(alpha: 0.3),
          backgroundColor: Colors.white24,
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    // Must run before the controllers are torn down — it reads position and
    // duration off `_videoController.value`.
    _trackWatchCompleted();
    _videoController?.removeListener(_onPlaybackTick);
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: const CustomAppBarBackButton(
          key: ValueKey('lesson.back_button'),
          iconColor: Colors.white,
          backgroundColor: Color(0x33000000),
        ),
        title: Text(
          key: const ValueKey('lesson.title'),
          widget.title,
          style: AppTextStyles.h5.copyWith(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _hasError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Failed to load video',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  KylePrimaryButton(
                    text: 'Retry',
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                      });
                      _initializePlayer();
                    },
                  ),
                ],
              )
            : _chewieController != null
            ? Chewie(
                key: const ValueKey('lesson.video_player'),
                controller: _chewieController!,
              )
            : const CircularProgressIndicator(color: AppColors.orange),
      ),
    );
  }
}
