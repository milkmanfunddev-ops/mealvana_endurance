-- G23a repair rider (land blast-radius result, 2026-09-25): normalize any
-- carb_loading_days.plan_date carrying a time-of-day to its date's midnight.
-- Counts at pinning: DEV 0 affected rows (clean); PROD 3 rows, all 12:21:00
-- — one athlete's 3-day plan written by the pre-G23a create path (gun time
-- leaked from the event's startTime), never rendered because the dashboard's
-- date reads are midnight-keyed. The date part is already correct, so this
-- is exactly the value fixed code would have written — no day shifts.
-- Idempotent: the WHERE excludes already-normalized rows. Deploys with the
-- carb-loading land set (slot-CHECK + foods seed), dev first, prod at the
-- release cut under the existing deploy gate.
UPDATE carb_loading_days
SET plan_date = date_trunc('day', plan_date)
WHERE plan_date <> date_trunc('day', plan_date);
