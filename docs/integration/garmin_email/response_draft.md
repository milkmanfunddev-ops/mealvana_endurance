# Garmin Production Review — Response Draft

> **Status:** Ready for Lee's review. Capture the 5 screenshots listed in
> `screenshot_plan.md`, drop them into `response_screenshots/`, run the zip
> command, then paste this body into the Zendesk ticket and attach
> `response_bundle.zip`.
>
> Tone target: factual, polite, first-person. No marketing speak. Match every
> claim to a screenshot.

---

Hi Elena,

Thanks for the review. We've shipped two changes in response to your Apr 23
note and have a third thing to add for clarity on the API question.

## 1 · Brand compliance — Garmin Connect badge

We've replaced the standalone Garmin tag with the Garmin Connect badge from
the Authenticating Applications guidance throughout the app. It now appears
in the integration card during onboarding and settings, on every activity
that originated from Garmin Connect, and beside any individual data point we
display that came from Garmin. The legacy tag mark remains in code but is no
longer the default — every visible attribution surface uses the Garmin
Connect badge.

> **Screenshot A** — `response_screenshots/A_garmin_connect_card.png`
> Connected Apps screen showing the Garmin Connect badge on the integration
> card. The "Latest received" line underneath surfaces ongoing
> Health-API + Activity-API ingestion (daily summary, sleep, body comp,
> stress, user metrics, completed activities) per data type.
>
> **Screenshot E** — `response_screenshots/E_workout_match_with_badge.png`
> Activity detail view showing the Garmin Connect badge on a workout that
> was matched from a Garmin upload (the existing workout-matching flow,
> reshot with the new badge).

## 2 · Activity API usage

We use the Activity API in two places:

**Workout matching.** Garmin completed-activity push notifications are
matched against planned workouts that came from TrainingPeaks or Final
Surge. When a Garmin activity matches, it stamps the planned workout as
completed and pulls the device name, duration, and total energy expenditure.
This flow has been in production since our evaluation key was issued.

**Retrospective nutrition recalculation (new).** When Garmin reports actual
energy expenditure for a completed session, our nutrition calculator
re-runs in retrospective mode and shows the athlete how their daily macro
plan adjusts based on what they actually burned. The athlete sees the prior
plan, the corrected plan, and the delta side-by-side. This is the first
case where Garmin Activity data influences the nutrition output, not just
the calendar.

> **Screenshot C** — `response_screenshots/C_retrospective_delta.png`
> Activity detail showing the "Nutrition adjusted from your actual effort"
> banner inline on a Garmin-completed activity, with the carb/fat/TDEE/
> session deltas computed from the measured Garmin Activity payload.

## 3 · Training API usage

Today we ingest planned training data from TrainingPeaks and Final Surge,
not from Garmin's Training endpoint. Those planned sessions feed our
prospective macro calculation (carb timing, intensity factor, weekly load).
The Garmin Training API endpoint is enabled on our portal because we plan
to consume planned-workout data from Garmin Connect Calendar in a future
release; we have not started that consumption yet and will not claim
production usage of it until we do.

## 4 · Health API usage

Health-API daily summary records (`bmrKilocalories`, `activeKilocalories`)
now drive two values in the daily macro calculator:

- **RMR** — when Garmin reports BMR for the day, we use that measured value
  instead of our Mifflin/Cunningham fallback formula.
- **NEAT** — when Garmin reports active kilocalories for the day, we
  compute non-exercise activity thermogenesis as
  `activeKilocalories − sum(session_kcal)` (clamped at zero), instead of
  estimating from the athlete's volume tier and lifestyle.

Each macro target the athlete sees has a per-input source attribution. We
expose it through a "Why these numbers?" sheet — every row that came from
Garmin shows the Garmin Connect badge.

> **Screenshot B** — `response_screenshots/B_sources_sheet.png`
> Daily nutrition screen with "Why these numbers?" expanded, showing
> per-input source rows with Garmin Connect attribution on RMR and NEAT.
>
> **Screenshot D** — `response_screenshots/D_body_comp_attribution.png`
> Nutrition profile showing body-composition values fall back to Garmin
> Connect when the athlete hasn't entered them manually.

We also receive sleep, stress, body composition (beyond fall-back BF%),
user metrics, and epoch summaries from the Health API. We persist these
today; they aren't yet inputs to the macro calculator. We plan to surface
sleep and stress in a future iteration as recovery-aware modifiers, and
will only describe them as "in production" once they are.

## 5 · Privacy

No Garmin Connect data is processed by external AI providers. All Garmin
ingestion runs in our own Supabase edge functions and database; the
nutrition calculator that consumes it is a deterministic algorithm running
in our own infrastructure. Our privacy policy reflects this — anchor
[link to privacy policy section, to be confirmed before sending].

---

Happy to provide additional screenshots or walk through any of this on a
call. Apologies for the turnaround — wanted to ship the Health-API
consumption before describing it.

Best,
Lee Martin
Mealvana

---

## Attachments
- `response_bundle.zip` — A through E screenshots inline above.
