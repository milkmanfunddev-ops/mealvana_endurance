# Test accounts (testing-wave)

<!--
The shape of secrets/test_accounts.md. The real file lives ONLY at
  /Users/leemartin/development/mealvana_endurance/secrets/test_accounts.md
(gitignored). Agents never open it: they reach it only through scripts/testing-wave/cred.mjs,
which types, saves and adds passwords without printing one. This template holds no passwords and
is the only copy that is committed. Every account is on DEV; nothing here is
ever used against prod. The real file may hold sections only another branch uses (the
mealplanning branch's Kroger login); cred.mjs reads them like any other and nothing here needs them.

Agents type these passwords themselves (Lee, 2026-09-23; this repo only, the QA repo's rule is
unchanged). Never paste a password into a Finding, a commit, a report or a console excerpt.
-->

## Dev admin

| Field | Value |
|---|---|
| Address | test@test.com |
| Password | <fill in> |
| Notes | Admin. |

## Patrol account (dev, is_admin)

| Field | Value |
|---|---|
| Address | <fill in, from secrets/integration_test.env> |
| Password | <fill in> |
| Notes | is_admin. If the address also appears in another section: `cred.mjs type <email> --section patrol`. |

## Apple sandbox testers

| Address | Password | Region | Notes |
|---|---|---|---|

## Provider test logins (dev)

One `## ` section per provider the Connected Apps screen can link (cred.mjs reads `## ` headings only), kept here so tickets find them with
`cred.mjs list` and type them with `cred.mjs type <login> --udid UDID` into the provider's web
sign-in sheet. The Address cell holds the provider's username when it is not an email.

## TrainingPeaks test login (dev, Lee's, authorised for testing)

| Field | Value |
|---|---|
| Address | <TrainingPeaks username> |
| Password | <fill in> |
| Notes | Username, not an email. Lee authorised it for connect/sync/disconnect tests (2026-10-07). Used by the connected-apps tickets and to reconnect the dev admin's TrainingPeaks link. |

## Created accounts

One row per account an agent signs up, added the moment signup succeeds and updated when its
state changes. Address: `lee+e2e-<ticket>-<UTC time>@rightpathprogramming.com`.
bought: nothing, trial, monthly, annual, coach code, athlete code, grant.
when: the UTC time of the purchase or grant, empty if nothing was bought.
state: new, paid, lapsed, deleted, delete-failed.

| Address | Password | Bought | When | State | Ticket / run |
|---|---|---|---|---|---|
