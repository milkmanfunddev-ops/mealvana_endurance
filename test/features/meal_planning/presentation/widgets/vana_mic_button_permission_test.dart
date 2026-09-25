// Ticket 79 (Finding 09-004): opening a Vana chat must not ask iOS for
// Speech Recognition. `SpeechToText.initialize` is the call that raises the
// system prompt, so building the mic button must not make it; the first tap
// does, and a granted tap goes straight on to listening.
//
// Ticket 104 (Finding 86-005): after "Don't Allow" the mic stays and a tap
// says where to turn access back on; only a device with no speech engine at
// all loses the button.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_mic_button.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
}
