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
| none yet | | | |

The first account is the existing dev test account, verified for Pro and wallet budget before
judging begins. Further persona accounts are spawned as the corpus grows.
