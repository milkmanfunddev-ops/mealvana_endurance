# Rulings on the 2026-09-28 review

Lee, in the terminal, 2026-09-28, walking section 2 of `review-20260928.md`.

## Standing ruling: no more retests

"I just want to deal with errors at this point and not do retests. I want to focus on fixing the errors that we have found."

- Retest drafts 143 to 161 stay in `retest-drafts/`, not moved to `issues/`. No retests get written for fix tickets 126 to 132.
- The 147 bugs in 3a and 3b stay `triaged` (fixed in code, not device-verified).
- Ticket 114 (Describe and photo retest) is not run. The testing-app rebuild, IMPROVEMENTS #82, #98 and #100, and ticket 140 item 6 (sandbox cancel) are dropped with it.
- Test tickets 13 (Apple sandbox, Lee's iPhone) and 22 (Kroger certification login) stay parked.

## Decisions

1. **Wave 43 landed.** Merge `647cfcac`, no conflicts, 3139 tests green. Closed in `86fda48e`. Not pushed.
2. **Drafts live only in Vana's chat and never leak out** (88-018, 89-006). "You either confirm or you don't." A draft is reachable only through its conversation. 88-018 needs no fix: fix 126 labels the conversation rows.
3. **Use this plan again confirms straight away** (89-006). It asks "Replace this week's plan with this one?" and on Yes the copy becomes this week's confirmed plan and its shopping list is rebuilt. It never creates a draft. This changes mp-675, which the SSOT still has to record.
4. **The three plain bugs from 3c get fixed:** 88-001 (a second general conversation per day), 88-005 (Browse writes into an archived plan; mp-675 makes a replaced draft read-only) and 89-012 (no Plan tab menu when there is no plan).
5. **CI contract (item 10):** Lee chose to drop the carb-loading flow from M1, but the test was already green (15/15 on 2026-09-28; vana-judging's `093d0fef` fixed it). No change. The wider question is review-queue CI-001.
6. **Garmin orphans `dad6fb42…`, `1df3fb7b…` (item 12):** leave them. Closed.
7. **Prod migrations (item 13):** a release-day checklist, unchanged.
8. **Servings (item 14, 135):** editing a 2-serving log's items keeps servings at 2.
9. **Favorite (item 15, 136):** a meal that is already a favorite shows "In favorites" in place of Save as favorite. It never makes a duplicate.
10. **Barcode (item 16, 136):** typed entry accepts only 8, 12, 13 or 14 digits. The hint and the error say so.
11. **Draft's offline shopping copy (item 17, 133):** hidden. There is no shopping list for a draft.
12. **Kroger (item 18, 133):** after a successful connect from Add to cart, the app goes straight on to matching and the send.
13. **Coach code (item 19, 140):** a code reopens a pairing the coach declined or archived. The refusal copy is rewritten for the cases still refused ("asked this coach to pair" goes).
14. **Xuan's items (items 20, 21):** queued for Xuan in `.scratch/ssot/review-queue.md`: CS-6 month sheet, light-theme accent contrast, the `validateDuringTotals` 1.1 cap, the override info icon, and 112-009, 116-009 and 117-003. Nothing changes until she answers.
