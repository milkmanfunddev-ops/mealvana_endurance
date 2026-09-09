# 01: Verify feedback lands from Vana

**What to build:** An athlete tells Vana "you keep suggesting fish" in a real dev conversation. Vana thanks them in one plain sentence, does not troubleshoot, and a feedback row exists with negative sentiment, about Vana, the message in their words, and the conversation id. The same for praise and for a suggestion. The first conversation of a fresh user shows the one-time "have feedback? just type it here" prompt after the opener and never again. Whatever this finds broken gets fixed in the same ticket. Nothing here is built on a self-report: the rows are read back from the table.

**Blocked by:** None (can start immediately)

**Status:** eval cases written; live verification not run (2026-09-09)

- [ ] A complaint, praise, and suggestion each produce one feedback row with the right sentiment, about-field, message, and conversation id
- [ ] Vana's reply after each is one sentence, no chips, no troubleshooting
- [ ] Taste comments ("not those") and "other options" do not produce a feedback row
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

