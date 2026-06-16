# Re-walk — 2026-06-13

**Build:** `com.milkman.mealvanaendurance.dev` v**1.20.0+1** (vs the original
audit's v1.18.1) · iPhone 15 Pro Max sim (iOS 17.5) · driven via mobile-mcp.

**Goal of this session:** Not bug-hunting — the objective is to **build the
integration test suite**. This walk re-confirmed the onboarding flow on the
current build and produced the first full **create-new-user** integration test.

## What was done

1. Confirmed current screen on launch = **Welcome**.
2. Verified the prior audit's "Log In button un-tappable" was a mobile-mcp
   keyboard-overlap artifact, not an app bug (the button fires once the soft
   keyboard is dismissed). See `BUG_REGRESSION_TRACKING.md` → NOTE-005 / BUG-006.
3. Walked the **full anonymous onboarding flow** end-to-end and **created a new
   dev user via email signup**, landing on the calendar ("Account created
   successfully!").
4. Instrumented the two previously-unkeyed screens on the signup path
   (`email_signup_screen.dart`, `birth_year_picker.dart`).
5. Wrote `integration_test/flows/onboarding_signup_flow_test.dart` — the
   canonical release smoke test (find.byKey-driven, unique email per run).

## Screenshots (current build, this walk)

| File | Screen |
|------|--------|
| `01_welcome.png` | Welcome |
| `02_connect_training.png` | Connect Training (skip/continue) |
| `03_profile_form_filled.png` | Profile form (filled) |
| `04_sport_selection.png` | Sport selection (Running default) |
| `05_dietary_preference.png` | Dietary preference (Omnivore) |
| `06_allergies.png` | Allergies (None) |
| `07_food_selection.png` | Food selection (chips) |
| `08_create_account.png` | Create account (Apple/Google/Email/skip) |
| `09_signup_email.png` | Sign Up with Email (empty) |
| `09b_signup_filled.png` | Sign Up with Email (filled) |
| `10_calendar_new_user.png` | Calendar after signup ✅ |
| `03b_login_failed.png` | (prod creds on dev — see NOTE-005) |

## Result

- **UI has not drifted** between v1.18.1 and v1.20.0+1 on the onboarding path —
  every screen and element matches the original `02_onboarding/README.md`.
- The onboarding happy path is now covered by an automated test.

## Test users created on dev (disposable — clean periodically)

- `audit_rewalk_0613@example.com` / `Test1234!` (manual walk)
- `audit_<epoch>@example.com` / `Test1234!` (one per automated test run)

## Next test targets (post-onboarding, logged-in)

The onboarding + auth entry points are now covered. Remaining flows to turn into
`find.byKey` tests (keys already exist per the instrumentation docs):
calendar → activity create → adjust macros → nutrition plan; event create →
event details → carb loading; settings subtree; fuel log. Drive each from a
freshly-onboarded user (this test's end state) rather than a seeded login.
