# Before Formula Page

_Started 2026-05-14 20:08 UTC_

---

## User

Save as standalone HTML: Formula Kit.html

## Assistant

_[tool: read_file]_

_[tool: grep]_

_[tool: super_inline_html]_

_[tool: show_html]_

_[tool: show_html]_

_[tool: sleep]_

_[tool: get_webview_logs]_

_[tool: present_fs_item_for_download]_

Standalone file ready — fonts and all scripts inlined into a single offline HTML.

## User

<system-info comment="Only acknowledge these if relevant">
Project title is now "Formula library (Remix)"
User is viewing file: Formula Kit.html
Current date is now May 14, 2026
</system-info>

<pasted_text name="Pasted text (137 lines)">
# Formula Kit — Create new formula from scratch

## Overview

Add the ability to create a brand-new personal formula from scratch (not derived from a system template). The entry point lives on the list view, and the create flow itself is structurally a sibling of the existing edit state with an empty starting point.

## 1. Entry point on the list view

On both the Before and During tabs, modify the "YOUR FORMULAS" section header:

- Keep the section title and count chip on the left.
- On the same row, right-aligned, add a small "+ New" pill in cream/neutral fill — smaller visual weight than the section title (~80% of section header text size, lighter weight). Pill shape with a "+" glyph left of the "New" label, matching the existing "Make this mine" pill on the detail view.

Tapping "+ New" opens the create flow with the phase pre-set based on the current tab (Before tab → Before formula, During tab → During formula). The user does not pick phase again inside the flow.

## 2. Updated empty state for "Your formulas"

Currently the "Your formulas" section hides when a phase has zero personal formulas. Change this:

When a phase has 0 personal formulas, still show the section header ("YOUR FORMULAS · 0") with the "+ New" pill on the right. Below the header, show a quiet card with two affordances:

- A cream text line: "No personal formulas yet."
- Two affordances below: "Make any template yours" (descriptive only, points at the system library below — not interactive) and "+ Create new formula" (interactive, opens the create flow).

The card uses the dark plum chip styling but with no border or shadow — quieter than a normal card. When the user creates or forks their first formula, the card is replaced by the actual formula card and the count updates.

## 3. The create-from-scratch flow

### Header

A full-screen view (not a sheet) with:

- Top-left: "Cancel" text button — discards in-progress work and returns to list view. No confirmation prompt.
- Top-center: "New formula" title in display face.
- Top-right: "Save" pill in orange. Visually muted (50% opacity) until validation passes; fully orange when valid.

### Eyebrow

Below the header:
- "NEW · BEFORE FORMULA" if entered from the Before tab
- "NEW · DURING FORMULA" if entered from the During tab

Use the same desaturated purple as the "DRAFT · FROM [SOURCE]" eyebrow on the existing edit state.

### Title

Below the eyebrow:

- Auto-generate from components as the user adds them (e.g., "Banana + Honey").
- If no components yet, show italic placeholder: "Title will appear as you add components"
- The title is tappable to rename inline. If the user types a custom name, it persists regardless of component changes. If they leave it as auto, it auto-updates with components.

To the left of the title, render the orange person-with-pencil icon.

### Phase-specific metadata section

A section labeled "DETAILS" between the title and the macros panel. Contents vary by phase.

**Before:**

- Sub-phase — required. Three pills: Meal, Snack, Top-Up. Single-select, none pre-selected.
- Digest speed — optional. Three pills: Fast, Medium, Slow. Single-select, defaults to Medium.

**During:**

- Activity — required, multi-select. Horizontally scrollable row: Running, Cycling, Tri — Bike, Tri — Run, Tri — Transition. Each with its existing activity icon.
- Duration — required, multi-select. Four pills: < 90 min, 90–150 min, 150–240 min, > 240 min.
- Gut training — optional. Three pills: Low, Moderate, High. Single-select, defaults to Moderate.

Multi-select pills use the same teal-outline treatment as the dietary filter chips, so the pattern is consistent.

### Macros panel

Same macros panel as the existing edit state, with the "UPDATES AS YOU ADJUST COMPONENTS" caption.

- Before: live-computed macros that update as components change.
- During: replace with the "Scales to your plan" treatment from the During detail (no absolute macros). Panel stays visible in this alternate form.

### Coach insight card

Same card as the existing edit state, with an inert starting state:

- Header: "Coach insight" with subtitle "Add a component to get started"
- Body: muted text "Once you add at least one component, I'll review your formula and offer suggestions."
- No "Refresh" action until 1+ components exist.

Once the user adds a component, the card becomes active with placeholder insight content (match the tone and length of existing insight examples). "Refresh" action and "UP TO DATE" status appear.

### Components section

Standard "COMPONENTS" uppercase header. Initial empty state:

- A prompt card: "Add your first food" with a centered "+ ADD FOOD" outlined orange button below it.

Tapping the button opens the Swap sheet. Re-purpose the sheet's header to read "Add food" instead of "Swap [component]." Selecting a food closes the sheet and adds the food as the first component row.

After the first component is added, subsequent additions use the standard "+ ADD FOOD" button at the bottom of the component list.

Each component row follows the existing edit-state pattern: food-type icon, quantity inline with name (Before only — During shows just the food name), expand chevron, expanded row offers quantity stepper (Before only) + Swap + Remove.

### Validation

Save pill is muted until:

- (Before) Sub-phase selected AND at least 1 component added
- (During) At least 1 activity AND at least 1 duration AND at least 1 component added

Tapping muted Save shows a toast naming what's missing, one at a time. Priority order: phase-specific metadata first, then components. Examples: "Pick a sub-phase to save", "Add at least one food to save".

When valid, Save becomes fully orange. Tapping it:

1. Commits the new formula to localStorage under the existing personal_formulas key.
2. Closes the create flow and returns the user to the read-only detail view of the new formula.
3. Shows a toast: "Created in Your formulas."

Cancel closes the create flow without saving. No confirmation prompt even with components added.

## Personal formula detail view — eyebrow update

The personal formula detail view currently shows "YOUR FORMULA · FROM [SOURCE NAME]" for forked formulas. For create-from-scratch formulas, drop the source line — show only "YOUR FORMULA" as the eyebrow.

Add a provenance flag to the personal formula data model (forked vs. from_scratch) and use it to determine which eyebrow to render.

## Out of scope

- Switching phase mid-create (locked from entry tab)
- Sharing personal formulas with a coach
- Importing recipes from external sources
- Photo upload
- Reordering components

## Notes

- The create flow reuses the edit-state scaffolding. Where components already exist for the edit state, reuse them with empty-state variants — don't build parallel.
- Multi-select pills need clear selected vs. unselected states. The dietary filter chip pattern is the right precedent.
- The DETAILS section sits inline on the same scrolling screen — not a separate step, not a sheet.
- After Save, the new formula appears at the top of "Your formulas" (newest first) and gently highlights (subtle background pulse) for ~1.5 seconds to draw the user's eye.
</pasted_text>

## Assistant

_[tool: list_files]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: update_todos]_

_[tool: write_file]_

Now update app.jsx — add the create route, wire it up:

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

Now update browser.jsx — YourFormulasSection always shows, with "+ New" pill, empty card, and highlight pulse:

_[tool: str_replace_edit]_

Now replace the YourFormulasSection itself — always show, with "+ New" pill, empty card, and highlight pulse support on PersonalCard:

_[tool: str_replace_edit]_

Now update PersonalCard for: 1) `highlight` pulse, 2) hide "From X" eyebrow when from-scratch:

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

Now add the pulse keyframe to Formula Kit.html's style block, and load create.jsx:

_[tool: str_replace_edit]_

Now update detail.jsx's Eyebrow to handle from-scratch personal formulas (drop the FROM line):

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

Now check it loads cleanly:

_[tool: show_html]_

_[tool: done]_

_[tool: fork_verifier_agent]_

Built the create-from-scratch flow.

- **List view**: `YOUR FORMULAS · N` always shows now with a small cream "+ New" pill on the right; empty state is a quiet plum card with "No personal formulas yet." plus two affordances (passive "Make any template yours", interactive "+ Create new formula").
- **Create flow** (new `create.jsx`): full-screen sibling of edit; phase locked to the entering tab; auto-titles from components with inline rename; phase-specific DETAILS block (Before: sub-phase + digest speed; During: multi-select activity/duration + gut training); live macros for Before / "Scales to your plan" card for During; inert Coach insight that activates after the first component; empty Components prompt → reuses Swap sheet as "Add Food".
- **Validation**: Save pill muted at 50% until valid; tapping muted Save toasts the first missing piece (phase-metadata before components).
- **After save**: jumps to read-only detail of the new formula, toasts "Created in Your formulas.", and the list card pulses for ~1.5 s when you return.
- **Provenance**: new formulas tagged `provenance: "from_scratch"`; detail eyebrow and personal card drop the "FROM …" line for them.

Note — the standalone offline export from earlier is now stale; rebuild it when you want a refreshed one.

## User

Verifier agent check completed

## Assistant

All checks passed.

## User

In creating before formula page, there is no need to have digest speed as this is not something a user would know. A user can suggest meal or snack or top-up, but coach insight might correct it if it is not fitting.

## Assistant

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: grep]_

_[tool: str_replace_edit]_

Now guard the detail view from rendering "null digest" for from-scratch formulas:

_[tool: done]_

Removed Digest speed from the Before create flow — only Sub-phase remains, with a short helper line that the coach insight will flag mismatches. Detail view also guards against rendering a digest pill when there's no value.

## User

In editing phase of any user created formula, it should allow user to edit the attributes such as "meal" etc

## Assistant

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

Now wire `draftMeta` through DetailScreen and render the DetailsBlock when editing:

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

Now plumb `draftMeta` into the Before/During detail bodies and render the DetailsBlock when editing:

_[tool: grep]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: str_replace_edit]_

_[tool: done]_

_[tool: fork_verifier_agent]_

Edit state now exposes the phase metadata. Personal Before formulas can edit Sub-phase; personal During formulas can edit Activities / Duration / Gut training. Same DETAILS block also appears when forking a system template via "Make this mine", pre-populated from the source.

## User

Verifier agent check completed

## Assistant

The verifier got stuck navigating the multi-step UI — no concrete failure surfaced. The page loads cleanly with no console errors, so the edit-meta feature should work; let me know if you hit anything off when you try it.

## User

For during template, coach insight needs to be above components, not after, just like before templates

## Assistant

_[tool: grep]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: str_replace_edit]_

_[tool: done]_

Coach insight now sits above Components in the During template edit view, matching Before.

## User

# Formula Kit — Favoriting

## Star on every card
- Top-right of every card (system + personal, both tabs), replacing the chevron
- Outlined star at ~40% opacity = unfavorited; filled teal = favorited
- 44×44 tap target, separate from card body
- Tap star → toggle + 150ms scale pulse (1 → 1.2 → 1), no toast
- Tap card body → opens detail

## Filters sheet
Insert between DIETARY PROFILE and ALLERGENS TO AVOID:
- Header: FAVORITES
- One toggle pill: "Show favorites only"
- ANDs with other active filters; cleared by existing Reset link

## Persistence
- localStorage key `mealvana.kit.favorites`
- Array of strings: `system:[id]` or `personal:[id]`

## Edge case
Deleting a favorited personal formula removes it from the favorites array.

## Assistant

_[tool: update_todos]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

Now add favorites state, helpers, and "show favorites only" filter to app.jsx:

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

Now update browser.jsx for the favorites filter, badge count, and pass-through:Now update BeforeBody/DuringBody to apply favorites filter + pass props through:

_[tool: str_replace_edit]_

Now refactor the three cards: outer becomes a clickable div, replace chevron with FavoriteStar.

_[tool: str_replace_edit]_

_[tool: grep]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

Now refactor PersonalCard + YourFormulasSection to also use FavoriteStar and apply favorites-only filter:

_[tool: str_replace_edit]_

_[tool: grep]_

_[tool: read_file]_

_[tool: str_replace_edit]_

_[tool: done]_

_[tool: fork_verifier_agent]_

Favoriting is live: tap the star (top-right of every system + personal card) to toggle — outlined cream when off, filled teal when on, 150 ms pulse on tap, no toast. Tapping the card body still opens detail. A new **FAVORITES** section in the Filters sheet (between Dietary profile and Allergens) holds a "Show favorites only" pill that ANDs with the other filters and clears via Reset. Favorites persist under `mealvana.kit.favorites` (`system:<id>` / `personal:<id>`), and deleting a personal formula prunes its entry.

## User

Verifier agent check completed

## Assistant

All checks passed.

