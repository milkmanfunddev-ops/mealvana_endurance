-- Home location as a Fact (the Voodoo Doll spec, ticket 07).
--
-- Vana kept answering weather and shopping questions for the athlete's race venue, because the
-- race was the only place on file. Three columns on the user record fix that: where they live, in
-- words and in coordinates, and the timezone that goes with it. Vana can set them from a sentence
-- ("I live in Birmingham") through the setHomeLocation tool; weather and Kroger prefer them and
-- fall back to the race location when they are empty.
--
-- Idempotent. Apply to dev; prod follows the meal-planning cutover runbook.

alter table public.users add column if not exists home_city     text;
alter table public.users add column if not exists home_lat      double precision;
alter table public.users add column if not exists home_lon      double precision;
alter table public.users add column if not exists home_timezone text;

comment on column public.users.home_city is
  'Where the athlete lives, as they said it ("Birmingham, AL"). Set by Vana or by the profile screen.';
comment on column public.users.home_lat is 'Home latitude, geocoded from home_city.';
comment on column public.users.home_lon is 'Home longitude, geocoded from home_city.';
comment on column public.users.home_timezone is 'IANA timezone of home_city, e.g. America/Chicago.';
