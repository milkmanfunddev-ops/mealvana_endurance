# Meal images: a Meal shows a Dish photo or nothing

Status: accepted (2026-09-15)

A Meal shows one Dish photo or no picture at all. Nothing takes its place: no Mosaic, no single
Tile, no icon. On the card and on the recipe screen, the space is simply absent. Mosaics were
built because only 292 of 1,922 Meals had a Dish photo. Lee saw them on a device and ruled them
out: three unrelated photographs and three credit lines don't show the meal, and an empty space
does less harm.

A Dish photo is one image address with an optional credit line. The address points at our
Supabase Storage or at the web. There are no kinds of photo: where a photo came from doesn't
change how it's shown, and nothing is copied just to bring it into our storage.

Testers maintain photos. A Tester is anyone who has turned on "Mark this device as internal" in
Settings (tap the version seven times). Only Testers see the entry point on the recipe screen.
It opens a Meal photos page where a Tester can:

- take or choose a photo, crop it, preview it and confirm it;
- paste a web address, preview it and confirm it;
- remove the current photo;
- restore or delete a photo from the Meal's History.

The newest confirmed photo is the one shown. A photo a Tester adds never goes through the Judge,
because the person who cooked the dish is the judge.

The image pipeline is frozen, not deleted, and its scripts are archived under
`scripts/_archived/meal-images/`. Nothing new is sourced from it. Everything it wrote stays in the
database: Verdicts, the Tile bank and each Meal's Tile list.
The ability to show Mosaics
([0002](0002-mosaics-are-composed-on-the-client.md)) is kept for when good enough Mosaics exist.
How to find pictures from here on is a question for a later session.

## Considered options

- **Keep Mosaics with an `ok` Verdict.** Rejected: the 148 `ok` Mosaics include grids like salmon,
  quinoa and spinach, which passed the Judge and still didn't show the meal.
- **Label photos as Kitchen, Web or Stock, with a ranking between the kinds.** Rejected. The
  labels added rules and no benefit, since a photo is either there or it isn't.
- **Copy every photo into our storage.** Rejected. A web address can be shown where it lives. The
  cost is that a hotlinked photo can fail to load (Wikimedia rate-limits) or disappear upstream.
  When that happens the Meal shows nothing, and a Tester can replace the photo.
- **Only allow uploads from a server-side list of named people.** Rejected for now. Anyone who
  finds the Settings gesture becomes a Tester and can change a picture every athlete sees. Lee
  accepts that risk. Every add, remove, restore and delete records who did it and when, so
  vandalism can be found and undone.

## Consequences

- At switchover, a Meal keeps its picture only if that picture is a Dish photo with an `ok`
  Verdict. On dev on 2026-09-15 that is 170 Meals: 109 in our storage and 61 on the web. The 61
  are 20 from Pexels, 24 from Wikimedia and 17 from other hosts, all kept. Every other Meal shows
  nothing, and its History starts empty.
- A photo can be added only while online. The app waits for the server to confirm, as it does for
  any write other users must see, and nothing is queued offline.
- Before upload, a camera or gallery photo is cropped, shrunk, and stripped of location and other
  metadata. No photo can be edited once live; to change one, replace it.
- The production cutover copies the files in dev storage that shown photos point at, and rewrites
  their host. Web addresses need nothing.
- The Unsplash production-access application is dropped.
