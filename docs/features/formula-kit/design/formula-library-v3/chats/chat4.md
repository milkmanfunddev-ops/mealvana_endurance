# Filter formula application

_Started 2026-05-15 14:54 UTC_

---

## User

Save as standalone HTML: Formula Kit.html

## Assistant

_[tool: read_file]_

_[tool: grep]_

_[tool: grep]_

Good — fonts are referenced via CSS url() which the bundler handles automatically. No JS-string resource references. Let me run the bundler.

_[tool: super_inline_html]_

_[tool: show_html]_

_[tool: show_html]_

_[tool: get_webview_logs]_

Clean — only the usual Babel dev warning. Delivering the file.

_[tool: present_fs_item_for_download]_

Standalone bundle ready — fonts, scripts, and CSS all inlined into a single offline-capable file.

## User

I'd like the filter will also apply to each of your own formulas. Right it seems the filter only applies to existing formula.

## Assistant

_[tool: list_files]_

_[tool: read_file]_

_[tool: grep]_

_[tool: grep]_

_[tool: grep]_

_[tool: grep]_

_[tool: grep]_

_[tool: grep]_

_[tool: read_file]_

_[tool: grep]_

_[tool: str_replace_edit]_

Now I understand. Personal formulas DO carry `sub_phase` / `activities` / `durations` / `foodForm` / `gut` / `allergens` / `excludes`, but `YourFormulasSection` only filters by `sourcePhase` — none of the active filters apply. Let me fix that by filtering personals in `BeforeBody` and `DuringBody` before passing them down.

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

Now rebuild the standalone bundle.

_[tool: super_inline_html]_

_[tool: done]_

_[tool: present_fs_item_for_download]_

Done. Phase + diet + "more" filters now apply to **Your formulas** too:

- **Before**: sub-phase (Meal/Snack/Top-up), digestion, types, dietary profile
- **During**: activity, duration, food form, gut, dietary profile

The count chip shows `matching/total` when a filter is hiding some of your personals, and the section shows a quiet "None of your N formulas match the active filters" card when filters hide them all (instead of the "no personal formulas yet" message). Favorites-only behavior is unchanged.

## User

allow user to filter out their favorites

## Assistant

_[tool: grep]_

_[tool: grep]_

_[tool: read_file]_

_[tool: grep]_

_[tool: read_file]_

_[tool: str_replace_edit]_

Now thread `favoritesOnly` + `setFavoritesOnly` through `BrowserScreen` to the header.

_[tool: str_replace_edit]_

_[tool: read_file]_

_[tool: str_replace_edit]_

Rebuild and deliver.

_[tool: super_inline_html]_

_[tool: done]_

_[tool: present_fs_item_for_download]_

Added a **star toggle** in the header (left of the Filters button). Tapping it activates "favorites only" — filters both system templates and Your formulas to starred items, on whichever phase tab you're on. The star fills with the teal electrolyte accent when active. The existing "Show favorites only" chip in the More Filters sheet still works too.

