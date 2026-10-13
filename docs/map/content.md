# Content (on-screen copy)

domain: 9 Account and app · folder: `lib/features/content/` (4 files, no screen)

Where the app's words come from. Every piece of copy has a dotted key (`learn.notify_me`) in
`assets/config/content_defaults.json`, read through `ContentKeys`; `ContentKeys.format` fills `{name}` placeholders. At
launch the app downloads the newest active `app_content` row for its environment and locale and caches it, so copy can
change without an app release; the bundled file covers anything missing and the raw key shows as a last resort.
Reuse: `content_service`, `content_repository`, `domain/content_keys.dart`. Related: `settings.md`, `integrations.md`
(error texts), `carb_loading.md` (nudge copy).
