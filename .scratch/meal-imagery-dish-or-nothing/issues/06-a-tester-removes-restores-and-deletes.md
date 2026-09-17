# 06: A Tester removes, restores and deletes

**What to build:** On the Meal photos page a Tester can remove the current photo, so the Meal
shows nothing and the photo stays in History. History lists every photo the Meal has had, with who
added it and when. From History a Tester can restore any photo as the current one, or delete one
for good after confirming, which removes the file too when it is in our storage. Every action is
recorded with the account and time, so vandalism can be found and undone.

**Blocked by:** 04

**Status:** done (2026-09-16) — simulator check owed

- [x] The edge function gains `remove`, `restore` and `delete`, each with the Tester check and
      one transaction that updates the current-photo fields and writes an event:
      - `remove` clears the current photo and leaves History unchanged. An older photo does not
        come back.
      - `restore` makes a History row the current photo.
      - `delete` removes the History row from History and its stored file if it has one. It
        clears the current photo when it was current, and keeps the audit events.
      - An unknown photo returns 404.
- [x] The function is deployed to dev.
- [x] The page shows History rows (thumbnail, who, when, Restore, Delete). Remove is offered only
      when there is a current photo. Delete asks for confirmation first. Results use
      `MealvanaSnackbar`.
- [x] The controller's remove, restore and delete use remote-ack only. On success they
      invalidate the Meal's detail and the catalog, and a failure leaves state unchanged.
- [x] Seam 2 tests through the real notifier: one request per action, state changes only after
      the ack, and failure surfaces.
- [x] Seam 3 Deno tests:
      - remove clears the current photo and writes an event;
      - restore sets the current photo;
      - delete removes the row and the stored file in the fake storage, and clears the current
        photo if it was current;
      - a non-Tester gets 403 for each action.
- [ ] Checked on the simulator: remove, restore and delete on a web-address photo. Once 05 has
      landed, deleting an uploaded photo removes its file from dev storage.

## Comments

**2026-09-16 — implemented.** Everything but the simulator check is done and verified against
deployed dev.

- **Migration `20260916180000_meal_photo_remove_restore_delete.sql`** — `meal_photo_remove`,
  `meal_photo_restore` and `meal_photo_delete`, each the shape ticket 04 set: one transaction that
  moves the Meal's current-photo fields and writes the audit event together, `security definer`,
  execute granted to `service_role` only. Applied to dev and confirmed there (all three present,
  `service_role=X` and nothing else, matching `meal_photo_add`).
  - `remove` clears the photo and leaves History alone. **No older photograph is pulled forward** —
    that is the whole point of story 42, and it is asserted on both sides of the seam.
  - `restore` looks its row up **by Meal as well as by id**, so one Meal's photo id is not a way to
    paste its photograph onto another Meal. There is a test for exactly that.
  - `delete` writes the event *before* the row goes, so the deletion is recorded even if what
    follows fails; the FK then nulls `photo_id` and the address on the event keeps the record
    readable. It answers the row's `storage_path`, and the **file is deleted after the transaction
    commits** — a file with no row is litter nobody finds, while a row pointing at a deleted file
    would be a Meal promising a photograph that draws nothing.
- **`meal-photo`** gained the three actions behind the same Tester check, and is deployed to dev.
  `photo_not_found` is a new 404 beside `meal_not_found`. The 404 mapping that tickets 04 and 05
  had copied into two places collapsed into one `rpcFailure`.
- **App:** `remove` / `restore` / `deletePhoto` on the repository (remote-ack, no queue), the same
  three on the controller, and the page: Remove beside the current photo, History rows with
  Restore and Delete, Delete behind a confirmation.

**Verified live against deployed dev, twice** (before and after the review fixes): remove clears
the photo and writes an event while both History rows stay and none is marked current; restore puts
either row back on; deleting the worn photograph leaves the Meal showing nothing rather than
reverting to an older one; the deleted row leaves History; an unknown photo is 404 `photo_not_found`
and an unknown Meal 404 `meal_not_found` — the SQLSTATE path the fake database cannot prove — and a
malformed id is 400. **AD-001 was left exactly as it was found each time.**

**A trap worth knowing: a deleted photo's URL keeps answering 200.** The first live check called
the public object URL after deleting and read it as "the file is still there". It was not: the
bucket is public and served through a CDN, which kept answering from cache after the object was
gone. `storage.objects` is the only honest witness, and against it the file really does leave — and
nothing else in the bucket is touched.

**Tests:** seam 3 33 Deno tests on the handler with the fake database and fake bucket (13 new),
full Deno suite 109/109. Seam 2 24 through the real notifier, 24 on the page. Flutter suite
**5116 pass / 8 skip / 2 fail**. Both failures are in `test/features/kroger/kroger_flow_test.dart`,
which fails the same way on its own and sits inside 484 lines of another session's uncommitted
Kroger work; nothing in meal_planning fails. Note this is a *different* baseline from the pair
tickets 04 and 05 recorded (`ci_config_contract_test` and a manual-live TrainingPeaks test) — those
two passed this time.

**What `/code-review` caught, all fixed:**

1. **The restored row could disagree with the photograph above it.** `withRestored` set the current
   photo to the server's answer but left the History row showing this device's possibly-stale copy —
   in exactly the case the server's answer exists to handle. The row now takes that answer too.
2. **Two of the three SQL functions took no lock.** `remove` locked the `meal_library` row;
   `restore` and `delete` did not, so two Testers on one Meal could interleave. All three lock now.
3. **`storage.remove` could throw after the transaction had committed**, turning a completed delete
   into an error the Tester would retry. It is guarded and stays best-effort.
4. **The 404 matcher had widened** to any message containing `_not_found`. It matches the two codes
   the functions actually raise.
5. A delete affordance named the hue (`dragonfruit`) rather than the semantic (`AppColors.error`),
   and `_publish` had become a one-line delegate to `_run`. Both tidied.

Two review findings were **wrong and not acted on**, recorded so nobody re-fixes them: the Spec
axis reported the migration unapplied and the function undeployed (it could not see either — both
were done), and reported `bucketStorage.remove` surfacing storage failures (it already swallowed
them).

**Four things for your eye — three are deviations I chose:**

- **Restore is not offered on the row the Meal is wearing.** The ticket says History rows carry
  "Restore, Delete" without exception. Restoring what is already worn changes nothing, so that row
  shows only Delete. Say the word and it comes back.
- **A remove that removes nothing writes no event.** The ticket says each action writes an event;
  story 44 wants every action recorded. A removal that cleared nothing is not a change, and the
  page never offers Remove without a photograph, so this is only reachable through the API.
- **A malformed photo id is 400, not 404.** The ticket fixes the answer at "an unknown photo
  returns 404". A string that is not a uuid at all would otherwise make Postgres refuse the cast and
  the Tester see a server error, so it is refused earlier and more plainly.
- **`AsyncValue.guard()` is still unruled**, inherited from tickets 04 and 05. These three writes
  follow the same choice for the same reason, so **one ruling settles all five paths**.

**The commit is not this ticket's alone.** While this was being built, a parallel session committed
`d2d52044` ("Paywall onboarding shape, meal-photo remove/restore/delete, and Vana reads the screen
honestly"), which swept most of ticket 06 into it alongside paywall and Vana work. The code that
landed is the final code — the committed migration carries the locks and the committed handler the
tightened matcher — so nothing is lost or broken, but ticket 06 is no longer separable in history.
Unpicking it would have meant rewriting a commit another live session is building on, which is
worse than the mixing. The page, the seam-2 test and this file follow in their own commit.

**The simulator check is NOT done** — the last box, and the one thing no test stands in for. Dev is
seeded ready: **AD-001** wears the ticket-05 upload (`0682e867`), with the ticket-04 Pexels
photograph (`6df796ea`) behind it in History, so Remove, Restore and Delete all have something real
to act on. `607f9dd5` (test@test.com) is the Tester. What is left to see on a device is a removal
taking the picture off the Meals tab and recipe screen, a restore putting it back, and a delete
asking first and then taking an uploaded photo's file with it.

**2026-09-17 — Lee's rulings.**

- **No Restore on the worn row, no event for a remove that removes nothing, 400 for a malformed
  photo id — all accepted as built.**
- **`AsyncValue.guard()` — ruled: keep as built.** Photo writes rethrow to the screen and leave the
  shown state intact. CLAUDE.md now carries this as a named exception to the controller rule.
