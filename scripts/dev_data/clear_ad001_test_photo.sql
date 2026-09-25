-- Ticket 69 (testing-wave, Finding 09-003): the dev meal library's salmon
-- salad (meal_library AD-001) still wears meal-imagery ticket 05's striped
-- test upload, credited "Photo by Lee (ticket 05 live check)", so every dev
-- athlete whose plan holds AD-001 sees a test pattern.
--
-- What AD-001 wore before the live checks: nothing. Its pipeline picture was a
-- `mosaic` with verdict `weak`, so the ADR 0003 switchover (dish or nothing,
-- migration 20260916140000) left photo_url null. Both of its History rows are
-- live-check adds from 2026-09-16 (ticket 04's Pexels 1640777 at 11:47Z,
-- ticket 05's striped upload at 12:24Z), so there is no earlier photograph to
-- put back; the pre-test state is photo_url / photo_credit / photo_credit_url /
-- photo_history_id all null, and the app then shows no picture.
--
-- The clear goes through public.meal_photo_remove, the same function the
-- photo edge function calls: it nulls the four fields, leaves History alone
-- (both rows stay restorable by a Tester) and writes a `remove` event with the
-- photo's address, so the audit log says what happened. The account is null:
-- a script did this, not a Tester. The storage object
-- (meal-images/photos/AD-001/7e5d921c-….jpg, 8.8 KB) is left where it is; its
-- History row still points at it and deleting a file under a live row is the
-- one order the ticket-06 design forbids.
--
-- Idempotent: guarded on AD-001 still wearing that History row (or the test
-- credit line), so a second run matches nothing and writes no event
-- (meal_photo_remove on a Meal that shows nothing is a no-op with no event).
-- Run on DEV only (vlmtsdzpnjnavdgytcmi) via the Management API
-- `database/query`. Read first; the after-SELECT is at the bottom.

-- 1. Read first: what AD-001 wears now.
SELECT id, photo_url, photo_credit, photo_credit_url, photo_history_id
  FROM public.meal_library
 WHERE id = 'AD-001';

-- 2. Clear it, only while it still carries the ticket-05 test photo.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM public.meal_library
     WHERE id = 'AD-001'
       AND (photo_history_id = '0682e867-c488-49e1-b6ee-c64b36fdd344'
            OR photo_credit = 'Photo by Lee (ticket 05 live check)')
  ) THEN
    PERFORM public.meal_photo_remove('AD-001', NULL);
  END IF;
END
$$;

-- 3. After: the four photo fields are null and the newest event is a `remove`
--    for the striped upload.
SELECT id, photo_url, photo_credit, photo_credit_url, photo_history_id
  FROM public.meal_library
 WHERE id = 'AD-001';

SELECT action, photo_id, photo_url, account_id, created_at
  FROM public.meal_photo_events
 WHERE meal_id = 'AD-001'
 ORDER BY created_at DESC
 LIMIT 1;
