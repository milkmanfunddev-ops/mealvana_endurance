// develop-2026-10 ticket 41.
//
// 32-015: "completed" means watched. Every exit from a lesson sends
// `education_video_closed` with `percent_watched`; `education_video_completed`
// only when at least 90 % was watched (lesson 1.3 left at 15 % used to log a
// completion).
//
// 69-007 (develop-2026-10 ticket 82): watched means PLAYED. A scrub to the end
// without playing sent `watched_sec: 96` and a completion. `watched_sec` and
// `percent_watched` now count time played; `furthest_sec` keeps the furthest
// position reached.
//
// 32-007: a lesson opened offline is weather, not a fault. iOS phrases it as
// `PlatformException(VideoError, Failed to load video: Could not connect to
// the server., ...)` (run 32 console, 08:17:08).
//
// The real VideoPlayerScreen and the real video_player controller; only the
// platform side of video_player is fake.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:mealvana_endurance/features/education/presentation/screens/video_player_screen.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart' show MockSharedPreferences;

const _duration = Duration(seconds: 100);

/// video_player's platform side: a 100 s clip that initializes at once and
/// seeks at once, or (with [createError]) a load that fails. [position] is
/// what the controller's 100 ms poll reads while playing; the test advances
/// it the way a playing clip would.
class _FakeVideoPlatform extends VideoPlayerPlatform {
  _FakeVideoPlatform({this.createError});

  final Object? createError;
  Duration position = Duration.zero;
  final _events = StreamController<VideoEvent>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    if (createError != null) throw createError!;
    return 1;
  }

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  /// The controller listens right after this returns; the clip reports
  /// itself initialized just after.
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    scheduleMicrotask(
      () => _events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: _duration,
          size: const Size(540, 960),
        ),
      ),
    );
    return _events.stream;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    this.position = position;
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
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  late RecordingAnalyticsTracker analytics;
  late RecordingReport report;

  setUp(() {
    analytics = RecordingAnalyticsTracker();
    report = RecordingReport();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportProvider.overrideWithValue(report),
          appExternalDepsProvider.overrideWithValue(
            AppExternalDeps(
              analytics: analytics,
              supabaseClient: fakeSupabaseClient(),
              sharedPreferences: MockSharedPreferences(),
              report: report,
            ),
          ),
        ],
        child: const MaterialApp(
          home: VideoPlayerScreen(
            title: 'Lesson 1.3',
            videoUrl: 'https://example.com/lesson-1-3.mp4',
            contentId: 'lesson-1-3',
          ),
        ),
      ),
    );
    // Initialization crosses several async gaps (the platform's create, then
    // its `initialized` event).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  late _FakeVideoPlatform platform;

  Future<VideoPlayerController> openLesson(WidgetTester tester) async {
    platform = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    await open(tester);
    return tester
        .widget<Chewie>(find.byType(Chewie))
        .controller
        .videoPlayerController;
  }

  /// Real playback: play, then move the clip forward 100 ms per 100 ms pump
  /// (the controller polls the position every 100 ms while playing) until
  /// [to], then pause.
  Future<void> playTo(
    WidgetTester tester,
    VideoPlayerController video,
    Duration to,
  ) async {
    await video.play();
    await tester.pump();
    while (platform.position < to) {
      platform.position += const Duration(milliseconds: 100);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await video.pause();
    await tester.pump();
  }

  /// Leave the lesson: the screen's dispose sends the exit events.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Map<String, dynamic>? closedProperties() =>
      analytics.findEvents('education_video_closed').single.properties;

  testWidgets('played to 91 %: closed and completed, with the same '
      'properties', (tester) async {
    final video = await openLesson(tester);
    await playTo(tester, video, const Duration(seconds: 91));
    await close(tester);

    final closed = analytics.findEvents('education_video_closed');
    final completed = analytics.findEvents('education_video_completed');
    expect(closed, hasLength(1));
    expect(completed, hasLength(1));
    expect(closed.single.properties?['video_id'], 'lesson-1-3');
    expect(closed.single.properties?['watched_sec'], 91);
    expect(closed.single.properties?['percent_watched'], 91);
    expect(closed.single.properties?['furthest_sec'], 91);
    expect(closed.single.properties?['duration_sec'], 100);
    expect(completed.single.properties, closed.single.properties);
  });

  testWidgets('left at 15 %: education_video_closed {percent_watched: 15}, '
      'and no completed', (tester) async {
    final video = await openLesson(tester);
    await playTo(tester, video, const Duration(seconds: 15));
    await close(tester);

    expect(closedProperties()?['watched_sec'], 15);
    expect(closedProperties()?['percent_watched'], 15);
    expect(analytics.findEvents('education_video_completed'), isEmpty);
  });

  testWidgets('69-007: scrubbed to the end, never played: watched 0, '
      'furthest 100, no completed', (tester) async {
    final video = await openLesson(tester);
    await video.seekTo(_duration);
    await tester.pump();
    await close(tester);

    expect(closedProperties()?['watched_sec'], 0);
    expect(closedProperties()?['percent_watched'], 0);
    expect(closedProperties()?['furthest_sec'], 100);
    expect(analytics.findEvents('education_video_completed'), isEmpty);
  });

  testWidgets('played 10 s, then dragged to the end while playing: the '
      'drag does not count', (tester) async {
    final video = await openLesson(tester);
    await video.play();
    await tester.pump();
    while (platform.position < const Duration(seconds: 10)) {
      platform.position += const Duration(milliseconds: 100);
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The drag: one jump while still playing, then a few more polls.
    await video.seekTo(_duration);
    await tester.pump(const Duration(milliseconds: 300));
    await video.pause();
    await tester.pump();
    await close(tester);

    expect(closedProperties()?['watched_sec'], 10);
    expect(closedProperties()?['percent_watched'], 10);
    expect(closedProperties()?['furthest_sec'], 100);
    expect(analytics.findEvents('education_video_completed'), isEmpty);
  });

  testWidgets('a lesson opened offline is a breadcrumb and one count, not a '
      'fault; the screen still says so', (tester) async {
    VideoPlayerPlatform.instance = _FakeVideoPlatform(
      createError: PlatformException(
        code: 'VideoError',
        message:
            'Failed to load video: Could not connect to the server.: '
            'Could not connect to the server.',
      ),
    );
    await open(tester);

    expect(find.text('Failed to load video'), findsOneWidget);
    expect(report.faults, isEmpty);
    expect(report.degradeds, isEmpty);
    final crumbs = report.calls.where(
      (c) => c.severity == 'breadcrumb' && c.area == 'education.weather',
    );
    expect(crumbs, hasLength(1));
    expect(analytics.findEvents(expectedFailureEvent).single.properties, {
      'area': 'education',
      'reason': 'offline',
    });

    await tester.pumpWidget(const SizedBox());
  });
}
