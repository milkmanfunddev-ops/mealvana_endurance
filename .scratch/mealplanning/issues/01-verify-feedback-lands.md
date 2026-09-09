# 01: Verify feedback lands from Vana

**What to build:** An athlete tells Vana "you keep suggesting fish" in a real dev conversation. Vana thanks them in one plain sentence, does not troubleshoot, and a feedback row exists with negative sentiment, about Vana, the message in their words, and the conversation id. The same for praise and for a suggestion. The first conversation of a fresh user shows the one-time "have feedback? just type it here" prompt after the opener and never again. Whatever this finds broken gets fixed in the same ticket. Nothing here is built on a self-report: the rows are read back from the table.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] A complaint, praise, and suggestion each produce one feedback row with the right sentiment, about-field, message, and conversation id
- [ ] Vana's reply after each is one sentence, no chips, no troubleshooting
- [ ] Taste comments ("not those") and "other options" do not produce a feedback row
- [ ] A brand-new user's first conversation shows the feedback prompt once; the second conversation does not
- [ ] The save-feedback path has a live eval case in the vana-eval scripts recording token cost
- [ ] Anything found broken is fixed and the uncommitted feedback work on dev is committed
