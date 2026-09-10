# 01: Finish the feedback loop

**Status:** done
**Blocked by:** None.
**Next:** `/mattpocock-skills:implement 02`

**What to build:** Feedback typed into Vana is the feedback system, and it works for all three kinds,
not just a complaint. Praise and a suggestion each produce their own row with the right sentiment and
about-field. A brand-new athlete's first conversation shows the one-time "have feedback? just type it
here" prompt after the opener, and their second conversation does not. Nothing here is built on a
self-report: the rows are read back from the table.

- [x] Praise produces one row with positive sentiment; a suggestion produces one with about = suggestion
- [x] Both have eval cases in `scripts/vana-eval/personalization.ts`, reading the rows back
- [x] A brand-new user's first conversation shows the feedback prompt once; the second does not
- [x] That first-conversation path was verified live on dev, against an athlete created for it
- [x] The acknowledgement is settled — server-authored — and its eval case passes

## Done, 2026-09-10

`deno run -A scripts/vana-eval/personalization.ts` is **13 of 13** on dev, up from 9 of 10. Every
assertion below is a row read back through PostgREST, never a self-report.

### The acknowledgement is server-authored

Lee's ruling, and it took two tries to land. The `feedback_saved` part was already drawn by the
client from `meal_planning.feedback_saved_row` ("Saved for the team"), so no new part was needed —
that row IS the acknowledgement. What was missing was making it the *whole* reply:

- **The persona asks for silence.** "Filing it IS the answer — no other tool, and no text of your
  own: the app itself shows them it is saved."
- **The server guarantees it.** `silenceAfterFeedback` in `chat.ts`: once a `feedback_saved` part has
  gone out, every later text delta is dropped — in the live NDJSON stream and in the persisted
  transcript alike, so the two never disagree. Six unit tests in `tests/vana/feedback_ack.test.ts`.
- **A question mark buys an answer.** A message that is both a complaint and a question keeps its
  prose; a pure vent is answered by the row alone. That is the combined case the old ticket named.

This is not the clamp that was rejected: a clamp keeps whichever sentence came first, which in the
worst run was "You're right, and I apologize". This drops the prose and keeps the line the content
system owns.

### Two things the prompt work taught, worth not relearning

- **Position beat wording.** The first rewrite dropped "treat it like taking a note in a meeting" and
  the tool stopped being called at all on a complaint — Vana apologised instead of filing, about half
  the time. Restoring the framing was not enough on its own. Moving the rule to the **top** of
  `GENERAL_PROMPT`'s rules, and naming *being corrected* ("I have told you", "you keep getting this
  wrong") as feedback, made it four for four.
- **The `about` enum needed the taxonomy spelled out.** "I wish I could send the shopping list to my
  partner" filed as `app`; it is a `suggestion`. The enum now says suggestion wins whenever they are
  asking for something new, and `vana` covers praise or complaint about her suggestions even when the
  athlete says "the app".

### The first-conversation prompt, verified at last

The only part of this ticket never exercised at all. It cannot be tested with the eval user, who has
hundreds of conversations, so `feedback-prompt-once` mints a brand-new dev athlete (auth user plus
the minimal `public.users` row — there is no trigger), opens two conversations, and asserts the
`feedback_prompt` part appears in the first and not the second. **The athlete is deleted at the end**,
so dev accumulates nothing and the case re-runs. It passes.

### Left standing

- The praise case asserts positive sentiment and rating, and only **logs** the about-field. Praise
  that names "this app" while describing how Vana plans is genuinely either `vana` or `app`, and the
  ticket asks only that praise land as positive.
- When the athlete's complaint carries a question mark, Vana keeps her prose and still answers it
  apologetically. That is the trade the question mark buys; sharpening what she says there is a
  separate piece of work, not this ticket.

**Full history:** `../archive/issues-2026-09-10/01-verify-feedback-lands.md`
