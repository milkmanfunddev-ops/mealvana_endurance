# Ticket 10, part C2: auth, integrations, subscription, settings, events

Scope: `lib/features/{auth,integrations,subscription,settings,events}` and
`test/features/{auth,integrations,settings,events,subscription}`.

## Converted

- 19 lib files, about 240 call sites, mapped per the wave 4 brief table.
  - auth (7): `auth_migration_service` (`SentryReporter sentry` became `Report report`;
    33 breadcrumbs, 3 database faults, 2 network degradeds), `auth_service`, `email_auth_service`,
    `oauth_service`, `password_recovery_controller`, `post_onboarding_auth_controller`,
    `post_onboarding_auth_screen`. The `_logger` getters (`appExternalDepsProvider.logger`) became
    `Report get _report => ref.read(reportProvider)`. `state.error` passed to `fault` gets a `!`
    because each one sits under `if (state.hasError)`.
  - integrations (7): `integrations_repository` (logger param dropped; uses its existing
    `Report? report`), `provider_raw_payloads_repository`, `provider_event_import_service`,
    `integrations_providers`, `athlete_zones`, `athlete_zones_provider`,
    `training_peaks_sync_service` (decoder wiring only).
  - settings (2): `settings_controller` (3 local `logger`s), `food_preferences_screen` (2
    `DebugLogger.info`s onto its existing `_report`). `debug_screen.dart` already had no legacy
    references.
  - events (3): `events_repository` (`logger` + `sentry` became `required Report report`),
    `events_service` (positional `AppLogger` dropped; it already had `report:`),
    `active_com_service`.
  - subscription: nothing left to convert.
- 10 test files: the 9 in scope plus `test/new_sync/events_repository_sync_test.dart`, which my
  `EventsRepository` signature change would otherwise have broken. Mocks became `RecordingReport()`,
  and `appLoggerProvider` overrides became `reportProvider` overrides. None of these tests asserted
  on logger or sentry calls, so no assertions changed.

## Changes beyond the mechanical mapping

- `events_repository`: four sites called `logger.warning(e)` and then
  `sentry.reportNetworkError(e)` on the same error. Each pair is now a single `degraded`
  (area `EVENTS_REPOSITORY`, the network method as a tag, the url folded into `extra`).
  `Report` dedupes by error identity, so a second call would have been dropped along with its tags.
- `provider_raw_payloads_repository`: its provider never passed a logger, so the
  `NoopAppLogger` default made a failed capture silent in prod (D9). The provider now passes
  `report:`, and the failure is a `degraded` that carries the caught error and stack.
- `integrations_providers`: dropped a `ref.watch(appExternalDepsProvider)` that only fed the logger.

## Identity calls deleted

None. No `setUserContext` or `clearUserContext` calls were in scope.

## Domain decoders moved

- `lib/features/integrations/domain/athlete_zones.dart`: `fromJsonString` takes
  `DecodeIssue onIssue = ignoreDecodeIssue`, and the Report import is gone. The string length that
  used to go in `extra` now goes in the message. Both callers pass
  `report.decodeIssue('training_peaks')`: `training_peaks_sync_service` (via `_r`) and
  `athlete_zones_provider` (via `ref.read(reportProvider)`).

## Left over

- The requested grep still matches `AppExternalDeps(` constructions and `mockAppExternalDeps()`
  helper calls in `test/features/{auth,settings,events,integrations}`. None of them pass
  `sentry:` or `logger:`. They match because the class name is in the pattern.
- `test/features/integrations/connect_identity_seam_test.dart` and
  `disconnect_soft_hide_state_machine_test.dart` still build `ActivitiesRepository(logger:, sentry:)`
  and `ActivityDeduplicationService(logger:)`. Those constructors belong to the activities part. Fix
  these lines when that part removes the params.
- Two warnings in changed test files were there before this part and are unrelated:
  `anonymous_account_upgrade_test.dart:217` (override_on_non_overriding_member) and
  `connect_identity_seam_test.dart:215` (unused local).
- Verification: `dart analyze` shows no errors in any changed file and no new warnings. No
  `flutter test`, per the brief.
