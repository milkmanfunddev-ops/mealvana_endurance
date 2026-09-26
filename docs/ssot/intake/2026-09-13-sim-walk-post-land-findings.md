> **F2 RESOLVED 2026-09-13 → D-4 (option A: erase the sublabels; no window copy on connect cards).**
> **F1/F3 WITHDRAWN 2026-09-13 — false alarms from dual-driver sim interference:** the
> coding agent and QA were driving sim 860F418A concurrently; interleaved idb taps
> produced the phantom restart and the premature toast. Single-driver repro on an
> isolated sim walks welcome → 9 steps → reveal → daily-plan preview → create-account
> → app home cleanly; code-verified (QA re-check): reveal-continue is
> `_pageController.animateToPage(...)` (onboarding_pageview_screen.dart:210,274) and the
> only restart vector is step-0 back → `context.go('/welcome')` (:88), unreachable from
> the reveal. F2 stands regardless — static copy, not tap-order-dependent.
> Process rule adopted both sides: ONE driver per sim; reproduce another agent's sim
> finding single-driver before trusting it.**

# Sim walk — post-land build (develop 5f6f7473, installed 2026-09-13 20:50)

Charter: `charter-integrations-surfaces.md` + the day's fix list. Fresh install wiped
the persisted avery session → walk ran the FRESH-ONBOARDING path (previously the
blocked surface). Three findings, one walk limit.

## F1 — Validation toast fires on cold entry (minor)
"Please select at least one sport" toast is visible at first paint of the sports page,
before any user interaction. Cosmetic/UX; no contract violation.

## F2 — Connect-page history sublabels contradict the ratified Q-INT27 contract (major, copy)
Onboarding connect cards read: TrainingPeaks "Imports ~30 days of history"; Final Surge
"Imports ~7 days of history". The ratified contract (Q-INT27, RULED 2026-09-11) is the
INVERSE: NO TP/FS history import (their windows are FORWARD: TP 45d; FS 14d — server-cap
verified today+14d in probe 191e422); Garmin is the one provider that DOES import
history (30 days of activities at connect) and its card carries NO sublabel; V.O2's
real 14-day lookback is also unlabeled. Either the copy is wrong (forward windows
misdescribed as history, wrong numbers) or unratified behavior shipped. The Garmin
historical-data primer sheet itself is well-formed and matches Q-INT18/27 intent.
Route: failing-vector-first is N/A (copy register); needs a ruling on the correct
sublabel copy per provider, then the fix. Suggested truthful set: Garmin "Imports your
last 30 days"; TP "Imports your next 45 days of workouts"; FS "Imports your next 2
weeks of workouts"; V.O2 "Imports 2 weeks back, 45 days ahead".

## F3 — Onboarding loop: reveal's "Continue to See My Daily Plan" restarts the flow (blocker)
Platform-less path: sports → about-you → body comp → nutrition settings → reveal
("We built your plan", 70 g/hr · 768 ml/hr · 634 mg/hr, honest no-platform card) →
Continue → **back to step 1, all state cleared**. The daily plan is unreachable on a
fresh install without auth; if the intended next step is the post-onboarding auth
screen, it is not being routed to. Repro: cold launch fresh install, any sports pick,
defaults through, Continue at reveal.

## Walk limits (unwalked this pass)
- D-2 pill-PRESENT states + TP-row toggle live: need a real provider OAuth (Xuan's
  credentials) — pinned by the app golden suites meanwhile.
- avery's seeded timeline (brick border D-1b, verified card, Events chips on data,
  FTP/water-bottle persistence fixes): session was wiped by the fresh install; needs a
  login or re-seed. The landed Patrol suite covers settings_persist/brick_plan/
  activities_crud on its own fixture account.
- Coach Athlete Detail: still gated on a coach login.

## Verdict
The landed contract itself is not contradicted by anything walked EXCEPT F2's copy;
F3 is an app flow defect on the fresh-install path (likely post-land regression or
auth-routing gap — the Patrol flows run authed, which is why 7/7 stayed green).
