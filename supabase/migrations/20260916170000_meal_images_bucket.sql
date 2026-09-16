-- The public image bucket a Meal's photographs live in (ADR 0003, ticket 05).
--
-- The bucket has existed on dev since 2026-09-08, created by hand for the
-- (now frozen) image pipeline and never written down. Prod has nothing, and
-- the meal-planning cutover has to create it. This migration is that record:
-- prod can be built from migrations, and dev keeps exactly the bucket it has.
--
-- The values below are dev's, read from storage.buckets on 2026-09-16:
--   public            true     — a Meal's photo is shown to every athlete, and
--                                a public object URL needs no signing, so a
--                                card can draw straight from the address the
--                                History row stores.
--   file_size_limit   5 MiB    — the app prepares uploads to ~1600px JPEG,
--                                which lands far inside this; the limit is the
--                                backstop, and the function checks it too so a
--                                Tester gets a clear refusal rather than a
--                                storage error.
--   allowed_mime_types         — jpeg/webp/png. Tester uploads are always JPEG
--                                (prepareDishPhoto re-encodes); the other two
--                                are what the pipeline's mirrored files are.
--
-- No storage policies. Reads need none: the bucket is public. Writes need none
-- either, and deliberately get none — only the meal-photo edge function
-- writes here, with the service role, after it has checked users.is_internal.
-- A client holding the anon key can read a photograph and store nothing.
--
-- Idempotent: on an existing bucket (dev) this changes nothing at all.

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'meal-images',
  'meal-images',
  true,
  5242880,
  array['image/jpeg', 'image/webp', 'image/png']
)
on conflict (id) do nothing;

commit;

-- ------------------------------------------------------------ verify (read-only)
--   select id, public, file_size_limit, allowed_mime_types
--     from storage.buckets where id = 'meal-images';
--   -- meal-images | t | 5242880 | {image/jpeg,image/webp,image/png}
--
--   select count(*) from pg_policies
--    where schemaname = 'storage' and qual like '%meal-images%';  -- 0
