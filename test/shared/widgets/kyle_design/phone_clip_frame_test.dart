/// phone-clip-frame spec (PROPOSED v1, paywall ticket 14 — mp-493 §1, §6):
///   PCF-1  the clip plays muted, once, inside the frame; the poster holds
///          the screen until the first frame plays
///   PCF-2  the end of the clip is reported once; a clip that fails or never
///          starts reports the end too, so a page never waits on it
///   PCF-3  still: the poster alone, no player is ever made
///   PCF-4  the frame keeps the clip's aspect ratio at any width
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/data/phone_clip_frame.dart';

import 'phone_clip_fakes.dart';

void main() {
  late FakePhoneClipPlayer player;
  late int made;
  late int ended;

  Future<void> pump(
    WidgetTester tester, {
    bool still = false,
    double width = 240,
    Duration loadTimeout = const Duration(seconds: 3),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: PhoneClipFrame(
                player: () {
                  made++;
                  return player;
                },
                poster: testPoster,
                still: still,
                aspectRatio: 0.46,
                loadTimeout: loadTimeout,
                onEnded: () => ended++,
                semanticLabel: 'The app playing',
              ),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    player = FakePhoneClipPlayer();
    made = 0;
    ended = 0;
  });

  testWidgets('PCF-1 starts the clip muted and shows it once it plays', (
    tester,
  ) async {
    await pump(tester);
    expect(made, 1);
    expect(player.started, isTrue);
    expect(player.muted, isTrue);
    // Loading: the poster holds the screen.
    expect(find.byKey(PhoneClipFrame.posterKey), findsOneWidget);
    expect(find.byKey(FakePhoneClipPlayer.viewKey), findsNothing);

    player.phase.value = PhoneClipPhase.playing;
    await tester.pump();
    expect(find.byKey(FakePhoneClipPlayer.viewKey), findsOneWidget);
    expect(ended, 0);
  });

  testWidgets('PCF-2 reports the end once', (tester) async {
    await pump(tester);
    player.phase.value = PhoneClipPhase.playing;
    await tester.pump();
    player.phase.value = PhoneClipPhase.ended;
    await tester.pump();
    player.phase.value = PhoneClipPhase.failed;
    await tester.pump();
    expect(ended, 1);
  });

  testWidgets('PCF-2 a failed clip reports the end', (tester) async {
    await pump(tester);
    player.phase.value = PhoneClipPhase.failed;
    await tester.pump();
    expect(ended, 1);
    // The poster stays up; no broken video surface.
    expect(find.byKey(PhoneClipFrame.posterKey), findsOneWidget);
  });

  testWidgets('PCF-2 a clip that never starts reports the end after the '
      'load timeout', (tester) async {
    await pump(tester, loadTimeout: const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 1900));
    expect(ended, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(ended, 1);
  });

  testWidgets('PCF-3 still shows the poster and never makes a player', (
    tester,
  ) async {
    await pump(tester, still: true);
    expect(made, 0);
    expect(find.byKey(PhoneClipFrame.posterKey), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(ended, 0);
  });

  testWidgets('disposing the frame disposes the player', (tester) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox());
    expect(player.disposed, isTrue);
  });

  testWidgets('PCF-4 keeps the clip aspect ratio', (tester) async {
    for (final width in [180.0, 250.0]) {
      player = FakePhoneClipPlayer();
      await pump(tester, still: true, width: width);
      final size = tester.getSize(find.byType(PhoneClipFrame));
      expect(size.width, width);
      expect(size.width / size.height, moreOrLessEquals(0.46, epsilon: 0.01));
    }
  });

  test('the fake is a PhoneClipPlayer', () {
    expect(FakePhoneClipPlayer(), isA<PhoneClipPlayer>());
    expect(FakePhoneClipPlayer().phase, isA<ValueListenable<PhoneClipPhase>>());
  });
}
