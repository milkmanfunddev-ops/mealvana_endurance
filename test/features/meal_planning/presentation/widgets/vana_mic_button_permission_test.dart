// Ticket 79 (Finding 09-004): opening a Vana chat must not ask iOS for
// Speech Recognition. `SpeechToText.initialize` is the call that raises the
// system prompt, so building the mic button must not make it; the first tap
// does, and a granted tap goes straight on to listening.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_mic_button.dart';
import 'package:speech_to_text/speech_to_text.dart';

class _FakeSpeech extends Fake implements SpeechToText {
  _FakeSpeech({this.grants = true});

  final bool grants;
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
  Future<void> stop() async {}
}

Widget _host(SpeechToText speech) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: VanaMicButton(
        onText: (_) {},
        tooltip: 'Dictate',
        listeningTooltip: 'Listening',
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

  testWidgets('a refused ask hides the mic and does not listen', (
    tester,
  ) async {
    final speech = _FakeSpeech(grants: false);
    await tester.pumpWidget(_host(speech));
    await tester.pumpAndSettle();

    await tester.tap(_mic);
    await tester.pumpAndSettle();

    expect(speech.initializeCalls, 1);
    expect(speech.listenCalls, 0);
    expect(_mic, findsNothing);
  });
}
