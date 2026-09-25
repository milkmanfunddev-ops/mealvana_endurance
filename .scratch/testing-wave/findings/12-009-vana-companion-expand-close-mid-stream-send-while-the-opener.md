# 12-009 · Vana companion: expand, close mid-stream, send while the opener streams, and the pro_required answer on screen

- kind: followup-test
- status: closed
- ticket: 12
- run: w4-20260924T0417Z
- screen: Vana
- decision: 

**Steps.**
1. Open Ask Vana from the timeline.
2. Try: the expand button; Close while the opener is still streaming, then reopen; type and send while the opener streams; tap a suggested chip ("What should I eat tonight"); send with the network off.
3. On an Admin with no Pro (12-001), open Ask Vana and send one message.

**Expected.**
The companion keeps one conversation, never loses a sent message, and on 403 `pro_required` shows the athlete what mp-416 implies (not a generic error); record exactly what it shows.

**Actual.**

**Evidence.**
- runs/12/09-vana-open.png, runs/12/10-vana-opener.png, runs/12/12-vana-reply.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).

Run by retest ticket 88 (run w29-20260925T1949Z, build e3367d2c): fail, filed as 88-022, 88-024; closed here, the new Findings carry it.
