# Test accounts (testing-wave)

<!--
The shape of secrets/test_accounts.md. The real file lives ONLY at
  /Users/leemartin/development/mealvana_endurance/secrets/test_accounts.md
(gitignored; worktree agents read and append to it by that absolute path). This template holds
no passwords and is the only copy that is committed. Every account is on DEV; nothing here is
ever used against prod.

Agents type these passwords themselves (Lee, 2026-09-23; this repo only, the QA repo's rule is
unchanged). Never paste a password into a Finding, a commit, a report or a console excerpt.
-->

## Dev admin

| Field | Value |
|---|---|
| Address | test@test.com |
| Password | <fill in> |
| Notes | Admin: skips the paywall screen only (mp-416). |

## Kroger shopper login (Lee's, certification environment)

| Field | Value |
|---|---|
| Address | <fill in> |
| Password | <fill in> |
| Notes | For the Kroger sign-in sheet only. |

## Apple sandbox testers

| Address | Password | Region | Notes |
|---|---|---|---|

## Created accounts

One row per account an agent signs up, added the moment signup succeeds and updated when its
state changes. Address: `lee+e2e-<ticket>-<UTC time>@rightpathprogramming.com`.
bought: nothing, trial, monthly, annual, coach code, athlete code, grant.
when: the UTC time of the purchase or grant, empty if nothing was bought.
state: new, paid, lapsed, deleted, delete-failed.

| Address | Password | Bought | When | State | Ticket / run |
|---|---|---|---|---|---|
