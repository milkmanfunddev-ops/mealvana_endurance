# 01: Verify feedback lands from Vana

**What to build:** An athlete tells Vana "you keep suggesting fish" in a real dev conversation. Vana thanks them in one plain sentence, does not troubleshoot, and a feedback row exists with negative sentiment, about Vana, the message in their words, and the conversation id. The same for praise and for a suggestion. The first conversation of a fresh user shows the one-time "have feedback? just type it here" prompt after the opener and never again. Whatever this finds broken gets fixed in the same ticket. Nothing here is built on a self-report: the rows are read back from the table.

**Blocked by:** None (can start immediately)

**Status:** verified live on dev; one defect open (2026-09-10)

- [x] A complaint produces one feedback row (praise and suggestion variants still unwritten) with the right sentiment, about-field, message, and conversation id
- [ ] **OPEN:** the reply is 3–5 sentences and troubleshoots. See below.
- [x] Taste comments ("not those") and "other options" do not produce a feedback row
- [ ] A brand-new user's first conversation shows the feedback prompt once; the second conversation does not
- [x] The save-feedback path has a live eval case in the vana-eval scripts recording token cost
- [x] The uncommitted feedback work on dev is committed (a976b957); nothing found broken yet because nothing has been run

**Notes (2026-09-09).** The uncommitted feedback work that was sitting in the tree is committed as
`a976b957`, separated from the Voodoo Doll changes it was interleaved with, so there is now
something to verify against.

The live verification itself is not done. Two cases sit in `scripts/vana-eval/personalization.ts`:
`feedback-lands` (a complaint produces one row with negative sentiment, about Vana, the athlete's
words and the conversation id, and the reply is one sentence with no chips) and
`taste-is-not-feedback` (a taste comment writes no row). Both read the rows back through PostgREST
rather than trusting anything the model said about itself.

Running them bills real model spend against dev and writes real rows for the eval user, so it is a
by-hand step:

    deno run -A scripts/vana-eval/personalization.ts --only feedback-lands,taste-is-not-feedback --verbose

Still unwritten: the praise and suggestion variants, and the first-conversation feedback prompt
appearing once and never again. The prompt's server path is committed and contract-tested; what has
never been checked is that a brand-new user sees it.

## Verified live on dev, 2026-09-10

A complaint typed into Vana now produces exactly one `user_feedback` row with `rating -1`,
`metadata.sentiment = negative`, `metadata.about = vana`, the athlete's words verbatim, and the
conversation id. Read back from the table, not self-reported.

Two real defects were found and fixed getting there:

- **The conversation id was always null.** `saveFeedback` read it from the *plan* scope, which is
  null in general mode by design, so every general-mode feedback row lost its conversation. The
  conversation id is now threaded to the tools independently of the plan scope.
- **The tool was not reliably called.** Vana twice said "your feedback has been saved for the team"
  without calling `saveFeedback` — the team would have seen nothing. The persona and the tool
  description now say plainly that claiming it is saved without calling the tool means the team
  never sees it.

## Open: the reply will not stay to one sentence

Every variant produces the right tool call and the right row. None keeps the reply to one sentence.
Three prompt attempts, in order:

| Prompt | Result |
|---|---|
| "then ONE sentence acknowledging it is saved" | 3 sentences, promises a fix |
| Same plus an explicit list: no apology, no promise, no explanation | **5 sentences** — the list primed the behaviours it forbade |
| Positive framing: "like taking a note in a meeting" | 3 sentences, first one correct, then troubleshooting |

The Doll makes it worse rather than better: with the complaint now in MEMORIES, Vana reads that she
has been corrected before and apologises for it.

Prompt-only brevity is not holding on Haiku for this turn, and further sharpening made it worse
twice. This needs a decision rather than another rewrite:

1. **Clamp the saveFeedback turn server-side to one sentence.** There is precedent —
   `RUNAWAY_SENTENCES` already clamps planning turns — but it contradicts the posture written into
   chat.ts, that brevity is a prompt rule because a clamp only cuts text after it was paid for.
2. **Relax the criterion to two sentences** and accept a short acknowledgement.
3. **Use a stronger model for this turn only**, which the eval's per-case token numbers now price.

