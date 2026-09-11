# 09: A draft saved before ticket 02 is stuck on pickup

**What to build:** Decide whether a Kroger draft that still says `PICKUP` needs a way back to
delivery. If it does, an unsent draft that is not `DELIVERY` becomes one the next time it loads,
and the shopper sees delivery matching as if the draft were new.

Found on the 2026-09-10 simulator pass (`../device-verification.md`, defect 2; screenshot
`../evidence/2026-09-10/06-legacy-pickup-draft-no-delivery.png`).

**Blocked by:** None (can start immediately)

**Status:** needs-triage (filed 2026-09-10): fix, or `wontfix` because it is pre-release data

## What happens

Before ticket 02 a new draft defaulted to `PICKUP`, and the Location picker set it. The dev
account's draft on the simulator was still `modality: PICKUP`, with the Birmingham Spoke chosen
through the old picker. Ticket 04 removed the picker, which was the only thing that ever changed the
Modality, and nothing replaced it. So:

- `setArea` sends `draft.modality` to the `location` action. The server probes the Spoke under the
  curbside filter, gets 0 results (delivery gets 1 or more), and answers `location: null`. The
  shopper reads "Kroger does not deliver to that ZIP code", for a ZIP Kroger delivers to.
- Matching against the stored Location searches curbside and finds nothing.
- Clearing the local draft does not help: it syncs to `kroger_drafts`, and the next load restores
  it from there.

Ticket 02's notes predicted this ("Choosing the Location again sets the modality; ticket 04 removes
the stored-modality question entirely"). The second half didn't happen: the request still carries
the stored Modality.

## Who it affects

Only drafts created before ticket 02 (2026-09-09), and Shop with Kroger has not shipped, so only dev
and internal devices. That is the case for `wontfix`.

## If it is fixed

- When a draft loads with a Modality other than `DELIVERY` and has no receipt, reset it to
  `DELIVERY`, clear the stored Location, and clear matched products and approvals, since products
  are per-Location. Persist it as a local edit, so the normal sync replaces the cloud copy.
- Leave sent drafts alone: the receipt records what was sent and must not change.
- Pickup stays representable in the model and on the wire (ticket 04).

## Acceptance (if fixed)

- [ ] A stored unsent `PICKUP` draft loads as `DELIVERY` with no Location, and matching works after
      a ZIP is entered
- [ ] The corrected draft reaches `kroger_drafts` through the normal sync, and a reload does not
      bring `PICKUP` back
- [ ] A draft with a receipt keeps its Modality
- [ ] The test goes through the real `KrogerController`, starting from a stored JSON draft shaped
      like the pre-02 one
