# 06: A Tester removes, restores and deletes

**What to build:** On the Meal photos page a Tester can remove the current photo, so the Meal
shows nothing and the photo stays in History. History lists every photo the Meal has had, with who
added it and when. From History a Tester can restore any photo as the current one, or delete one
for good after confirming, which removes the file too when it is in our storage. Every action is
recorded with the account and time, so vandalism can be found and undone.

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] The edge function gains `remove`, `restore` and `delete`, each with the Tester check and
      one transaction that updates the current-photo fields and writes an event:
      - `remove` clears the current photo and leaves History unchanged. An older photo does not
        come back.
      - `restore` makes a History row the current photo.
      - `delete` removes the History row from History and its stored file if it has one. It
        clears the current photo when it was current, and keeps the audit events.
      - An unknown photo returns 404.
- [ ] The function is deployed to dev.
- [ ] The page shows History rows (thumbnail, who, when, Restore, Delete). Remove is offered only
      when there is a current photo. Delete asks for confirmation first. Results use
      `MealvanaSnackbar`.
- [ ] The controller's remove, restore and delete use remote-ack only. On success they
      invalidate the Meal's detail and the catalog, and a failure leaves state unchanged.
- [ ] Seam 2 tests through the real notifier: one request per action, state changes only after
      the ack, and failure surfaces.
- [ ] Seam 3 Deno tests:
      - remove clears the current photo and writes an event;
      - restore sets the current photo;
      - delete removes the row and the stored file in the fake storage, and clears the current
        photo if it was current;
      - a non-Tester gets 403 for each action.
- [ ] Checked on the simulator: remove, restore and delete on a web-address photo. Once 05 has
      landed, deleting an uploaded photo removes its file from dev storage.
