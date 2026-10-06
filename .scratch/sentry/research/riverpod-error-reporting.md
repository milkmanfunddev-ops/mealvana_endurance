# Riverpod 3 error reporting: what the docs say, what the code does

Researched 2026-10-05 against riverpod.dev, pub.dev API docs, the pub.dev changelog, and the
riverpod package source. Locked versions in this repo: `riverpod` / `flutter_riverpod` 3.0.1,
`sentry_flutter` 9.6.0. Source citations are from 3.0.1 (checked against 3.3.2; same paths).

## 1. What Riverpod officially recommends

The docs frame `ProviderObserver` as the logging hook: "An object that listens to the changes
of a ProviderContainer. This can be used for logging or making devtools."
([ProviderObserver API](https://pub.dev/documentation/riverpod/latest/riverpod/ProviderObserver-class.html))

3.x signatures (all take a `ProviderObserverContext` carrying `provider`, `container`, and the
pending `mutation`; [context API](https://pub.dev/documentation/riverpod/latest/riverpod/ProviderObserverContext-class.html)):

- `didAddProvider(ProviderObserverContext context, Object? value)`
- `didUpdateProvider(ProviderObserverContext context, Object? previousValue, Object? newValue)`:
  "Called by providers when they emit a notification."
- `providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace)`:
  "A provider emitted an error, be it by throwing during initialization or by having a
  Future/Stream emit an error."
- `didDisposeProvider`, plus `mutationStart/Error/Success/Reset`.

The one piece of explicit error-reporting guidance is the dedupe example in
[What's new in 3.0](https://riverpod.dev/docs/whats_new): skip `ProviderException` inside
`providerDidFail` because "The provider didn't fail directly, but instead depends on a failed
provider. The error was therefore already logged."

**Does `providerDidFail` fire when `AsyncValue.guard` sets `state = AsyncError`?** Yes. The docs
don't spell this out, so I traced it in source:

- `state = x` in a notifier calls `ref._element.setValueFromState(newState)`
  (`lib/src/core/provider/notifier_provider.dart:89-94`). For async providers that is
  `value = state`, which routes through `setValue` → `value.map(loading:, error:, data:)`
  (`element.dart`).
- `onError` then loops `container.observers` and calls `observer.providerDidFail(context,
  value.error, value.stackTrace)` (3.0.1 `element.dart:103-117`), guarded by "if result is not
  already a hard error" so sync providers don't report twice.
- `AsyncValue.guard` is just try/catch returning `AsyncValue.error(err, stack)`
  (`async_value.dart:502-520`). The observer sees the raw error, same as when `build` throws.

So in this codebase the observer covers both the `build` path and every `AsyncValue.guard`
write path, with no extra plumbing. One gap: `Ref.listen(onError:)` is explicitly *not* a
reporting hook: "onError will not be triggered if the provider catches the exception and emit a
valid value out of it. As such, if a FutureProvider/StreamProvider fail, onError will not be
called. Instead the listener will receive an AsyncError." (`ref.dart:748-753`). There is no
`Ref.onError`.

## 2. 3.x features that change error visibility

**Automatic retry.** "Providers that fail during initialization will automatically retry … with
an exponential backoff … until it succeeds or is disposed." Default: "starts with a 200ms delay
that doubles after each retry up to 6.4 seconds", max 10 retries
([whats_new](https://riverpod.dev/docs/whats_new),
[retry concept page](https://riverpod.dev/docs/concepts2/retry),
[`defaultRetry`](https://pub.dev/documentation/riverpod/latest/riverpod/ProviderContainer/defaultRetry.html)).
`defaultRetry` returns null (no retry) for `Error` subclasses and `ProviderException`
(`provider_container.dart:833`). Disable globally with `ProviderScope(retry: (_, __) => null)`
or per provider via `@Riverpod(retry: fn)`.

Does retry spam the observer? No. While retrying, `triggerRetry` emits
`AsyncLoading(..., error: (err, stack, retrying: true))`, not `AsyncError`
(`element.dart:668-680`), and that goes through `onLoading`, which never calls
`providerDidFail`. Only when retries are exhausted or the retry callback returns null does it
emit `AsyncError(..., retrying: false)` and the observer fires once. Consequence for Sentry:
a transient exception in `build` is invisible for up to ~12 s of backoff and never reported if
a retry succeeds. The retry page confirms the future "will keep waiting until either: all
retries are exhausted, or the provider succeeds." Retry applies only to `build`; `guard` in a
method sets `AsyncError` directly and reports immediately.

**`ProviderException` wrapping.** "When a `ref.watch`/`ref.read` rethrows an error, the error is
now wrapped in a `ProviderException`" (changelog 3.0.0-dev.16,
[pub.dev changelog](https://pub.dev/packages/riverpod/changelog)). Fields: `exception` (original)
and `stackTrace` (`stack_trace.dart:40-49`). The docs are explicit that "AsyncValue.error,
ref.listen(..., onError: ...) and ProviderObservers are unaffected by this change, and will
still receive the unaltered error." That holds for the provider that *threw*. A provider that
*depends on* a failed one (via `.future` or `requireValue`) rethrows a `ProviderException` and
fails itself, so its own `providerDidFail` call carries the wrapper. The class doc adds that
Riverpod will "Not report the error to Zone if it is a ProviderException. This avoids reporting
the same error twice." Unwrapping rule for a reporter: if `error is ProviderException`, either
drop it (docs' recommendation) or report `error.exception` with `error.stackTrace` tagged as
downstream.

**`AsyncValue.error` vs `AsyncError`.** Same thing; `AsyncValue.error` is the factory,
`AsyncError` the sealed subclass. `AsyncValue` is sealed in 3.0 for exhaustive matching.

**`isRefreshing` / `isReloading`.** "isRefreshing: Whether the associated provider was forced to
recompute even though none of its dependencies has changed" (`Ref.invalidate`/`refresh`);
"isReloading: … recomputed because of a dependency change (using Ref.watch)"
([AsyncValue API](https://pub.dev/documentation/riverpod/latest/riverpod/AsyncValue-class.html)).
An error during either keeps the previous value: `asyncTransition` calls
`newState.copyWithPrevious(previous, isRefresh: seamless)` (`element.dart:59-69`), and
`value` "If currently in error/loading state, will return the previous value." The observer
still fires for that `AsyncError`; the UI just keeps showing stale data.

## 3. Reporting inside `AsyncValue.guard` callers

Signature: `static Future<AsyncValue<T>> guard<T>(Future<T> Function() future,
[bool Function(Object)? test])`
([guard API](https://pub.dev/documentation/riverpod/latest/riverpod/AsyncValue/guard.html)).
`test` decides what gets *caught*: "An optional callback can be specified to catch errors only
under a certain condition … catch all exceptions beside FormatExceptions." When `test(err)`
is false the error is rethrown with its original trace (`Error.throwWithStackTrace`). It is a
filter, not a reporting hook, and the repo never passes it (108 `guard` calls, all one-arg).

There is no official guidance on "swallowed" errors beyond the observer and the retry page.
Since `guard` output lands in `providerDidFail` anyway, wrapping each call is redundant for
reporting. The remaining blind spots are not guard-related: `try/catch` blocks that return a
fallback value, and errors in plain services with no provider state.

## 4. The existing observer

`lib/shared/services/sentry/sentry_provider_observer.dart` matches the 3.x signature exactly
(`providerDidFail(ProviderObserverContext, Object, StackTrace)`), reads
`context.provider.name`, and is wired as `observers: const [SentryProviderObserver()]` in
`main.dart`, `main_prod.dart`, `main_web.dart`.

Double-reporting with the `FlutterError.onError` / `PlatformDispatcher.onError` /
`runZonedGuarded` handlers in those entrypoints: **no**, for errors Riverpod catches. `build`
throws and `guard` failures become `AsyncError` state and never reach the zone or Flutter's
handler. Two real duplicate paths exist:

1. A downstream provider failing with `ProviderException` after an upstream one already
   reported the raw error. The observer currently reports both as separate Sentry events
   (different `provider` tags, same root cause).
2. An exception thrown *inside* an observer or listener goes to `container._onError`, which
   defaults to `Zone.current.handleUncaughtError` (`provider_container.dart:854`) and therefore
   to `runZonedGuarded`'s Sentry capture. Not a duplicate, just a note that observer bugs
   surface there.

## Recommendation: observer-only, with two edits

Riverpod's documented hook for reporting is `ProviderObserver`, and the source confirms it sees
every `AsyncError`, whether from `build` or from `AsyncValue.guard`. A guard wrapper would add
a second report for the same event and touch 108 call sites for no new coverage. Keep the
observer and:

1. Skip or downgrade `ProviderException` per the docs' example, so dependency cascades don't
   fan out into N Sentry events. If you want the chain visible, report `error.exception` with
   `error.stackTrace` and tag `riverpod.downstream=true`, fingerprinted on the inner error.
2. Decide the retry policy deliberately. Default retry hides transient `build` failures from
   Sentry entirely when a retry succeeds, and delays the first report by up to ~12 s. Either
   accept that (less noise) or, for providers whose first failure you want to see, add a
   breadcrumb via a global `retry` callback on `ProviderScope` that records the attempt and
   returns `defaultRetry(...)`.

Optional: add `context.mutation?.toString()` and `isRefreshing`/`isReloading` (from `newValue`
in `didUpdateProvider`, or pass the `AsyncError` through) as tags so refresh-time errors that
kept stale data are distinguishable from first-load failures.
