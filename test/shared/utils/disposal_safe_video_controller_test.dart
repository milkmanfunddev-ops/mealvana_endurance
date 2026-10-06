// Sentry MEALVANA-ENDURANCE-DEV-9R (ticket 24a): "A VideoPlayerController was
// used after being disposed", thrown from VideoPlayerController.seekTo ->
// _updatePosition. seekTo awaits the platform seek and then writes the
// position; a controller disposed while the seek is in flight takes that
// write on a disposed ChangeNotifier.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/utils/disposal_safe_video_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A platform whose seeks finish only when the test says so.
class _SlowSeekPlatform extends VideoPlayerPlatform {
  final _events = StreamController<VideoEvent>.broadcast();
  Completer<void>? pendingSeek;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  void reportInitialized() => _events.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(540, 1174),
    ),
  );

  @override
  Future<void> seekTo(int playerId, Duration position) {
    pendingSeek = Completer<void>();
    return pendingSeek!.future;
  }

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _SlowSeekPlatform platform;

  setUp(() {
    platform = _SlowSeekPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  Future<void> initialize(VideoPlayerController controller) async {
    final done = controller.initialize();
    await Future<void>.delayed(Duration.zero);
    platform.reportInitialized();
    await done;
  }

  test(
    'the package controller throws when a seek lands after dispose',
    () async {
      // Pins the hazard the safe controller exists for: if video_player ever
      // guards this itself, this test fails and the wrapper can go.
      final controller = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/clip.mp4'),
      );
      await initialize(controller);

      final seek = controller.seekTo(const Duration(seconds: 3));
      await controller.dispose();
      platform.pendingSeek!.complete();

      await expectLater(seek, throwsA(isA<FlutterError>()));
    },
  );

  test('DEV-9R: a seek that lands after dispose is dropped', () async {
    final controller = DisposalSafeVideoPlayerController.networkUrl(
      Uri.parse('https://example.com/clip.mp4'),
    );
    await initialize(controller);

    final seek = controller.seekTo(const Duration(seconds: 3));
    await controller.dispose();
    platform.pendingSeek!.complete();

    await expectLater(seek, completes);
  });

  test('before dispose the safe controller still reports position', () async {
    final controller = DisposalSafeVideoPlayerController.networkUrl(
      Uri.parse('https://example.com/clip.mp4'),
    );
    await initialize(controller);

    final seek = controller.seekTo(const Duration(seconds: 3));
    platform.pendingSeek!.complete();
    await seek;

    expect(controller.value.position, const Duration(seconds: 3));
    await controller.dispose();
  });
}
