type: spec-erratum
bundle: data-integrations@v1 (field-map/events capture) — app-side conformance
filed: 2026-09-18 by qa-33, from qa-70's premium-trial probe

# TP events: unguarded response-type casts, and a dead method holding the observed shape

## Why this matters
qa-70's premium-trial probe (`runs/2026-09-18-tp-premium-trial-probe.md`, `qa/real-payload-corpus`)
found `/v2/events/next` returning a **full JSON object for one athlete and a BARE STRING for
another** — same endpoint, different top-level JSON *type* by account state. Our client casts the
decoded body without checking its type. Chased 2026-09-18; the result is narrower than it first
looked, and the narrowing matters.

## What is actually true
1. **The method with the observed risk is DEAD CODE.**
   `TrainingPeaksApiClient.getNextEvent` (`training_peaks_api_client.dart:274-297`) ends with
   `return json as Map<String, dynamic>;` — a bare string decodes to `String` and the cast throws.
   But `getNextEvent` and its only wrapper `TrainingPeaksSyncService.syncNextEvent` (`:609`) have
   **no callers anywhere in `lib/`** (verified by grep, 2026-09-18). Nothing invokes them, so the
   observed shape reaches nothing today. It is a loaded gun on a shelf, not a live defect —
   and `/v2/events/next` is exactly the endpoint a future "next race" feature would reach for.
2. **RESOLVED 2026-09-18 (qa-70, four-cell matrix, `f878705`): the live path is observed SAFE,
   and the shape rule is not what we first said.** `/v2/events/{date}` returned a **LIST in every
   cell** — `list[1]` with an event, `list[0]` without, on both athletes — so
   `getEventsForDate`'s `as List` holds on all observed evidence. And the object-vs-bare-string
   behaviour is **confined to `/events/next`**, where it tracks **whether an upcoming event
   exists** (object when one does — Lee on both runs, the trial after an event was created; bare
   string when none — the trial before it), **not account state** as this file and the corpus
   addendum first inferred from two athletes. Net: hazard is latent in the DEAD `getNextEvent`
   reader only. Original reading kept below for the trail.

   **The LIVE path carries the same assumption, unobserved (superseded by the above).**
   Events actually import via `syncEvents` (`:537`) → `getEventsInRange` → `getEventsForDate`
   (`training_peaks_api_client.dart:304-325`), which does
   `jsonDecode(response.body) as List` then `.cast<Map<String, dynamic>>()`. Both are unguarded:
   a bare-string body throws on the cast, and a list of strings throws lazily when elements are
   read. **We have NOT observed a bare string from `/v2/events/{date}`** — only from
   `/v2/events/next`. So this is an untested assumption on the live path, not a proven defect.
3. **Failures are swallowed, not surfaced.** Both `syncEvents` and `syncNextEvent` wrap everything
   in `catch (e) → TrainingPeaksEventSyncResult.error(...)`. No caller reads the error. So the
   failure mode is *events silently never import* for an affected account state — the
   "app reports a state that isn't true" class, alongside the stale `last_sync_status`.

## The cheap decisive test (not run — needs Xuan's token, and the trial is time-boxed)
Extend `scripts/tp-payload-probe.sh`'s sweep to call `/v2/events/{date}` on BOTH athletes, for a
date known to hold an event and a date known not to, and print the top-level JSON type. That
settles whether the live path can receive the shape the dead path demonstrably can. If it can, the
severity jumps from latent to live-for-some-accounts.

## The smallest corrections
1. Type-guard both decodes: a response that is not the expected shape returns empty/null rather
   than throwing — never a bare `as List` / `as Map` on a provider body.
2. Delete `getNextEvent`/`syncNextEvent`, or wire them; dead code that encodes a wrong assumption
   about a live endpoint will be resurrected by the next person who needs "next race".
3. Producer-shape vectors for events must carry BOTH top-level shapes (object and bare string), and
   the vector runner must tolerate a non-object root — recorded in the vectors note on
   `qa/data-integrations-v1.1` (b5f1c13).
4. Spec: `field-map.md`/`payload-usage-map.md` should state that a provider response's top-level
   TYPE can vary by account state. Nothing in the family says that today; every producer contract
   is written as if the shape were fixed per endpoint.

## Gates
- Whether this is v1.1 scope or the corpus round: it needs no captured payload for corrections 1–2
  (the code is wrong either way), but correction 3 needs the events exemplars (corpus C8).
