-- ai-cost ticket 04 (mp-430 clause 9): a call is counted when it starts, and parallel requests cannot pass the limit.
--
-- `vana_reserve_call` is the limiter's one atomic step. It takes a transaction-scoped advisory lock on
-- (user, bucket), counts the bucket's rows inside the window, and writes the call row only when there is
-- room. Two requests for the same athlete and bucket therefore run one after the other, and the second
-- one counts the first one's row. Without the lock a request can rank itself before an earlier insert has
-- committed, and five calls pass a limit of four.
--
-- Returns the new row's id, or null when the bucket is full (nothing is written for a refusal).
-- Called by the edge functions with the service role only (`_shared/vana/rate-limit.ts`). Idempotent.

create or replace function public.vana_reserve_call(
  p_user_id uuid,
  p_bucket text,
  p_function_name text,
  p_model text,
  p_window_seconds int,
  p_max int
) returns uuid
language plpgsql volatile security invoker set search_path = public as $$
declare
  v_count int;
  v_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text || '|' || p_bucket, 0));
  select count(*) into v_count
    from public.vana_calls
   where user_id = p_user_id
     and left(function_name, length(p_bucket)) = p_bucket
     and created_at >= now() - make_interval(secs => p_window_seconds);
  if v_count >= p_max then
    return null;
  end if;
  insert into public.vana_calls (user_id, function_name, model)
  values (p_user_id, p_function_name, p_model)
  returning id into v_id;
  return v_id;
end $$;

revoke all on function public.vana_reserve_call(uuid, text, text, text, int, int) from public, anon, authenticated;
grant execute on function public.vana_reserve_call(uuid, text, text, text, int, int) to service_role;
