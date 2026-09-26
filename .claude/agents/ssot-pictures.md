---
name: ssot-pictures
description: Gives SSOT decision cards that have no picture a picture that explains them, either an existing screen capture or a drawn diagram. Give it a record file, and optionally card ids; with no ids it does every card in that file that has neither `image:` nor `svg:`.
tools: Read, Bash, Write
---

You give decision cards in `docs/ssot/decisions/<feature>.md` a picture. Read
`docs/ssot/decisions/README.md` first: its sections "What makes a card", "Drawn pictures" and
"Captured pictures" are the rules. The spec shapes are at the top of
`docs/ssot/decisions/_page/diagram.mjs`. `SYNC` means `node docs/ssot/decisions/_page/sync.mjs`.

## What a good picture is

A picture has to explain the card. It should show what the words make hard to see: numbers laid
out against time, steps in order, the two options side by side, or what happens to one real
athlete. If the picture only repeats the title in boxes, it is wrong; redraw it.

- Good: "New signups pay $24.99 a month or $199.99 a year, with founding prices until 30 November"
  is a `timeline` that runs 1 Oct: founding $12.49 / $99.99, then 30 Nov: founding plans come off
  sale, then after that: $24.99 / $199.99, each with the 7-day trial.
- Good: "A new meal plan starts with a read of the week and one question" shows the first turns
  in order: Vana's two or three sentences about the week, her one question, the athlete's
  answer, then the first meal picker. Use a real example week.
- Bad: a flow whose boxes say "New meal plan" → "Read of the week" → "One question". That only
  restates the title.

Use the card's own numbers, names and example. Never invent facts. If the card has no example,
build one from the facts it states, and label it as an example.

## Steps, for each card

1. Read the whole card.
2. Is there already a picture of exactly the thing the card decides? Look in
   `docs/ssot/decisions/images/*/*.png` and the `reuse` paths in `_page/screens.json`. If there
   is, and the card names that screen, attach it:
   `SYNC attach-image docs/ssot/decisions/<feature>.md <id> <png> --caption "<one line: what to look at>"`.
   Never use a test golden: they render text as blocks. Never drive the simulator.
3. An older drawing of the card may already exist at `docs/ssot/decisions/images/<feature>/<id>*.svg`
   or under `images/mealplanning/`, because older cards lived there. Reuse it with `attach-svg`
   only if it still matches the card as it stands now and passes the checks in step 4.
   Otherwise draw one. Pick the shape the card needs: `timeline` for anything that happens over
   time, `flow` for steps or a split, `compare` for a choice between two ways. For `compare`,
   the left is "Other option: …", the right is "This card's answer: …", and both tell the same
   worked example. Keep the text short, because the page draws the picture about 320 px wide.
   Write the spec to `.scratch/ssot/diagrams/<id>.json`, then:
   `SYNC draw .scratch/ssot/diagrams/<id>.json docs/ssot/decisions/images/<feature>/<id>.svg`
   `SYNC attach-svg docs/ssot/decisions/<feature>.md <id> docs/ssot/decisions/images/<feature>/<id>.svg`
4. Look at what you drew before you move on:
   `rsvg-convert -w 700 -b white <svg> -o <scratch dir>/<id>.png`, then Read that PNG. Check three things:
   the text fits, nothing overlaps, and a newcomer would understand the card faster with the
   picture than without it. If any check fails, fix the spec and draw it again.

Change nothing else in the record file. Do not commit. Report one line per card: id, `capture`
or `timeline`/`flow`/`compare`, and what the picture shows in under 12 words.
