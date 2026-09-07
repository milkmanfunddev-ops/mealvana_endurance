---
name: intake-handoff
description: Turn brainstorming / code + data analysis done in the app repo into atomic, typed intake files that the ops side files into Notion — invoked when asked to "hand this off to ops", "prep these for the ops intake", "write this up as bug reports / feature requests for ops", or after an analysis session that surfaced bugs, feature ideas, decisions, or instrumentation gaps. Splits the findings into one-item-per-file, assigns a valid `type:` from the ops contract, and drops each file into ../ops/data/{bug-reports,feature-requests}/ for the ops `intake-pipeline` to file. Never writes to Notion; never does the ops side's dedup / corroboration / roadmap / impact work.
---

# Intake Handoff — Producer (app side)

## Purpose
This skill is the **producer** half of a two-repo contract. You (an agent in the `app/` repo) just did analysis or brainstorming; this skill turns that into clean **input** for the ops side. The ops repo has the matching **consumer** — its `intake-pipeline` skill scans the drop folders, routes each file, and files it into Notion behind one human gate. You produce; ops files. Stay on your side of the line.

**The line (do NOT cross it):** no Notion access, no dedup against Notion, no Problem-Statement corroboration, no Roadmap mapping, no Impact/Status/Priority. If you're tempted to look something up in Notion, stop — that's the ops pipeline's job. Your job is to make each finding *fileable without the ops agent having to re-derive anything.*

## The contract is in ops — read it every run
`../ops/data/INTAKE-CONVENTIONS.md` is the **single source of truth** for the file format. **Read it at the start of every invocation** and follow it — do not restate or hardcode the format here (that's how the two sides drift). This skill is deliberately thin: it's the *workflow* (split → type → write → self-check); the *format* lives in the contract.

From the contract you get: the valid `type:` values, the `driver:` values, the per-type required fields, the file-naming rule, and the folder-routing rule. If anything below disagrees with the contract, **the contract wins** — and flag the mismatch so we fix one place.

## Steps

### 1 · Split the analysis into atomic items
One finding per file. **Never** a batch doc. A single analysis usually yields several items of *different* types — a bug here, a feature request there, an instrumentation gap, a decision to make. Separate them. If two findings are truly one thing, they're one file; if one "finding" is really two independent asks, split it.

### 2 · Assign a valid `type:` — never invent one
Read the `type:` enum from the contract and pick the one that fits: `bug | feature-request | eng-task | experiment | decision | note` (verify against the contract — it's authoritative). **Do not coin a new type** (a `product-insight` / `observation` / `idea` that isn't in the enum will mis-route or get dropped). If a finding doesn't fit any type, it's almost always a `note` (context, not a fileable action) or it should be reshaped into a `decision` (a call to make) or `feature-request` (a capability to build). When genuinely unsure, write it as the closest valid type and say so in the body.

Routing (confirm against the contract): a `bug` file goes in `../ops/data/bug-reports/`; **every other type** goes in `../ops/data/feature-requests/` — the `type:` header does the routing, not the folder.

### 3 · Write the header + body per the contract
Every file starts with the header block the contract specifies — at minimum `type:`, `driver:` (`engineering/analytics-enablement | usability/functional`), and a `## Why this matters` line — plus the per-type fields:
- **bug:** `## Symptom` / `## Expected`, `severity:` (Critical/Major/Minor — blank if unsure), `area:` (ideally `lib/features/…`), `reporter:`, `found:`, `environment:`, `platform:`, evidence, `file:line` code path, suggested investigation.
- **feature-request:** problem → evidence → proposed change → success metric (+ baseline) → instrumentation status → **app surface** (`lib/features/…`) + optional `effort:` 1–5.
- **eng-task / experiment / decision:** per the contract; keep them actionable and reference the item they serve.
- **note:** reference context only — it will not be filed.

Name the file `YYYY-MM-DD-<short-slug>.md`.

### 4 · Label evidence, and only use CLEAN data
Label every metric as **behavioral / quantitative** and keep its **source** (Mixpanel project/board · Supabase · OneSignal) + **date measured** — the ops side corroborates against *interview* evidence separately and needs the two kept distinct.

**Guardrail — exclude dev / simulator / team traffic before you cite a number.** A metric drawn from contaminated data produces a phantom bug (this happened: a "sync bug" was inferred from a Mixpanel↔Supabase mismatch whose flagship user was an **iOS Simulator in the team's city** — retracted). Before a quantitative claim, confirm the dataset excludes dev/simulator/internal/team-city sessions; if you can't confirm it, say so in the evidence line rather than stating the number as fact. (Standing fix tracked as `analytics-exclude-dev-internal-traffic`.)

### 5 · Cross-reference, don't duplicate
When an item overlaps another, **name the sibling file** instead of restating it (e.g. an instrumentation `eng-task` that unblocks a `feature-request` — reference the FR; the ops side folds prerequisite eng-tasks into their parent FR rather than filing clutter). Don't re-file the same finding under two types.

### 6 · Don't over-substantiate
No invented repro steps, no guessed severity/impact stated as fact, no Notion lookups. If a field is genuinely unknown, **leave it blank** — the ops side fills it at filing time. The bar is exactly: a coding agent can act on it and the ops agent can file it without re-deriving. Nothing beyond that.

### 7 · Self-check before you drop the files
Run this checklist; fix anything that fails:
- [ ] One atomic item per file; no batch docs.
- [ ] `type:` is a **valid enum value** from the contract (not invented).
- [ ] `driver:` + `## Why this matters` present.
- [ ] Per-type required fields present (blank only where genuinely unknown).
- [ ] Every metric labeled behavioral/quantitative with **source + date**, and **not** from dev/simulator/team-contaminated data.
- [ ] File in the right folder for its `type:`, named `YYYY-MM-DD-<slug>.md`.
- [ ] Overlaps cross-referenced by filename, not duplicated.
- [ ] No Notion-side work done (no dedup/corroboration/roadmap/impact/status).

Then tell the human which files you wrote, and that they're ready for the ops side to run `intake-pipeline` (or "process the intake folders").

## The FILED stamp is the ops side's — never strip it
When the ops pipeline files an item, it writes a `> **FILED <date> → …**` (or `> **NOT FILED …**`) line as the **first line** of your file — that line is *its* ledger, the way it knows not to re-file. **If you ever edit an already-stamped file, preserve that first line verbatim.** (A stamp was accidentally overwritten once during a rewrite; don't repeat it.)

### Retracting or materially revising an already-filed item
If analysis later **invalidates or changes** an item the ops side already filed (like the retracted dev-traffic "sync bug"):
1. **Keep the `> **FILED …**` stamp line** at the top.
2. Add a `retracted: <YYYY-MM-DD>` (or `revised: <YYYY-MM-DD>`) field to the header and rewrite the body as a `## Retraction` / `## Revision` explaining what changed and why (cite the clean-data reason).
3. **Flag it explicitly to the human** — because the ops `intake-pipeline` skips FILED-stamped files, a retraction won't be auto-detected yet; the human must tell the ops agent to update/close the existing Notion record. (A future ops enhancement: scan FILED files for a newer `retracted:`/`revised:` field and queue the Notion update. Until then, the flag is manual.)

## Guardrails
- **Producer only.** Never touch Notion; never do the ops side's dedup/corroboration/roadmap/impact/status. Read `../ops/` freely; write only into `../ops/data/{bug-reports,feature-requests}/` (and this app repo).
- **Contract is single-source.** Read `../ops/data/INTAKE-CONVENTIONS.md` each run; never duplicate the format here. Contract wins on any conflict; flag mismatches.
- **Valid types only.** Never invent a `type:`; unknown → closest valid type or `note`, and say so.
- **Clean data only.** Exclude dev/simulator/team traffic before citing a metric.
- **Never strip the ops FILED stamp.** Preserve it on any edit; use `retracted:`/`revised:` + a human flag for changes to already-filed items.
- **Leave unknowns blank.** Don't fabricate to fill a field.
