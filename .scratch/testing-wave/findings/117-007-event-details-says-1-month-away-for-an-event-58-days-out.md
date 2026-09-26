# 117-007 · Event Details says 1 month away for an event 58 days out

- kind: bug
- status: open
- ticket: 117
- run: w40-20260926T1052Z
- screen: Event Details
- decision: 

**Steps.**
1. test@test.com, Events, open IRONMAN Cozumel (Monday, November 23, 2026) on Saturday, September 26.

**Expected.**
About two months away (58 days), or "8 weeks away".

**Actual.**
It reads "1 month away". The count appears to floor whole months; 58 days reads as one month.

**Evidence.**
- runs/117/42-event-cozumel.png

**Decision quote.**
> 

**Triage.**

