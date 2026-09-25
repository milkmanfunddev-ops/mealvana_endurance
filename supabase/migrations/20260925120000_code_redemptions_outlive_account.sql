-- testing-wave ticket 39 (Finding 11-012, mp-535): a code redemption outlives the account that made it.
--
-- `code_redemptions.user_id` referenced auth.users with `on delete cascade`, so deleting an account took
-- its redemption rows with it: per-code counts fell back and a spent single-use giveaway worked again
-- for the next account. mp-535 says a giveaway works once in total unless its row allows more.
--
-- Now the reference is `on delete set null` and `user_id` may be null: the row stays, still counts
-- toward the code's total in `code_claim` (which counts every row for the code), and no longer names
-- the deleted account. The unique (code_id, user_id) key treats nulls as distinct, so any number of
-- deleted accounts' rows can sit on one code.
--
-- Not changed here: `code_redemptions.code_id` still cascades from `codes`, and `codes.owner_user_id`
-- still cascades from public.users, so deleting a coach or influencer deletes their own code and its
-- redemptions with it (a giveaway has no owner and is not affected).
--
-- Idempotent: safe to re-run. Applies ahead of any function deploy; redeem-code needs no change for it.

alter table public.code_redemptions
  alter column user_id drop not null;

alter table public.code_redemptions
  drop constraint if exists code_redemptions_user_id_fkey;

alter table public.code_redemptions
  add constraint code_redemptions_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;

comment on column public.code_redemptions.user_id is
  'The account that redeemed the code; null once that account is deleted. The row is kept so the code''s total still counts it (mp-535).';

comment on table public.code_redemptions is
  'One row per account per redeemed code (mp-458). Written only by code_claim and the redeem-code function. Kept when the account is deleted (user_id set null), so a spent code stays spent (mp-535).';
