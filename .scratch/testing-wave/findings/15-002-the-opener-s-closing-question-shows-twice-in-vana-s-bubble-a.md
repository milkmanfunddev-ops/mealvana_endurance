# 15-002 · The opener's closing question shows twice: in Vana's bubble and again above the choice chips

- kind: bug
- status: open
- ticket: 15
- run: w12-20260924T1712Z
- screen: Vana chat (meal planning), opened from Conversations
- decision: 

**Steps.**
1. Conversations → Meal plans → "This week's plan, Sep 22, 7:08 AM" (`ebac747d`); scroll to the top.

**Expected.**
The opener asks its question once, either at the end of the bubble or as the prompt above the chips.

**Actual.**
The bubble ends "…How much cooking do you want to do this week: batch one or two meals at a time and eat them across the days, or make most nights fresh?" and the same sentence is printed again right under it as the askChoice prompt, above the three chips. The stored message holds it twice: `content` ends with the question and the `tool-askChoice` part's `input.question` is the same text, so the screen draws what was stored; the repeat comes from how the opener was generated (or the client could drop a trailing question that equals the choice prompt). The Sep 16 opener (`1a24f2bf`) does not repeat: its bubble ends on a statement and the prompt "What matters most for this week?" is separate.

**Evidence.**
- runs/15/16-ebac747d-top.png — the question in the bubble and again above the chips.
- runs/15/db-messages-ebac747d.txt — row 1, content ends with the question.
- runs/15/20-1a24f2bf-scroll-5.png — an opener that does not repeat, for comparison.

**Decision quote.**
> 

**Triage.**
