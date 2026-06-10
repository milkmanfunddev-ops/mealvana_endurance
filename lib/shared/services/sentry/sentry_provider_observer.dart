import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// A [ProviderObserver] that forwards provider failures to Sentry.
///
/// Because all Riverpod controllers use [AsyncValue.guard], errors end up in
/// [AsyncError] state rather than propagating as uncaught exceptions. Without
/// this observer, Sentry never sees those failures.
///
/// Wired into [ProviderScope(observers: [SentryProviderObserver()])] in every
/// app entrypoint so it covers every flavour (dev, prod, web).
///
/// Riverpod 3 API — [providerDidFail] receives a [ProviderObserverContext]
/// which carries the failing provider reference.
final class SentryProviderObserver extends ProviderObserver {
  const SentryProviderObserver();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('component', 'riverpod_provider');
        scope.setTag('provider', context.provider.name ?? context.provider.runtimeType.toString());
        scope.level = SentryLevel.error;
      },
    );
  }
}
