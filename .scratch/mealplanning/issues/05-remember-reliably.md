# 05: Remember reliably

**What to build:** An athlete says "remember that Wednesdays are chaos" and it sticks: the remember tool fires every time the person asks, and the next conversation uses it unprompted. The prompt is sharpened so the model also calls remember on its own when the margin-note rule is met and never for this week's plan or a Fact it already has. Writes are deduped: a sentence near-identical by embedding to an existing Memory is not inserted; the existing row's confirmed date is refreshed instead. The duplicated debrief learning on dev is the fixture.

**Blocked by:** 02 Vana test harness

**Status:** ready-for-agent

- [ ] Server seam: writing a sentence near-identical to an existing Memory inserts nothing and refreshes the existing confirmed date; a distinct sentence inserts
- [ ] The duplicated debrief learning, replayed through the writer, yields one row
- [ ] Live eval: "remember X" writes exactly one Memory with source conversation
- [ ] Live eval: a Memory saved in one conversation is used unprompted in the next
- [ ] Live eval: "I want 5 dinners this week" writes no Memory
