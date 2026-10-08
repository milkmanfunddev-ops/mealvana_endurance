# Report source guard: allow-list

Read by `report_source_guard_test.dart` (rules in `source_guard.dart`). One
entry per line, counted: a file with three identical unreported catch lines
needs three entries. Line format:

    <kind> <path> :: <signature> :: <reason>

`<kind>` is `unreportedCatch`, `printInCatch` or `sentryImport`; `<signature>`
is the trimmed source line holding the `catch` / bare `on` keyword (or the
import). Lines starting with `>` are notes.

> The `baseline` section (every violation on the day the guard landed,
> 2026-10-06, 549 lines) was emptied by the migration tickets and deleted with
> ticket 10. Only reasoned entries remain; the test fails on a stale one.
>
> `reasoned` holds sites that stay silent on purpose, each with a one-line
> reason. Adding one is a review decision, not a shortcut.

## reasoned

unreportedCatch lib/shared/services/sentry/sentry_provider_observer.dart :: } on ArgumentError {  :: Expando refuses primitive keys; the catch is the type test, the primitive goes to its own set
unreportedCatch lib/shared/services/sentry/sentry_provider_observer.dart :: } on ArgumentError {  :: same as above, the mark side of the pair
unreportedCatch lib/shared/services/sentry/sentry_provider_observer.dart :: } on StateError { :: the catch IS the test: reading from a disposed container throws, and Riverpod keeps `ProviderContainer.disposed` internal (ticket 18)
unreportedCatch lib/shared/services/launch_trail.dart :: } catch (_) { :: LaunchTrail is the tape the D9 trail is written to; a recorder that reports into what it records recurses. Lee ruled it stays as is (ticket 05): begin() falls back to memory-only
unreportedCatch lib/shared/services/launch_trail.dart :: } catch (_) { :: same ruling, the native-key re-read: best effort, memory-only on failure
unreportedCatch lib/shared/services/launch_trail.dart :: } catch (_) { :: same ruling, the prefs persist step: the tape stays in memory for this launch
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) { :: `_captureFailed`: the SDK failed twice (capture, then breadcrumb); the debug log already holds it and there is nothing left to write to
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) { :: `_toSentryLog`: structured logs are narrative; a lost log line is not worth a Fault, and raising one from inside Report would recurse
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) { :: `_mirror` debug-log sink: the dev debug screen's log is a convenience; Report must not call itself from its own sink
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) { :: `_mirror` console sink: best effort; Report must not call itself from its own sink
unreportedCatch lib/shared/services/report/report.dart :: } catch (analyticsError) { :: Mixpanel fan-out failed after the Sentry event already left; mirrored to console and the debug log, and a Fault here would fan out again
unreportedCatch lib/shared/services/report/report.dart :: } catch (sdkError) { :: `fault`/`degraded`: Sentry capture threw; `_captureFailed` keeps it on the debug log and as a breadcrumb. The reporter must never take the app down
unreportedCatch lib/shared/services/report/report.dart :: } catch (sdkError) { :: `note` promotion: same as above, the captureMessage side
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on IntegrationApiException catch (e) {  :: delegates to handleApiException, which classifies every status through Report (403 degraded, 404 note, else degraded); the guard only sees the block text
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on IntegrationApiException catch (e) {  :: same as above (feedback push)
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on IntegrationApiException catch (e) {  :: same as above (plan removal)
unreportedCatch lib/features/integrations/data/vdot_api_client.dart :: } catch (_) {  :: the body is read as JSON only to pick out an error message; a non-JSON body (HTML error page) is an expected input and the raw text is the fallback output
unreportedCatch lib/shared/services/report/metrickit_relay.dart :: } on FormatException { :: the catch IS the parse: an unparseable payload is still forwarded whole under `raw`, so nothing is lost
unreportedCatch lib/shared/services/report/performance_telemetry.dart :: } catch (_) { :: `_startSpan`: span bookkeeping inside the Report layer; a Fault over a lost span would recurse into Report
unreportedCatch lib/shared/services/report/performance_telemetry.dart :: } catch (_) { :: `_finishSpan`: same ruling, the finish side
unreportedCatch lib/features/education/data/education_cache.dart :: } catch (_) { :: an unreadable cached value reads as no cache; the repository has already reported the failed fetch that sent it here, and with no cache Learn shows its offline state (develop-2026-10 ticket 29, item 31)
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksApiException catch (e) { :: a token refresh that failed; `_refreshToken` reported it (degraded) before rethrowing, and this records it on the row as the sync error (develop-2026-10 ticket 29, item 11)
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksApiException catch (e) { :: same as above (second sync entry point)
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksApiException catch (e) { :: same as above (third sync entry point)
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksApiException catch (e) { :: same as above (fourth sync entry point)
unreportedCatch lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart :: } catch (_) { :: pull to refresh awaits the day only to keep the indicator up; the day provider's error is the screen's own error state and is reported there (develop-2026-10 ticket 29, item 30)
unreportedCatch lib/features/settings/presentation/screens/settings_screen.dart :: } on AccountDeletionNeedsConnectionException { :: settings_controller.deleteAccount reports (degraded or fault) before it throws this; the screen only shows the message (develop-2026-10 ticket 29, item 8)
unreportedCatch lib/shared/services/notification_service.dart :: } catch (_) { :: `_trailBail` writes the D9 trail (LaunchTrail line + Sentry breadcrumb); the guard only sees the block text (develop-2026-10 ticket 29, item 16)
unreportedCatch lib/features/auth/domain/pending_signup.dart :: } catch (_) { :: `PendingSignup.fromJson` returns null for a malformed record by contract; `PendingSignupStore.read` reports it as `unreadable` and the launch path clears it with a note (develop-2026-10 ticket 42)
unreportedCatch lib/features/auth/data/pending_signup_store.dart :: } on FormatException { :: `_decode` returns null for bad JSON; `read` reports the record as `unreadable` and the launch path notes and clears it (develop-2026-10 ticket 42)
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) { :: `trackExpectedFailure`: the analytics sink lookup is a convenience; on failure the count is held and reported later through Report itself, which must not call itself from here (develop-2026-10 ticket 41)
unreportedCatch lib/shared/services/sync/sync_coordinator.dart :: } catch (e, stackTrace) { :: `_uploadDirty` returns the error as `failure`; its one caller faults it with the repo key (develop-2026-10 ticket 29, item 13 prerequisite t103)
