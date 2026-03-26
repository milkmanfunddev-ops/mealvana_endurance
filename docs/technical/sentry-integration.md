# Sentry Integration Guide (Repo Truth)

## Current State (Repo Truth)
- Sentry is initialized at app entrypoints and used through provider-backed dependencies.
- Feature code accesses reporting through injected external deps (`appExternalDepsProvider`).
- The current integration pattern is `SentryReporter`-based, not a monolithic legacy service.

## Source of Truth
- Reporter interface/implementation: `lib/shared/services/sentry/sentry_reporter.dart`
- External dependency wiring: `lib/shared/services/app_external_deps.dart`
- App entrypoints:
  - `lib/main.dart`
  - `lib/main_web.dart`

## Runbook / Commands
- Find Sentry usage in app code:
```bash
rg -n "Sentry|sentry|SentryReporter|appExternalDepsProvider" lib -S
```
- Validate web entrypoint Sentry wiring:
```bash
rg -n "SentryFlutter\.init|SentryWidget|sentryNavigatorKey" lib/main_web.dart
```

## Verification Checklist
- New error reporting calls use injected `SentryReporter` from external deps.
- App entrypoints initialize Sentry before major app logic.
- Sensitive data filtering remains in Sentry options/hooks where applicable.

## Related Docs
- `/docs/technical/README.md`
- `/docs/deployment/README.md`

## Deprecated/Legacy Notes
- Legacy `SentryService` examples may exist in historical docs; prefer current `SentryReporter` pattern.
