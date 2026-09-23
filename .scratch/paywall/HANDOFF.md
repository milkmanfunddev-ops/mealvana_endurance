# Paywall handoff, 2026-09-23

Read this, then run `/implement-lee paywall`. Store submission is around 25 September; the
paywall opens 1 October. Nothing below is pushed (the branch is 271 commits ahead of
`origin/mealplanning`); pushing is Lee's act.

## Where the build is

- Waves 1 to 6 are merged: tickets 01 to 04, 06 to 09, 11, 12, 14 to 18.
- **Next wave: tickets 19 and 21 together, then 20.** All three were approved in the terminal
  on 23 September (cards mp-611, mp-612, mp-613). Each runs on Opus.
  - **19, one full-screen paywall for everyone without Pro.** The Gate answers open or closed;
    closed is the full-screen paywall with no close. The sheet over the app goes; the glass
    sheet widget stays for Redeem code.
  - **20, read-only plumbing comes out.** It needs 19 first. It deletes the write guard,
    `WriteAccessDenied`, `PlanEndedHost`, `paywallRequestsProvider` and the plan-ended bar,
    plus the `canWrite` / `requireWriteAccess` checks in 37 controllers and their tests.
  - **21, the Subscription screen shows a Grant's source and days left** (mp-558).
- **05, the production products:** held until Lee says "go prod". `scripts/store/asc.mjs` and
  `play.mjs` have 328 uncommitted lines from 21 September. Find out whose they are before
  05 runs. **13, the store checks,** waits on 05 and ends with Lee's phone run on both stores.

## What Lee ruled on 23 September (all in the record, commit 4091406b)

- **No read-only mode.** A lapsed account stays signed in and meets the same full-screen paywall
  as a new one, with Restore, Redeem code, Manage, Sign out and Delete account in the ⋯ menu
  (mp-280, mp-457; mp-460, 493 and 496 follow it). Logging lapsed accounts out was weighed and
  dropped: Restore and a new purchase need the account.
- **The server's paid check on AI calls stays (mp-505).** Lee hoped to drop "complicated edge
  function checks". Claude recommended keeping this one: it is a single row lookup, and it is
  the only thing that stops the current App Store build from using Vana free after 1 October.
  **Lee has not confirmed this; ask him.**
- **Folds:**
  - mp-609, the server's Pro row, replaces mp-285, 317, 454 and 503.
  - mp-610, test everything on dev and ship prod through TestFlight, replaces mp-318, 336
    and 553.
- **Xuan's spec wins on grace** (mp-554 rewritten plain, mp-455 approved). Lee: "just approve
  whatever Xuan says".

## Owed checks

- **Device checks, after 2026-09-23 12:54 UTC,** when the throwaway account
  `paywall15_1790080942@example.com` has lapsed:
  - ticket 18's coach code: a coach entering their own code lands in the app, not the
    paywall. The dev code `DEVCOACH18` belongs to test@test.com.
  - ticket 19's lapsed account on the full-screen paywall.

  The checks owed for tickets 12 and 17 are moot, because 19 and 20 remove what they built.
- `/design-sync` for the glass sheet component (spec PROPOSED, awaiting Xuan).
- Ticket 18's two open questions, mp-600 and mp-601. The coach mode and the pairing request
  show only after the next sync. Claude recommended A (refresh at once) for both.

## Open questions on the page (paywall)

Claude's recommendations were given in the terminal on 23 September; Lee has not ruled on
these yet:

| Id | Question | Recommendation |
|---|---|---|
| mp-513 | Trial and renewal wording (Apple reads it) | Lee and Xuan, before 25 Sep |
| mp-567 | Is the free week on the dev and prod products | 05 sets prod; 13 checks dev |
| mp-321 | Prod order: offers, table, webhook | offers with 05; table then webhook at the 1 Oct cutover |
| mp-512 | Does a Grant get the Monthly budget | yes |
| mp-514 | Refused AI call opens the paywall | yes (ticket 19 makes it moot for lapsed) |
| mp-561 | Retry a failed grace claim | retry at startup for pre-flip accounts |
| mp-563 | Email confirmation before or after the grace claim | claim first |
| mp-566 | Short phone: plan cards stacked | stacked |
| mp-582 | Admin with no plan on the Subscription screen | "Admin access" |
| mp-590 | Glass sheet grabber, gap, entrance | Xuan's call |
| mp-600, 601 | Coach mode and pairing at once after a Code | refresh at once |

mp-458 is still amended (the codes card agreeing with mp-535 and mp-494) and waits for a plain
approve on the page.

## Gotchas from this session

- **Two sessions share the proposals and record files.** Another session applied page verdicts
  into the working tree without marking them applied, so a later apply read an Approve as
  "withdraw" (mp-417, fixed by hand).
  - Before applying, check whether the record already has today's history line for that id.
  - Page writes need `if_version`, and another session can bump a version between the read and
    the write. Write only the cards your change touched.
- **Card pictures are status-neutral.** They are titled "Other option" and "This card's answer",
  never "rejected" or "decided" (`.claude/skills/ssot/rewrite.md` rule 6). The card face now
  shows context, why and what else was considered (page version 48).
- **The page has a Reference section** holding Xuan's RevenueCat spec, which Ask reads with the
  `read_reference` tool. Rebuild it with `sync.mjs reference` when the spec changes.
- **`prepare` keeps only the last `--tickets` flag.** Prepare each feature's tickets separately.
- **Pressing Finish on the page does not wake a terminal session.** The next `/ssot` or `-lee`
  prologue picks up the queued verdicts.

## Future work, not ticketed

- mp-600 and mp-601, once ruled.
- The prod cutover (1 October): the table, the webhook and the grace script with Lee's go
  (`GRACE_FLIP_AT` is unset on dev, so the claim answers 503 until then).
- The Admin view on the Subscription screen (mp-582), once ruled.
