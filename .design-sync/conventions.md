# Building with Mealvana Endurance

Import components from `window.MealvanaDS`. No provider is required — every component styles itself from the CSS custom properties in `styles.css`, so `styles.css` must be loaded. Nothing renders correctly without it. The library, by group:

- **Foundations:** `Icon`, `IconChip`, `InfoIcon`
- **Buttons:** `PrimaryButton`, `SecondaryButton`, `SegmentedControl`, `SelectionButton`, `TertiaryButton`
- **Inputs:** `Dropdown`, `InputField`, `Stepper`, `Switch`
- **Surfaces:** `Card`, `HeroImageCard`, `PhaseCard`
- **Feedback:** `Banner`, `Snackbar`
- **Navigation:** `DetailHeader`, `ScreenHeader`, `TabBar`, `TripleAction`
- **Data:** `ActivityRow`, `FoodRow`, `FuelItem`, `FuelStep`, `MacroDonut`, `MacroRing`, `MacroStat`, `NutritionalTargetsCard`, `ScheduleBlock`, `SourceDot`, `SourceLegend`, `StackedBar`
- **Timeline:** `StatusPill`, `Timeline`, `WorkoutCard`
- **Dashboard:** `NetBalanceCard`, `ViewTabs`, `WeekStrip`
- **Sheets:** `BreakdownTable`, `EnergyRow`, `EquationCard`, `HeroNumber`, `PagerDots`, `SheetHeader`

The app is **dark-first**: every component defaults to the blackberry ground. The fuel timeline is `ViewTabs` + `WeekStrip` + `NetBalanceCard` + `SegmentedControl` (filters) + `Timeline` of `WorkoutCard`/`FoodRow` + `TabBar`; sheets are `SheetHeader` + (`EquationCard` | `HeroNumber`+`StackedBar`+`EnergyRow` | `MacroDonut`×3) + `SourceLegend` + `PagerDots`; activity details are `DetailHeader` + `HeroImageCard` + `ScheduleBlock` + `Banner` + orange `SegmentedControl` + `PhaseCard`s of `MacroStat`/`FuelStep`/`FuelItem`. Each component's `.prompt.md` shows its composition; the composed-screen previews on `Timeline`, `SheetHeader`, and `PhaseCard` show the whole screens.

## Surfaces and the `dark` prop
The app is dark-first: the ground is blackberry (`--me-bg`), ink is cream (`--me-ink`), and every component defaults to `dark={true}`. **Never white** (`#fff` is a logged deviation, not a choice). For the light re-tint, wrap the subtree in `<div className="on-light">` (swaps `--me-bg/--me-ink/--me-card*` tokens) **and** pass `dark={false}` to each component inside it — components branch on the prop, not on the wrapper. Same UI, re-tinted; never redesign for a theme.

## Styling idiom: CSS variables + role classes, no utility framework
Use the tokens for any layout glue you write; never a raw hex.
- Ground & ink (surface-relative, resolve through `.on-light`): `var(--me-bg)`, `--me-ink`, `--me-ink-2` (secondary), `--me-ink-3` (eyebrows, times), `--me-ink-4` (units), `--me-card` (card fill), `--me-card-line` (hairline), `--me-card-raised` (raised sub-card).
- Brand: `--me-blackberry`, `--me-cream`, `--me-orange` (energy / intake accent, the CTA, planned-food dots), `--me-electrolyte` (burn / activity side: verified, done, workout chips, provenance dots), `--me-dragonfruit` (**destructive only**), `--me-yolk` (**reserved — no meaning yet; don't use for semantics**), `--me-inactive`, `--me-hairline`, `--me-cream-dark` / `--me-blackberry-light`, `--me-input-bg`.
- Data colours (as rendered on the dashboard): `--me-data-carbs` (electrolyte), `--me-data-protein` (violet), `--me-data-fat` (pink). Pass them to `MacroDonut`, `MacroRing`, and the `FoodRow` macro line uses them automatically.
- Type roles (classes): `.me-page-title` `.me-section-title` `.me-screen-title` `.me-data-xl` (Sansita), `.me-tab` `.me-food-title` `.me-activity-title` `.me-descriptor` (Compadre / Compadre Wide caps), `.me-body` `.me-body-lg` `.me-body-sm` `.me-caption` `.me-eyebrow` `.me-data` `.me-data-number` `.me-button-label` (Apercu), `.me-mono` (Apercu Mono — figures in tables).
- Shape: `--me-radius-md` 15px is the ratified card radius (`Card`); timeline and sheet cards use 14–18px per their Dart; `--me-radius-pill` for anything button-like; `--me-radius-input` 12px for fields.
- Spacing: `--me-space-1..12` on a 4px grid; mobile gutter 16–17px (`--me-space-4/5`). Mobile canvas is 428px wide (iPhone Pro Max); design at `width: 100%; max-width: 428px`.
- Elevation: none on cards — hairlines (`--me-card-line`) do the work. `--me-shadow-md` only under the floating `TripleAction` / `TabBar` pills.

## Composition rules
- One `PrimaryButton` per screen. Secondary actions are `SecondaryButton` (`size="sm" outline="dashed"` for the `+ Add Food / + Add Activity` pair); text actions are `TertiaryButton` (`tone="electrolyte"` add, default dragonfruit remove).
- Timeline screens: `ViewTabs` → `WeekStrip` → `NetBalanceCard` → filter `SegmentedControl` + outline `IconChip`s → `Timeline` whose entries are `WorkoutCard` (`status` planned / verified / skipped; `reveal` for swipe mockups) and `FoodRow` (`kcal/carbs/protein/fat`) → `TabBar` pinned in a `position: relative` container.
- Sheets: `SheetHeader` first, `PagerDots` last. Energy: `EquationCard` + `BreakdownTable` + `SourceLegend`. Active energy: `HeroNumber` + `StackedBar` + `EnergyRow`s. Fuel: `size="lg"` `SegmentedControl` + three `MacroDonut`s.
- Activity details: `DetailHeader` (delete is `tone="destructive"`) → `HeroImageCard` → `ScheduleBlock` → `Banner` → `tone="orange" size="lg"` `SegmentedControl` → `PhaseCard` per phase (`before` orange, `during` electrolyte, `after` dragonfruit) holding three `MacroStat`s then `FuelStep`s (before/after) or `FuelItem`s (during).
- Group other content in `Card` (15px, hairline); lists of foods outside the timeline are `FoodRow`s.
- Icons: `<Icon name="…">` only (Font Awesome names as in the Flutter app: `personRunning`, `utensils`, `calendarCheck`, `gear`, `penToSquare`, `trash`…); 13–16px inline, 18–24px in an `IconChip`. No emoji anywhere.
- Copy: Title Case labels, no exclamation marks; figures with units (`5.0 mi · 43 min`, `640 kcal · 116C · 16P · 12F`); separators use `·` inside data lines and `•` between stats.

## Where the truth lives
Read `_ds/<folder>/styles.css` for every token and role class before styling. Each component's `.prompt.md` shows its canonical composition. Meaning contracts (what a colour may signify, gesture and state rules) are ratified in the app repo at `docs/ssot/spec/design/`.

## Idiomatic screen
```tsx
<div style={{ position: 'relative', width: '100%', maxWidth: 428, background: 'var(--me-bg)', color: 'var(--me-ink)', padding: '44px 16px 120px', boxSizing: 'border-box', display: 'grid', gridTemplateColumns: 'minmax(0,1fr)', gap: 16 }}>
  <ViewTabs tabs={[{ value: 'week', label: 'By Week' }, { value: 'month', label: 'By Month' }]} selected="week" onChange={setView} period="August 2026" onPrev={prev} onNext={next} onSettings={openSettings} />
  <WeekStrip days={days} selected={2} onSelect={setDay} />
  <NetBalanceCard value={-415} status="slight deficit" onExpand={openEnergy} />
  <SegmentedControl full segments={[{ value: 'all', label: 'All' }, { value: 'workout', label: 'Workout' }, { value: 'meals', label: 'Meals' }]} selected="all" onChange={setFilter} />
  <Timeline entries={[
    { dot: 'start', children: <SecondaryButton size="sm" outline="dashed" tone="orange" icon={<Icon name="plus" size={12} />}>Add Activity</SecondaryButton> },
    { time: '5:57 AM', dot: 'planned', children: <WorkoutCard title="Drills Day" detail="3 mi · 43 min" status="planned" onClick={open} /> },
    { time: '7:51 AM', dot: 'food', children: <FoodRow name="Oatmeal with Berries" kcal={777} carbs={102} protein={29} fat={31} onMore={more} /> },
  ]} />
  <TabBar items={[{ value: 'timeline', icon: 'calendar', label: 'Timeline' }, { value: 'plan', icon: 'calendarCheck', label: 'Plan' }, { value: 'learn', icon: 'graduationCap', label: 'Learn' }]} selected="timeline" onChange={go} />
</div>
```
