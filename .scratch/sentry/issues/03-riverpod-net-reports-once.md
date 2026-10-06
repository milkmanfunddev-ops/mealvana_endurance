# 03: Riverpod net reports once

**What to build:** The provider observer remains the universal net for provider failures, including those `AsyncValue.guard` turns into `AsyncError`. It reports through `Report`, unwraps a `ProviderException` and reports the inner error only if it has not already been reported (tag `wrapped`), dedupes by provider name plus exception type plus message within a session, and a global retry callback on the root scope records a breadcrumb for each retry attempt before delegating to the default policy. No guard wrapper is added anywhere.

**Blocked by:** 01 Report service exists

**Status:** built 2026-10-06

- [x] A provider whose `build` throws produces exactly one Sentry event; a downstream provider that rethrows the `ProviderException` adds none
- [x] A `guard`-caught error in an AsyncNotifier method produces one event with the provider name tag
- [x] A `build` that fails twice then succeeds produces two retry breadcrumbs and no event
- [x] The same failure on rebuild within a session does not produce a second event
- [x] Tests run through a real `ProviderContainer` with the observer attached and the SDK in-memory transport
- [x] No call site of `AsyncValue.guard` changed

## Build notes (2026-10-06)

**Design.** `lib/shared/services/sentry/sentry_provider_observer.dart` no longer imports the
Sentry SDK; it reports through `Report.fault` with tags `component: riverpod_provider`,
`provider: <name>` (plus `(argument)` for families) and `wrapped: true` when a
`ProviderException` was unwrapped. `Report` is injected (`SentryProviderObserver(report: ...)`),
defaulting to `SentryReport.global` resolved at call time so the instance `reportProvider`
builds is picked up once it exists. The bootstrap now builds one observer and wires it twice:
`ProviderScope(observers: [net], retry: net.retry)`.

**ProviderException.** Unwrapped to `error.exception` / `error.stackTrace`. Skipped when that
inner error object was already reported this session (identity, via `Expando`; thrown
primitives fall back to a `type|message` set). Every skip writes a `riverpod.duplicate`
breadcrumb with the reason (rule D9).

**Dedupe key.** `providerName|runtimeType|toString()` of the (unwrapped) error, held in a set on
the observer instance; one instance is one session. A second observer instance reports the
same failure again (tested).

**Retry hook.** Riverpod 3.0.1 (locked) exposes `ProviderScope(retry:)` /
`ProviderContainer(retry:)` typed `Duration? Function(int retryCount, Object error)`; the
`Retry` typedef is `@internal`, so the shape is spelled out locally as `RetryPolicy`. The
callback carries no provider name, so the observer owns it: `retry()` delegates to
`ProviderContainer.defaultRetry` (overridable for tests), parks the approved attempt, and the
observer call that follows synchronously with the identical error object writes the
`riverpod.retry` breadcrumb (`provider`, `attempt`, `error_type`, `delay_ms`). Probe against the
package source showed which call that is: an async provider (`FutureProvider`, `AsyncNotifier`)
surfaces a retrying attempt only via `didUpdateProvider` as `AsyncLoading(error, retrying: true)`
and never calls `providerDidFail` until the retries end; a sync `Provider` calls
`providerDidFail` on every attempt. The research note's claim that retries never reach the
observer is right only for async providers. No event is sent while `retrying` is true; the
one `AsyncError` after exhaustion (or a declined retry) is the event.

**Call sites.** No `AsyncValue.guard` call site changed; no guard wrapper. Diff touches only the
observer, the bootstrap wiring, and the new test file.

**Tests.** `test/shared/services/sentry/sentry_provider_observer_test.dart`, real
`ProviderContainer` + `SentryReport` on the SDK's in-memory transport, 10 tests: build throw =
one event and the downstream `ProviderException` adds none (duplicate breadcrumb instead);
unwrapped wrapper tagged `wrapped`; guard-caught `AsyncNotifier` method error = one event with
the provider tag; async build fails twice then succeeds = two retry breadcrumbs, no event; the
same for a sync `Provider`; exhausted retries = breadcrumbs then one event; same failure on
rebuild = no second event; a different failure on the same provider = its own event; a new
observer = new session; the `SentryReport.global` default. `flutter analyze` clean on the
three files; `flutter test test/shared/services/sentry test/shared/services/report
test/shared/core/bootstrap` = 88 passed.

Test-only note: a retry rebuilds only while something listens, and a sync provider hands each
rebuild failure to the listener's `onError`; the tests hold a `container.listen` the way a
widget's `ref.watch` would.
