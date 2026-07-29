# Kyle's Design System — Web Prototype Spec (Next.js + Tailwind + shadcn/ui)

**Audience:** Engineers spinning up the `mealplanning_prototype` Next.js app at `/Users/leemartin/development/mealplanning_prototype`.
**Source of truth:** `/Users/leemartin/development/mealvana_endurance/docs/kyle/` and `/Users/leemartin/development/mealvana_endurance/lib/theme/kyle_design/`.
**Goal:** Translate the Flutter implementation of Kyle's brand into copy-pasteable Tailwind + CSS-variable starters for shadcn/ui, without losing the distinctive look.

> Note on source drift: Kyle's Figma MCP extraction (`docs/kyle/EXTRACTED_EXACT_VALUES.md`) updated several hex values. The Flutter constants in `lib/theme/kyle_design/app_colors.dart` still use the **original estimates** in places (Blackberry `#3D1F47`, Cream `#F5F3ED`, Orange `#FF8B3D`, Electrolyte `#5DE4D3`, Dragonfruit `#E84393`). The Figma-extracted values (Blackberry `#381633`, Cream `#F8F6EB`, Orange `#F78B14`, Electrolyte `#1CF9CF`, Dragonfruit `#DC2597`) are documented as "exact" in `docs/kyle/DESIGN_TOKENS.md`. **For the web prototype, use the Figma-extracted values** — they match the screenshots Kyle delivered and they are what's already shipping in the Flutter `textLight`/`textDark` overrides (see `app_colors.dart:62`, `app_colors.dart:66`).

---

## 1. Brand summary

**Voice & mood.** Mealvana Endurance reads as a *premium athletic-nutrition* brand for endurance athletes. Looking at the screenshots (`docs/kyle/new_activity.png`, `docs/kyle/month_dark.png`, `docs/kyle/settings.png`, `docs/kyle/new_activity_dark.png`), three impressions stand out:

1. **Editorial, not "fitness app"** — the design avoids stock electric-blue gradients, neon green, and pumped-up bevels. Instead it pairs a **deep aubergine purple ("Blackberry")** with a **warm off-white ("Cream")**, which feels closer to a high-end cookbook or a boutique running brand than to a typical macros tracker.
2. **Athletic energy, controlled** — the accent palette is bold (a saturated orange CTA, a *very* bright cyan for activity/food chips, a magenta pink for warnings/destructive edits) but it's deployed in small doses against large quiet fields. The hero photography in `new_activity.png` uses a **bright cyan duotone with a magenta starburst behind the runner**, which is the most distinctive piece of the brand. Recreate that energy somewhere in the web prototype, even if just as a hero treatment.
3. **Confident, slightly retro typography** — Sansita (a friendly slab-ish display) for titles + Compadre Wide (extended uppercase) for subtitles + Apercu (a clean grotesque) for data and body. This trio is what makes the system feel custom rather than Material/HIG default.

**What is distinctive (don't lose this):**
- Blackberry + Cream as the *only* surface colors — never a generic gray background.
- 100px (fully rounded) primary buttons with a saturated orange fill and dark text.
- 36px Electrolyte-cyan circles for every food/activity icon — these are signature.
- Flat, no-elevation cards in dark mode; subtle 1px outlines instead of shadows.
- Uppercase data labels in tracked-out Compadre Wide.
- The "starburst" hero photo treatment (magenta zigzag halo around a duotone subject) on activity hero cards.

**What is NOT distinctive (safe to align with shadcn defaults):**
- Spacing scale — basically 8pt with no surprises.
- Form input affordances (label + outlined input).
- Switch/toggle behavior.

---

## 2. Color tokens

### 2.1 Full palette

These hex values come from `docs/kyle/DESIGN_TOKENS.md:181-298` and `docs/kyle/EXTRACTED_EXACT_VALUES.md:13-19` (Figma MCP extraction). Where the Flutter file in `lib/theme/kyle_design/app_colors.dart:11-35` still uses an older estimate, I note both — use the Figma value.

| Token | Hex (use this) | Flutter still says | Role |
|---|---|---|---|
| `blackberry` | `#381633` | `#3D1F47` (`app_colors.dart:11`) | Dark-mode background; primary text on cream |
| `blackberry-light` | `#4A2854` | `#4A2854` (`app_colors.dart:12`) | Dark-mode elevated surface (cards) |
| `blackberry-dark` | `#2D1535` | `#2D1535` (`app_colors.dart:13`) | Dark-mode deepest section |
| `blackberry-input` | `#5A3366` | `#5A3366` (`app_colors.dart:16`) | Dark-mode input fill (more contrast) |
| `cream` | `#F8F6EB` | `#F5F3ED` (`app_colors.dart:19`) | Light-mode background; text on blackberry |
| `cream-dark` | `#E8E6E0` | `#E8E6E0` (`app_colors.dart:20`) | Light-mode borders/dividers |
| `off-cream` | `#C6C3B2` | (n/a in Flutter) | Inactive/disabled chips, secondary text on cream |
| `orange` | `#F78B14` | `#FF8B3D` (`app_colors.dart:23`) | Primary CTA fill, plus/minus borders |
| `orange-light` | `#F9A042` | `#FFA05A` (`app_colors.dart:24`) | Hover |
| `orange-dark` | `#E57D0C` | `#E67A2E` (`app_colors.dart:25`) | Pressed |
| `electrolyte` | `#1CF9CF` | `#5DE4D3` (`app_colors.dart:28`) | Activity/food icon backgrounds, success |
| `electrolyte-light` | `#4FFBD9` | `#7FEEE0` (`app_colors.dart:29`) | Hover/lighter accent |
| `electrolyte-dark` | `#00E7BA` | `#3FD4C0` (`app_colors.dart:30`) | Switch active track |
| `dragonfruit` | `#DC2597` | `#E84393` (`app_colors.dart:33`) | Tertiary buttons, warnings, "Edit" links, errors |
| `dragonfruit-light` | `#E952AE` | `#F060A8` (`app_colors.dart:34`) | Hover |
| `dragonfruit-dark` | `#C31B7F` | `#D0357E` (`app_colors.dart:35`) | Pressed |

### 2.2 Tailwind config snippet

For Tailwind v3 *or* v4 — works the same way under `theme.extend.colors`. (Tailwind v4 also lets you do `@theme { --color-blackberry: ... }` in CSS — see §9.)

```ts
// tailwind.config.ts
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Brand — raw palette (use these only when you really need a
        // brand-named color; prefer the semantic shadcn slots below for
        // surfaces, text, borders, etc.)
        blackberry: {
          DEFAULT: "#381633",
          light: "#4A2854",
          dark: "#2D1535",
          input: "#5A3366",
        },
        cream: {
          DEFAULT: "#F8F6EB",
          dark: "#E8E6E0",
        },
        "off-cream": "#C6C3B2",
        orange: {
          DEFAULT: "#F78B14",
          light: "#F9A042",
          dark: "#E57D0C",
        },
        electrolyte: {
          DEFAULT: "#1CF9CF",
          light: "#4FFBD9",
          dark: "#00E7BA",
        },
        dragonfruit: {
          DEFAULT: "#DC2597",
          light: "#E952AE",
          dark: "#C31B7F",
        },

        // shadcn semantic slots — wired to CSS vars (see globals.css).
        // These are what you should reach for in components.
        background: "hsl(var(--background) / <alpha-value>)",
        foreground: "hsl(var(--foreground) / <alpha-value>)",
        card: {
          DEFAULT: "hsl(var(--card) / <alpha-value>)",
          foreground: "hsl(var(--card-foreground) / <alpha-value>)",
        },
        popover: {
          DEFAULT: "hsl(var(--popover) / <alpha-value>)",
          foreground: "hsl(var(--popover-foreground) / <alpha-value>)",
        },
        primary: {
          DEFAULT: "hsl(var(--primary) / <alpha-value>)",
          foreground: "hsl(var(--primary-foreground) / <alpha-value>)",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary) / <alpha-value>)",
          foreground: "hsl(var(--secondary-foreground) / <alpha-value>)",
        },
        accent: {
          DEFAULT: "hsl(var(--accent) / <alpha-value>)",
          foreground: "hsl(var(--accent-foreground) / <alpha-value>)",
        },
        muted: {
          DEFAULT: "hsl(var(--muted) / <alpha-value>)",
          foreground: "hsl(var(--muted-foreground) / <alpha-value>)",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive) / <alpha-value>)",
          foreground: "hsl(var(--destructive-foreground) / <alpha-value>)",
        },
        border: "hsl(var(--border) / <alpha-value>)",
        input: "hsl(var(--input) / <alpha-value>)",
        ring: "hsl(var(--ring) / <alpha-value>)",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};

export default config;
```

### 2.3 CSS custom properties (shadcn token mapping)

shadcn/ui historically uses HSL triplets for tokens (no `hsl()` wrapper, just `H S% L%`) so colors can be alpha-modulated cleanly. Below I provide both the HSL form (for shadcn parity) and the matching hex inline as a comment so future devs can see the mapping.

```css
/* app/globals.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    /* ---- Light mode (Cream theme) ---- */
    /* Background = cream, Foreground = blackberry */
    --background: 50 47% 95%;          /* #F8F6EB cream */
    --foreground: 314 44% 15%;         /* #381633 blackberry */

    /* Cards: in light mode, Kyle uses pure white panels on cream — see
       lib/theme/kyle_design/app_theme.dart:126 cardTheme uses surfaceLight (#FFFFFF). */
    --card: 0 0% 100%;                  /* #FFFFFF */
    --card-foreground: 314 44% 15%;     /* #381633 */

    --popover: 0 0% 100%;               /* #FFFFFF */
    --popover-foreground: 314 44% 15%;  /* #381633 */

    /* Primary = Orange CTA. Foreground on orange = blackberry (per
       docs/kyle/DESIGN_TOKENS.md:464 "Primary Button Text Color") */
    --primary: 30 94% 53%;              /* #F78B14 orange */
    --primary-foreground: 314 44% 15%;  /* #381633 blackberry */

    /* Secondary = Blackberry surface (used for selected segmented controls,
       activity selectors). Foreground = cream. */
    --secondary: 314 44% 15%;           /* #381633 */
    --secondary-foreground: 50 47% 95%; /* #F8F6EB */

    /* Accent = Electrolyte cyan. Foreground stays blackberry. */
    --accent: 169 95% 54%;              /* #1CF9CF */
    --accent-foreground: 314 44% 15%;   /* #381633 */

    /* Muted = off-cream / cream-dark. Used for secondary text, disabled
       states, table dividers. */
    --muted: 49 14% 89%;                /* #E8E6E0 cream-dark */
    --muted-foreground: 51 12% 73%;     /* #C6C3B2 off-cream */

    /* Destructive = Dragonfruit pink (also used for tertiary text buttons
       and "Edit" links — see docs/kyle/DESIGN_TOKENS.md:558). */
    --destructive: 325 73% 50%;         /* #DC2597 */
    --destructive-foreground: 50 47% 95%; /* #F8F6EB */

    /* Border in light mode = blackberry at low alpha for subtle outlines.
       The Flutter theme uses solid #381633 for primary borders
       (app_colors.dart:72 borderLight) and #E0E0E0 for secondary
       (app_colors.dart:73). Pick the secondary for default chrome. */
    --border: 0 0% 88%;                 /* #E0E0E0 */
    --input: 0 0% 88%;                  /* #E0E0E0 */
    --ring: 30 94% 53%;                 /* #F78B14 orange — focus ring matches CTA */

    /* Brand non-semantic raw tokens (rarely needed — prefer the slots above) */
    --brand-orange: 30 94% 53%;
    --brand-electrolyte: 169 95% 54%;
    --brand-dragonfruit: 325 73% 50%;
    --brand-blackberry: 314 44% 15%;
    --brand-cream: 50 47% 95%;

    --radius: 0.9375rem; /* 15px — Kyle's card/input radius */
  }

  .dark {
    /* ---- Dark mode (Blackberry theme) ---- */
    --background: 314 44% 15%;          /* #381633 */
    --foreground: 50 47% 95%;           /* #F8F6EB */

    /* Dark cards = blackberry-light (one step up). Per
       lib/theme/kyle_design/app_theme.dart:383 cardTheme uses surfaceDark = #4A2854. */
    --card: 297 36% 24%;                /* #4A2854 */
    --card-foreground: 50 47% 95%;      /* #F8F6EB */

    --popover: 297 36% 24%;
    --popover-foreground: 50 47% 95%;

    /* Primary stays orange in dark — see app_theme.dart:316 */
    --primary: 30 94% 53%;              /* #F78B14 */
    --primary-foreground: 314 44% 15%;  /* #381633 still */

    /* Secondary inverts: a step-up surface for selected pills/cards */
    --secondary: 297 36% 24%;           /* #4A2854 */
    --secondary-foreground: 50 47% 95%; /* #F8F6EB */

    --accent: 169 95% 54%;              /* #1CF9CF — same in both modes */
    --accent-foreground: 314 44% 15%;   /* #381633 — icons on cyan stay blackberry */

    --muted: 314 44% 22%;               /* between blackberry and blackberry-light */
    --muted-foreground: 50 25% 80%;     /* #CCCCCC-ish — see app_colors.dart:67 textDarkSecondary */

    --destructive: 325 73% 50%;         /* #DC2597 */
    --destructive-foreground: 50 47% 95%;

    /* Borders in dark are cream at low alpha — Flutter uses
       Color(0xFFF8F6EB).withOpacity(0.1) on dividers (app_theme.dart:495). */
    --border: 50 47% 95%;               /* used with /10 alpha utility */
    --input: 297 36% 30%;               /* #5A3366 blackberry-input — app_colors.dart:16 */
    --ring: 30 94% 53%;                 /* orange focus ring */
  }
}

@layer base {
  * { @apply border-border; }
  body {
    @apply bg-background text-foreground;
    font-feature-settings: "rlig" 1, "calt" 1;
  }
}
```

### 2.4 Light vs dark pairing rules (read this before building)

These come from `app_theme.dart:13-265` (light) and `app_theme.dart:270-522` (dark) plus `docs/kyle/DESIGN_TOKENS.md:1006-1020`:

- **Background flips, accents do not.** Orange, Electrolyte, and Dragonfruit are identical in both themes. Don't auto-tone them.
- **Text on Orange is always Blackberry.** Even in dark mode. (`app_theme.dart:317` uses `textDark` which is `#F8F6EB` *but* the design spec at `DESIGN_TOKENS.md:1015` says "Primary Button Text → Blackberry" in both modes. Match the spec, not the Flutter bug.)
- **Icons on Electrolyte are always Blackberry**, in both modes (`docs/kyle/EXTRACTED_EXACT_VALUES.md:189-201`).
- **Light mode uses subtle shadows.** Dark mode uses **no shadows** — depth is signaled with a one-step-lighter surface (`#4A2854`) and a 1px border (`app_spacing.dart:126`).
- **Cards in light mode are pure white (`#FFFFFF`)**, not cream. Cream is the *page* background. (`app_colors.dart:82` `surfaceLight`.) This is important — most "cream-on-cream" instincts are wrong.
- **Light borders are `#E0E0E0` for chrome, `#381633` for emphasis** (e.g., the segmented-control selected outline). (`app_colors.dart:72-73`.)

---

## 3. Typography

### 3.1 Three families

From `lib/theme/kyle_design/app_text_styles.dart:9-11` and `docs/kyle/DESIGN_TOKENS.md:21-152`:

| Family | Role | Web source |
|---|---|---|
| **Sansita** (Bold 700) | Page titles, section titles, button text, segmented control labels, large date/time | Free on Google Fonts: https://fonts.google.com/specimen/Sansita |
| **Compadre** (Regular + Wide) | Subtitles, food names, activity titles, distance labels, table headers — usually uppercase, tracked | Commercial (Type Department / unverified for the Wide variant). Local files exist under `assets/fonts/Compadre/` (demo). **For web, license check needed; fallback below.** |
| **Apercu** (Regular 400, Medium 500, Semibold 600, Bold 700; also `Apercu Mono`) | Body text, data numbers, small labels, input text | Commercial (Colophon Foundry). Local Pro files at `assets/fonts/Apercu/`. **License check needed; fallback below.** |

### 3.2 Web-safe fallbacks (use these until licensing is confirmed)

From `docs/kyle/DESIGN_TOKENS.md:1053-1056`:

- Sansita → **Sansita** (Google Fonts, free)
- Compadre Wide → **Work Sans** with `letter-spacing: 0.05em` and `text-transform: uppercase` — the design relies on the *wide tracked* feel, which Work Sans + letter-spacing reproduces convincingly.
- Apercu → **Inter** (Google Fonts) — visually closest free grotesque.
- Apercu Mono → **JetBrains Mono** or **IBM Plex Mono**.

### 3.3 `next/font` setup

```ts
// app/fonts.ts
import { Sansita, Work_Sans, Inter, JetBrains_Mono } from "next/font/google";

export const sansita = Sansita({
  subsets: ["latin"],
  weight: ["700", "800"],
  variable: "--font-sansita",
  display: "swap",
});

export const compadre = Work_Sans({
  subsets: ["latin"],
  weight: ["400", "500"],
  variable: "--font-compadre",
  display: "swap",
});

export const apercu = Inter({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-apercu",
  display: "swap",
});

export const apercuMono = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["400", "500"],
  variable: "--font-apercu-mono",
  display: "swap",
});
```

```tsx
// app/layout.tsx
import { sansita, compadre, apercu, apercuMono } from "./fonts";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html
      lang="en"
      className={`${sansita.variable} ${compadre.variable} ${apercu.variable} ${apercuMono.variable}`}
    >
      <body>{children}</body>
    </html>
  );
}
```

If/when the licensed Apercu and Compadre Wide files are confirmed for web use, swap the Google fonts for `next/font/local` pointing at `/public/fonts/Apercu-*.woff2` etc.

### 3.4 Tailwind theme extension

```ts
// tailwind.config.ts (theme.extend, alongside colors)
fontFamily: {
  sansita: ["var(--font-sansita)", "ui-serif", "Georgia", "serif"],
  compadre: ["var(--font-compadre)", "ui-sans-serif", "system-ui", "sans-serif"],
  apercu: ["var(--font-apercu)", "ui-sans-serif", "system-ui", "sans-serif"],
  "apercu-mono": ["var(--font-apercu-mono)", "ui-monospace", "monospace"],
  // shadcn default
  sans: ["var(--font-apercu)", "ui-sans-serif", "system-ui", "sans-serif"],
},
fontSize: {
  // Kyle's scale, named for usage. Sizes from app_text_styles.dart and
  // docs/kyle/DESIGN_TOKENS.md "Typography Scale Summary".
  "data-xl":    ["3rem",     { lineHeight: "1.2",  fontWeight: "700" }], // 48px dataNumberLarge
  "data":       ["2rem",     { lineHeight: "1.2",  fontWeight: "600" }], // 32px dataNumber
  "page-title": ["1.75rem",  { lineHeight: "1.2",  fontWeight: "700" }], // 28px pageTitle
  "date-time":  ["1.5rem",   { lineHeight: "1.2",  fontWeight: "700" }], // 24px dateTime
  "section":    ["1.25rem",  { lineHeight: "1.3",  fontWeight: "700" }], // 20px sectionTitle
  "activity":   ["1.125rem", { lineHeight: "1.3",  letterSpacing: "0.03em", fontWeight: "400" }], // 18px
  "body-lg":    ["1rem",     { lineHeight: "1.5",  fontWeight: "400" }], // 16px
  "subtitle":   ["1rem",     { lineHeight: "1.4",  letterSpacing: "0.03em", fontWeight: "400" }], // 16px
  "btn":        ["1rem",     { lineHeight: "1.2",  fontWeight: "700" }], // 16px buttonPrimary
  "body":       ["0.875rem", { lineHeight: "1.5",  fontWeight: "400" }], // 14px bodyMedium
  "descriptor": ["0.875rem", { lineHeight: "1.4",  letterSpacing: "0.03em" }], // 14px
  "input":      ["0.875rem", { lineHeight: "1.4",  fontWeight: "400" }], // 14px (Figma), 16px (Flutter)
  "label":      ["0.75rem",  { lineHeight: "1.3",  letterSpacing: "0.05em", fontWeight: "500" }], // 12px
  "segment":    ["0.75rem",  { lineHeight: "1.2",  fontWeight: "700" }], // 12px segmentedControl
  "caption":    ["0.625rem", { lineHeight: "1.3",  letterSpacing: "0.05em", fontWeight: "500" }], // 10px macroLabel/nutritionFact
  "unit":       ["0.4375rem",{ lineHeight: "1.2",  fontWeight: "400" }], // 7px unit labels
},
letterSpacing: {
  wider: "0.05em",
  widest: "0.1em",
},
```

### 3.5 Usage cheat sheet

| Use | Class |
|---|---|
| Screen title ("Activity Details") | `font-sansita text-page-title` |
| Section title ("Today's Activities") | `font-sansita text-section` |
| CTA button label | `font-sansita text-btn uppercase` |
| Activity/food name ("BAGELS", "ENERGY BAR") | `font-compadre text-descriptor uppercase tracking-wider` |
| Distance ("12 MILES") | `font-compadre text-subtitle uppercase tracking-wider` |
| Body paragraph | `font-apercu text-body` |
| Big number (823 calories) | `font-apercu text-data` |
| Small uppercase label ("DATE", "TIME") | `font-apercu text-label uppercase tracking-wider` |
| Nutrition facts grid value | `font-apercu text-body font-semibold` |
| Nutrition facts grid label ("CARBS") | `font-apercu text-caption uppercase tracking-wider` |

---

## 4. Spacing scale

From `lib/theme/kyle_design/app_spacing.dart:8-18`:

| Kyle token | Value | Tailwind default? | Tailwind class |
|---|---|---|---|
| `xxs` | 4px | yes (`1`) | `p-1`, `gap-1` |
| `xs` | 8px | yes (`2`) | `p-2` |
| `sm` | 12px | yes (`3`) | `p-3` |
| `md` | 16px | yes (`4`) | `p-4` |
| `lg` | 20px | yes (`5`) | `p-5` |
| `xl` | 24px | yes (`6`) | `p-6` |
| `xxl` | 32px | yes (`8`) | `p-8` |
| `xxxl` | 40px | yes (`10`) | `p-10` |
| `huge` | 48px | yes (`12`) | `p-12` |

**Good news:** Kyle's 8pt grid maps cleanly onto Tailwind's default scale. **No spacing customization needed.**

A few component dimensions worth memorializing as semantic tokens (from `app_spacing.dart:188-215`):

```ts
// tailwind.config.ts theme.extend, additions
spacing: {
  "input-h":   "2.875rem",  // 46px — Kyle's text-input height (app_spacing.dart:196)
  "btn-h":     "3.5rem",    // 56px — primary button height (app_spacing.dart:185)
  "control":   "2.25rem",   // 36px — plus/minus container, food/activity icon
  "icon-btn":  "3rem",      // 48px — circular icon button
  "act-sel-w": "3.875rem",  // 62px — activity type selector width
  "act-sel-h": "4.625rem",  // 74px — activity type selector height
},
```

**Screen padding** is `16px` (`md`) horizontal in the Flutter app (`app_spacing.dart:23`). On web, default to `px-4 md:px-6` for content gutters.

---

## 5. Radii, borders, shadows

### 5.1 Radii

From `lib/theme/kyle_design/app_spacing.dart:60-96` and `docs/kyle/EXTRACTED_EXACT_VALUES.md:55-65`:

| Token | Value | Used for |
|---|---|---|
| `xs` | 8px | (legacy) |
| `sm` | 12px | (legacy) |
| `card` / `input` | **15px** | Cards, text inputs, segmented controls, activity-type selectors |
| `pill` | **100px** | All buttons, plus/minus controls, circular action buttons |

Tailwind extension:

```ts
// tailwind.config.ts theme.extend.borderRadius
borderRadius: {
  // shadcn convention — drives <Card>, <Input>, etc.
  lg: "var(--radius)",            // 15px (set in :root)
  md: "calc(var(--radius) - 3px)",// 12px
  sm: "calc(var(--radius) - 7px)",// 8px

  // Kyle named tokens
  card: "0.9375rem",   // 15px
  input: "0.9375rem",  // 15px
  pill: "9999px",      // 100px+ (Kyle's "fully rounded")
},
```

### 5.2 Borders

- **Standard chrome:** `1px solid border` (uses `--border` CSS var).
- **Emphasized selection** (segmented control selected, activity selector selected): `2px solid hsl(var(--foreground))` — `border-2 border-foreground`.
- **Plus/minus control:** `2px solid hsl(var(--primary))` — `border-2 border-primary` (orange).
- **Outlined buttons** (Kyle's "secondary"): `2px solid hsl(var(--primary))` — `border-2 border-primary`.

### 5.3 Shadows

From `lib/theme/kyle_design/app_spacing.dart:106-135`:

```ts
// tailwind.config.ts theme.extend.boxShadow
boxShadow: {
  // Light mode shadows (subtle, ~8% black)
  "kyle-card":     "0 2px 8px 0 rgb(0 0 0 / 0.08)",
  "kyle-elevated": "0 4px 16px 0 rgb(0 0 0 / 0.12)",
  // Dark mode: no card shadow per design. For elevated overlays only:
  "kyle-elevated-dark": "0 4px 12px 0 rgb(0 0 0 / 0.30)",
},
```

Use `shadow-kyle-card dark:shadow-none` for cards. Dark mode reads "flat by default; depth from a lighter surface + 1px border."

---

## 6. Component vocabulary

This list is the union of `lib/shared/widgets/kyle_design/{buttons,cards,inputs,navigation,typography,feedback}/` and `docs/kyle/COMPONENTS_CATALOG.md`. For each, I name the Kyle component, what it does, the closest shadcn primitive, and what to customize.

### Buttons (`lib/shared/widgets/kyle_design/buttons/`)
| Kyle component | Description | shadcn primitive | Customize |
|---|---|---|---|
| `primary_button.dart` | Solid orange pill, blackberry text, Sansita Bold uppercase, 100px radius, 10/16 padding | `Button` (default variant) | New `kyle` variant: `bg-primary text-primary-foreground rounded-pill font-sansita uppercase` |
| `secondary_button.dart` | Outlined orange pill, transparent fill | `Button` (outline variant) | `border-2 border-primary text-primary rounded-pill font-sansita uppercase` |
| `tertiary_button.dart` | Text-only, dragonfruit pink, Apercu Medium 14px | `Button` (ghost or link variant) | `text-destructive font-apercu` |
| `circular_action_button.dart` | 48px circle icon button (Calendar, Menu, Add) | `Button` (icon size) | `size-12 rounded-full` |
| `segmented_control.dart` | Group of 2-3 pills with selected = filled blackberry, 15px radius | `ToggleGroup` | Override `data-[state=on]` styles, `rounded-card` |
| `selection_button.dart` | Activity-type selector (62×74, icon over label) | Custom — closest is a styled `Toggle` | Build custom |
| `add_food_button.dart` | Outlined orange `+ Add Food` pill | `Button` (outline) | `border-2 border-primary rounded-card text-sm` |

### Cards (`lib/shared/widgets/kyle_design/cards/`)
| Kyle component | Description | shadcn primitive | Customize |
|---|---|---|---|
| `base_card.dart` | 15px radius, optional elevation, subtle border | `Card` | Override radius (`rounded-card`), shadow (`shadow-kyle-card dark:shadow-none`) |
| `activity_hero_card.dart` | Hero image w/ magenta starburst overlay, activity icon, big date/time | Compose `Card` + custom hero treatment | Build the starburst SVG separately |
| `nutrition_section_card.dart` | Before/During/After Run section: header + macro summary + food list | Compose `Card` | Inline composition |
| `food_item_card.dart` | Expandable food row with Electrolyte icon | Use `Collapsible` inside `Card` | Custom |
| `macro_targets_table.dart` | Pre/During/Post × Carbs/Protein/Fluids/Sodium grid | `Table` | Style headers Compadre uppercase, values Apercu semibold |

### Inputs (`lib/shared/widgets/kyle_design/inputs/`)
| Kyle component | Description | shadcn primitive | Customize |
|---|---|---|---|
| `text_field.dart`, `kyle_input_field.dart` | 46px height, 15px radius, blackberry border on cream | `Input` | Set `h-input-h rounded-input` and orange focus ring |
| `kyle_dropdown.dart` | Same input chrome, with chevron | `Select` | Same chrome customizations |
| `kyle_switch.dart` | Track + thumb; active = electrolyte | `Switch` | `data-[state=checked]:bg-accent` |
| `plus_minus_control.dart` | [-] N unit [+] with 36px orange-bordered circles | Custom — compose two `Button`s and a value | Build inline |
| `two_option_pill_slider.dart` | "Indoor / Outdoor" pill selector | `ToggleGroup` (single) | Pill-shaped, blackberry-on-cream selected |
| `intensity_zone_slider.dart`, `intensity_distribution_widget.dart` | Sport-specific composite controls | Custom | Use `Slider` as substrate where possible |
| `intensity_preset_chips.dart` | Tap-to-select pills | `ToggleGroup` (single) | Pill chips |
| `duration_pace_toggle.dart`, `indoor_outdoor_toggle.dart` | Two-state toggles | `ToggleGroup` | Customize |

### Navigation (`lib/shared/widgets/kyle_design/navigation/`)
| Kyle component | Description | shadcn primitive | Customize |
|---|---|---|---|
| `floating_action_buttons_bar.dart` | 3 circular buttons centered at bottom (Calendar, Menu, Add) | Compose 3 `Button`s in a `nav` | On web prototype this could become a top nav or a sticky bottom bar |
| Tab selector ("BY MONTH / BY WEEK") | 2-up underline tabs | `Tabs` | Style `TabsTrigger` underline orange, Apercu uppercase |
| App bar | Back button (40px circle) + centered title | Custom header | Build inline; not really a shadcn component |

### Typography (`lib/shared/widgets/kyle_design/typography/`)
| Kyle component | Description | shadcn primitive | Customize |
|---|---|---|---|
| `section_header_text.dart` | "Today's Activities" header (Sansita Bold 18-20) | n/a — just typography | Render as `h2 className="font-sansita text-section"` |

### Feedback (`lib/shared/widgets/kyle_design/feedback/`)
| Kyle component | Description | shadcn primitive | Customize |
|---|---|---|---|
| `mealvana_snackbar.dart` | Brand-styled toast (success = electrolyte, error = dragonfruit) | `Toast` / `Sonner` | Theme background to `bg-accent`/`bg-destructive`, Blackberry text |

### Iconography (`lib/shared/widgets/kyle_design/icons/`)
| Kyle component | Description | shadcn primitive | Customize |
|---|---|---|---|
| `activity_icon.dart`, `food_icon.dart` | 36px circle, Electrolyte fill, Blackberry FA Sharp Regular icon | Custom | Build a `<CircularIcon icon={...} />` component |

---

## 7. Iconography

From `docs/kyle/FONT_AWESOME_PRO_SETUP.md:1-294`:

Kyle's design uses **Font Awesome 7 Pro Sharp Regular** for everything — activity icons (running, biking, swimming), food category icons (energy bar, banana, gel, droplet, bottle, etc.), navigation icons, and inline UI affordances (chevrons, plus, minus, X, heart).

### 7.1 Pro license required

The team has FA Pro for Flutter (`font_awesome_flutter_pro`). For Next.js the path is the same FA Pro license, but a different package: **`@awesome.me/kit-<KIT_ID>`** (FA's official kit-based npm distribution) or `@fortawesome/pro-sharp-regular-svg-icons` + `@fortawesome/react-fontawesome`. The team will need to:

1. Log in to https://fontawesome.com → Kits → create a kit (or reuse the mobile kit's package distribution).
2. Get an npm auth token from the FA dashboard.
3. Configure `.npmrc` with the FA registry:

```
@fortawesome:registry=https://npm.fontawesome.com/
//npm.fontawesome.com/:_authToken=${FONTAWESOME_NPM_TOKEN}
```

4. Install:

```bash
pnpm add @fortawesome/react-fontawesome @fortawesome/fontawesome-svg-core
pnpm add @fortawesome/pro-sharp-regular-svg-icons
```

### 7.2 Reusable component

```tsx
// components/circular-icon.tsx
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import type { IconDefinition } from "@fortawesome/fontawesome-svg-core";
import { cn } from "@/lib/utils";

type Props = {
  icon: IconDefinition;
  size?: number;        // container px
  iconSize?: number;    // glyph px
  className?: string;
};

export function CircularIcon({ icon, size = 36, iconSize = 18, className }: Props) {
  return (
    <span
      className={cn(
        "inline-flex shrink-0 items-center justify-center rounded-full bg-accent text-accent-foreground",
        className
      )}
      style={{ width: size, height: size }}
    >
      <FontAwesomeIcon icon={icon} style={{ fontSize: iconSize }} />
    </span>
  );
}
```

### 7.3 Icon size table

From `docs/kyle/FONT_AWESOME_PRO_SETUP.md:178-184`:

| Context | Container | Icon |
|---|---|---|
| Food / Activity | 36px circle | 18px |
| Plus/Minus control | 36px circle | 20px |
| Bottom nav button | 48px circle | 24px |
| Inline UI (chevron, edit) | n/a | 15-16px |
| Larger UI accents | n/a | 20px |

### 7.4 Fallback path (no Pro license yet)

Use **lucide-react** (which shadcn ships with by default) for the prototype's first cut. The Sharp Regular look will not match perfectly but the icon names are similar (`PersonStanding`, `Bike`, `Waves`, `Plus`, `Minus`, `X`, `Heart`, `ChevronDown`). Note this in PRs and swap to FA Pro before any branded screenshots ship.

---

## 8. Light/Dark mode strategy

The Flutter app supports system / light / dark via a `ThemeProvider` (referenced from `kyle_design.dart:30`) and exposes a `theme_toggle_widget.dart`. The pattern to mirror in Next.js:

1. **Use `next-themes`** (de facto standard, what shadcn docs assume):
   ```bash
   pnpm add next-themes
   ```
2. Wrap the root layout in a `<ThemeProvider attribute="class" defaultTheme="system" enableSystem>` from `next-themes`.
3. Tailwind `darkMode: "class"` is already set — Next-themes toggles `class="dark"` on `<html>`.
4. Build a `<ThemeToggle />` button in the header (sun/moon icons via FA or lucide).
5. **All colors must come from CSS variables**, never hardcoded `#381633`. The variables in §2.3 already have light + dark values; everything else will Just Work.

Per-mode rules to encode (recap from §2.4):
- Orange/Electrolyte/Dragonfruit are mode-invariant.
- Light cards = white (`hsl(var(--card))` resolves to `#FFFFFF` in light, `#4A2854` in dark).
- Dark cards = no shadow, just a 1px border at low opacity.
- Icons on Electrolyte are always blackberry — `text-accent-foreground` covers it because we made `--accent-foreground` blackberry in *both* modes.

---

## 9. Concrete starter file set

Lee mentioned `me_website_new`. I have not inspected it, so I'll provide both Tailwind v3 (most common for shadcn projects today) and Tailwind v4 (CSS-first config) variants of the entry points. Pick one path; the rest of the components are identical.

> **Tailwind v3 vs v4 quick check:** if `tailwind.config.ts` exists at the repo root and `@tailwind base;` directives are in `globals.css`, you're on **v3**. If there's no `tailwind.config.ts` and `globals.css` starts with `@import "tailwindcss";` plus `@theme { ... }`, you're on **v4**.

### 9.1 Tailwind v3 path

**`tailwind.config.ts`** — combine §2.2 (colors), §3.4 (typography), §4 (spacing extras), §5.1 (radii), §5.3 (shadows):

```ts
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    container: { center: true, padding: "1rem", screens: { "2xl": "1280px" } },
    extend: {
      colors: {
        // ... (paste §2.2 colors block here)
      },
      fontFamily: {
        sansita: ["var(--font-sansita)", "ui-serif", "Georgia", "serif"],
        compadre: ["var(--font-compadre)", "ui-sans-serif", "system-ui", "sans-serif"],
        apercu: ["var(--font-apercu)", "ui-sans-serif", "system-ui", "sans-serif"],
        "apercu-mono": ["var(--font-apercu-mono)", "ui-monospace", "monospace"],
        sans: ["var(--font-apercu)", "ui-sans-serif", "system-ui", "sans-serif"],
      },
      fontSize: {
        // ... (paste §3.4 fontSize block)
      },
      spacing: {
        "input-h":   "2.875rem",
        "btn-h":     "3.5rem",
        "control":   "2.25rem",
        "icon-btn":  "3rem",
        "act-sel-w": "3.875rem",
        "act-sel-h": "4.625rem",
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 3px)",
        sm: "calc(var(--radius) - 7px)",
        card: "0.9375rem",
        input: "0.9375rem",
        pill: "9999px",
      },
      boxShadow: {
        "kyle-card":          "0 2px 8px 0 rgb(0 0 0 / 0.08)",
        "kyle-elevated":      "0 4px 16px 0 rgb(0 0 0 / 0.12)",
        "kyle-elevated-dark": "0 4px 12px 0 rgb(0 0 0 / 0.30)",
      },
      keyframes: {
        "accordion-down": { from: { height: "0" }, to: { height: "var(--radix-accordion-content-height)" } },
        "accordion-up":   { from: { height: "var(--radix-accordion-content-height)" }, to: { height: "0" } },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up":   "accordion-up 0.2s ease-out",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};

export default config;
```

**`app/globals.css`** — paste §2.3 verbatim.

### 9.2 Tailwind v4 path (CSS-first)

`tailwind.config.ts` is no longer required. Put everything in `globals.css`:

```css
/* app/globals.css (Tailwind v4) */
@import "tailwindcss";

@custom-variant dark (&:where(.dark, .dark *));

@theme {
  /* Colors */
  --color-blackberry: #381633;
  --color-blackberry-light: #4A2854;
  --color-blackberry-dark: #2D1535;
  --color-cream: #F8F6EB;
  --color-cream-dark: #E8E6E0;
  --color-off-cream: #C6C3B2;
  --color-orange: #F78B14;
  --color-orange-light: #F9A042;
  --color-orange-dark: #E57D0C;
  --color-electrolyte: #1CF9CF;
  --color-electrolyte-light: #4FFBD9;
  --color-electrolyte-dark: #00E7BA;
  --color-dragonfruit: #DC2597;
  --color-dragonfruit-light: #E952AE;
  --color-dragonfruit-dark: #C31B7F;

  /* Semantic (driven by :root vars below) */
  --color-background:   hsl(var(--background));
  --color-foreground:   hsl(var(--foreground));
  --color-primary:      hsl(var(--primary));
  --color-primary-foreground: hsl(var(--primary-foreground));
  --color-accent:       hsl(var(--accent));
  --color-accent-foreground:  hsl(var(--accent-foreground));
  --color-destructive:  hsl(var(--destructive));
  --color-destructive-foreground: hsl(var(--destructive-foreground));
  --color-muted:        hsl(var(--muted));
  --color-muted-foreground:    hsl(var(--muted-foreground));
  --color-card:         hsl(var(--card));
  --color-card-foreground:     hsl(var(--card-foreground));
  --color-border:       hsl(var(--border));
  --color-input:        hsl(var(--input));
  --color-ring:         hsl(var(--ring));

  /* Fonts */
  --font-sansita: var(--font-sansita), ui-serif, Georgia, serif;
  --font-compadre: var(--font-compadre), ui-sans-serif, system-ui, sans-serif;
  --font-apercu: var(--font-apercu), ui-sans-serif, system-ui, sans-serif;
  --font-apercu-mono: var(--font-apercu-mono), ui-monospace, monospace;
  --font-sans: var(--font-apercu);

  /* Radii */
  --radius-card: 0.9375rem;
  --radius-input: 0.9375rem;
  --radius-pill: 9999px;

  /* Shadows */
  --shadow-kyle-card: 0 2px 8px 0 rgb(0 0 0 / 0.08);
  --shadow-kyle-elevated: 0 4px 16px 0 rgb(0 0 0 / 0.12);
  --shadow-kyle-elevated-dark: 0 4px 12px 0 rgb(0 0 0 / 0.30);

  /* Custom spacing */
  --spacing-input-h: 2.875rem;
  --spacing-btn-h: 3.5rem;
  --spacing-control: 2.25rem;
  --spacing-icon-btn: 3rem;
  --spacing-act-sel-w: 3.875rem;
  --spacing-act-sel-h: 4.625rem;
}

/* Mode-switched variables (paste the contents of :root and .dark from §2.3 here) */
:root { /* ...light mode HSL triplets... */ }
.dark { /* ...dark mode HSL triplets... */ }

@layer base {
  * { @apply border-border; }
  body { @apply bg-background text-foreground; }
}
```

### 9.3 `components/ui/button.tsx` — Kyle-themed shadcn Button

```tsx
import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap font-sansita uppercase tracking-wider transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-40 [&_svg]:pointer-events-none [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        // Kyle Primary — orange pill, blackberry text
        default:
          "rounded-pill bg-primary text-primary-foreground hover:bg-orange-light active:bg-orange-dark",
        // Kyle Secondary — outlined orange pill
        outline:
          "rounded-pill border-2 border-primary bg-transparent text-primary hover:bg-primary/10 active:bg-primary/20",
        // Kyle Tertiary — text-only dragonfruit
        ghost:
          "rounded-md font-apercu normal-case tracking-normal text-destructive hover:bg-destructive/10",
        // shadcn's destructive — solid dragonfruit
        destructive:
          "rounded-pill bg-destructive text-destructive-foreground hover:bg-dragonfruit-light",
        // Subtle blackberry-on-cream pill (used for selected segmented options)
        secondary:
          "rounded-card border-2 border-foreground bg-foreground text-background",
        link:
          "font-apercu normal-case tracking-normal text-destructive underline-offset-4 hover:underline",
      },
      size: {
        default: "h-btn-h px-6 py-2.5 text-btn",
        sm: "h-9 px-4 text-segment",
        lg: "h-14 px-8 text-btn",
        icon: "size-icon-btn rounded-full",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp
        ref={ref}
        className={cn(buttonVariants({ variant, size, className }))}
        {...props}
      />
    );
  }
);
Button.displayName = "Button";

export { buttonVariants };
```

### 9.4 `components/ui/card.tsx` — Kyle-themed shadcn Card

```tsx
import * as React from "react";
import { cn } from "@/lib/utils";

export const Card = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div
      ref={ref}
      className={cn(
        // Kyle: 15px radius, white-on-cream in light, blackberry-light surface in dark.
        // Subtle shadow in light only; no shadow in dark, just a 1px border.
        "rounded-card border bg-card text-card-foreground shadow-kyle-card dark:shadow-none",
        className
      )}
      {...props}
    />
  )
);
Card.displayName = "Card";

export const CardHeader = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn("flex flex-col gap-1.5 p-4", className)} {...props} />
  )
);
CardHeader.displayName = "CardHeader";

export const CardTitle = React.forwardRef<HTMLHeadingElement, React.HTMLAttributes<HTMLHeadingElement>>(
  ({ className, ...props }, ref) => (
    <h3
      ref={ref}
      className={cn("font-sansita text-section leading-tight", className)}
      {...props}
    />
  )
);
CardTitle.displayName = "CardTitle";

export const CardDescription = React.forwardRef<HTMLParagraphElement, React.HTMLAttributes<HTMLParagraphElement>>(
  ({ className, ...props }, ref) => (
    <p
      ref={ref}
      className={cn("font-apercu text-body text-muted-foreground", className)}
      {...props}
    />
  )
);
CardDescription.displayName = "CardDescription";

export const CardContent = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn("p-4 pt-0", className)} {...props} />
  )
);
CardContent.displayName = "CardContent";

export const CardFooter = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn("flex items-center p-4 pt-0", className)} {...props} />
  )
);
CardFooter.displayName = "CardFooter";
```

### 9.5 `components/ui/circular-icon.tsx`

(Already shown in §7.2 — include in the starter set.)

### 9.6 Smoke-test page

```tsx
// app/page.tsx (or app/(prototype)/styleguide/page.tsx)
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";

export default function Page() {
  return (
    <main className="min-h-screen bg-background px-6 py-10 text-foreground">
      <h1 className="font-sansita text-page-title">Kyle Style Smoke Test</h1>
      <p className="font-apercu text-body text-muted-foreground mt-2">
        If this looks like the screenshots in <code>docs/kyle/</code>, the tokens are wired up.
      </p>

      <section className="mt-10 grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Today&rsquo;s Activities</CardTitle>
            <CardDescription>Long endurance run, 12 miles.</CardDescription>
          </CardHeader>
          <CardContent className="flex flex-wrap gap-3">
            <Button>Generate Plan</Button>
            <Button variant="outline">Edit Macros</Button>
            <Button variant="ghost">Remove</Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="font-compadre uppercase tracking-wider text-subtitle">
              10 Mile Run
            </CardTitle>
            <CardDescription>18.8 mi &middot; 10:30/mi</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="font-apercu-mono text-data">823</p>
            <p className="font-apercu text-caption uppercase tracking-wider text-muted-foreground">
              Total Burn
            </p>
          </CardContent>
        </Card>
      </section>
    </main>
  );
}
```

---

## 10. Open questions and gaps

1. **Apercu and Compadre licensing for web.** The team has Pro Apercu locally (`assets/fonts/Apercu/`) and demo Compadre files. The Flutter `pubspec.yaml` ships them as embedded assets, but **embedding in a public web app is a different license.** Action: confirm Apercu and Compadre web licenses with Colophon Foundry / Type Department before launch. Until then the prototype uses Inter + Work Sans, which the report covers.

2. **Compadre Wide vs Compadre Regular.** The Figma extraction (`docs/kyle/EXTRACTED_EXACT_VALUES.md:30-33`) calls out `Compadre:Regular` *and* `Compadre:Wide` as separate cuts. Work Sans + `tracking-wider` simulates "Wide" reasonably, but only one Work Sans cut is needed. If the licensed Compadre family ships with both, expose them as `font-compadre` and `font-compadre-wide`.

3. **Apercu Mono vs Apercu.** Figma shows nutritional values and search inputs use **Apercu Mono** (`docs/kyle/EXTRACTED_EXACT_VALUES.md:46-50`), while body uses Apercu (proportional). The Flutter `app_text_styles.dart` uses Apercu (proportional) for *both* — this is a known drift. The web should honor the Figma intent: numbers and inputs in Apercu Mono / fallback `font-apercu-mono`.

4. **Hex value drift between Figma and Flutter.** Documented at the top — the prototype follows Figma. If the Flutter app later lands a sweep to update its hex constants to the Figma values, the web side does not need to change.

5. **Hero image starburst treatment.** The activity hero (`new_activity.png`) has a magenta zigzag halo around a duotone-cyan subject. There's no Flutter component or web equivalent yet. This will need a designer pass — likely an SVG mask layer + a CSS `mix-blend-mode` duotone filter. Out of scope for the token spec but **call this out before any "hero" feature is shipped**.

6. **Bottom-nav vs. top-nav for web.** Kyle's bottom floating action bar (`floating_action_buttons_bar.dart`) is a mobile pattern. The web prototype should likely move primary navigation to a top header with the same circular-button vocabulary. Decision needed.

7. **Outlined-button text color in dark mode.** `app_theme.dart:73-78` and `:330-335` give outlined buttons orange text + orange border in *both* modes, but `docs/kyle/DESIGN_TOKENS.md:506-518` says the secondary's border + text should be **cream** in dark mode and **blackberry** in light mode (i.e., neutral, not orange). The Figma screenshots agree with the spec, not the Flutter theme. The web should follow the spec: secondary outlined buttons use `border-foreground text-foreground`, not `border-primary text-primary`. (The `Button` variant `outline` in §9.3 uses orange — that's correct for emphasis; consider also a `secondaryOutline` variant for the neutral case.)

8. **Border-radius `--radius` tokenization.** shadcn's default is 0.5rem; we set it to 0.9375rem (15px) so `rounded-md`/`rounded-lg` track Kyle's card radius. Buttons explicitly use `rounded-pill` (100px). Tab/menu/dropdown components from shadcn that pick up `rounded-md` will end up at ~12px (`calc(15px - 3px)`) — matches the design intent.

9. **Sentry / analytics theming.** Out of scope here, but worth flagging: any third-party widget that injects its own styles (Sentry feedback, RevenueCat paywall, Stripe Elements) will need brand overrides. List those as you wire them in.

10. **Shadows on dark mode overlays.** Dark cards have no shadow, but **dropdowns and dialogs** still need depth in dark mode. The token `--shadow-kyle-elevated-dark` (0 4px 12px black/30%) covers this; apply it to `Popover`, `DropdownMenu`, `Dialog` content, etc.

---

## Appendix: file pointers

For an engineer resuming this work, these are the highest-value source files:

- `/Users/leemartin/development/mealvana_endurance/lib/theme/kyle_design/app_colors.dart:1-88`
- `/Users/leemartin/development/mealvana_endurance/lib/theme/kyle_design/app_text_styles.dart:1-231`
- `/Users/leemartin/development/mealvana_endurance/lib/theme/kyle_design/app_spacing.dart:1-216`
- `/Users/leemartin/development/mealvana_endurance/lib/theme/kyle_design/app_theme.dart:1-545`
- `/Users/leemartin/development/mealvana_endurance/docs/kyle/DESIGN_TOKENS.md` (full system reference)
- `/Users/leemartin/development/mealvana_endurance/docs/kyle/EXTRACTED_EXACT_VALUES.md` (Figma-true tokens)
- `/Users/leemartin/development/mealvana_endurance/docs/kyle/COMPONENTS_CATALOG.md` (component-by-component spec)
- `/Users/leemartin/development/mealvana_endurance/docs/kyle/FONT_AWESOME_PRO_SETUP.md` (icon strategy)
- Screenshots: `/Users/leemartin/development/mealvana_endurance/docs/kyle/{settings,settings_dark,month_light,month_dark,new_activity,new_activity_dark}.png`

End of report.
