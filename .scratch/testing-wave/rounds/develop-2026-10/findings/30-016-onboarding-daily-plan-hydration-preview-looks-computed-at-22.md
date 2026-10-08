# 30-016 · Onboarding daily-plan hydration preview looks computed at 22 C / 50 % where the hydration spec's ruled fallback is 20 C / 60 %

- kind: followup-test
- status: triaged
- ticket: 30
- run: w3-20261008T1255Z
- screen: Onboarding, Your daily plan (preview)
- decision: review queue (PREVIEW-HYDRATION-001: which conditions the preview's hydration line uses)

**Steps.**
1. Onboarding to "Your daily plan" with account A's answers (runs/30/notes.md, 30b-2). 2. Read the fluid and sodium per hour. 3. Compute the engine's output at 20 °C / 60 % and at 22 °C / 50 %.

**Expected.**
The preview's hydration numbers use the spec's ruled fallback conditions, or a ruling says which conditions it uses.

**Actual.**
Filed by the wave lead from runs/30/notes.md (30b-2, unfiled judgment call). Account A's preview showed fluid 768 ml/hr and sodium 634 mg/hr; at the ruled fallback (20 °C, 60 %) the engine would give about 721 / 595. The ruling's wording covers failed weather fetches and the preview never fetches, so whether the preview must use the fallback is a product question (triage). Unverified: read `lib/features/onboarding` and the hydration engine's defaults, then compute both.

**Evidence.**
- runs/30/notes.md (30b-2 paragraph: the numbers and the spec quotes checked)

**Decision quote.**
> 

**Triage.**

