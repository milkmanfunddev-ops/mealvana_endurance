# Claude Design prompts — create-flow fueling controls (DG-2/DG-3)
The ruled behavior: §3a window table + early-start rule + clamp (`spec/fueling/food-recommendation.md`),
fasted toggle removed (§7). PROPOSED design contract: `spec/design/surfaces/create-flow-fueling-controls.md`.

## Starting material (no prior Claude Design prototype exists for this screen)
- **Screenshots to attach:** `runs/2026-09-03-design-recording/07-window-fasted.png` (window
  stepper + fasted toggle + weather, as-built) and `runs/2026-09-03-design-recording/pin-banner-ref.png`
  if doing both jobs in one session.
- **Path A (recommended):** in the Claude Design project, attach the screenshot and use Prompt 1 —
  reconstruct-then-modify in one step.
- **Path B (pin job):** `prototypes/formula-kit/formula-kit-v2.html` is the existing Formula Kit
  prototype — open/import it in Claude Design and iterate the conflict label there
  (prompts: `runs/2026-09-03-pin-conflict-label-design-prompts.md`).

## Prompt 1 — reconstruct + apply the ruled changes (WHOLE SCREEN, IN PLACE)
> Standing rule: modify the working screen in place; keep the full phone frame and the flow
> interactive; return extra states as additional full screens, never as cropped element tiles.
"Attached is the current Create New Activity Plan fueling section from Mealvana Endurance (plum
#381633 / cream #F8F6EB, orange #F78B14 accent, teal #12C9A8, Sansita display + Manrope body).
Reconstruct this section as an artboard, then apply three ratified changes: (1) REMOVE the
'Fasted Workout' toggle row entirely (the fasted state is retired). (2) The PRE-RUN FUELING
WINDOW stepper now gets its default from a ratified table (race 3h · long 3h · mid 2.5h ·
moderate hour-long 2h · easy 1h · under-an-hour 45min; training before 7 a.m. drops to 60 min)
and is CLAMPED to the time remaining before the session — design the clamp-bound state: the
stepper opens AT the ceiling, the plus control reads as inert (not hidden), and a one-line caption
explains the default (e.g. '3 h — race morning' / '60 min — early start', or 'Capped: session in
45 min'). (3) Keep the weather steppers and their location-blocked state as-is. Show the section
in both themes, three states: normal default, early-start default, clamp-bound."

## Prompt 2 — the caption variants (decision aid — the one place a comparison board is fine)
"Decision aid only, nothing downstream drives it. One board comparing the window stepper WITH and WITHOUT the explanatory caption
under it, in the three states above — six tiles, annotated with one line each on clarity vs
clutter. This decides open question Q-CF1."

## Follow-up frames for the next design pass (D-02, ruled 2026-09-03)
1. Clamp-bound stepper: opens AT the ceiling, + inert, caption "Capped: session in 45 min" (CF-2).
2. Location-blocked weather state (CF-4) with "Open app settings" link.
