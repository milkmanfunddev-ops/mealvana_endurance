# 01: Finish the feedback loop

**Status:** ready-for-agent
**Blocked by:** None. One acceptance line — the acknowledgement's length — waits on a ruling from Lee; the rest does not.
**Next:** `/mattpocock-skills:implement 01`

**What to build:** Feedback typed into Vana is the feedback system, and it works for all three kinds,
not just a complaint. Praise and a suggestion each produce their own row with the right sentiment and
about-field. A brand-new athlete's first conversation shows the one-time "have feedback? just type it
here" prompt after the opener, and their second conversation does not. Nothing here is built on a
self-report: the rows are read back from the table.

**Already verified live on dev (2026-09-10).** A complaint produces exactly one `user_feedback` row
with `rating -1`, `metadata.sentiment = negative`, `metadata.about = vana`, the athlete's words
verbatim and the conversation id. Taste comments write nothing. Two defects were found and fixed
getting there: the conversation id was always null in general mode, and Vana twice said the feedback
was saved without calling the tool.

- [ ] Praise produces one row with positive sentiment; a suggestion produces one with about = suggestion
- [ ] Both have eval cases in `scripts/vana-eval/personalization.ts`, reading the rows back
- [ ] A brand-new user's first conversation shows the feedback prompt once; the second does not
- [ ] That first-conversation path has never been exercised at all — verify it live, not by reading the code
- [ ] The acknowledgement's length is settled (see below) and its eval case passes

## The one open line: the acknowledgement will not stay short

The row lands correctly every time. The reply runs to three to five sentences and troubleshoots —
apologising, naming what went wrong, promising to do better. The user story is "I want Vana to
acknowledge feedback in one line and stop, so that I am not troubleshot when I was venting", and it
is the diagnosing and the promising that cause that harm; the sentence count was only a proxy for it.

Three prompt variants were tried on 2026-09-10:

| Prompt | Result |
|---|---|
| "then ONE sentence acknowledging it is saved" | 3 sentences, promises a fix |
| The same plus an explicit list: no apology, no promise, no explanation | **5 sentences** — the list primed the behaviours it forbade |
| Positive framing: "like taking a note in a meeting" | 3 sentences, first one correct, then troubleshooting |

It got worse **because the Doll works**: with the complaint now in MEMORIES, Vana reads that she has
been corrected before and apologises for it.

**Recommended: a server-authored acknowledgement.** When `saveFeedback` succeeds the server appends a
fixed, content-managed line and the model is told to say nothing about the feedback at all. The
precedent is in this same file — the first-conversation `feedback_prompt` part is server-authored
precisely so "the model never sees or writes it, so it cannot be paraphrased away". Deterministic,
keeps the right words, removes the priming problem because she is asked to be silent rather than
brief, puts the copy in the content system, and costs fewer output tokens. The case to handle is a
message that is both a complaint and a question, where she still answers the question.

**Not a clamp.** A clamp keeps whichever sentence came first. In the best run that was "Your feedback
is saved"; in the worst it was "You're right, and I apologize", with the acknowledgement last. A clamp
would preserve the apology and delete the part that matters.

The alternatives, if the recommendation is rejected: relax the criterion to two sentences, or route
this one turn to a stronger model — the eval now prices it at about 9.6k in and 170 out.

**Full history:** `../archive/issues-2026-09-10/01-verify-feedback-lands.md`
