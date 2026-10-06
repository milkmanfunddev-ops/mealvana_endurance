// Riverpod net seam (spec: .scratch/sentry/spec.md § Riverpod, § Testing
// seam 1; ticket 03).
//
// A real `ProviderContainer` carries the observer and its retry hook; the
// observer reports through a real `SentryReport` whose SDK transport is
// in-memory. Assertions are on what left: events, their tags, breadcrumbs.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/debug_log_storage.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_provider_observer.dart';

class CapturingTransport implements Transport {
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

/// A notifier whose one method fails through `AsyncValue.guard`, the shape
/// every controller in the app uses.
class SaveController extends AsyncNotifier<int> {
  @override
  Future<int> build() async => 0;

  Future<void> save() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      throw FormatException('bad payload');
    });
  }
}

/// A retry policy with no delay and a low ceiling so a test runs in
/// milliseconds. Same shape as Riverpod's default otherwise.
Duration? _fastRetry(int retryCount, Object error) =>
    ProviderContainer.defaultRetry(
      retryCount,
      error,
      maxRetries: 2,
      minDelay: Duration.zero,
      maxDelay: Duration.zero,
    );

void main() {
  late CapturingTransport transport;
  late SentryReport report;
  late SentryProviderObserver observer;
  late ProviderContainer container;

  /// Breadcrumbs ride on the next event; read them off the scope directly.
  Future<List<Breadcrumb>> breadcrumbs() async {
    late List<Breadcrumb> crumbs;
    await Sentry.configureScope((scope) => crumbs = scope.breadcrumbs);
    return crumbs;
  }

  List<Breadcrumb> ofCategory(List<Breadcrumb> crumbs, String category) =>
      crumbs.where((c) => c.category == category).toList();

  /// Lets the observer's fire-and-forget `fault` reach the transport.
  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    transport = CapturingTransport();
    await Sentry.init((options) {
      options.dsn = 'https://public@sentry.example.com/1';
      options.transport = transport;
      options.environment = 'test';
    });
    report = SentryReport(
      analytics: () => const NoopAnalyticsTracker(),
      logStorage: DebugLogStorage()..clear(),
      console: false,
      consoleLogger: Logger(
        level: Level.off,
        printer: SimplePrinter(),
        output: _NullOutput(),
      ),
    );
    observer = SentryProviderObserver(report: report, retryPolicy: _fastRetry);
    container = ProviderContainer(observers: [observer], retry: observer.retry);
  });

  tearDown(() async {
    container.dispose();
    await Sentry.close();
  });

  test('a build that throws yields exactly one event, and a downstream '
      'provider rethrowing the ProviderException adds none', () async {
    final upstream = Provider<int>(
      (ref) => throw StateError('catalog missing'),
      name: 'catalogProvider',
    );
    final downstream = Provider<int>(
      (ref) => ref.watch(upstream) + 1,
      name: 'menuProvider',
    );

    expect(() => container.read(downstream), throwsA(isA<ProviderException>()));
    await flush();

    final event = transport.events.single;
    expect(event.throwable, isA<StateError>());
    expect(event.tags, containsPair('component', 'riverpod_provider'));
    expect(event.tags, containsPair('provider', 'catalogProvider'));
    expect(event.tags, isNot(contains('wrapped')));

    final crumbs = await breadcrumbs();
    final skipped = ofCategory(crumbs, riverpodDuplicateCategory);
    expect(skipped, hasLength(1));
    expect(skipped.single.data, containsPair('provider', 'menuProvider'));
  });

  test('a ProviderException whose inner error was never reported is '
      'unwrapped and tagged wrapped', () async {
    // The wrapper is the only thing this observer sees: the upstream failure
    // happened in a container with no observer. Riverpod builds the wrapper;
    // its constructor is internal.
    final unobserved = ProviderContainer();
    addTearDown(unobserved.dispose);
    final upstream = Provider<int>(
      (ref) => throw StateError('offline catalog'),
      name: 'catalogProvider',
    );
    late final ProviderException wrapper;
    try {
      unobserved.read(upstream);
      fail('expected the failed provider to throw');
    } on ProviderException catch (e) {
      wrapper = e;
    }

    final downstream = Provider<int>(
      (ref) => throw wrapper,
      name: 'menuProvider',
    );
    expect(() => container.read(downstream), throwsA(isA<ProviderException>()));
    await flush();

    final event = transport.events.single;
    expect(event.throwable, isA<StateError>());
    expect(event.tags, containsPair('wrapped', 'true'));
    expect(event.tags, containsPair('provider', 'menuProvider'));
  });

  test('a guard-caught error in an AsyncNotifier method yields one event '
      'tagged with the provider name', () async {
    final saveProvider = AsyncNotifierProvider<SaveController, int>(
      SaveController.new,
      name: 'saveController',
    );
    await container.read(saveProvider.future);

    await container.read(saveProvider.notifier).save();
    await flush();

    expect(container.read(saveProvider).hasError, isTrue);
    final event = transport.events.single;
    expect(event.throwable, isA<FormatException>());
    expect(event.tags, containsPair('component', 'riverpod_provider'));
    expect(event.tags, containsPair('provider', 'saveController'));
    expect(event.tags, containsPair('severity', 'fault'));
  });

  test('a build that fails twice then succeeds yields two retry breadcrumbs '
      'and no event', () async {
    var attempts = 0;
    final flaky = FutureProvider<int>((ref) async {
      attempts++;
      if (attempts <= 2) throw Exception('transient $attempts');
      return attempts;
    }, name: 'flakyProvider');

    // A retry rebuilds only while something listens, as a widget would.
    container.listen(flaky, (_, _) {});
    expect(await container.read(flaky.future), 3);
    await flush();

    expect(transport.events, isEmpty);
    final retries = ofCategory(await breadcrumbs(), riverpodRetryCategory);
    expect(retries, hasLength(2));
    expect(retries[0].data, containsPair('provider', 'flakyProvider'));
    expect(retries[0].data, containsPair('attempt', 1));
    expect(retries[0].data, containsPair('error_type', '_Exception'));
    expect(retries[1].data, containsPair('attempt', 2));
  });

  test('a sync Provider that fails twice then succeeds takes the other door: '
      'two retry breadcrumbs and no event', () async {
    var attempts = 0;
    final flaky = Provider<int>((ref) {
      attempts++;
      if (attempts <= 2) throw Exception('transient $attempts');
      return attempts;
    }, name: 'flakySyncProvider');

    // A sync provider hands each rebuild failure to its listener's onError
    // (the zone, by default); a widget's ref.watch would swallow it the same.
    container.listen(flaky, (_, _) {}, onError: (_, _) {});
    // Zero-delay retries land on later event-loop turns.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(flaky), 3);
    await flush();

    expect(transport.events, isEmpty);
    final retries = ofCategory(await breadcrumbs(), riverpodRetryCategory);
    expect(retries.map((c) => c.data?['attempt']), [1, 2]);
    expect(retries[0].data, containsPair('provider', 'flakySyncProvider'));
  });

  test('a build that exhausts its retries yields the breadcrumbs and then '
      'one event', () async {
    final broken = FutureProvider<int>((ref) async {
      throw Exception('still down');
    }, name: 'brokenProvider');

    container.listen(broken, (_, _) {});
    await expectLater(container.read(broken.future), throwsA(isA<Exception>()));
    await flush();

    expect(transport.events, hasLength(1));
    expect(
      transport.events.single.tags,
      containsPair('provider', 'brokenProvider'),
    );
    final retries = ofCategory(await breadcrumbs(), riverpodRetryCategory);
    expect(retries.map((c) => c.data?['attempt']), [1, 2]);
  });

  test(
    'the same failure on rebuild within a session yields no second event',
    () async {
      final broken = Provider<int>(
        (ref) => throw StateError('catalog missing'),
        name: 'catalogProvider',
      );

      expect(() => container.read(broken), throwsA(isA<ProviderException>()));
      container.invalidate(broken);
      expect(() => container.read(broken), throwsA(isA<ProviderException>()));
      await flush();

      expect(transport.events, hasLength(1));
      final skipped = ofCategory(
        await breadcrumbs(),
        riverpodDuplicateCategory,
      );
      expect(skipped, hasLength(1));
      expect(
        skipped.single.data,
        containsPair('reason', 'same failure this session'),
      );
    },
  );

  test('a different failure on the same provider is its own event', () async {
    var n = 0;
    final broken = Provider<int>(
      (ref) => throw StateError('failure ${++n}'),
      name: 'catalogProvider',
    );

    expect(() => container.read(broken), throwsA(isA<ProviderException>()));
    container.invalidate(broken);
    expect(() => container.read(broken), throwsA(isA<ProviderException>()));
    await flush();

    expect(transport.events, hasLength(2));
  });

  test(
    'a new observer is a new session: the same failure reports again',
    () async {
      final broken = Provider<int>(
        (ref) => throw StateError('catalog missing'),
        name: 'catalogProvider',
      );
      expect(() => container.read(broken), throwsA(isA<ProviderException>()));

      final second = SentryProviderObserver(report: report);
      final other = ProviderContainer(observers: [second], retry: second.retry);
      addTearDown(other.dispose);
      expect(() => other.read(broken), throwsA(isA<ProviderException>()));
      await flush();

      expect(transport.events, hasLength(2));
    },
  );

  test(
    'without an explicit Report the observer uses SentryReport.global',
    () async {
      final previous = SentryReport.global;
      SentryReport.global = report;
      addTearDown(() => SentryReport.global = previous);

      final net = SentryProviderObserver();
      final scope = ProviderContainer(observers: [net], retry: net.retry);
      addTearDown(scope.dispose);
      final broken = Provider<int>(
        (ref) => throw StateError('boom'),
        name: 'p',
      );
      expect(() => scope.read(broken), throwsA(isA<ProviderException>()));
      await flush();

      expect(transport.events, hasLength(1));
    },
  );
}
