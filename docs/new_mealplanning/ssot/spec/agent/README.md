# spec/agent/ — the Vana agent contract

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** A fourth truth family this feature needs
and the fueling SSOT does not: the contract between the **model** (which phrases and handles ambiguity) and
the **engine** (which decides). The QA repo's nearest precedent is `spec/recommendation/generate-plan.md` —
an invariant contract that says what any correct implementation must guarantee and nothing about how.

| File | Owns |
|---|---|
| [`guardrails.md`](guardrails.md) | the hard invariants H1–H10 (never invent, tools enforce, confirm is a word…) and the soft ones |
| [`voice.md`](voice.md) | the moment-based voice contract: registers, caps, copy rules, the refusal lines |
| [`tools.md`](tools.md) | the tool inventory by conversation kind: what each may do, its side effects, its part |
| [`wire-protocol.md`](wire-protocol.md) | the NDJSON envelope, models, limits, rate limits, persistence — a digest of `02-contract.md` §5 with the contract-level rules |

The prompts themselves (`persona.ts` CORE / PLANNING_PROMPT / GENERAL_PROMPT / OPENERS) are the **reference
rendering** of this family — mirrored verbatim between prototype and edge ("edit here AND there"). A prompt
change that alters a contract row here is a versioned change; a prompt change that only rewords is not.

**Executable form:** `scripts/vana-eval/` (13 canned conversations against dev, asserting the voice contract
and the fork/milestone rules; bills spend, run by hand) + `vectors/agent/clamp-sentences.json` (the one pure
function).
