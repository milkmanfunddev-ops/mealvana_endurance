# Design SSOT — Component: Vana Sheet

**Status: PROPOSED v1 (Lee, 2026-09-11) — authored app-side, awaiting Xuan.** Drafted 2026-09-09
and revised 2026-09-10 against the companion export. Q-VS1 and Q-VS2 were confirmed by Lee on
2026-09-11, and the readings the app build settled were folded in the same day. This file lives in
the app repo until Xuan takes it into the QA repo; an older draft sits unpushed in a local QA
checkout. Ships as part of `home-shell@v1`'s reserved utility slot.
**Reference rendering:** `New Homepage with updated navbar calendar and chat.html` (Claude Design
export, read 2026-09-10). It **illustrates**; this file governs — phase-card-parity precedent. Where
the first draft guessed and the export draws, the export wins and the ruling is noted inline.
**Component contract** — owns the launcher, the sheet's chrome, the four states, and the
summon / dismiss / go-full-screen gesture set. *Where* the launcher may appear, and where it may
not, is stated here because it is a property of the launcher, not of any one screen; what the
sheet *says* is the persona's business and lives nowhere in `spec/design/`.
**Tokens / material:** [`../tokens.md`](../tokens.md) §Materials — the launcher takes `glass`
(floating chrome, `lift`), the sheet takes `glass-sheet` **including its scrim (blackberry 60 %)**,
which the calendar sheet's ruling made inheritable by "every future summoned glass surface". Raw
values live in the tokens file only; nothing here carries an alpha or a blur number.
**Slot authority:** [`tab-bar.md`](tab-bar.md) Q2 — the bar reserved "a named, empty utility slot
at the bottom-**right** corner … the deferred AI companion is the known candidate". This spec is
that occupant, filling the slot **additively**: no geometry change to the bar, no re-ratification
of `tab-bar.md`.
**Sibling precedent:** [`calendar-sheet.md`](calendar-sheet.md) — the first summoned
`glass-sheet`. Chrome, scrim and grabber follow it; a second summoned sheet must not invent a
second vocabulary.

## Why it exists

Vana lives on one screen. To ask her anything the athlete has to leave what they were looking at,
which is usually the thing they wanted to ask about. The sheet brings her to the screen instead,
and the screen stays visible behind it — that visibility is the whole point of the material, and
is what makes "what should I eat before this" a sentence the athlete can say.

## Anatomy

**Launcher** — one ~52 px circular `glass` button in the bottom-**right** corner, mirroring the
collapsed tab-bar button's size and material on the opposite corner. It carries Vana's mark and no
label. It **inherits the old FAB's clearance rule** (`tab-bar.md` Q2 → [`workout-card.md`](workout-card.md)
G1/G4): it may not overlap a workout card's swipe-reveal travel.

**Sheet** — a `glass-sheet` rising from the bottom edge over the current screen, top radius 26,
grabber at the top edge, the scrim between page and sheet, and a circular dismiss button at the
top-right of the chrome. It rises in 360 ms and **condenses back into the launcher** on dismiss
(470 ms, transform origin at the launcher's own corner) rather than sliding away — the sheet is
understood as the launcher opened up, and the motion says so. "The launcher's own corner" is the
launcher's **centre**, in its corner: the export's `transform-origin` is
`calc(100% - 42px) calc(100% - 48px)`, the centre of its 52 px launcher at 16 px right, 22 px bottom.

**Three heights, not one.** `auto` for a sheet that is one message and a dismiss; **75 %** at rest
for a sheet with a card and replies; **100 %** expanded. The grabber drags between them. The page
stays visible at rest, which is the contract; the numbers are the export's. **"A dismiss" is any
single reply**, whatever it says; a receipt part (memory saved, logged) counts as a card. `auto` is
as tall as what the sheet holds, up to 75 %. **100 %** stops under the status bar.

**Inside the sheet**, top to bottom: a **status chip** naming what this exchange is about
(`Fuel plan · to do` in `orange` when there is something to do, `Update` in `electrolyte` when there
is not); Vana's messages, each with a small filled `orange` sparkle avatar and cream body text, flush
left; **quick replies** as at most two chips, one filled and one outline, which disappear the moment
the athlete types anything; the thread, where the athlete's own turns are right-aligned in a soft
cream-tinted bubble and Vana's stay flush left with no bubble; a typing indicator; and the composer,
whose send control is inert grey until there is a draft and `orange` once there is.

The generative-UI parts Vana already renders (pickers, plans, shopping lists) compose inside the
message column unchanged. This spec does not re-contract them.

## States

| State | Contract |
|---|---|
| `CLOSED` | Launcher only. No scrim, no sheet, nothing dimmed. |
| `OPEN` | Scrim + sheet at rest height. The page behind stays legible through the glass — a sheet that hides its page has failed the material. Composer focused is still `OPEN`, not a fifth state. |
| `STREAMING` | `OPEN` plus the turn in flight: a typing indicator where the answer will land, and quick replies suppressed. The sheet does not resize while streaming. |
| `ERROR` | `OPEN` plus one plain line and a retry. Never a dialog, never a snackbar over the sheet — the sheet is already the surface in front of the athlete. |

Exactly one at a time. There is no loading state: the sheet opens to whatever the conversation
already holds, and an empty conversation opens to the opener.

## Where the launcher does not appear

Absent on: authentication, onboarding, privacy consent, paywall, force-upgrade, and **every Vana
route** (a launcher that summons the surface you are already on is a bug, not a shortcut). This is
a **suppression contract** — a screenshot of a paywall cannot show that the launcher is absent *by
rule* rather than scrolled off, so it needs its own conformance golden.

Also absent on **flow screens** (Lee, 2026-09-11): a screen whose job ends in a full-width bottom
action — creating or editing something, a wizard step, a form — where the launcher would cover the
action's right end. Hidden rather than given a clearance inset. The app names the set of routes
beside the other exclusions, as exact routes, never as subtrees; a flow screen opened without the
router names itself with the same kind of route name.

Everywhere else — every browsing screen — it appears, including screens with no Situation to
report.

## Gestures

| # | Gesture | Contract |
|---|---|---|
| VS-1 | Tap the launcher | `CLOSED` → `OPEN`. Summons over the current screen; the screen is not navigated away from and its scroll position is untouched |
| VS-2 | Tap the scrim, swipe the grabber down, or system back | `OPEN` → `CLOSED`, returning to exactly the screen and position underneath |
| VS-3 | Tap the full-screen affordance | Opens the existing Vana chat route **carrying the same conversation**; the sheet closes as it goes. Not a new conversation, not a second transcript |
| VS-4 | Send while `OPEN` | → `STREAMING`; the stream never changes the sheet's height. The one exception is the athlete's own first send from `auto`, which grows the sheet to 75 % once, in that frame (holding `auto` would grow it with every streamed word) |
| VS-5 | (continuity invariant) | Opening the sheet again later the same day continues the same ambient conversation; the next day opens a new one. Nothing about this is visible as chrome — it is what the athlete finds in the transcript |
| VS-6 | (suppression invariant) | On an excluded route the launcher does not render. It is not disabled, not hidden behind an opacity — there is no node |
| VS-7 | Drag the grabber | Between the three heights. Dragging down past the shortest dismisses, taking the VS-2 path. The export's thresholds: 24 px up expands; 90 px down collapses from 100 % or dismisses from rest; from 100 %, 90 px past the rest line dismisses; a tap on the grabber toggles 100 %; an upward pull at rest gives at 35 % |
| VS-8 | Tap a quick reply | Sends it as the athlete's turn. Quick replies vanish as soon as the thread has anything in it, and never come back in that exchange |
| VS-9 | (dismiss invariant) | Every dismissal condenses into the launcher; none of them slides the sheet off-screen. Whatever the athlete was reading ends where the thing that will bring it back lives |

## Open questions for the ruling desk

- **Q-VS1 — rest height. CLOSED (answered by the export 2026-09-10, confirmed by Lee 2026-09-11):**
  three heights, `auto` / 75 % / 100 %, with the grabber dragging between them. Recorded above.
- **Q-VS2 — the launcher's mark. CLOSED (answered by the export 2026-09-10, confirmed by Lee
  2026-09-11):** a speech-bubble outline, drawn as a path rather than taken from Font Awesome — the
  first branded glyph on the shell, confirmed deliberately.
- **Q-VS3 — the launcher while the tab bar is collapsed.** The tab bar collapses on scroll
  (`tab-bar.md` trigger rule). Options: (a) the launcher collapses with it, so the two corners stay
  symmetrical; (b) the launcher is scroll-independent, because a question can occur to someone
  mid-scroll and that is when they most want it.
- **Q-VS4 — the launcher over a full-width scrollable.** The clearance rule inherited from the FAB
  keeps it clear of a workout card's swipe travel. Does that rule also apply to the meal-planning
  Plan tab's swipe-to-swap rows, or do those need their own clearance?

## Conformance (design vectors)

- **Golden (L1):** `CLOSED` (launcher over a populated screen), `OPEN`, `STREAMING`, `ERROR` — each
  light and dark, at iPhone-SE width, on the glass shell so the material composes against real
  content rather than a flat fill. Plus the **suppression golden**: a paywall render showing **no
  launcher node**.
- **Widget (L2):** VS-1 summon over the current route; VS-2 dismiss returning to the same route and
  scroll position; VS-3 opening the chat route with the same conversation id; VS-6 as a negative
  test over the router — every excluded route has no launcher in the tree, and a route outside the
  excluded set has one.
- **Through the real notifier:** VS-5 — one ambient conversation per person per day, and a new day
  opening a new one.
- **A golden may only be regenerated after this spec changes** — never to make a red test pass.

## Deferred: the companion that speaks first

The export also draws Vana **speaking unprompted** — a traced ring round the launcher, then a colour
tint (`orange` when there is something to do, `electrolyte` when it is only news), then for an
actionable moment a short pill beside the launcher ("Fuel tonight's run?") that retires after about
four seconds and leaves the tint behind. It draws a **minimized** state too: a pulsing pill reading
"planning…" for work happening in the background. The tab bar retracts while she speaks.

**Contracted since 2026-09-11 in [`vana-moment.md`](vana-moment.md)**, once the trigger set was
ruled. What follows is the original note, kept for the drawing. **None of that is contracted here, and it is not deferred for lack of drawing — it is deferred
because nothing has decided what makes her speak.** A companion that interrupts on the wrong trigger
is worse than one that waits. When the trigger set is ruled, this section becomes its own component
spec; the states above are recorded so the drawing is not lost in the meantime.

## Not in this contract

- What Vana says, which parts she renders, and how the transcript is laid out. Those are the
  conversation surface's, already contracted by their own parts.
- Gating. The sheet follows the app's gate; there is no Vana-specific paywall and this file does not
  create one.
- The Situation. Which screen is underneath and what it holds is a server contract, not a visual one.
