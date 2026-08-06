# Activity-upload push: copy rework + click-through instrumentation

Branch: `copy/garmin-activity-push-accuracy-hook`
Notion: Sprint Tasks — "Rework the Garmin-connect notification copy with AI"

## ⚠️ Release checklist — merging is not enough

Nothing in CI deploys edge functions (see the note under "Two deployables").
Merging this branch ships the **app** half only; the notification keeps its old
wording until someone runs the deploy by hand.

- [ ] `supabase secrets set MIXPANEL_PROJECT_TOKEN=<token> --project-ref <prod-ref>`
      — one-time; without it the click-through denominator records nothing
- [ ] `./scripts/deploy_prod.sh garmin-push garmin-ping`
      — **both**; `_shared/garmin/onesignal.ts` changed and each imports it
- [ ] App build carrying the client half (`copy_variant` on the click event)

Deploy the functions close to the app release. Ship the server well ahead and
athletes get the new copy while their old app reports clicks with no variant —
sent events tagged `accuracy_hook_v2`, clicks untagged. Total click-through
still computes; the per-variant split has a blind window until the app lands.

Verify after: `./scripts/edge_logs.sh -m 5 garmin-push` should show
`OneSignal notification sent … (recipients=N)` with N ≥ 1. A `recipients=0`
line means the send reached no device.

## What changed

The push an athlete gets when a Garmin activity syncs.

| | Before | After |
|---|---|---|
| Heading | `Workout uploaded` | `Your targets just updated` |
| Body | `A workout for 08/05/2026 was uploaded from Garmin Connect.` | `Your Garmin Forerunner 955 workout is in. We recalculated your fuel plan for 08/05 from what you actually burned.` |

Plus a `copy_variant` tag on the push and a new `activity_upload_push_sent`
Mixpanel event, so click-through can be measured as sent → clicked and
segmented by wording instead of inferred from a release date.

Out of scope: the connect-prompt banner on the fuel timeline. The ticket's
"device-agnostic" ask lands there, not on this push — see "Why the Garmin name
stays" below.

## Two deployables, shipped separately

This change spans the server and the app. They are independent and can go out
in either order.

| Deployable | Carries | How it ships |
|---|---|---|
| Edge functions | The copy itself, `copy_variant` in the push payload, `activity_upload_push_sent` | **Manual** — `scripts/deploy_dev.sh` |
| App binary | `copy_variant` on `activity_upload_notification_clicked`, the local-notification mirror | Dev build / TestFlight |

The notification text is composed **server-side**. Garmin POSTs a webhook →
`garmin-push` (on Supabase) builds the heading/body → calls the OneSignal REST
API → OneSignal delivers to the device. The app never composes this text, so a
new app build alone changes nothing about what the notification says.

Deploying the function alone is safe: dev gets the new copy immediately even
against an old app build. Clicks from that old build simply won't carry
`copy_variant`.

> **CI does not deploy edge functions.** `.github/workflows/deploy-dev.yml`
> and `deploy-prod.yml` were deleted in `b2f86b4f`; no remaining workflow runs
> `supabase functions deploy`. `docs/deployment/README.md` still describes them
> as live and is stale on this point. Merging to `develop` ships the app
> changes and **none** of the server changes.

## Deploy

`_shared/garmin/onesignal.ts` changed, so **both** importing functions need
redeploying — not just `garmin-push`.

```bash
# dev
./scripts/deploy_dev.sh garmin-push garmin-ping

# prod (with the release)
./scripts/deploy_prod.sh garmin-push garmin-ping
```

### One-time secret

`activity_upload_push_sent` posts to Mixpanel from the edge function, which
reads its own env — `MIXPANEL_PROJECT_TOKEN` in `.env.dev.local` is client
config and is not visible to it.

```bash
supabase secrets set MIXPANEL_PROJECT_TOKEN=<token> --project-ref <dev-ref>
supabase secrets set MIXPANEL_PROJECT_TOKEN=<token> --project-ref <prod-ref>
```

Without it the push still sends; you just get no denominator, and the logs say
`[mixpanel] MIXPANEL_PROJECT_TOKEN missing`.

## Test it

Automated coverage runs in CI with no network and no deploy:

```bash
bash supabase/functions/run-algorithm-tests.sh    # incl. _shared/garmin/onesignal.test.ts
flutter test test/shared/services/notification_payload_parsing_test.dart
```

To see the real thing on a device, `scripts/test_activity_push.sh` impersonates
Garmin: it POSTs a synthetic workout to the **deployed** `garmin-push`, so the
real path runs without waiting on an actual session. It runs from your machine,
not on Supabase — and it exercises whatever version is currently live, so
deploy first or you are re-testing the old copy.

Prereqs: a `garmin_user_mappings` row for the account under test
(`select garmin_user_id, user_id from garmin_user_mappings;`), and the app
signed in as that user with push permission granted.

```bash
./scripts/test_activity_push.sh -g <garmin_user_id>                 # dev
./scripts/test_activity_push.sh -g <id> -d ""                       # → "Garmin Connect"
./scripts/test_activity_push.sh -g <id> -d "Forerunner 965 Music"   # longest label
```

Then check:

1. **Device** — heading and body read correctly, nothing truncated.
2. **Logs** — `./scripts/edge_logs.sh -m 5 garmin-push` → `OneSignal notification sent for activity <id>`.
3. **Mixpanel Live View** — `activity_upload_push_sent` within ~30s. Tap the
   push, then look for `activity_upload_notification_clicked` carrying the same
   `copy_variant` (needs an app build with this branch; an older build omits
   the property).

Each run generates a unique `summaryId` — a repeat would take the duplicate
path, which deliberately skips the notification. `--prod` requires the prod ref
explicitly plus a typed `PROD` confirmation, because it writes a real activity
row and pushes a real athlete.

## Measuring the rework

Funnel: `activity_upload_push_sent` → `activity_upload_notification_clicked`,
segmented by `copy_variant`.

- `accuracy_hook_v2` — current copy
- `unknown` — pushes sent before this field existed (the old wording's
  baseline; it never carried the field, so it is not mislabelled as v2)

Two honest limits:

- The event counts **sent**, not delivered or seen. A device with notifications
  disabled still lands in it, so CTR reads low against a true delivered
  baseline. OneSignal Confirmed Deliveries is the lever if you need delivered.
  Nothing can report "seen" for a push.
- Server events carry no Mixpanel super properties, so the `is_internal` super
  property set on client events is absent here. Filter internal traffic by the
  `is_internal` **People** property instead, or internal sends won't be
  excluded.

Worth checking before building dashboards: `docs/features/analytics/legacy_README.md`
references a `push_notification_opened` event that exists nowhere in this
codebase, which suggests OneSignal's Mixpanel integration may already be
feeding delivery data in. If so, a delivered-based denominator may already
exist alongside this one.

## Why the Garmin name stays in the body

The ticket asks to avoid assuming Garmin since "people could have Coros". That
applies to the connect prompt, not this push:

- `sendActivityUploadedPush` is called only from `garmin-push` and
  `garmin-ping`. Final Surge and TrainingPeaks sync paths never send it, so a
  Coros athlete never receives this message at all.
- Garmin's Developer API Brand Guidelines require attribution wherever
  Garmin-derived data is surfaced (`garmin_attribution.dart`), and the open
  production review in `docs/integration/garmin_email/` (Ticket 206017)
  explicitly asks for "all required attribution statements". Stripping the
  brand from a notification about Garmin data would work against a live review.

`buildGarminProviderLabel()` keeps the compliant form — device model when
known, `Garmin Connect` otherwise, never a bare "Garmin". This is now covered
by tests.

## Changing the copy later

Bump **both** constants together, or the funnel silently compares two
different messages under one label:

- `ACTIVITY_UPLOAD_COPY_VARIANT` in `supabase/functions/_shared/garmin/onesignal.ts`
- `_activityUploadCopyVariant` in `lib/shared/services/notification_service.dart`

The push body has a 130-character test guard against the longest realistic
device name — iOS truncates around there.
