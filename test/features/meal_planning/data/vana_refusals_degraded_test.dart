// Ticket 24 (Sentry DEV-90, DEV-91, DEV-9C, DEV-9A): an expected refusal that
// fails a provider arrives as Degraded, not as a Fault.
//
// The path these issues took: the real `VanaTransport` maps the HTTP status to
// a typed exception (and already sends the status as a Degraded), the
// exception fails the provider, and the Riverpod observer sent it again, this
// time as a Fault (`component: riverpod_provider`). The Code entry's
// `CodeRedeemFailure` took the same observer path from its notifier's
// `AsyncValue.guard`.
//
// Seam: real transport (HTTP answered by a mock client with the server's own
// bodies) → real provider failure → real `SentryProviderObserver` → real
// `SentryReport` with an in-memory SDK transport. Assertions are on the
// envelope that left.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_provider_observer.dart';

import '../helpers/fakes.dart';

class _CapturingTransport implements Transport {
  final List<SentryEnvelope> envelopes = [];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId;
  }

  List<SentryEvent> get events => envelopes
      .expand((e) => e.items)
      .where((i) => i.header.type == 'event')
      .map((i) => i.originalObject)
      .whereType<SentryEvent>()
      .toList();
}

class _NullOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

/// Same type name and `toString()` as the Code entry's failure
/// (`lib/features/subscription/domain/code_redemption.dart` on
/// `mealplanning`, not yet on this branch). The allow-list classifies on
/// exactly that text (`describeThrowable`).
class CodeRedeemFailure implements Exception {
  const CodeRedeemFailure(this.kind);

  final String kind;

  @override
  String toString() => 'CodeRedeemFailure($kind)';
}

/// The Code entry's shape: `redeem` writes the failure into state through
/// `AsyncValue.guard`.
class _CodeEntry extends AsyncNotifier<String?> {
  _CodeEntry(this.failure);

  final Object failure;

  @override
  Future<String?> build() async => null;

  Future<void> redeem() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => throw failure);
  }
}

void main() {
  late _CapturingTransport sdk;
  late ProviderContainer container;

  setUp(() async {
    sdk = _CapturingTransport();
    await Sentry.init((options) {
      options.dsn = 'https://public@sentry.example.com/1';
      options.transport = sdk;
      options.environment = 'test';
    });
    final report = SentryReport(
      analytics: () => const NoopAnalyticsTracker(),
      logStorage: ReportLog()..clear(),
      console: false,
      consoleLogger: Logger(
        level: Level.off,
        printer: SimplePrinter(),
        output: _NullOutput(),
      ),
    );
    final observer = SentryProviderObserver(
      report: report,
      retryPolicy: (_, _) => null,
    );
    container = ProviderContainer(observers: [observer], retry: observer.retry);
  });

  tearDown(() async {
    container.dispose();
    await Sentry.close();
  });

  /// Fail a provider with what the real transport throws for [status] and
  /// [body], and return the one event the observer sent.
  Future<SentryEvent> providerFailsOnVana(int status, String body) async {
    final harness = TransportHarness(status: status, body: body);
    final provider = FutureProvider<Map<String, dynamic>>(
      (ref) => harness.transport.postJson('vana-action', {'type': 'get_home'}),
      name: 'homeControllerProvider',
    );
    await expectLater(container.read(provider.future), throwsA(anything));
    await pumpEventQueue();
    return sdk.events.single;
  }

  test(
    'DEV-90/91: a 401 from Vana arrives as Degraded (expired_session)',
    () async {
      final event = await providerFailsOnVana(
        401,
        jsonEncode({'error': 'unauthenticated'}),
      );
      expect(event.throwable.toString(), contains('VanaUnauthenticated'));
      expect(event.level, SentryLevel.warning);
      expect(event.tags, containsPair('severity', 'degraded'));
      expect(event.tags, containsPair('expected_failure', 'expired_session'));
      expect(event.tags, containsPair('component', 'riverpod_provider'));
    },
  );

  test(
    'DEV-9C: a 403 pro_required arrives as Degraded (not_entitled)',
    () async {
      final event = await providerFailsOnVana(
        403,
        jsonEncode({'error': 'pro_required'}),
      );
      expect(event.throwable.toString(), contains('ProRequiredException'));
      expect(event.level, SentryLevel.warning);
      expect(event.tags, containsPair('expected_failure', 'not_entitled'));
    },
  );

  test('a 429 rate_limited arrives as Degraded (handled_refusal)', () async {
    final event = await providerFailsOnVana(
      429,
      jsonEncode({'error': 'rate_limited', 'retry_after_seconds': 12}),
    );
    expect(event.level, SentryLevel.warning);
    expect(event.tags, containsPair('expected_failure', 'handled_refusal'));
  });

  test('control: a 500 from Vana is still a Fault', () async {
    final event = await providerFailsOnVana(
      500,
      jsonEncode({'error': 'internal'}),
    );
    expect(event.level, SentryLevel.error);
    expect(event.tags, containsPair('severity', 'fault'));
    expect(event.tags, isNot(contains('expected_failure')));
  });

  for (final kind in ['unavailable', 'signInRequired']) {
    test('DEV-9A: CodeRedeemFailure($kind) in the Code entry state arrives '
        'as Degraded (handled_refusal)', () async {
      final entry = AsyncNotifierProvider<_CodeEntry, String?>(
        () => _CodeEntry(CodeRedeemFailure(kind)),
        name: 'codeEntryControllerProvider',
      );
      await container.read(entry.future);
      await container.read(entry.notifier).redeem();
      await pumpEventQueue();

      final event = sdk.events.single;
      expect(event.level, SentryLevel.warning);
      expect(event.tags, containsPair('expected_failure', 'handled_refusal'));
      expect(
        event.tags,
        containsPair('provider', 'codeEntryControllerProvider'),
      );
    });
  }
}
