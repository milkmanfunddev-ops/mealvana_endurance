# 02: One bootstrap, SDK current

**What to build:** All four entry points call one `bootstrap(flavor)` that initialises Sentry in the documented shape (`appRunner` runs the app; no manual FlutterError or PlatformDispatcher handlers; no zone wrapper), so a crash arrives marked unhandled with the Flutter mechanism. The SDK moves to the latest stable 9.x (`sentry_flutter`, `sentry_drift`, add `sentry_supabase`, plugin to latest 3.x) with Supabase breadcrumbs and trace propagation on. A per-flavor table supplies DSN, environment, traces rate (prod 0.1, dev 1.0), replay (session 0 everywhere; on-error prod cohort only, dev 0), debug flag; the hardcoded prod DSN fallback is gone and a missing dev DSN disables Sentry locally instead of reporting to prod. Identity is the Supabase user id with a role tag and a device-id tag; no email; replay masks text and images. A `shorebird_patch` tag is read at startup. Web follows the same table. The content preload missing from the prod entry point is restored by construction.

**Blocked by:** 01 Report service exists

**Status:** ready-for-agent

- [ ] `pubspec` resolves the latest stable 9.x SDK packages and `sentry_supabase`; codegen and analyzer clean
- [ ] One `bootstrap(flavor)`; the four `main*` files are thin; `SentryFlutter.init` uses `appRunner`, with no `runZonedGuarded`, `FlutterError.onError` or `PlatformDispatcher.onError` set by app code
- [ ] A forced crash in a dev build shows in the dev project with `handled: false` and mechanism `FlutterError`
- [ ] No prod DSN literal remains in app code; a dev build with no DSN reports nothing and logs a Fault to the console
- [ ] Events carry `user.id` = Supabase user id, tags `role`, `device_id`, `shorebird_patch`; no email anywhere in an event; `sendDefaultPii` false
- [ ] A PostgREST call appears as a breadcrumb and span on a dev event; `sentry-trace` reaches the edge request headers
- [ ] Full suite green
