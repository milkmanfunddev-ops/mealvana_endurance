-- G23a blast radius (READ-ONLY): non-midnight plan_date rows on the server.
-- Run against DEV (vlmtsdzpnjnavdgytcmi) and PROD (wvmvsodrvbkxfydabqed) in
-- default (non-auto) permission mode — the auto-mode classifier blocks the
-- Management API query call (playbook §7 note).
--
-- Expectation: 0 on both — the app's upload serializer truncates plan_date
-- to date-only on the wire — but the column is `timestamp without time
-- zone`, so any other writer could have stored times. If prod returns > 0,
-- the count + affected user_ids go to Xuan with the land deploy notes.
SELECT
  count(*)                                            AS total_rows,
  count(*) FILTER (WHERE plan_date::time <> TIME '00:00:00') AS non_midnight_rows
FROM carb_loading_days;

-- If non_midnight_rows > 0, identify them:
SELECT d.id, d.carb_loading_plan_id, d.plan_date, d.day_number,
       p.user_id
FROM carb_loading_days d
JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
WHERE d.plan_date::time <> TIME '00:00:00'
ORDER BY d.plan_date;
