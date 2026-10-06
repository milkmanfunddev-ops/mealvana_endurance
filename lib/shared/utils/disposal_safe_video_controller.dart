import 'package:video_player/video_player.dart';

/// A [VideoPlayerController] that ignores value writes once [dispose] has
/// been called.
///
/// `video_player`'s `seekTo` awaits the platform seek and then writes the new
/// position into [value]. When the owner disposes the controller while that
/// seek is in flight, the write lands on a disposed `ChangeNotifier` and
/// throws "A VideoPlayerController was used after being disposed" (Sentry
/// MEALVANA-ENDURANCE-DEV-9R). The seek is not always ours to await: the
/// package itself calls `pause().then(seekTo(duration))` when a clip ends,
/// and chewie seeks when the athlete scrubs or leaves full screen. A screen
/// that pops at that moment cannot see the pending seek, so the guard lives
/// on the controller: after dispose, a late write is dropped.
class DisposalSafeVideoPlayerController extends VideoPlayerController {
  DisposalSafeVideoPlayerController.networkUrl(
    super.url, {
    super.formatHint,
    super.closedCaptionFile,
    super.videoPlayerOptions,
    super.httpHeaders,
    super.viewType,
  }) : super.networkUrl();

  DisposalSafeVideoPlayerController.asset(
    super.dataSource, {
    super.package,
    super.closedCaptionFile,
    super.videoPlayerOptions,
    super.viewType,
  }) : super.asset();

  bool _disposeRequested = false;

  @override
  set value(VideoPlayerValue newValue) {
    if (_disposeRequested) return;
    super.value = newValue;
  }

  @override
  Future<void> dispose() {
    _disposeRequested = true;
    return super.dispose();
  }
}
