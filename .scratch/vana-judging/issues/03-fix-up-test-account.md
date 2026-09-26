# 03: Fix up the judging test account

**What to build:** The first Scenario account — the existing test account (test@test.com) —
made ready for judging: it holds Pro (via a Grant through the subscription provider, since the
Gate is server-side and refuses anything else), its wallet has budget so the monthly AI budget
never refuses the Examiner mid-round, and its dev data is shaped to one documented persona
(the athlete situation its Scenarios assume). Record the persona in `/eval`'s accounts map and
the credentials in the secrets directory. Later persona accounts (dense, sparse, vegetarian,
offseason) are spawned by the same recipe as the corpus grows — document the recipe.

**Blocked by:** 01 (scaffold — the accounts map lives there).

**Status:** ready-for-agent

- [ ] The account holds Pro with a live Expiry and the wallet shows budget available
- [ ] A hand request to the chat function with the account's JWT streams a reply (no
      `pro_required`, no `insufficient_credits`)
- [ ] The account's persona (training, diet, plan state) matches what `accounts.md` documents
- [ ] Credentials are in the secrets directory, not in `/eval`
- [ ] The grant/top-up recipe is written down for spawning the next persona accounts
