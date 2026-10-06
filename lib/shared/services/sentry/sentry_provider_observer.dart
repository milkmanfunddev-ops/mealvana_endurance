/// The Riverpod net (spec: `.scratch/sentry/spec.md` § Riverpod; ticket 03).
///
/// Every provider failure Riverpod sees passes through [ProviderObserver.
/// providerDidFail]: a `build` that throws, a `Future` that errors, and the
/// `AsyncError` that `AsyncValue.guard` writes into a notifier's state. This
/// observer is the one place those become a Fault, through [Report]; it never
/// touches the Sentry SDK itself.
///
/// Three rules keep one failure at one event:
///
/// 1. A [ProviderException] is a downstream provider rethrowing an upstream
///    failure. The inner error is reported once, tagged `wrapped: true`, and
///    only if the upstream observer call did not already report that same
///    error object. Otherwise the wrapper is skipped.
/// 2. Dedupe within a session: provider name + exception type + message. One
///    observer instance is one session, so the set lives on the instance.
/// 3. A failure that Riverpod is about to retry is not a failure yet. The
///    [retry] callback (wired as `ProviderScope(retry: observer.retry)`)
///    sees each attempt before the observer does; the observer turns that
///    attempt into a breadcrumb and no event. The event comes only when the
///    retries are exhausted (or the policy declines), which is the one
///    `AsyncError` Riverpod emits with `retrying: false`.
///
/// Why the retry callback and the observer share one object: Riverpod's retry
/// hook is `Duration? Function(int retryCount, Object error)` and carries no
/// provider. The element calls it synchronously and then notifies observers
/// with the same error object, so the callback parks the attempt and the
/// observer call that follows names the provider. Which call that is depends
/// on the provider kind (riverpod 3.0.1 `element.dart`, `triggerRetry`,
/// confirmed by probe): an async provider emits `AsyncLoading(error,
/// retrying: true)` through `didUpdateProvider` and never calls
/// `providerDidFail` while retrying; a sync `Provider` calls
/// `providerDidFail` on every attempt. Both doors lead to one breadcrumb.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show ProviderBase, ProviderException;

import '../report/report.dart';

/// Breadcrumb category for a retry attempt.
const String riverpodRetryCategory = 'riverpod.retry';

/// Breadcrumb category for a failure the observer saw but did not report
/// again (rule D9: a skipped step is written down).
const String riverpodDuplicateCategory = 'riverpod.duplicate';

/// The retry policy signature Riverpod expects (its `Retry` typedef is marked
/// internal, so the shape is spelled out here).
typedef RetryPolicy = Duration? Function(int retryCount, Object error);

final class SentryProviderObserver extends ProviderObserver {
  /// [report] defaults to [SentryReport.global], resolved on each call so the
  /// instance built by `reportProvider` is picked up once it exists.
  /// [retryPolicy] is the policy [retry] delegates to; tests shorten it.
  SentryProviderObserver({Report? report, RetryPolicy? retryPolicy})
    : _report = report,
      _retryPolicy = retryPolicy ?? ProviderContainer.defaultRetry;

  final Report? _report;
  final RetryPolicy _retryPolicy;

  Report get _reporter => _report ?? SentryReport.global;

  /// Dedupe keys seen this session (provider | type | message).
  final Set<String> _reported = <String>{};

  /// Error objects reported this session, by identity. An [Expando] holds
  /// them weakly; primitives (a thrown `String`) cannot be expando keys and
  /// fall back to [_reportedPrimitives].
  final Expando<bool> _reportedErrors = Expando<bool>('riverpod reported');
  final Set<String> _reportedPrimitives = <String>{};

  /// The attempt [retry] just approved, waiting for the `providerDidFail`
  /// that follows it synchronously and names the provider.
  _PendingRetry? _pendingRetry;

  /// Riverpod's global retry hook. Records the attempt, then delegates.
  ///
  /// Wire as `ProviderScope(retry: observer.retry)` (or
  /// `ProviderContainer(retry: observer.retry)` in tests).
  Duration? retry(int retryCount, Object error) {
    final delay = _retryPolicy(retryCount, error);
    if (delay != null) {
      _pendingRetry = _PendingRetry(
        error: error,
        attempt: retryCount + 1,
        delay: delay,
      );
    }
    return delay;
  }

  /// An async provider (`FutureProvider`, `AsyncNotifier`) under retry does
  /// not fail: it emits an `AsyncLoading` carrying the error with
  /// `retrying: true`, and `providerDidFail` stays silent until the retries
  /// end. This is where that attempt becomes a breadcrumb.
  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (newValue is! AsyncValue<Object?> || !newValue.retrying) return;
    final error = newValue.error;
    if (error == null) return;
    _retryBreadcrumb(_nameOf(context.provider), error);
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final providerName = _nameOf(context.provider);

    // A sync provider under retry does reach this hook, once per attempt,
    // with the error the retry callback just approved.
    final pending = _pendingRetry;
    if (pending != null && identical(pending.error, error)) {
      _retryBreadcrumb(providerName, error);
      return;
    }

    var reported = error;
    var reportedStack = stackTrace;
    var wrapped = false;
    if (error is ProviderException) {
      final inner = error.exception;
      if (_wasReported(inner)) {
        _skipped(providerName, inner, reason: 'upstream already reported');
        return;
      }
      reported = inner;
      reportedStack = error.stackTrace;
      wrapped = true;
    }

    final key = '$providerName|${reported.runtimeType}|$reported';
    if (!_reported.add(key)) {
      _skipped(providerName, reported, reason: 'same failure this session');
      return;
    }
    _markReported(reported);

    unawaited(
      _reporter.fault(
        reported,
        stackTrace: reportedStack,
        tags: <String, String>{
          'component': 'riverpod_provider',
          'provider': providerName,
          if (wrapped) 'wrapped': 'true',
        },
      ),
    );
  }

  /// The attempt number and delay come from the parked [retry] call when it
  /// was for this same error object; a container wired without the callback
  /// still gets the breadcrumb, minus those two fields.
  void _retryBreadcrumb(String providerName, Object error) {
    final pending = _pendingRetry;
    final matched = pending != null && identical(pending.error, error);
    if (matched) _pendingRetry = null;
    _reporter.breadcrumb(
      matched
          ? 'Provider $providerName failed; retry ${pending.attempt} '
                'in ${pending.delay.inMilliseconds}ms'
          : 'Provider $providerName failed; retrying',
      category: riverpodRetryCategory,
      data: <String, dynamic>{
        'provider': providerName,
        'error_type': error.runtimeType.toString(),
        if (matched) 'attempt': pending.attempt,
        if (matched) 'delay_ms': pending.delay.inMilliseconds,
      },
    );
  }

  void _skipped(String providerName, Object error, {required String reason}) {
    _reporter.breadcrumb(
      'Provider $providerName failed again; not reported ($reason)',
      category: riverpodDuplicateCategory,
      data: <String, dynamic>{
        'provider': providerName,
        'error_type': error.runtimeType.toString(),
        'reason': reason,
      },
    );
  }

  bool _wasReported(Object error) {
    if (SentryReport.wasReported(error)) return true;
    try {
      return _reportedErrors[error] == true;
    } on ArgumentError {
      return _reportedPrimitives.contains(_primitiveKey(error));
    }
  }

  /// Marks the observer's own view only; `Report` marks the shared registry
  /// itself when the fault below is captured (marking it here first would
  /// make that capture look like a duplicate).
  void _markReported(Object error) {
    try {
      _reportedErrors[error] = true;
    } on ArgumentError {
      _reportedPrimitives.add(_primitiveKey(error));
    }
  }

  static String _primitiveKey(Object error) => '${error.runtimeType}|$error';

  static String _nameOf(ProviderBase<Object?> provider) {
    final base = provider.name ?? provider.runtimeType.toString();
    final argument = provider.argument;
    return argument == null ? base : '$base($argument)';
  }
}

final class _PendingRetry {
  const _PendingRetry({
    required this.error,
    required this.attempt,
    required this.delay,
  });

  final Object error;
  final int attempt;
  final Duration delay;
}
