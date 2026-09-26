# Persona accounts

One persona per account, permanent. Memories and Voodoo Doll state must never bleed between
Scenarios, so each Scenario pins the single account whose persona it runs as, and no account
ever plays two personas.

Credentials never live in this directory. They go in the secrets directory, which is `secrets/`
at the repo root, gitignored and never committed. This file records account slugs, personas,
setup state, and the Scenarios each account serves.

## Rules

- One persona per account. A new athlete situation, such as dense, sparse, vegetarian, or
  offseason, gets a new account spawned for it. It never gets a re-skin of an existing account.
- An account is set up before its first round. Pro is granted via the subscription provider,
  the wallet is topped, and the account's data is shaped to its persona, so the Gate never
  refuses the Examiner mid-round.
- The account a Scenario runs as is pinned in the Scenario file and mirrored in the corpus index
  in `README.md`.

## Accounts

| Slug | Persona | Scenarios | Setup notes |
|------|---------|-----------|-------------|
| `judging-1` | Everyday-name dev test account; actually a dense vegetarian triathlete in an IRONMAN build (see below) | pilot + the corpus's dense/race-persona Scenarios until the corpus conversion pins them | Pro to 2027-09-15 (RevenueCat promotional, pre-dates `pro_grants`); wallet topped to $50 2026-09-26; persona fields set same day |

### `judging-1` — the persona in full

The existing dev test account (the "Dev admin" row in `secrets/test_accounts.md`; it is also
`is_admin`, which the Gate would honor anyway — the Scenario runs on its real Pro, not on that).
Its history is long: months of Vana conversations, feedback and plans from testing waves. That
is part of this persona, not noise to clean — an athlete who has talked to Vana before. What the
Examiner's CONTEXT block will hold:

- **Athlete**: first name Xuan. Vegetarian, no allergies, gut training high.
- **Home**: Baton Rouge, LA (`America/Chicago`), set 2026-09-26 — consistent with the Baton
  Rouge Half Marathon in the account's past events. The weather and HOME lines read from here.
- **Training**: dense triathlon build. 17 sessions in the next 7 days (swim/bike/run mix, roughly
  3 a day on quality days); the event ahead is IRONMAN Cozumel, 2026-11-23 (the RACE line, ~8
  weeks out at setup). Sessions are seeded about a week ahead only — far-future weeks are empty,
  so Scenarios that need a longer runway must say so before their round.
- **Goals** (`onboarding_surveys`, set 2026-09-26): "Finish IRONMAN Cozumel strong", "Fuel the
  dense training weeks without falling behind on protein".
- **Plan state**: a confirmed plan for the current week on the Plan tab (status `confirmed`,
  batch history from prior weeks archived). Daily macro targets come from the daily-macros
  engine, which fills the week on demand (`ensureWeekTargets`) — one explicit target row is not
  a gap.
- **Wallet/Pro at setup** (2026-09-26): Pro active to 2027-09-15 in both `user_entitlements`
  and RevenueCat; wallet balance topped to 50,000,000 micro-dollars ($50) of model cost, on top
  of the monthly allowance window (dev grants 6,000,000/month while Pro is live). A
  ~22-Scenario round of ~20 turns draws roughly 5–7M micro-dollars, so the top-up alone covers
  several rounds; `setup-account.mjs setup` re-tops to target when a round report shows the
  balance low.

A future dense/sparse/vegetarian/offseason persona account is a NEW account, spawned by the
recipe below and shaped to that situation. This account keeps whatever Scenarios its persona
matches; the corpus index in `README.md` is the arbiter of which.

## Spawning the next persona account (the recipe)

Everything except the persona shape is one command; the shape is per-account SQL.

1. **Create the account** on dev (sign-up through the app or the auth admin API), sign it in
   once so the `public.users` row exists, and record the credentials in
   `secrets/test_accounts.md` — never here.
2. **Pro + wallet** (idempotent, safe to re-run, dev only):

   ```
   node eval/setup-account.mjs setup <email>            # 365 days of Pro, wallet topped to $50
   node eval/setup-account.mjs status <email>           # read-only check
   ```

   The script grants Pro through RevenueCat (the only thing the server Gate reads, via the
   webhook-maintained `user_entitlements` cache), waits for the cache to go live, and tops the
   wallet to target through the `grant_credits` RPC (ledger reason `grant_admin`, an
   `eval-judging-topup:*` ref). Secrets come from `SUPABASE_ACCESS_TOKEN` /
   `REVENUECAT_SECRET_KEY` or the main clone's `secrets/`.
3. **Shape the persona** with SQL through the Management API `database/query` endpoint against
   dev — the fields Vana's CONTEXT block reads (`_shared/vana/context.ts`): `users`
   (`first_name`, `dietary_preference`, `allergies`, `gut_training_level`, `home_city`,
   `home_lat`, `home_lon`, `home_timezone`), `activities` (the coming week's sessions),
   `events` (the race), `onboarding_surveys.goals` (note `completed_at` is NOT NULL), and a
   meal plan in the state the Scenarios assume. For `judging-1` the writes were:

   ```sql
   update public.users set home_city='Baton Rouge', home_lat=30.4515, home_lon=-91.1581,
     home_timezone='America/Chicago' where id='<uid>';
   insert into public.onboarding_surveys (user_id, goals, completed_at) values ('<uid>',
     '["Finish IRONMAN Cozumel strong", "Fuel the dense training weeks without falling behind on protein"]'::jsonb, now())
     on conflict (user_id) do update set goals = excluded.goals, updated_at = now();
   ```

   (Training, diet and the plan already matched the persona, so they were left as found.)
4. **Verified 2026-09-26 (wave 2): the request streamed a full reply, no `pro_required`/`insufficient_credits`, ledger reserve settled at real cost**: sign the account in on the dev auth API and POST
   one message to the deployed `vana-chat`
   (`https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/vana-chat`, body
   `{message, kind: 'general'|'meal_planning', timezone}`) — expect NDJSON stream lines ending
   in a `done` line, and neither `pro_required` (403) nor `insufficient_credits` (402). Then
   `node eval/setup-account.mjs status <email>` and write the row into the table above.

Undo: the Pro grant is revocable in the RevenueCat dashboard (or the v2 API
`actions/revoke_granted_entitlement`); the wallet top-up needs no undo (it is dev-only budget).
