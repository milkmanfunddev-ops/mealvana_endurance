# 121-019 · Delete a Pro account: the confirm says the subscription keeps renewing, but the RevenueCat customer is removed

- kind: followup-test
- status: open
- ticket: 121
- run: w34-20260925T2320Z
- screen: Delete account confirm
- decision: 

**Steps.**
1. A Pro account (Test Store Annual, ticket 121's C): Settings → Delete account; read the confirm, tap Manage subscription once, then Delete.
2. After the delete, read RevenueCat for the customer and its subscription.

**Expected.**
The confirm's "Deleting your account does not cancel your subscription. It keeps renewing…" matches what happens: on a store subscription the renewals must still map to something, or the copy changes. Ticket 121 saw the customer answer resource_missing 6 s after the delete (db-rc-C-after-delete.txt), with the Test Store subscription active until 00:35Z. Manage subscription's behaviour for a Test Store plan was not tried.

**Actual.**
Not run (look-around, ticket 121).

**Evidence.**
- runs/121/44-C-settings-delete-confirm.png
- runs/121/db-rc-C-after-delete.txt

**Decision quote.**
> 

**Triage.**

