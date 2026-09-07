type: ruling-request
bundle: intent@v1

## Why this matters
`spec/agent/guardrails.md` H10 and every planning surface currently hard-block race-day fueling generation on
this interim reading; if Xuan meant the scenarios' race-day domain to be in scope, several guardrails and the
day-guidance "Race day" row (which deliberately carries no carb number) would need to change.

## The question
The two AI Scenarios documents (SCEN-S, SCEN-U) use race-day nutrition as their worked example, which predates
or conflicts with the 2026-06-17 scope decision that race fueling stays deterministic, outside the assistant.
Do the scenarios govern **mechanics/tone/loop only** (our interim reading), or does some of their race-day
*domain* content apply to what Vana may say?

## Options
- **Mechanics-only (current build).** Vana may present the deterministic module's numbers in a race-week
  conversation but never generate fueling advice. Safest, matches the explicit 2026-06-17 rationale
  ("if you use AI, it will hallucinate… it doesn't know the protocol"). Cost: some of the scenarios' race-week
  texture (the AI "reasoning" about race fueling) never ships.
- **Scenarios partially govern domain too.** Some race-day content becomes assistant-eligible. Requires deciding
  exactly which claims are safe to hand an LLM and rewriting H10 accordingly — more work, more surface area for
  a wrong number to reach an athlete.

## Recommendation
Keep mechanics-only. The 2026-06-17 decision is explicit and safety-motivated; nothing in the scenarios revokes
it, and the cost of getting a race-fueling number wrong is high enough that the deterministic module should stay
the only source of those numbers.

## Gates
`spec/agent/guardrails.md` H10; the day-guidance "Race day" row; whether a future scenario-driven feature can
ever synthesize race-day carb numbers.

## Suggested spec home
`spec/intent/vana-mealplanning-chatbot.md` §1.3 (fold the ruling in as a dated quote); `spec/agent/guardrails.md`
H10 if anything changes.
