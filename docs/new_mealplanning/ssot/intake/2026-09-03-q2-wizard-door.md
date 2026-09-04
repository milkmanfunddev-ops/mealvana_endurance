type: ruling-request
bundle: intent@v1

## Why this matters
Blocks whether a second, structured entry surface (the 6-step wizard) ever gets built, or whether its virtues
(macro visibility, coverage-scope fork) permanently live inside chat instead.

## The question
Xuan authored a full 6-step wizard scenario (training schedule → goal → diet/allergies → meal-prep style →
include-breakfast → confirm). Does it ship — as a first-plan-only alternate door, as the default for new
athletes, or never — or does chat absorb its virtues permanently (as it already has: the batch-cooking fork,
the coverage-scope fork, and macro visibility all now live inside chat, no wizard)?

## Options
- **No wizard, ever (interim, current build).** Chat absorbs the wizard's useful forks one at a time as they
  come up naturally in conversation. Simpler surface area; matches Testing Theme findings that users don't start
  with chat unprompted less than they don't want a form.
- **Wizard for first-ever plan only.** A one-time structured onboarding, then chat for every plan after.
  Front-loads the "known answers" Xuan's scenarios assume, at the cost of the exact anti-pattern §2.1/§2.2
  reject (asking what the context already answers, e.g. training schedule and diet — both already in the
  profile).
- **Wizard always available as an alternate door.** Higher build cost, no evidence yet it's needed.

## Recommendation
Keep no wizard in v1; revisit only if Phase 1–4 user feedback (post-build) shows athletes bouncing off
unstructured chat specifically for lack of a guided first plan.

## Gates
Any wizard build; whether the intro-card / opener reversal (see the opener-reversal ruling request) forecloses
this further by making the opener itself the "structured" first contact.

## Suggested spec home
`spec/intent/vana-mealplanning-chatbot.md` §2.8; `OPEN-QUESTIONS.md` Q-2.
