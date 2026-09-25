# 88-001 · Ask Vana on a new install starts a second general conversation for today and pays for a new opener

- kind: bug
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Ask Vana sheet
- decision: 

**Steps.**
1. Retest of 15-004. App data cleared on wave-pool-1; test@test.com already had today's general conversation `d17ba332` (13:36:59Z, context_day 2026-09-25, made on another simulator).
2. Sign in, open Food, tap Ask Vana (19:53:20Z).
3. Read vana_conversations and vana_calls.
4. Repeat on the same install after killing and relaunching the app (20:32Z).

**Expected.**
One general conversation per person per day (VS-5, `VanaAmbientConversation`): the sheet continues today's conversation `d17ba332` and spends no new opener.

**Actual.**
Step 2 created a new general conversation `0aeabaa0` (context_day 2026-09-25) and streamed a paid Haiku opener (vana.opener.general, $0.0213, 19:53:25Z). Conversations > Ask Vana then lists two "Quick question" rows for Sep 25. The same install after a kill reopened `0aeabaa0` with no new opener (step 4 is fine). Cause, read from the code: the day's conversation id lives only in the device's `vanaAmbientStore` (`vana_ambient_conversation_controller.dart` reads `vanaAmbientStoreProvider.read(userId, day)`); `context_day` on the row is the athlete-context cache (`context-cache.ts`), not a pointer. So every new install, reinstall or second device starts its own "today" conversation and pays for an opener. Ticket 89 on the other simulator did the same at 20:13:14Z (`29897d1c`). Product question: should a sign-in on a new device find today's conversation on the server?

**Evidence.**
- runs/88/db-02-15-004-general.txt: `d17ba332` and `0aeabaa0`, both context_day 2026-09-25, and the two opener rows in vana_calls.
- runs/88/07-ask-vana-sheet-8s.png: the new opener.
- runs/88/db-29-15-004-after-relaunch.txt: after the kill, no third conversation from this install.
- runs/88/127-15-004-ask-vana-after-relaunch.png

**Decision quote.**
> 

**Triage.**

Held for the SSOT pass (Lee, 2026-09-25): a product question, no ticket until it is ruled on the page.
