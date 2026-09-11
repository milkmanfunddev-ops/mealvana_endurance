# Meal images: mirroring is decided per provider

Status: accepted (2026-09-08, recorded 2026-09-11)

A meal-library picture is copied into our `meal-images` storage bucket when it comes from an
archive (Wikimedia Commons, Openverse) and is hotlinked to the provider's CDN when it comes from a
stock-photo API (Unsplash, Pexels). The rule is `MAY_MIRROR` in
`scripts/meal-images/lib/providers.mjs`. It is a licensing rule, not a performance setting, and the
two halves go opposite ways for opposite reasons.

Archive material is mirrored because nothing obliges us to fetch it from the archive, and the
archive is a poor host for an app. Every archive photograph we keep carries a Creative Commons or
public-domain licence that allows copying with attribution. Serving it from `upload.wikimedia.org`
made the library depend on a host that rate-limits hard: pass 8's first sweep got 429s from it
thirty meals in. The 2026-09-01 dish-photo pass predates this rule and hotlinked Wikimedia
directly; 133 of its photographs are still shown that way on 2026-09-11, and they are the fragile
part of the library for that reason.

Stock-photo material is hotlinked because the providers' terms require it. Unsplash's API
guidelines, which are also the checklist for production access, require serving photos from the
Unsplash CDN, firing a download event when a photo is used, and crediting and linking both the
photographer and Unsplash. Pexels expects hotlinking and a link back. Copying one of their files
into our bucket would breach those terms and cost us the API key.

## Considered options

- **Mirror everything.** One host, one caching story, no dependence on third-party CDNs. Ruled out
  by the stock providers' terms, and they supply most of the bank's most-used tiles.
- **Hotlink everything.** Nothing to migrate between projects. Ruled out by the archives' rate
  limits and the risk of files being renamed or deleted upstream.
- **Stock photos only, no archives.** Pexels allows 200 requests an hour and Unsplash 50 on a demo
  key, which is not enough to source a 1,922-meal library. The archives are unmetered and carry
  the long tail of ingredients.

## Consequences

- A stored `image_url` is either our storage or a provider CDN, and code must not assume which.
  Two consequences of that already cost a bug each. A mirrored photograph is stored once per meal
  (`meal-images/meals/<id>.jpg`), so the same photograph on two meals has two URLs and "is this the
  same picture" has to compare `image_source_url` as well (pass 10's in-use set, and
  `picturesForList` in the app).
- A mirrored URL names the project it was mirrored into. Every mirror so far is in the **dev**
  bucket: on 2026-09-11, 506 of the 804 meals showing a picture load at least one image from dev
  storage. Seeding production from a dev snapshot copies those URLs verbatim, so the production
  cutover has to copy the bucket and rewrite the host, or accept prod serving from dev. The
  cutover runbook carries this (`supabase/migrations/cutover/meal_planning/README.md`).
- Nothing can be pre-rendered from a hotlinked photograph, because a rendered file containing it is
  a copy. See [0002](0002-mosaics-are-composed-on-the-client.md).
- Attribution fields (`provider`, `creator`, `license`, `source_url`) travel with every picture and
  tile, and the app builds its credits from them (`KyleImageCredit`).

## What unwinding it would cost

Mirroring stock photos would mean giving up the Unsplash and Pexels keys and re-sourcing every
picture they supplied. On 2026-09-11 that is 778 of the 1,385 Tile placements across Meals and 20 Dish
photos. Pass 2 asks the stock libraries first for the 450 most-used ingredients, so these are the
Tiles on the most cards, and every Meal wearing a re-sourced Tile would need judging again.

Hotlinking the archives instead takes one URL rewrite back to the `image_source_url` files. After
that, every card render is subject to Wikimedia's rate limits.

Changing which bucket holds the mirrors is a copy plus a URL rewrite across `meal_library.image_url`
and `meal_library.image_tiles`, with nothing to re-judge, because the pictures are the same bytes. The
bank's own URLs (`ingredient_images.image_url`) need the same rewrite only where the pipeline runs;
the app never reads that table, and the cutover does not seed it.
