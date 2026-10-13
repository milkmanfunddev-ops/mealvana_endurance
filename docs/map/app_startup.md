# App startup

domain: 9 Account and app · folder: `lib/features/app_startup/` (7 files, no screens)

What happens between tapping the icon and seeing a screen. An athlete sees only the outcome: the app opens on the
Timeline, or on Welcome, or on a forced-update screen, or on a notification's destination.

Where a launch lands, checked in order: a required update → `/force-upgrade`; a failed database re-sync →
Welcome; a sign-up left on "Verify your email" → that screen; no profile or not onboarded or signed out → Welcome;
a strict-region athlete with no consent answer → the privacy screen; otherwise the Timeline. No sync runs at
launch; the Timeline's own refresh rules apply (`activities.md`, "When they refresh").

Startup order: region lookup in parallel; an abandoned password-reset session is signed out; any pending sign-up
is read; version and schema check (a schema re-sync deletes the local database, deferred while an anonymous
athlete has unsent data); database, Sentry user and region in parallel; then the deferred chain, each step on its
own: launch trail, notifications first (so the tap that opened the app is read), device info, analytics
(`app_opened`), user session, coach status, report identity, RevenueCat, app version. A notification tap is held
until the router would land on the Timeline and is dropped if the session changes; it routes to home first and
then pushes the destination so back works; `plan_workout` opens the plan screen pre-filled. The launch trail is a
recorder for cold starts from notifications (long-press the "Connected Apps" title to read it).

Reuse: `application/app_startup_provider.dart` (the launch snapshot, `refreshSession` after sign-in),
`app_startup_service.dart` (the deferred chain), `shared/services/launch_trail.dart`, `shared/widgets/root_app_widget.dart`
(notification tap routing), `shared/services/notification_intent_routes.dart`. Dev only: `scripts/sim-dev-login.sh`
drives the simulator's log-in from a Keychain entry; it is not app code. Gardening: stale comments at
`app_startup_service.dart:260-265,429-430`, `app_startup_provider.dart:306-308`. ops: feature-request
`eng-task-sim-notification-tap-harness`; push relay facts in `ops/docs/messaging-relay-and-testing.md`. Related:
`onboarding.md`, `auth.md`, `settings.md`.
