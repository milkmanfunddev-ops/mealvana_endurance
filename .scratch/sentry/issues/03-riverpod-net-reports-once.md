# 03: Riverpod net reports once

**What to build:** The provider observer remains the universal net for provider failures, including those `AsyncValue.guard` turns into `AsyncError`. It reports through `Report`, unwraps a `ProviderException` and reports the inner error only if it has not already been reported (tag `wrapped`), dedupes by provider name plus exception type plus message within a session, and a global retry callback on the root scope records a breadcrumb for each retry attempt before delegating to the default policy. No guard wrapper is added anywhere.

**Blocked by:** 01 Report service exists

**Status:** ready-for-agent

- [ ] A provider whose `build` throws produces exactly one Sentry event; a downstream provider that rethrows the `ProviderException` adds none
- [ ] A `guard`-caught error in an AsyncNotifier method produces one event with the provider name tag
- [ ] A `build` that fails twice then succeeds produces two retry breadcrumbs and no event
- [ ] The same failure on rebuild within a session does not produce a second event
- [ ] Tests run through a real `ProviderContainer` with the observer attached and the SDK in-memory transport
- [ ] No call site of `AsyncValue.guard` changed
