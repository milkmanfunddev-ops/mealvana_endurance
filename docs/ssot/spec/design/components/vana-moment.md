# Design SSOT — Component: Vana Moment (the launcher that speaks first)

**Status: PROPOSED v1 (Lee, 2026-09-11) — authored app-side, awaiting Xuan.** Written from the
deferred section of [`vana-sheet.md`](vana-sheet.md) once the trigger set was ruled (Lee delegated
the call on 2026-09-11). The states and their numbers are the companion export's.
**Reference rendering:** `New Homepage with updated navbar calendar and chat.html` (Claude Design
export, read 2026-09-10). It illustrates; this file governs.
**Component contract** — owns what the launcher does when Vana has something to say before she is
asked: the ring, the tint, the pill, and what tapping the launcher opens while a moment is live. It
extends the launcher in [`vana-sheet.md`](vana-sheet.md); the sheet itself is unchanged.
**Tokens / material:** [`../tokens.md`](../tokens.md) — `orange` for a to-do, `electrolyte` for news,
the launcher's `glass` at rest. Raw values live in the tokens file only.

## Why it exists

The sheet waits to be asked. But the moments that matter most in fuelling come at a time, and the
athlete may not think to ask: the pre-run window opening with nothing eaten, a finished session with
nothing logged for recovery. A companion that notices those and says so once, quietly, is worth
more than one that waits. A companion that interrupts on the wrong trigger is worse than one that
waits, so the trigger set below is narrow on purpose.

## The trigger set (ruled 2026-09-11)

A **moment** is at most one thing Vana has to say right now. Fuelling windows only, decided on the
device from data it already holds:

| # | Moment | Raised when | Retires when |
|---|---|---|---|
| M-1 | **Pre-workout** (to-do) | A planned workout today whose pre-workout window has opened (window length from the fuelling-window authority, `food-recommendation.md` §3/§3a) and nothing has been logged since the window opened | The workout starts, something is logged in the window, or the athlete acts on it |
| M-2 | **Recovery** (to-do) | A workout today has finished, nothing has been logged since it ended, and the post-workout recovery window the fuelling SSOT names is still open | The window closes, something is logged, or the athlete acts on it |

Not in this set, deliberately: the meal-plan beats (cook check-in, week debrief). They are decided
on the server (`pickOpener`) and reach the launcher only through a server call; they follow as their
own ticket. No informational moments are raised yet, so the `electrolyte` tint is specified but
unused.

## Cadence

- **Each window speaks once.** A moment rings the first time it is raised. It never rings again for
  the same workout and window, across screens and app restarts.
- **At most two rings a day.**
- **One moment at a time.** When two qualify, the one whose window closes sooner wins.
- **A moment belongs to the day, not the screen.** The launcher is global, and so is the moment: it
  stays on the launcher as the athlete moves between screens until it retires.

## States

| State | Contract |
|---|---|
| `QUIET` | The launcher as `vana-sheet.md` draws it. No moment. |
| `RING` | About 2 s: the mark drops in (scale 0.7 → 1.12 → 1 over 420 ms) and a glow traces the bubble's outline, fading out over its last 500 ms. |
| `PILL` | To-do moments only. A pill beside the launcher with one short line ("Fuel tonight's run?") for about 4 s, then it retires. While the pill shows, the tab bar retracts to its collapsed button so the two do not overlap. |
| `TINTED` | After the ring, and after the pill for a to-do: the launcher fills with the moment's tone (`orange` to-do, `electrolyte` news), the mark in `blackberry`. It stays tinted until the moment retires. |

Reduced motion: no drop, no trace; the launcher goes straight to `TINTED`, and the pill still shows.

## Gestures

| # | Gesture | Contract |
|---|---|---|
| VM-1 | Tap the launcher while a moment is live | Opens the sheet on the moment: Vana's opening turn names it (the session, its time, the window) and offers two quick replies. It is written into the day's ambient conversation (VS-5) and starts a new exchange there, so its quick replies show even when the conversation already has a thread. The status chip reads `Fuel plan · to do`. |
| VM-2 | Dismiss the sheet without acting | The moment returns to the launcher, `TINTED`, with no second ring. It is not cleared. |
| VM-3 | Act on it | Anything the athlete sends in that exchange (a quick reply or a typed turn) answers the moment; it retires. |
| VM-4 | Tap the launcher with no moment | VS-1, unchanged. |

## Deferred

- The **minimized** "planning…" pill: nothing in the app does background planning work that it
  could honestly report. Not built until something does.
- **Meal-plan moments**, and informational moments: see the trigger set.

## Conformance

- **Unit:** the moment resolver over producer-shaped rows (planned and completed activities, meal
  logs, the clock). It covers each of M-1 and M-2 raised and retired, one at a time, and the cadence
  rules.
- **Widget (L2):** RING → PILL → TINTED on a to-do; the tab bar retracting while the pill shows;
  VM-1 through VM-3 through the real host; reduced motion.
- **Golden (L1):** `TINTED` in both tones and `PILL`, light and dark, at iPhone-SE width.
