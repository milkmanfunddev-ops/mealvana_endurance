/// VanaTransport timeouts (testing-wave 129, Finding 89-005): a request that
/// never answers ends in [VanaOfflineException] instead of spinning for good,
/// and long actions (confirm_plan, chat turns) get the longer budget.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_transport.dart';

import '../helpers/fakes.dart';

/// A transport whose HTTP client accepts the request and never answers.
/// [closed] completes when the transport closes the client.
({VanaTransport transport, Completer<void> closed}) _hanging({
  Duration timeout = const Duration(milliseconds: 40),
  Duration longTimeout = const Duration(milliseconds: 400),
}) {
  final closed = Completer<void>();
  final transport = VanaTransport(
    supabase: supabaseWithSession(),
    config: testConfig(),
    logger: FakeLogger(),
    timeout: timeout,
    longTimeout: longTimeout,
    clientFactory: () => _ClosingClient(
      MockClient((_) => Completer<http.Response>().future),
      onClose: () {
        if (!closed.isCompleted) closed.complete();
      },
    ),
  );
  return (transport: transport, closed: closed);
}

class _ClosingClient extends http.BaseClient {
  _ClosingClient(this._inner, {required this.onClose});

  final http.Client _inner;
  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    onClose();
    _inner.close();
  }
}

void main() {
  test('postJson: a request that never answers ends offline after the '
      'timeout, and the client is closed', () async {
    final h = _hanging();
    final watch = Stopwatch()..start();

    await expectLater(
      h.transport.postJson('vana-action', {'type': 'get_plan'}),
      throwsA(isA<VanaOfflineException>()),
    );

    expect(watch.elapsed, lessThan(const Duration(milliseconds: 380)));
    expect(h.closed.isCompleted, isTrue);
  });

  test('postJson: confirm_plan waits for the long timeout', () async {
    final h = _hanging();
    final watch = Stopwatch()..start();

    await expectLater(
      h.transport.postJson('vana-action', {'type': 'confirm_plan'}),
      throwsA(isA<VanaOfflineException>()),
    );

    expect(
      watch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 390)),
    );
  });

  test('streamNdjson: a chat turn whose headers never come ends offline '
      'after the long timeout', () async {
    final h = _hanging();
    final watch = Stopwatch()..start();

    await expectLater(
      h.transport.streamNdjson('vana-chat', {'message': 'hi'}),
      throwsA(isA<VanaOfflineException>()),
    );

    expect(
      watch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 390)),
    );
    expect(h.closed.isCompleted, isTrue);
  });

  test('the production budgets: 20 s for a read, 90 s for a long action', () {
    expect(VanaTransport.defaultTimeout, const Duration(seconds: 20));
    expect(VanaTransport.defaultLongTimeout, const Duration(seconds: 90));
    expect(VanaTransport.longActions, contains('confirm_plan'));
    expect(VanaTransport.longActions, isNot(contains('get_plan')));
  });
}
