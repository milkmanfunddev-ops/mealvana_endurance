# Screenshot capture plan — Garmin response

Capture these on the iOS simulator (or real device) using Lee's dev account
`607f9dd5-6fa7-48ee-a628-720d4a0506a1`. The dev account already has Garmin
data per memory (lee.b.martin@gmail.com → Lee's Garmin user
`af701316-e43f-4a8c-be41-a3fde89a8e96`).

Save all screenshots into `docs/integration/garmin_email/response_screenshots/`
with the exact filenames below. The email draft references each by name.

## Pre-flight

```bash
# 1. Make sure the new edge function is deployed to dev:
supabase functions deploy calculate-daily-macros

# 2. Run the app on simulator:
flutter run --flavor dev
# or your usual launch command
```

Sign in as Lee (lee.b.martin@gmail.com). Navigate around so the app caches
recent Garmin pushes (today's daily summary, recent activities).

## Screenshots to capture

### A — `A_garmin_connect_card.png`
**Where:** Settings → Connected apps
**What:** The Garmin Connect integration card with the new badge visible.
Connection status should read "Connected". Underneath the card, the
"Latest received: daily Xh ago · activity Yh ago · …" line should be
visible (renders only when the account has received Garmin pushes).
**Why:** Demonstrates the brand-compliant Garmin Connect badge **and**
ongoing Health-API + Activity-API ingestion.

### B — `B_sources_sheet.png`
**Where:** Daily nutrition screen → tap the "i" affordance next to "Daily
Total"
**What:** "Why these numbers?" bottom sheet expanded, showing per-input
source rows. RMR and Daily activity (NEAT) should show the Garmin Connect
badge if Lee has Garmin daily data for today.
**Why:** Demonstrates Health-API consumption (BmrKilocalories →
RMR, ActiveKilocalories → NEAT) in production.

### C — `C_retrospective_delta.png`
**Where:** Activity detail for a date with a Garmin-sourced completed
activity. **First** open the Daily Nutrition screen for that date (this
populates the in-memory live cache that the banner reads from), **then**
navigate to the activity.
**What:** The "Nutrition adjusted from your actual effort" banner inline
on the activity detail header, with delta numbers (e.g. "-313 session
kcal · -412 TDEE · -48g fat"). The Garmin Connect badge appears below the
delta numbers.
**Why:** Demonstrates Activity-API retrospective recalculation in
production, in-context next to the activity itself.

#### Alternative C — `C_alt_retrospective_delta.png` (optional)
**Where:** Daily nutrition screen → "Why these numbers?" sheet
**What:** Same delta callout inside the sources sheet (carries the same
numbers as inline screenshot C, for redundancy if needed).

### D — `D_body_comp_attribution.png`
**Where:** Settings → Nutrition profile
**What:** A view that shows the body-composition section with a Garmin
Connect attribution chip beside the body-fat-% line (visible only when the
athlete hasn't manually overridden BF%). If Lee has set BF manually, you
can temporarily clear it in the dev DB to capture this state.
**Why:** Demonstrates Health-API body-composition consumption in profile
fallback flow.

### E — `E_workout_match_with_badge.png`
**Where:** Activity detail screen for a Garmin-matched workout
**What:** The Garmin Connect badge attribution on a completed activity
that originated from a Garmin push.
**Why:** Reshoot of an existing flow with the new brand-compliant badge.

## Bundle

Once all 5 PNGs are in place:

```bash
cd /Users/leemartin/development/mealvana_endurance/docs/integration/garmin_email
zip -r response_bundle.zip response_screenshots/
ls -la response_bundle.zip
```

Then open `response_draft.md`, paste it into the Zendesk reply (Ticket
206017), and attach `response_bundle.zip`.

## Verification before sending

- [ ] Every "Screenshot X" reference in `response_draft.md` matches an
      actual filename in `response_screenshots/`.
- [ ] No screenshot shows speculative or unshipped behavior.
- [ ] Privacy-policy anchor URL in §5 is filled in (or that bullet is
      removed if no anchor exists yet).
- [ ] Visual: every Garmin attribution in screenshots uses the new pill
      badge, not the old tag.
- [ ] `flutter analyze` clean on the touched paths (already verified).
- [ ] Edge function tests pass (already verified — 171/171).

## Things explicitly not in this batch

- Sleep / stress / RHR consumption surfaces — deferred per the Iter 5 spec.

## Now also shipped (originally deferred, built post-merge of plan)

- **Connected-apps "Latest received" line** — under the Garmin Connect
  card, shows `Latest received: daily 2h ago · activity 1h ago · sleep 11h
  ago · …`. Surfaces ongoing Health-API + Activity-API ingestion. Screenshot
  A captures this when Lee's account has recent push data.
- **Activity-detail retrospective delta banner** — when an activity has
  Garmin completion data and the daily plan for that date has a delta
  (after a fresh edge-function call from the daily macros screen),
  Activity Detail shows a "Nutrition adjusted from your actual effort"
  banner with the carb/fat/TDEE/session deltas inline. Capture sequence:
  open Daily Macros for the activity's date first (this populates the
  in-memory live cache), then open the activity → screenshot the banner.
  Screenshot C now captures this banner directly on Activity Detail.
