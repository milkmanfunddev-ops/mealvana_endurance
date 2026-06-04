# Recipe browser interface

_Started 2026-05-06 17:14 UTC_

---

## User



## Assistant

I'll start by exploring the design system and reference screens, then ask clarifying questions before designing.

_[tool: list_files]_

_[tool: view_image]_

_[tool: list_files]_

_[tool: read_file]_

I need to ask clarifying questions before I start building. Let me also explore the relevant UI kit screens first to ground myself.

_[tool: read_file]_

_[tool: questions_v2]_

## User

Questions answered:
- scope: Just the two screens (Browser + Detail) as a connected flow
- theme: Dark only (matches screenshots)
- phase_control: Decide for me
- filter_density: Decide for me
- card_layout: Decide for me
- active_indicator: Decide for me
- detail_breakdown: Decide for me
- macros_visual: Decide for me
- cta_behavior: Decide for me
- variations: Decide for me
- tweaks: Decide for me
- interactivity: Fully interactive: filters work, tabs switch, detail opens, selection persists

## Assistant

I have my answers — let me get to work. I'll explore the remaining UI kit code I need, then build.

_[tool: read_file]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: snip]_

Now let me set up the project structure. I'll copy the design system fonts and CSS, build the prototype.

_[tool: update_todos]_

_[tool: copy_files]_

_[tool: copy_starter_component]_

_[tool: copy_files]_

_[tool: snip]_

Now I'll plan and design the Formula Kit. Based on the screenshots and brand:

**Design direction:**
- **Phase control**: Sticky segmented pill control at top (Before / During / After) — matches the brand's pill aesthetic
- **Filter bar**: Horizontal scrollable chips below tabs, two logical groups (sport + duration) using little dividers
- **Cards**: Dense list rows. Phase eyebrow at top, name in Sansita, food preview in Compadre, macro chips in mono. Active card has orange outline + small "ACTIVE" pill.
- **Detail screen**: Hero block with the template's stats, then slot-grouped cards showing each food with quantity + macros. Sticky CTA bottom.
- **Tweaks**: card density, active indicator style, phase control style

Let me build this. I'll use four files: index.html, app.jsx, browser.jsx, detail.jsx.

_[tool: write_file]_

_[tool: write_file]_

_[tool: write_file]_

_[tool: write_file]_

_[tool: snip]_

_[tool: write_file]_

_[tool: write_file]_

_[tool: show_html]_

_[tool: snip]_

_[tool: done]_

_[tool: fork_verifier_agent]_

Built the Formula Kit prototype — Browser screen with phase tabs (Before/During/After), sport + duration filter rows, 15 templates with food previews and macro chips, and a Detail screen with slot-grouped breakdown plus "Use This Template" CTA. Selection persists in localStorage, and Tweaks toggles density + active-indicator style.

## User

Save as standalone HTML: Formula Kit.html

## Assistant

_[tool: read_file]_

_[tool: grep]_

_[tool: snip]_

All resources are referenced via standard HTML attributes or CSS `url()` — no JS-string references. The bundler will pick everything up. Just need to add the thumbnail template.

_[tool: copy_files]_

_[tool: str_replace_edit]_

_[tool: snip]_

_[tool: super_inline_html]_

Two missing fonts I never copied. Let me grab them from the design system, then re-bundle.

_[tool: copy_files]_

_[tool: snip]_

_[tool: super_inline_html]_

_[tool: show_html]_

_[tool: show_html]_

_[tool: get_webview_logs]_

_[tool: snip]_

_[tool: present_fs_item_for_download]_

Standalone bundle is ready for download.

## User



## Assistant

_[tool: snip]_

_[tool: update_todos]_

I'll plan this iteration carefully. Major rewrite — let me build the new data file first, then update Browser & cards.

_[tool: write_file]_

_[tool: snip]_

Now I'll rewrite the UI helpers and screens for the new schema.

_[tool: write_file]_

_[tool: write_file]_

_[tool: snip]_

I need to update the detail screen to match the new schema (no slots — just a flat formula), update app.jsx for the new state shape, and add the More Filters sheet.

_[tool: write_file]_

_[tool: write_file]_

_[tool: snip]_

_[tool: done]_

_[tool: update_todos]_

_[tool: fork_verifier_agent]_

_[tool: snip]_

Updated the detail screen and app shell to match the new Before/During schema with the More Filters bottom sheet wired up. Browser, detail nav, dietary banner, and tweaks all working together.

## User

Verifier agent check completed

## Assistant

_[tool: grep]_

_[tool: str_replace_edit]_

_[tool: snip]_

_[tool: done]_

Fixed the phase tab transition bug — switched to `background-color` for reliable transitions.

## User

I'd like the "Meal" "Snack" and "Top-Up" function as a filter just like activity and duration for the "During" phase

## Assistant

Looking at the Before phase — it currently uses Meal/Snack/Top-Up as section headers. The user wants those to also work as filter chips on the Before phase (like the activity/duration rows on During), I'll add a third filter row.

Let me check the current state of browser.jsx and data:

_[tool: grep]_

_[tool: snip]_

_[tool: read_file]_

I'll convert the Before phase from collapsible sections to a chip filter row matching the During phase pattern.

_[tool: grep]_

_[tool: snip]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: done]_

Replaced the Before phase's collapsible sections with a "Timing" filter chip row (Meal / Snack / Top-Up), matching the During phase's filter pattern. Tapping a chip filters the list; tapping again clears it.

## User

I'd like the diet and allergen filter be included in the top right "Filters" section

## Assistant

_[tool: snip]_

_[tool: read_file]_

I'll add diet & allergens into the More Filters sheet, and remove the dietary banner from the browser.

_[tool: grep]_

_[tool: snip]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: done]_

Moved diet & allergen filters into the More Filters sheet — they're now the first two sections, with an "Ignore diet" toggle below. Removed the inline dietary banner from the browser. The filter button's count badge now reflects diet + allergens + extra filters together.

## User

get rid of "servings x-xxx"
get rid of template type and the corresponding badges

## Assistant

_[tool: snip]_

_[tool: grep]_

_[tool: grep]_

_[tool: grep]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: snip]_

_[tool: done]_

Removed the "Food / Drink / Electrolyte" type pills from the cards and detail header, dropped the servings range from both, and removed the "Template type" section from the More filters sheet.

## User

Right now the top of the card takes too much space. I'd like a way to scroll / browse with more space. Make only really relevant information stick on top.

## Assistant

_[tool: read_file]_

I'll trim each card down to only the essential info — name, key macros, and a tight components line. Move secondary tags (allergens, exclusions, digestion, ratio) into the detail screen only. This frees up vertical space so users can scan more cards per scroll.

_[tool: snip]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: done]_

Slimmed both card types down to essentials only:

**Before card** — name, components line, compact macro dots (carbs/protein/sodium). Removed: category eyebrow, digestion pill, add-on pills, allergen/exclusion tags.

**During card** — name + form pill on one line, components line, formula + ratio in mono. Removed: activity tags, duration/gut chip groups, the macro placeholder text, allergen/exclusion tags.

All the secondary metadata (digestion, add-ons, allergens, exclusions, activity coverage, gut training) still lives on the detail screen. Cards are now ~40% shorter, so you can scan ~3–4 per screen instead of 1–2.

_[tool: snip]_

_[tool: snip]_

Anything else you'd like adjusted?

## User

I meant for the top part to collapse to show minimal information when scrolling through the list

## Assistant

Got it — make the header chrome (title, subtitle, phase tabs, filter rows) collapse to a minimal sticky bar when the user scrolls down, so they get more vertical space to browse cards.

_[tool: read_file]_

I need to make the header chrome (title, subtitle, phase tabs, filter rows) collapse on scroll. The cleanest approach: track scroll on the list container, and when scrolled past a threshold, collapse to a compact sticky bar showing just the current phase + filter button.

Let me look at FKHeader and check structure first.

_[tool: grep]_

_[tool: snip]_

_[tool: read_file]_

_[tool: snip]_

Now I'll restructure the browser screen so:
- The chrome (back button + filter pill stay)
- Title, subtitle, phase tabs, filter chip rows live in a "collapsible" block
- On scroll, that block animates to height 0 (with opacity fade), and a compact sticky bar shows the current phase + active filter count
- Tapping the compact bar restores the full chrome

I'll route scroll state up so each Body component can drive it.

_[tool: str_replace_edit]_

_[tool: snip]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: done]_

_[tool: snip]_

Done. Now when you scroll the list down past ~24px, the subtitle, phase tabs, filter chip rows, and result count all collapse with an animated height/opacity transition. In their place, a compact sticky strip appears showing the current phase pill, result count, and active filter count — tap it (or scroll back to top) to expand the full chrome again.

The "Formula Kit" title and the Filters button stay pinned at all times so the back action and filter access never disappear. The header auto-resets to expanded when you switch phases.

## User

When collapse, the active filter for example "Top-Up" should be shown

## Assistant

_[tool: snip]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: done]_

_[tool: snip]_

Done — the collapsed strip now shows orange filter pills with the active filter labels (e.g. "Top-Up", "Run", "1–2 hr") next to the phase pill, so you always see what's narrowing the list at a glance.

## User

Save as standalone HTML: Formula Kit.html

## Assistant

_[tool: snip]_

_[tool: read_file]_

The HTML already has the thumbnail template and no JS-only resource references that I haven't already lifted. Let me bundle it.

_[tool: super_inline_html]_

_[tool: show_html]_

_[tool: snip]_

_[tool: show_html]_

_[tool: get_webview_logs]_

_[tool: snip]_

_[tool: present_fs_item_for_download]_

Standalone bundle ready for download.

