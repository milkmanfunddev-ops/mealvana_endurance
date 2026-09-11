# 10: The screen says Kroger has no match before anything was searched

**What to build:** The screen does not claim a search result that doesn't exist yet. It
distinguishes lines not searched yet from lines Kroger's catalogue had no match for. The first kind
is waiting for "Find product matches". Only the second kind is "You add these on Kroger".

Found on the 2026-09-10 simulator pass (`../device-verification.md`, defect 3; screenshot
`../evidence/2026-09-10/02-screen-header-dark-connected.png`).

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent (filed 2026-09-10)

## What happens

`KrogerDraft.unmatched` (`lib/features/kroger/domain/kroger_models.dart`) is every included line
with `product == null`. That covers "searched and nothing found" and also "not searched yet". So on
a fresh draft, before any matching run, all 13 lines sit under **"You add these on Kroger"** with
the note **"Kroger's delivery catalogue has no match for these. Add them yourself once you are on
Kroger."** That is untrue until a search has run.

The same thing happens after a matching run that failed partway: lines it never reached read as
"no match".

## Direction

Record per line whether a search has answered for it. For example, a persisted flag set by
`matchAll` and `search` when Kroger returned nothing, defaulting to false for drafts stored before
the change. Then:

- Lines with no product and no answer yet go in their own group, with copy that promises nothing
  (such as "Not matched yet"). "Find product matches" is the action for them.
- "You add these on Kroger" and its note show only for lines Kroger actually had nothing for.
- Any change to a line's product, Location or query clears its answer.

New copy goes in as content keys (`lib/features/content/domain/content_keys.dart` plus
`assets/config/content_defaults.json`), never as literals.

## Acceptance

- [ ] On a draft with no matching run, no line is described as having no match on Kroger
- [ ] After a run, only lines whose search returned nothing appear under "You add these on
      Kroger"
- [ ] A run that fails partway does not mark unreached lines as unmatched
- [ ] A draft stored before this change loads without a migration and reads as "not matched yet"
- [ ] Controller tests go through the real notifier; the screen test asserts both states
- [ ] Goldens updated where the grouping changes
