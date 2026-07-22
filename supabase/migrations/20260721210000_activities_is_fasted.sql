-- Persist the fasted flag on activities so plan regeneration (e.g. after a
-- sweat-profile edit) keeps a genuinely fasted activity fasted instead of
-- hardcoding false (follow-up to the 2026-07-21 keepAlive isFasted leak fix).
alter table public.activities
  add column if not exists is_fasted boolean not null default false;
