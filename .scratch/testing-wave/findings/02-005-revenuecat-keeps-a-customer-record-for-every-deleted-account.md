# 02-005 · RevenueCat keeps a customer record for every deleted account; nothing removes it

- kind: idea
- status: open
- ticket: 02
- run: w2-20260923T1442Z
- screen: none
- decision: 

**Steps.**
The idea: account deletion (the delete-user function, or the sweep) also deletes the RevenueCat
customer, or the record says why it is kept (purchase history, refunds, fraud).

Seen in this run: after both deletes, `GET /v2/projects/…/customers/<deleted id>` still returns
the customer (A: e7ab5001-…, no purchases; A2: a816e3ba-…, a Test Store subscription), with
aliases, platform, country and last-seen app version. The customer id is the deleted Supabase
user id. "Deletes your account and all of its data" is not true of this record.

**Expected.**
A decision on whether a deleted account's RevenueCat customer is deleted.

**Actual.**
Both customers remain.

**Evidence.**
- runs/02/revenuecat-A-after-delete.json
- runs/02/revenuecat-A2-after-delete.json

**Decision quote.**
> 

**Triage.**
