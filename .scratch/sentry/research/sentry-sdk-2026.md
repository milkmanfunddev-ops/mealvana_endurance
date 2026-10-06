# Sentry SDK research, 2026-10-05

Primary sources only (pub.dev, docs.sentry.io, getsentry GitHub, supabase.com, docs.shorebird.dev, registry.npmjs.org). Where a docs page did not state something, the row says so.

## Version table

| Package | Pinned (`pubspec.yaml`) | Resolved (`pubspec.lock`) | Latest stable | Latest prerelease |
|---|---|---|---|---|
| sentry_flutter | ^9.6.0 | 9.6.0 | **9.30.1** (~2026-09-22) | 10.0.0-rc.2 (~2026-10-02) |
| sentry (transitive) | – | 9.6.0 | 9.30.1 | 10.0.0-rc.2 |
| sentry_drift | ^9.6.0 | 9.6.0 | 9.30.1 | 10.0.0-rc.2 |
| sentry_dart_plugin (dev) | ^3.1.1 | 3.1.1 | **3.4.0** (~2026-06) | 3.2.0-beta.1 (older) |
| sentry_dio | not used | – | 9.30.1 | 10.0.0-rc.2 |
| sentry_logging | not used | – | 9.30.1 | 10.0.0-rc.2 |
| sentry_supabase | not used | – | 9.30.1 (exists) | 10.0.0-rc.2 |
| sentry_file | not used | – | 9.30.1 | 10.0.0-rc.2 |
| sentry_hive / sentry_isar | not used | – | 9.30.1 | 10.0.0-rc.2 |
| @sentry/deno (npm) | esm.sh `@sentry/deno@8.53.0` in `supabase/functions/_shared/sentry.ts` | – | **11.4.0** (2026-10-02); dist-tags v8 8.55.2, v9 9.47.2, v10 10.76.0 | 11.0.0-rc.1 (`next`) |

All 9.x packages share one version line; 10.0.0-rc.x requires Dart >= 3.12 / Flutter >= 3.44.

Sources: https://pub.dev/packages/sentry_flutter/versions · https://pub.dev/packages/sentry_drift/versions · https://pub.dev/packages/sentry_dart_plugin/versions · https://pub.dev/packages/sentry_supabase/versions · https://pub.dev/packages/sentry_dio/versions · https://pub.dev/packages/sentry_logging/versions · https://pub.dev/packages/sentry_file/versions · https://pub.dev/packages/sentry_hive/versions · https://pub.dev/packages/sentry_isar/versions · https://registry.npmjs.org/@sentry/deno

## 1. 9.6.0 → 9.30.1: what changed, and the 10.0 line

No breaking changes inside 9.x (same major). Notable additions after 9.6.0, from the changelog:

- 9.7.0+: Supabase trace propagation (`propagateTraceparent`, see §2).
- 9.11.0: Metrics (`Sentry.metrics.*`).
- 9.19.0: span-first trace lifecycle (`options.traceLifecycle = SentryTraceLifecycle.stream`, `Sentry.startSpan`); `enableNewTraceOnNavigation` became opt-in (default flipped true → false, the only default change flagged as breaking in 9.x).
- 9.20.0: `strictTraceContinuation` + `orgId` (cross-org trace guard).
- 9.21.0: `SentryFeedbackWidget` deprecated, renamed `SentryFeedbackForm`.
- 9.23.0: span streaming non-experimental; gRPC integration (`sentry_grpc`).
- 9.26.0: `enableStandaloneAppStartTracing` (experimental).
- 9.27.0: replay network breadcrumbs capture headers/body behind `networkDetailAllowUrls`/`networkDetailDenyUrls`.
- 9.28.0: `enableLogs`/`enableMetrics` now only gate *automatic* collection; manual `Sentry.logger` calls always send. Docs say logs are "enabled by default in 9.28.0+".
- 9.30.x: Android native/GPU memory leak fix, replay config restore.

sentry_dart_plugin 3.1.1 → 3.4.0: 3.2.0 adds Dart symbol-map upload for obfuscated builds (`dart_symbol_map_path`, needs `--extra-gen-snapshot-options=--save-obfuscation-map=<path>`); 3.3.0 adds `ignore_web_source_paths`, flavored Apple dSYM discovery, `SENTRY_URL` for symbol maps; 3.4.0 bumps sentry-cli to 2.58.6 and fixes stale debug-ID markers. No Shorebird entries.

**10.0.0 (rc.2, not yet stable)** breaking list, from the pub.dev changelog and the migration page:
- Dart >= 3.12, Flutter >= 3.44; Android minSdk 21 → **26**; **CocoaPods removed, SwiftPM required** on Apple.
- `enableLogs`, `enableMetrics` removed (always on). `enableStandaloneAppStartTracing` removed (always standalone). `enableTracing`, `autoAppStart`/`setAppStartEnd`, `attachScreenshotOnlyWhenResumed`, `SentryUser.segment`, legacy user-feedback API, `SentryFeedbackWidget`, SDK profiling, `copyWith`/`clone`, `options.log` all removed.
- `traceLifecycle` defaults to `stream` (spans sent as they finish, not as transactions).
- `beforeScreenshot` → `beforeCaptureScreenshot`; `LoadImagesListIntegration` → `LoadNativeDebugImagesIntegration`; `beforeSendTransaction`/log/metric/span callbacks gain a `Hint` parameter.
- Native failed-request capture becomes opt-in; error sampling runs after `beforeSend`; response bodies no longer attached to events (read `hint.response`); screenshots masked by default; `dart:html` → `package:web`; debug log level defaults to `warning`.
- New: manual replay controls `SentryFlutter.replay.start/startBuffering/pause/resume/stop/flush`; `SensitiveContent` masked by default; sampled-out errors count in release health.

Implication for this repo: 9.6.0 → 9.30.1 is a drop-in bump. 10.x is blocked until the app is on Flutter 3.44 / Dart 3.12, minSdk 26, and SwiftPM (the Android AGP-9 memory note says Flutter >= 3.44 needs newDsl=false; check before moving).

Sources: https://github.com/getsentry/sentry-dart/blob/main/CHANGELOG.md · https://pub.dev/packages/sentry_flutter/versions/10.0.0-rc.2/changelog · https://docs.sentry.io/platforms/dart/guides/flutter/migration/ · https://github.com/getsentry/sentry-dart-plugin/blob/main/CHANGELOG.md

## 2. Flutter SDK features (9.30.1 names; 10.x deltas noted)

Defaults below come from `packages/dart/lib/src/sentry_options.dart` and `packages/flutter/lib/src/sentry_flutter_options.dart` on `main`.

| Feature | Option / API | Setup needed |
|---|---|---|
| Session Replay | `options.replay.sessionSampleRate`, `options.replay.onErrorSampleRate` (both default 0); masking via `options.privacy.maskAllText/maskAllImages/maskAssetImages` (default true), `privacy.mask<T>()`, `unmask<T>()`, `maskCallback<T>()` | Yes. Non-zero rates **and** root wrapped in `SentryWidget`. **iOS and Android only; no Flutter Web.** Third-party widgets need manual mask rules. |
| Profiling | `options.profilesSampleRate` (default null) | Yes, and `tracesSampleRate` must be set. **iOS/macOS only, alpha.** 10.x removes SDK profiling. |
| Screenshots on error | `options.attachScreenshot` (false), `beforeCaptureScreenshot`, `screenshotQuality` (high); masked by `options.privacy` | Yes; needs `SentryWidget`. Debounced to once per 2 s. Best-effort (needs UI thread). |
| View hierarchy | `options.attachViewHierarchy` (false), `beforeCaptureViewHierarchy` | Yes. Attachments tab; 2 s debounce. |
| Structured logs | `Sentry.logger.trace/debug/info/warning/error/fatal`, `Sentry.logger.fmt`, `Sentry.setAttributes()`, `options.beforeSendLog` | 9.28+: manual calls always send; `options.enableLogs` (source default false) gates automatic capture only. 10.x removes the flag. `print()` capture is not documented. |
| Metrics | `Sentry.metrics.count/gauge/distribution`, `options.enableMetrics` (true), `beforeSendMetric` | Available 9.11+. 2 KB per metric. |
| User feedback | `Sentry.captureFeedback(SentryFeedback(message:, contactEmail:, name:, associatedEventId:))`; widget `SentryFeedbackForm` (9.21+; `SentryFeedbackWidget` deprecated, gone in 10); `SentryFeedbackOptions` for labels/required fields; `SentryFlutter.captureScreenshot()` | Yes. Show-on-error pattern: `beforeSend` + `options.navigatorKey`. Opening the form buffers up to 30 s replay. |
| Navigation breadcrumbs / transactions | `SentryNavigatorObserver` (go_router: pass in `observers:`; route name = `path` unless `name:` set); options `autoFinishAfter`, `enableAutoTransactions`, `ignoreRoutes`, `setRouteNameAsTransaction` | Yes. Unnamed routes produce no transactions. |
| TTID / TTFD | TTID automatic once observer is set. TTFD: `options.enableTimeToFullDisplayTracing = true` (default false) + `SentryDisplayWidget(child:)` or `SentryFlutter.currentDisplay().reportFullyDisplayed()` | Yes for TTFD. Manual TTID API removed in 10. |
| Asset loading | `DefaultAssetBundle(bundle: SentryAssetBundle(), child: ...)`; `enableStructuredDataTracing` (true) | Yes. Spans only inside an active transaction. |
| HTTP | `SentryHttpClient()`; `options.captureFailedRequests` (true), `failedRequestStatusCodes` (500-599), `failedRequestTargets` (`['.*']`), `maxRequestBodySize` (never) | Yes, Dart does not intercept HTTP globally. Already passed to `Supabase.initialize(httpClient:)` in `lib/main_*.dart`. |
| Drift | `sentry_drift`: `SentryQueryInterceptor(databaseName:)` via `executor.interceptWith(...)` or `runWithInterceptor` | Yes. Spans only attach to an active span (hence the diagnostic spam you silenced with `diagnosticLevel = error`). |
| Supabase | Two layers: (a) `sentry_supabase`: `Supabase.initialize(httpClient: SentrySupabaseClient())` gives breadcrumbs, spans, errors per PostgREST call; (b) 9.7+ `options.propagateTraceparent = true` + `SentryHttpClient` stamps W3C `traceparent` onto Supabase API-gateway and edge-function logs | Yes. (a) and (b) are separate; the docs integration page documents (b), the package README documents (a). |
| Isolates | Main isolate errors captured automatically (non-web). Own isolates: `isolate.addSentryErrorListener()` or `SentryIsolate.spawn` | Manual for spawned isolates. `attachThreads` (false) only attaches the current isolate. |
| beforeSend / beforeBreadcrumb / beforeSendTransaction | `options.beforeSend = (event, hint) => event or null`; `beforeBreadcrumb`; `beforeSendTransaction(transaction, hint)` | Optional. |
| ignoreErrors | `options.ignoreErrors` (List<String>, default `[]`), regex/substring like `ignoreTransactions` | Optional. |
| Exception type identification | `options.enableExceptionTypeIdentification` (true), `exceptionTypeIdentifiers` | On by default; keeps types readable in obfuscated builds. |
| attachThreads | `options.attachThreads` (false), io only | Optional. |
| ANR / app hangs | `anrEnabled` (true, Android, `anrTimeoutInterval` 5 s); `enableAppHangTracking` (true, iOS/macOS) | On. |
| Native breadcrumbs | `enableAutoNativeBreadcrumbs` (true), `enableUserInteractionBreadcrumbs` (true) | On. |
| release / dist | `options.release` (default `package@version+build`), `options.dist` | Set explicitly to match the plugin upload (already done in `main_*.dart`). |
| Spotlight | `options.spotlight = Spotlight(enabled: true)` (default disabled) | Dev-only local sidecar; no Flutter docs page exists, field is in source. |
| Level on captures | `Sentry.captureMessage('..', level: SentryLevel.warning)`; `SentryLevel.{fatal,error,warning,info,debug}`; `scope.level` inside `withScope` | – |
| captureMessage | `await Sentry.captureMessage(String, {level, template, params, hint, withScope})` | – |
| Sessions | `enableAutoSessionTracking` (true), `sessionTrackingIntervalMillis` 30 000 | On. Web needs `SentryNavigatorObserver` with named routes. |
| App start | automatic; `enableStandaloneAppStartTracing` (false, experimental; always-on in 10) | – |
| Frames | `enableFramesTracking` (true) | – |

Sources: https://docs.sentry.io/platforms/dart/guides/flutter/configuration/options/ · https://docs.sentry.io/platforms/dart/guides/flutter/session-replay/ · …/session-replay/privacy/ · …/profiling/ · …/enriching-events/screenshots/ · …/enriching-events/viewhierarchy/ · …/logs/ · …/metrics/ · …/user-feedback/ · …/integrations/routing-instrumentation/ · …/integrations/ · …/integrations/supabase/ · …/integrations/drift-instrumentation/ · …/integrations/http-integration/ · …/integrations/asset-bundle-instrumentation/ · …/configuration/filtering/ · https://pub.dev/packages/sentry_supabase · https://github.com/getsentry/sentry-dart/blob/main/packages/dart/README.md · https://github.com/getsentry/sentry-dart/blob/main/packages/dart/lib/src/sentry_options.dart · https://github.com/getsentry/sentry-dart/blob/main/packages/flutter/lib/src/sentry_flutter_options.dart

## 3. Error-capture best practices

**Init shape.** The documented form is `await SentryFlutter.init((options) {...}, appRunner: () => runApp(SentryWidget(child: MyApp())))`. The SDK installs `FlutterErrorIntegration` (wraps `FlutterError.onError`, mechanism `FlutterError`, `handled: false`, level `fatal` when `markAutomaticallyCollectedErrorsAsFatal`, default true; keeps calling your previous handler) and `OnErrorIntegration` (wraps `PlatformDispatcher.onError`, mechanism `PlatformDispatcher.onError`, level fatal, calls the original first and keeps its `handled` result). `appRunner` is also run inside the SDK's `RunZonedGuardedIntegration`. The README: "The SDK already runs your `callback` on an error handler … so that errors are automatically captured"; the outer `runZonedGuarded` form is documented for Flutter < 3.3 or if you want your own zone.

What this means for `lib/main_*.dart`: the current code wraps `SentryFlutter.init` in `runZonedGuarded`, calls `runApp` outside `appRunner`, and then reassigns `FlutterError.onError` and `PlatformDispatcher.instance.onError` to call `Sentry.captureException`. That replaces the SDK's wrappers, so those events arrive as `handled: true`, level `error`, without the `FlutterError` mechanism or `flutter_error_details` context, and `presentError` is called twice if the SDK's chain still runs. Moving `runApp` into `appRunner` and deleting both manual handlers gives the documented behaviour. `reportSilentFlutterErrors` (false) controls `FlutterErrorDetails.silent`.

**Handled exceptions.** `await Sentry.captureException(e, stackTrace: s, hint: Hint.withMap({...}), withScope: (scope) { scope.level = SentryLevel.warning; scope.setTag('feature', 'kroger'); scope.setContexts('order', {...}); scope.fingerprint = ['kroger-timeout']; })`. `withScope` clones the scope for that one event; `Sentry.configureScope((scope) => scope.setUser(SentryUser(id: ...)))` persists until changed (`setUser(null)` at logout). `scope.setTag` is `Future<void>`, await it.

**Fingerprinting.** `event.fingerprint = ['{{ default }}', ...]` in `beforeSend`, or `scope.fingerprint` in `withScope`; omitting `{{ default }}` replaces Sentry's grouping entirely. Server-side fingerprint rules are an alternative (§5).

**Tags vs contexts vs extra.** Tags: indexed and searchable, 200-char key/value. Contexts (`scope.setContexts(name, map)`): structured, visible on the issue, not searchable. `setExtra` is deprecated in favour of contexts.

**Environment / debug.** `options.environment` is a free string; dev/prod filter in the UI (§5). `options.debug` (default false; the docs page says true in debug builds) with `options.diagnosticLevel` (default `SentryLevel.warning`).

**Sampling.** `sampleRate` (errors, default 1.0) vs `tracesSampleRate` (transactions, default null = tracing off) vs `tracesSampler(samplingContext)` returning 0..1, honour `samplingContext.transactionContext.parentSampled` to keep distributed traces whole. `profilesSampleRate` is relative to sampled transactions.

**In-app frames.** `considerInAppFramesByDefault` (true); `options.addInAppInclude('mealvana_endurance')` / `addInAppExclude` to pin the app's package when `--obfuscate` blurs it. `enableDartSymbolication` (true) requires uploaded symbols for `--split-debug-info` builds.

**Shorebird.** Shorebird's page: Sentry "works out of the box" with releases and patches; the one addition is tagging the patch: `final patch = await ShorebirdUpdater().readCurrentPatch();` then in `appRunner`, `Sentry.configureScope((s) => s.setTag('shorebird_patch_number', '${patch?.number}'))`. Symbol uploads: run `sentry_dart_plugin` after `shorebird patch` as after `shorebird release`; the page does not say to change `release`/`dist` per patch. Note: `release`/`dist` must equal what the plugin uploaded or symbolication silently fails; a patch that changes Dart code but keeps the same `release`/`dist` means the patch's symbols overwrite or sit beside the base release's. Sentry's own docs have no Shorebird page; its CodePush guidance (React Native) is to make `dist` encode the patch, which is the pattern to copy if patched stack traces stop symbolicating.

Sources: https://docs.sentry.io/platforms/dart/guides/flutter/manual-setup/ · https://docs.sentry.io/platforms/dart/guides/flutter/usage/ · …/enriching-events/scopes/ · …/enriching-events/tags/ · …/enriching-events/context/ · …/usage/sdk-fingerprinting/ · …/configuration/sampling/ · https://github.com/getsentry/sentry-dart/blob/main/packages/flutter/lib/src/integrations/flutter_error_integration.dart · …/on_error_integration.dart · https://github.com/getsentry/sentry-dart/blob/main/packages/flutter/README.md · https://docs.shorebird.dev/code-push/crash-reporting/sentry/ · https://docs.sentry.io/platforms/react-native/sourcemaps/uploading/codepush/

## 4. Deno / Supabase Edge Functions

**Current state in repo:** `supabase/functions/_shared/sentry.ts` imports `https://esm.sh/@sentry/deno@8.53.0`, inits once per cold start from `SENTRY_DSN` / `SENTRY_ENVIRONMENT` / `SENTRY_RELEASE` with `tracesSampleRate: 0.1`, wraps handlers in `withSentry`, and awaits `Sentry.flush(2000)`. Used by `ai-coach`, `garmin-push`, `generate-macros-v4`, `send-nutrition-plan-email`, `lookup-product`.

**Recommended today (Supabase docs):**

```ts
import * as Sentry from 'npm:@sentry/deno@^8'
Sentry.init({
  dsn: Deno.env.get('SENTRY_DSN'),
  defaultIntegrations: false,
  tracesSampleRate: 1.0,
  profilesSampleRate: 1.0,
})
Sentry.setTag('region', Deno.env.get('SB_REGION'))
Sentry.setTag('execution_id', Deno.env.get('SB_EXECUTION_ID'))
// in handler:
try { ... } catch (e) {
  Sentry.captureException(e)
  await Sentry.flush(2000)
  return Response.json({ error: 'Internal Server Error' }, { status: 500 })
}
```

Points from the docs: use the `npm:` specifier (Supabase's runtime supports npm natively; Sentry's Deno guide lists only `npm:@sentry/deno`, with `deno.json` `"imports": {"@sentry/deno": "npm:@sentry/deno"}, "nodeModulesDir": "auto"` and `import "@sentry/deno/import"` first for the import hook, which needs `--allow-env`). `environment` defaults to `production`; `SENTRY_ENVIRONMENT`, `SENTRY_RELEASE`, `SENTRY_TRACES_SAMPLE_RATE` env vars are honoured. `Sentry.captureException(err)`, `Sentry.captureMessage(msg, level)`, `Sentry.withScope(scope => {...})` and `Sentry.withIsolationScope(() => {...})` all exist; wrap each request in `withIsolationScope` because "there is no scope separation between requests" when the isolate is reused.

Limitations: always `await Sentry.flush(ms)` before returning (or hand the flush promise to `EdgeRuntime.waitUntil(promise)`, which keeps the instance alive until it settles, bounded by wall-clock/CPU/memory limits). Sessions: v10 "disabled them unconditionally" for Deno servers; v11's `denoHttpIntegration` creates sessions for `node:http` servers (opt out with `sessions: false`); nothing says Supabase's `Deno.serve` path gets them, so treat release health as unavailable for edge functions. `tracesSampleRate` works (`Sentry.startSpan`).

Version to pin: `@sentry/deno` latest is 11.4.0, but v11 requires **Deno >= 2.8.3** while Supabase's hosted runtime is the "Deno 2.1 compatible release" (all regions since 2025-08-15, with a 1.45 fallback). Stay on the Supabase-documented `^8` (8.55.2) or test `^10` (10.76.0) locally; move to 11 only when Supabase announces a newer Deno. Migrating the existing esm.sh import to `npm:@sentry/deno@^8` is the one change that follows the docs.

Crons: `Sentry.captureCheckIn({monitorSlug, status: 'in_progress'})` → returns `checkInId`; finish with `{checkInId, monitorSlug, status: 'ok' | 'error'}`; or `Sentry.withMonitor(slug, fn, {schedule: {type: 'crontab', value: '0 * * * *'}, checkinMargin, maxRuntime, timezone})`, which upserts the monitor. Good fit for pg_cron-triggered edge functions.

Sources: https://supabase.com/docs/guides/functions/examples/sentry-monitoring · https://supabase.com/docs/guides/functions/background-tasks · https://supabase.com/changelog/37941-all-regions-now-run-deno-2-1-compatible-release · https://docs.sentry.io/platforms/javascript/guides/deno/ · …/deno/configuration/options/ · …/deno/configuration/apis/ · …/deno/enriching-events/scopes/ · …/deno/crons/ · https://github.com/getsentry/sentry-javascript/blob/develop/MIGRATION.md · https://registry.npmjs.org/@sentry/deno

## 5. Platform features to check in milkman-24.sentry.io

- **Issue alerts**: rules on "new issue / regression / escalating / frequency", actions email, Slack, webhook, Jira. Monitors > Alerts > Create. Default "notify on new issue" rule is per-project; check it exists for both environments.
- **Metric alerts (Monitors)**: fixed or anomaly thresholds on errors, spans, logs, releases (crash rate), application metrics. Create from Monitors page or "Create Monitor" on an Errors/Metrics view.
- **Slack**: Settings > Integrations > Slack > Add Workspace; then pick channel in alert actions; resolve/assign from Slack. Plan availability not stated on the page.
- **Releases + health**: `enableAutoSessionTracking` (true) sends sessions; crash-free sessions vs crash-free users shown on Releases; crash-rate monitors available. Release name must match SDK `release`.
- **Dashboards**: prebuilt frontend/backend/mobile/AI; custom ones by duplicate, AI-generate, or blank. Plan gating not stated.
- **Issue grouping**: Project Settings > Issue Grouping: fingerprint rules (`type:ConnectTimeout -> connect-timeout`) and stack-trace rules (ignore frames); apply to future events only; "merge" for existing issues.
- **Ownership rules**: Project Settings > Ownership Rules; `path:lib/features/kroger/* #team`, `url:`, `tags.x:`; auto-assign by suspect commit or rule; CODEOWNERS import is Business+.
- **Environments**: set by SDK; filter top-right; hide unused in Project Settings > Environments (hidden ones still count against quota).
- **Spike protection**: per-project toggle, Settings > Spike Protection (Manager/Billing/Owner); covers errors, transactions/spans, attachments; dynamic hourly rate limit.
- **Quotas**: Settings > Subscription; categories errors, spans, replays, attachments, logs, profiles, metrics, cron and uptime monitors; reserved + pay-as-you-go; per-project error rate limits under SDK Setup > Client Keys.
- **Tracing**: on once `tracesSampleRate` set (10 % prod today); Supabase `propagateTraceparent` links client spans to edge logs.
- **Replays quota**: separate category; rates in SDK (`replay.*`) decide volume; mobile only.
- **Seer**: Org Settings > "Show Generative AI Features", then per-project toggles; needs GitHub integration for autofix/PRs; billed per "active contributor" (2+ PRs/month in a Seer-enabled repo).
- **Uptime monitoring**: Monitors > Create; 1 min to 1 h intervals; 3 consecutive failures opens an issue; request spans are free.
- **Cron monitors**: see §4 `captureCheckIn`/`withMonitor`; alerts when a check-in is missed or errors; separate quota.
- **Data scrubbing / PII**: SDK `sendDefaultPii` (false) and `beforeSend` first; server: Settings > Security & Privacy for default scrubbers, Advanced Data Scrubbing rules, "Prevent Storing of IP Addresses".
- **Inbound filters**: Project Settings > Inbound Filters: localhost, legacy browsers, crawlers, extensions, error messages, releases, IPs, health checks; filtered events do not consume quota.
- **Source maps (web)**: `flutter build web --source-maps`, then `dart run sentry_dart_plugin` with `upload_source_maps: true` (already in pubspec), `upload_sources` optional; `SENTRY_RELEASE` via `--dart-define` so runtime release matches.
- **dSYM (iOS) / ProGuard (Android)**: `upload_debug_symbols: true` (set) makes the plugin upload dSYMs, Android `.so` symbols and `--split-debug-info` output; R8 mapping needs `proguardUuid` or the Android gradle plugin; obfuscated Dart titles need 3.2.0+ `dart_symbol_map_path` with `--save-obfuscation-map`. Env: `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_RELEASE`, `SENTRY_DIST`.

Sources: https://docs.sentry.io/product/alerts/ · https://docs.sentry.io/product/alerts/create-alerts/metric-alert-config/ · https://docs.sentry.io/organization/integrations/notification-incidents/slack/ · https://docs.sentry.io/product/releases/health/ · https://docs.sentry.io/platforms/dart/guides/flutter/configuration/releases/ · https://docs.sentry.io/product/dashboards/ · https://docs.sentry.io/product/issues/grouping-and-fingerprints/ · https://docs.sentry.io/product/issues/ownership-rules/ · https://docs.sentry.io/concepts/key-terms/environments/ · https://docs.sentry.io/pricing/quotas/spike-protection/ · https://docs.sentry.io/pricing/quotas/ · https://docs.sentry.io/product/ai-in-sentry/seer/ · https://docs.sentry.io/product/uptime-monitoring/ · https://docs.sentry.io/security-legal-pii/scrubbing/ · https://docs.sentry.io/concepts/data-management/filtering/ · https://docs.sentry.io/platforms/dart/guides/flutter/debug-symbols/dart-plugin/ · https://docs.sentry.io/platforms/dart/guides/flutter/debug-symbols/manual-upload/ · https://github.com/getsentry/sentry-dart-plugin/blob/main/_autodocs/configuration.md

## 6. Mixpanel + Sentry

No official integration in either direction. Sentry's Data Forwarding supports only Segment, Amazon SQS and Splunk (Business/Enterprise); no Mixpanel entry exists on docs.sentry.io, and Mixpanel's docs have no Sentry page. RudderStack's Mixpanel → Sentry combination is marked deprecated. Pattern that stays inside the SDK: in `options.beforeSend`, after the event is accepted, call `mixpanel.track('Error', {sentry_event_id: event.eventId.toString(), type: event.throwable.runtimeType.toString(), release: event.release})` and return the event; conversely put the Mixpanel distinct ID on Sentry via `scope.setUser(SentryUser(id: distinctId))` so the two can be joined by hand. Keep the Mixpanel call gated by the same consent flag the app already uses for replay.

Sources: https://docs.sentry.io/product/data-management-settings/data-forwarding/ · https://www.rudderstack.com/integration/sentry/integrate-mixpanel-with-sentry/ (deprecation notice, third-party)
