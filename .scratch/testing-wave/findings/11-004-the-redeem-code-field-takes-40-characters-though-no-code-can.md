# 11-004 · The Redeem code field takes 40 characters though no code can be longer than 32

- kind: idea
- status: closed
- ticket: 11
- run: w5-20260924T0840Z
- screen: Redeem code (paywall ⋯ menu)
- decision: 

**Steps.**
1. Redeem sheet: type 45 characters.
2. Idea: cap the field at 32 (the `codes_code_format` check and `MAX_CODE_LENGTH`), so the athlete cannot type a code that can never exist, or keep 40 deliberately (room for spaces) and write that down.

**Expected.**


**Actual.**
The field stops at 40 (`LengthLimitingTextInputFormatter(40)`); the server refuses anything over 32 after removing spaces. A 40-character code is sent and refused as not found, which is the ticket's expected answer, so this is not a bug.

**Evidence.**
- runs/11/08-step2-overlong-typed.png, runs/11/09-step2-overlong-refused.png
- lib/features/subscription/presentation/widgets/redeem_code_sheet.dart (the formatter)
- supabase/migrations/20260921140000_codes.sql (`length(code) between 3 and 32`)

**Decision quote.**
> 

**Triage.**
Fix ticket 81 (the wave lead, 2026-09-25: Lee asked for every bug fix that can be done without him). Closed by the retest after it merges.

Closed by retest ticket 87 (wave 25, build 5e05f8a6): pass, evidence in runs/87/verdicts.md.
