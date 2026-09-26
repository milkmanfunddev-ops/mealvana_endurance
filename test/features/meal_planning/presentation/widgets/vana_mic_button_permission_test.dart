// Ticket 79 (Finding 09-004): opening a Vana chat must not ask iOS for
// Speech Recognition. `SpeechToText.initialize` is the call that raises the
// system prompt, so building the mic button must not make it; the first tap
// does, and a granted tap goes straight on to listening.
//
// Ticket 104 (Finding 86-005): after "Don't Allow" the mic stays and a tap
// says where to turn access back on; only a device with no speech engine at
// all loses the button.
//
// Ticket 141 (Finding 120-005): the message names the app as the device
// lists it ("Endurance Dev" on the dev build, not "Mealvana"), and floats
// above the composer, which stays tappable while it shows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_mic_button.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../helpers/test_content.dart';

class _FakeSpeech extends Fake implements SpeechToText {
  _FakeSpeech({this.grants = true, this.permitted = true});

  /// What `initialize` answers.
  final bool grants;

  /// What `hasPermission` answers: false once the athlete refused.
  final bool permitted;
  int initializeCalls = 0;
  int listenCalls = 0;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    dynamic debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    initializeCalls++;
    return grants;
  }

  @override
  Future listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    dynamic cancelOnError = false,
    dynamic partialResults = true,
    dynamic onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    dynamic sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    listenCalls++;
  }

  @override
  Future<bool> get hasPermission async => permitted;

  @override
  Future<void> stop() async {}
}

const _settingsMessage =
    'Dictation needs Speech Recognition and Microphone access.';

Widget _host(SpeechToText speech) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: VanaMicButton(
        onText: (_) {},
        tooltip: 'Dictate',
        listeningTooltip: 'Listening',
        permissionMessage: _settingsMessage,
        speech: speech,
      ),
    ),
  ),
);

const _composerKey = ValueKey('test.composer');

/// The mic inside a composer docked at the bottom, as the chat lays it out,
/// with the composer's height as the message's clearance.
Widget _composerHost(SpeechToText speech) => MaterialApp(
  home: Scaffold(
    body: Column(
      children: [
        const Expanded(child: SizedBox.expand()),
        Builder(
          builder: (context) => Container(
            key: _composerKey,
            height: 72,
            color: Colors.white,
            alignment: Alignment.centerRight,
            child: VanaMicButton(
              onText: (_) {},
              tooltip: 'Dictate',
              listeningTooltip: 'Listening',
              permissionMessage: _settingsMessage,
              messageClearance: () {
                final box = context.findRenderObject() as RenderBox;
                final media = MediaQuery.of(context);
                return media.size.height -
                    box.localToGlobal(Offset.zero).dy -
                    media.viewPadding.bottom;
              },
              speech: speech,
            ),
          ),
        ),
      ],
    ),
  ),
);

final _mic = find.byKey(const ValueKey('meal_planning.chat_mic'));

void main() {
  testWidgets('building the mic button asks for no speech permission', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    await tester.pumpWidget(_host(speech));
    await tester.pumpAndSettle();

    expect(speech.initializeCalls, 0);
    expect(_mic, findsOneWidget, reason: 'the mic shows before any ask');
  });

  testWidgets('the first tap asks, then listens', (tester) async {
    final speech = _FakeSpeech();
    await tester.pumpWidget(_host(speech));
    await tester.pumpAndSettle();

    await tester.tap(_mic);
    await tester.pumpAndSettle();

    expect(speech.initializeCalls, 1);
    expect(speech.listenCalls, 1);
  });

  testWidgets('a refused ask keeps the mic and a tap says to allow access '
      'in Settings', (tester) async {
    final speech = _FakeSpeech(grants: false, permitted: false);
    await tester.pumpWidget(_host(speech));
    await tester.pumpAndSettle();

    await tester.tap(_mic);
    await tester.pump();

    expect(speech.listenCalls, 0);
    expect(_mic, findsOneWidget, reason: 'refused is not "no engine"');
    expect(find.text(_settingsMessage), findsOneWidget);

    // A second tap says it again rather than going quiet.
    ScaffoldMessenger.of(tester.element(_mic)).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.text(_settingsMessage), findsNothing);
    await tester.tap(_mic);
    await tester.pump();
    expect(find.text(_settingsMessage), findsOneWidget);
    expect(speech.listenCalls, 0);
  });

  testWidgets('no speech engine at all hides the mic', (tester) async {
    // Permission is not what failed: the device has no recogniser.
    final speech = _FakeSpeech(grants: false, permitted: true);
    await tester.pumpWidget(_host(speech));
    await tester.pumpAndSettle();

    await tester.tap(_mic);
    await tester.pumpAndSettle();

    expect(speech.initializeCalls, 1);
    expect(speech.listenCalls, 0);
    expect(_mic, findsNothing);
    expect(find.text(_settingsMessage), findsNothing);
  });

  test('the Settings message names the app as the device lists it', () {
    final template = loadDefaultContent()['meal_planning.mic_permission']!;
    expect(template, contains('{app}'));

    final message = VanaMicButton.permissionMessageFor(
      template,
      'Endurance Dev',
    );
    expect(message, contains('iOS Settings → Endurance Dev.'));
    expect(message, isNot(contains('{app}')));
    expect(message, isNot(contains('Mealvana')));
  });

  testWidgets('the Settings message floats above the composer, which stays '
      'tappable while it shows', (tester) async {
    final speech = _FakeSpeech(grants: false, permitted: false);
    await tester.pumpWidget(_composerHost(speech));
    await tester.pumpAndSettle();

    await tester.tap(_mic);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(_settingsMessage), findsOneWidget);
    // The SnackBar's own box includes its margin; the message is its surface.
    final message = tester.getRect(
      find
          .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
          .first,
    );
    final composer = tester.getRect(find.byKey(_composerKey));
    expect(message.bottom, lessThanOrEqualTo(composer.top));
    expect(_mic.hitTestable(), findsOneWidget);
  });
}
