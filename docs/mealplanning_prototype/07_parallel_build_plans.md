# 07 — Parallel Build Plans for the Meal-Planning Prototype

**Document version:** 1.0
**Date:** 2026-05-06
**Author:** Build lead synthesis
**Target repo:** `/Users/leemartin/development/mealplanning_prototype` (does not exist yet — this doc tells you how to create it)
**Status:** Build-ready playbook — supersedes the build sections of `05_design_proposal.md` for execution purposes (the design itself still lives there + in `06_five_uiux_approaches.md`).

This document is the project bible for building the five parallel UI/UX prototypes (A · Calendar, B · Stack, C · Columns, D · Hybrid, E · Coach) plus the landing-page hub in a single repository, using a worktree-per-variant model so up to five Claude code-executor agents can ship in parallel without stepping on each other.

It is *not* a design doc. For design intent see:

- `01_meal_planning_landscape.md` and `01a_top_picks_summary.md` — competitive context
- `02_me_website_new_stack.md` — the actual TanStack Start + Vite + Nitro stack we are inheriting (Convex/Sanity stripped; Supabase substituted)
- `03_kyle_design_for_web.md` — Kyle brand tokens + Tailwind/shadcn snippets
- `04_user_data_inventory.md` — Supabase schema + edge functions
- `05_design_proposal.md` — the prior single-design doc; still the source of truth for Phase 0 architecture details, schema deltas, and AI tool definitions
- `06_five_uiux_approaches.md` — the five variants A–E (Jade, wireframes, surface specs)

Where this doc and the design docs disagree, the design docs win. Where the design docs are silent, this doc decides.

---

## Table of Contents

- §0 — How parallelization works (worktrees, shared vs forked files, sync protocol, naming convention)
- §1 — Phase 0: shared scaffold (built ONCE on `main`, before any variant work starts)
- §2 — Phase 1A: variant A "Calendar"
- §3 — Phase 1B: variant B "Stack"
- §4 — Phase 1C: variant C "Columns"
- §5 — Phase 1D: variant D "Hybrid"
- §6 — Phase 1E: variant E "Coach"
- §7 — Cross-cutting build concerns (cost, observability, errors, a11y, perf)
- §8 — Parallel execution playbook (5-tab orchestration, kickoff prompts, STATUS.md, merge-back)
- §9 — Risk register
- §10 — Suggested daily-scrum milestone calendar
- Appendix A — File ownership matrix (who-touches-what)
- Appendix B — Quick reference of commands

---

## §0 — How Parallelization Works

### 0.1 The model: one repo, five worktrees, five branches

We use **git worktrees** — a single `.git` directory but multiple checked-out working directories, each on its own branch. This means:

- One `package.json`, one lockfile, one node_modules per worktree (each worktree gets its own — that is fine; pnpm hardlinks make it cheap).
- Five Claude code-executor agents can run `pnpm dev` simultaneously on five different ports without interfering.
- Variant branches share history through `main`; merging back is a normal PR.
- Each variant deploys to its own Vercel preview URL automatically when its branch is pushed.

ASCII layout:

```
/Users/leemartin/development/mealplanning_prototype/                <- main worktree, branch `main`
  .git/                                                              <- the only real git dir
  packages/web/...                                                   <- shared scaffold, Phase 0 work happens here

/Users/leemartin/development/mealplanning_prototype-a/               <- branch `variant/a`, port 3001
/Users/leemartin/development/mealplanning_prototype-b/               <- branch `variant/b`, port 3002
/Users/leemartin/development/mealplanning_prototype-c/               <- branch `variant/c`, port 3003
/Users/leemartin/development/mealplanning_prototype-d/               <- branch `variant/d`, port 3004
/Users/leemartin/development/mealplanning_prototype-e/               <- branch `variant/e`, port 3005
```

### 0.2 Exact bootstrap commands

After Phase 0 is committed to `main` (see §1), run these from the main worktree:

```bash
cd /Users/leemartin/development/mealplanning_prototype

# Create variant branches off main and check them out into sibling directories
git branch variant/a
git branch variant/b
git branch variant/c
git branch variant/d
git branch variant/e

git worktree add ../mealplanning_prototype-a variant/a
git worktree add ../mealplanning_prototype-b variant/b
git worktree add ../mealplanning_prototype-c variant/c
git worktree add ../mealplanning_prototype-d variant/d
git worktree add ../mealplanning_prototype-e variant/e

# Each worktree needs its own install (pnpm hardlinks node_modules so it's cheap)
for d in mealplanning_prototype-{a,b,c,d,e}; do
  ( cd "/Users/leemartin/development/$d" && pnpm install )
done
```

To remove a worktree later: `git worktree remove ../mealplanning_prototype-a` (this leaves the branch intact; use `git branch -D variant/a` to drop the branch too).

### 0.3 Per-worktree dev port assignment

To keep five `pnpm dev` instances from colliding, the variant routes always run on the same port across worktrees, but we differentiate with a `PORT` env var per worktree. Add to each variant's `.env.local`:

```
# /Users/leemartin/development/mealplanning_prototype-a/packages/web/.env.local
PORT=3001
```

```
# -b/...
PORT=3002
# -c/... PORT=3003
# -d/... PORT=3004
# -e/... PORT=3005
```

`vite.config.ts` already reads `process.env.PORT` (TanStack Start respects it). Confirm in Phase 0 step 8.

### 0.4 Shared vs forked files — the rule

**SHARED files** (touched only on `main`; variants never edit them; if a variant needs a change, it lands as a PR to `main` and variants rebase):

- `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `turbo.json`, `tsconfig.json`, `vite.config.ts`, `vercel.json`, `.nvmrc`
- `packages/web/components.json`, `packages/web/playwright.config.ts`, `packages/web/vitest.config.ts`
- `packages/web/src/styles/globals.css` (Kyle tokens)
- `packages/web/src/components/ui/**` (shadcn primitives, Kyle-themed)
- `packages/web/src/components/shared/**` (JadeAvatar, MealCell, DayColumn, MacroTotalsRail, JadeChatPanel, SwapDrawer, KyleButton, KyleCard, MacroBar, TrainingDayDot, CarbTierBadge, JadeMessageCard)
- `packages/web/src/lib/**` (utils, supabase client, auth helpers, jade module — see §1)
- `packages/web/src/server/jade/**` (Jade backend: system prompt, tools, streaming endpoints)
- `packages/web/src/routes/__root.tsx` (app shell)
- `packages/web/src/routes/index.tsx` (landing page hub)
- `packages/web/src/routes/sign-in.tsx`, `sign-up.tsx`, `onboarding/bridge.tsx`
- `packages/web/src/routes/settings.tsx`
- `packages/web/src/routes/styleguide.tsx`
- `packages/web/src/routes/api/jade/**` (the streaming endpoints variants call)
- `supabase/migrations/**`
- `STATUS.md` at repo root

**FORKED files** (touched only inside variant branches):

- `packages/web/src/routes/plan.a.tsx` — variant A only
- `packages/web/src/routes/plan.b.tsx` — variant B only
- `packages/web/src/routes/plan.c.tsx` — variant C only
- `packages/web/src/routes/plan.d.tsx` — variant D only
- `packages/web/src/routes/plan.e.tsx` — variant E only
- `packages/web/src/components/variant-a/**` — variant A only
- `packages/web/src/components/variant-b/**` — variant B only
- `packages/web/src/components/variant-c/**` — variant C only
- `packages/web/src/components/variant-d/**` — variant D only
- `packages/web/src/components/variant-e/**` — variant E only
- `packages/web/src/server/variants/{a,b,c,d,e}/**` — variant-specific server functions (rare; most server code is shared in `src/server/jade/`)

If a variant agent finds it needs a new shared component — say variant B realizes it needs a new `<JadeNarrator>` that variant E might reuse — the rule is:

1. Build it inside the variant branch first (`components/variant-b/jade-narrator.tsx`).
2. When demoable, propose moving it to `components/shared/` via a PR to `main`.
3. Other variants rebase.

This avoids a paralysis where every component change requires a sync.

Naming convention recap (for any new file):

- A route owned by exactly one variant: `routes/plan.{x}.tsx`
- A component owned by exactly one variant: `components/variant-{x}/<kebab-name>.tsx`
- A server function owned by exactly one variant: `server/variants/{x}/<kebab-name>.ts`
- A shared route, component, server function: `routes/<name>.tsx`, `components/shared/<name>.tsx`, `server/jade/<name>.ts`

### 0.5 Sync protocol — when shared files need to change mid-build

The most common reason for cross-variant collisions is a missing shared primitive. The protocol:

1. **Authority for shared files lives on `main`.** Only `main` commits can change `components/shared/*`, `lib/*`, `server/jade/*`, migrations, scaffold config.
2. **Variants make a request to `main`.** A variant agent that needs a shared change opens a PR titled `shared: <thing>` against `main`. Lee approves.
3. **Variants rebase, never merge.** After `main` lands the change, every variant runs `git fetch origin && git rebase origin/main`. Conflicts in shared files are resolved by accepting `main`'s version.
4. **Variants never edit `package.json` directly** (adding deps). If a variant needs a new package, the variant agent proposes it; Lee runs `pnpm add ... -w` on `main` and the variants rebase. This avoids three variants installing three different versions of the same package.

Exception: variant-only dev dependencies (e.g., a one-off Storybook plugin a variant uses to debug) can live in the variant branch's `package.json` if absolutely needed — but in practice, just put them on `main`.

### 0.6 Branch protection + merge strategy

- `main` is protected: no direct pushes, PR-only, requires Lee's review (or Claude code-reviewer skill review).
- Variant branches have no protection — agents push freely.
- Variants are not merged back into `main` during the prototype phase. After the user-test results are in, the **winning variant** gets a `winner/x` branch, which is rebased into `main`. The other four variants stay as branches in case we want to revisit them.

### 0.7 Vercel preview deploys per branch

Every push to a variant branch triggers a Vercel preview deploy at a unique URL: `mealplanning-prototype-git-variant-{x}-leesteam.vercel.app` (or whatever Vercel picks). Lee shares those URLs with testers in five different browser tabs and lets the tabs themselves be the A/B/C/D/E preference test surface.

---

## §1 — Phase 0: Shared Scaffold (built ONCE on `main`)

This is the long-running prerequisite. Until Phase 0 is done, no variant work can start. Estimate: **6–10 working hours for one focused agent.**

Phase 0 has 25 numbered steps. Each step has: subject, files to create/edit, command(s), expected result, gotchas.

### 1.0 Definition of done for Phase 0

By the end, all of the following are true on `main`:

1. The repo `/Users/leemartin/development/mealplanning_prototype` exists, is a pnpm workspace, contains `packages/web/` running on TanStack Start + Vite + Nitro.
2. Tailwind v4 + Kyle tokens from `03_kyle_design_for_web.md` §2.3 are wired and visible at `/styleguide`.
3. Clerk auth works: `/sign-in` and `/sign-up` render Clerk's UI; `/onboarding/bridge` matches Clerk users to Supabase `users.email`.
4. A signed-in user can hit `/settings` and see their real food preferences, allergies, dietary preference, current macro targets, and the upcoming-7-days training schedule from Supabase, RLS-filtered.
5. A signed-in user can hit `/api/jade/hello` and get a streamed one-line response from the model via Vercel AI Gateway.
6. The `meal_plans` and `meal_plan_meals` tables exist in dev Supabase with RLS policies; `approach_used` column included.
7. The landing page at `/` renders five cards (A–E), each linking to a stub at `/plan/a` … `/plan/e` (which can return "Variant X coming soon" — the actual variant routes are filled in by §2–§6).
8. ESLint + Prettier + Husky lint-staged are green on a clean checkout.
9. A Vercel project is linked and a preview deploy from `main` is up.

### 1.1 Step 1 — Init the repo

**Subject:** Create the directory and pnpm workspace skeleton.

**Files to create:** `package.json`, `pnpm-workspace.yaml`, `.nvmrc`, `.gitignore`, `turbo.json`, `tsconfig.json`, `README.md`, `STATUS.md`.

**Commands:**

```bash
mkdir -p /Users/leemartin/development/mealplanning_prototype
cd /Users/leemartin/development/mealplanning_prototype
git init -b main
pnpm init
```

Then write the following.

`/Users/leemartin/development/mealplanning_prototype/package.json`:

```json
{
  "name": "mealplanning-prototype",
  "private": true,
  "scripts": {
    "dev":         "pnpm --filter @mealplanning/web dev",
    "build":       "pnpm --filter @mealplanning/web build",
    "start":       "pnpm --filter @mealplanning/web start",
    "typecheck":   "pnpm -r typecheck",
    "test":        "pnpm -r test",
    "test:e2e":    "pnpm --filter @mealplanning/web test:e2e",
    "lint":        "pnpm -r lint",
    "format":      "prettier --write .",
    "supabase:types": "pnpm dlx supabase gen types typescript --project-id $SUPABASE_PROJECT_ID > packages/web/src/lib/supabase/types.ts"
  },
  "engines": { "node": ">=20", "pnpm": ">=9" },
  "devDependencies": {
    "typescript": "^5.9.3",
    "prettier": "^3.3.0",
    "eslint": "^9.0.0",
    "husky": "^9.0.0",
    "lint-staged": "^16.0.0",
    "turbo": "^2.0.0"
  },
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{json,md,css}": ["prettier --write"]
  }
}
```

`pnpm-workspace.yaml`:

```yaml
packages:
  - "packages/*"

onlyBuiltDependencies:
  - esbuild
  - "@clerk/shared"
```

`.nvmrc`:

```
20
```

`.gitignore` (lift from `me_website_new/.gitignore` and add):

```
node_modules
.output
.vinxi
.vercel
.env
.env.*
!.env.example
*.log
.DS_Store
.turbo
dist
coverage
playwright-report
test-results
```

`turbo.json` — copy verbatim from `me_website_new/turbo.json` (see `02_me_website_new_stack.md` §1).

`tsconfig.json` (root):

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "isolatedModules": true,
    "jsx": "react-jsx"
  },
  "references": [
    { "path": "./packages/web" }
  ]
}
```

`STATUS.md` — see §8.3 below for the template.

**Expected result:** `pnpm install` runs without errors and creates `node_modules/` + `pnpm-lock.yaml`.

**Gotchas:** pnpm 9+ is required (`pnpm -v`); if older, `npm i -g pnpm@latest`.

### 1.2 Step 2 — Bootstrap `@mealplanning/web` package

**Subject:** Create the TanStack Start app shell.

**Files to create:** `packages/web/package.json`, `packages/web/tsconfig.json`, `packages/web/vite.config.ts`, `packages/web/components.json`, `packages/web/index.html`.

**Commands:**

```bash
mkdir -p packages/web/src/{routes,components,lib,styles,server}
mkdir -p packages/web/public/fonts
```

`packages/web/package.json` — adapt from `me_website_new/packages/web/package.json` but trim:

```json
{
  "name": "@mealplanning/web",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite dev",
    "build": "vite build",
    "start": "node .output/server/index.mjs",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:e2e": "playwright test",
    "ui": "pnpm dlx shadcn@latest"
  },
  "dependencies": {
    "@tanstack/react-router": "^1.168.10",
    "@tanstack/react-router-ssr-query": "^1.166.10",
    "@tanstack/react-query": "^5.96.2",
    "@tanstack/react-start": "^1.167.16",
    "@clerk/tanstack-react-start": "^1.0.11",
    "@clerk/react": "^6.2.1",
    "@supabase/supabase-js": "^2.45.0",
    "ai": "^5.0.0",
    "@ai-sdk/react": "^2.0.0",
    "@ai-sdk/openai": "^2.0.0",
    "@ai-sdk/anthropic": "^2.0.0",
    "@ai-sdk/gateway": "^1.0.0",
    "zod": "^4.3.6",
    "react": "^19.2.4",
    "react-dom": "^19.2.4",
    "motion": "^12.38.0",
    "sonner": "^2.0.7",
    "lucide-react": "^0.564.0",
    "clsx": "^2.1.1",
    "tailwind-merge": "^2.5.0",
    "class-variance-authority": "^0.7.0",
    "@radix-ui/react-slot": "^1.1.0",
    "next-themes": "^0.4.0",
    "dayjs": "^1.11.13",
    "@dnd-kit/core": "^6.1.0",
    "@dnd-kit/modifiers": "^7.0.0"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.2.2",
    "tailwindcss": "^4.2.2",
    "tw-animate-css": "^0.3.0",
    "vite": "^8.0.7",
    "vitest": "^4.1.3",
    "@playwright/test": "^1.52.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@types/node": "^20.0.0",
    "typescript": "^5.9.3"
  }
}
```

`packages/web/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "isolatedModules": true,
    "jsx": "react-jsx",
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    },
    "types": ["vite/client"]
  },
  "include": ["src/**/*", "vite.config.ts", "playwright.config.ts", "vitest.config.ts"]
}
```

`packages/web/vite.config.ts` (adapted from `02_me_website_new_stack.md` §2 with Convex bits stripped):

```ts
import { defineConfig } from "vite";
import { tanstackStart } from "@tanstack/react-start/plugin/vite";
import tailwindcss from "@tailwindcss/vite";
import path from "node:path";

export default defineConfig({
  server: {
    port: Number(process.env.PORT ?? 3000),
  },
  resolve: {
    alias: { "@": path.resolve(__dirname, "src") },
  },
  plugins: [
    tanstackStart({ target: "node-server" }),
    tailwindcss(),
  ],
  ssr: {
    noExternal: [
      "@clerk/tanstack-react-start",
      "@clerk/clerk-react",
      "@clerk/shared",
    ],
  },
});
```

`packages/web/components.json` (shadcn config — Tailwind v4 mode):

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "css": "src/styles/globals.css",
    "baseColor": "neutral",
    "cssVariables": true
  },
  "iconLibrary": "lucide",
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  }
}
```

`packages/web/index.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Mealvana — meal planning prototype</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/start.ts"></script>
  </body>
</html>
```

**Commands:**

```bash
pnpm install
```

**Expected result:** `pnpm install` succeeds, lockfile updates, `pnpm --filter @mealplanning/web dev` starts a Vite server on port 3000 (will 404 until we add a root route in step 5).

**Gotchas:** TanStack Start's plugin name and target field changes occasionally between versions — if `@tanstack/react-start/plugin/vite` doesn't exist in the installed version, check the package's `dist/` for the actual plugin export. The `me_website_new` repo at `/Users/leemartin/development/me_website_new/packages/web/vite.config.ts` is the live reference.

### 1.3 Step 3 — Tailwind v4 + Kyle tokens

**Subject:** Wire Tailwind v4 with Kyle's full design tokens.

**Files to create:** `packages/web/src/styles/globals.css`.

Copy the **full** content of `03_kyle_design_for_web.md` §9.2 (the v4 path). Key ingredients:

- `@import "tailwindcss"`
- `@import "tw-animate-css"`
- `@theme { ... }` block with Kyle brand colors (Blackberry `#381633`, Cream `#F8F6EB`, Orange `#F78B14`, Electrolyte `#1CF9CF`, Dragonfruit `#DC2597`, plus light/dark variants)
- Semantic shadcn slot CSS vars (`--background`, `--foreground`, `--card`, `--primary`, `--accent`, `--destructive`, `--border`, etc.) — see §2.3 of `03_kyle_design_for_web.md`
- Font family vars (`--font-sansita`, `--font-compadre`, `--font-apercu`, `--font-apercu-mono`)
- Custom radii (`--radius-card: 0.9375rem`, `--radius-pill: 9999px`, `--radius: 0.9375rem`)
- Custom spacings (`--spacing-input-h`, `--spacing-btn-h`, `--spacing-control`, `--spacing-icon-btn`)
- Custom shadows (`--shadow-kyle-card`, `--shadow-kyle-elevated`, `--shadow-kyle-elevated-dark`)
- `:root` and `.dark` blocks with HSL triplets
- `@layer base { * { @apply border-border; } body { @apply bg-background text-foreground; } }`

**Expected result:** the styleguide page in step 14 will pick these up.

**Gotchas:** Tailwind v4's CSS-first config means **no** `tailwind.config.ts`. If you copy v3 examples by accident, they will silently no-op. The shadcn CLI (`pnpm dlx shadcn@latest`) generates v3-compatible files — ignore those generated config files; we only want the component TSX.

### 1.4 Step 4 — Fonts

**Subject:** Load Sansita Bold (display), Apercu (body), Apercu Mono (numerals), with Inter / Work Sans / JetBrains Mono fallbacks until Apercu/Compadre licensing for web is sorted (per `03_kyle_design_for_web.md` §3.2 + §10).

**Files to create:** `packages/web/src/styles/fonts.css`.

```css
/* Until Apercu and Compadre Wide are licensed for web, use:
   Sansita (Google) → Sansita
   Compadre Wide   → Work Sans + tracking-wider + uppercase (in usage)
   Apercu          → Inter
   Apercu Mono     → JetBrains Mono
*/
@import url('https://fonts.googleapis.com/css2?family=Sansita:wght@700;800&family=Work+Sans:wght@400;500&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');

:root {
  --font-sansita: 'Sansita', ui-serif, Georgia, serif;
  --font-compadre: 'Work Sans', ui-sans-serif, system-ui, sans-serif;
  --font-apercu: 'Inter', ui-sans-serif, system-ui, sans-serif;
  --font-apercu-mono: 'JetBrains Mono', ui-monospace, monospace;
}
```

In `globals.css`, add `@import "./fonts.css";` at the top.

**Expected result:** `font-sansita`, `font-compadre`, `font-apercu`, `font-apercu-mono` Tailwind utilities work.

**Gotchas:** Don't `@font-face` Apercu locally yet — the Pro license question (see `03_kyle_design_for_web.md` §10 open question 1) is unresolved for web. Inter is good enough until that's confirmed.

### 1.5 Step 5 — Root route + app shell

**Subject:** The TanStack Start `__root.tsx` with global providers.

**Files to create:**

- `packages/web/src/router.tsx`
- `packages/web/src/start.ts`
- `packages/web/src/routes/__root.tsx`
- `packages/web/src/routeTree.gen.ts` (auto-generated; touch only to commit)
- `packages/web/src/components/shared/app-header.tsx`
- `packages/web/src/components/shared/app-footer.tsx`

`start.ts` (request middleware for Clerk):

```ts
import { clerkMiddleware } from "@clerk/tanstack-react-start/server";
import { createStart } from "@tanstack/react-start";

export const startInstance = createStart(() => ({
  requestMiddleware: [clerkMiddleware()],
}));
```

`router.tsx` — see `02_me_website_new_stack.md` §8 for the live reference. Wire `QueryClient` + `setupRouterSsrQueryIntegration`.

`routes/__root.tsx` (sketch):

```tsx
import { ClerkProvider } from "@clerk/tanstack-react-start";
import { Outlet, createRootRoute, HeadContent, Scripts } from "@tanstack/react-router";
import { Toaster } from "sonner";
import { ThemeProvider } from "next-themes";
import { AppHeader } from "@/components/shared/app-header";
import { AppFooter } from "@/components/shared/app-footer";
import "@/styles/globals.css?url";

export const Route = createRootRoute({
  component: () => (
    <html lang="en" className="font-apercu">
      <head><HeadContent /></head>
      <body className="bg-background text-foreground min-h-screen">
        <ClerkProvider
          publishableKey={import.meta.env.VITE_CLERK_PUBLISHABLE_KEY}
          afterSignOutUrl="/"
        >
          <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
            <div className="min-h-screen flex flex-col">
              <AppHeader />
              <main className="flex-1"><Outlet /></main>
              <AppFooter />
            </div>
            <Toaster richColors position="top-right" />
          </ThemeProvider>
        </ClerkProvider>
        <Scripts />
      </body>
    </html>
  ),
});
```

`AppHeader` shows: brand mark (Sansita Bold "MEALVANA") linking to `/`, theme toggle (sun/moon Lucide icons), Clerk `<UserButton afterSignOutUrl="/" />`, and a "Settings" link. Hidden when unsigned.

`AppFooter` is small: copyright + a "powered by Mealvana" footnote + a link to `/styleguide` in dev only.

**Expected result:** `pnpm dev` → `http://localhost:3000/` returns a styled shell (404 in main slot is fine for now — index route comes in step 13).

**Gotchas:** TanStack Start's `Outlet` import path is `@tanstack/react-router` (not `@tanstack/react-start`). The `<HeadContent />` and `<Scripts />` come from `@tanstack/react-router`.

### 1.6 Step 6 — shadcn primitives, Kyle-themed

**Subject:** Install the primitives we know we need, theme them per Kyle.

**Commands:**

```bash
cd packages/web
pnpm dlx shadcn@latest init   # respond yes to overwrite components.json (we already wrote ours)
pnpm dlx shadcn@latest add button card dialog drawer sheet input scroll-area \
  tooltip separator badge dropdown-menu popover toast skeleton tabs avatar \
  resizable progress radio-group toggle-group label select textarea sonner
```

**Files to edit:** `packages/web/src/components/ui/button.tsx`, `card.tsx`.

Replace shadcn defaults with the Kyle-themed versions from `03_kyle_design_for_web.md` §9.3 (Button) and §9.4 (Card). Key rules to preserve:

- Default `Button` variant: `rounded-pill bg-primary text-primary-foreground font-sansita uppercase tracking-wider h-btn-h`
- `outline`: `rounded-pill border-2 border-foreground` (neutral, not orange — per `03_kyle_design_for_web.md` §10 open question 7)
- `ghost`: text-only dragonfruit, `font-apercu` normal case
- `destructive`: solid dragonfruit pill
- `Card`: `rounded-card border bg-card shadow-kyle-card dark:shadow-none`

Other primitives (Dialog, Drawer, Sheet, etc.) keep shadcn defaults; the CSS vars do the brand work.

**Expected result:** `<Button>Hello</Button>` renders as an orange Sansita pill with blackberry text.

**Gotchas:** shadcn's `init` will write a `tailwind.config.ts` — **delete it**. We're on Tailwind v4 CSS-first and don't need it. The `components.json` is the only persisted shadcn config.

### 1.7 Step 7 — Shared UI primitives (custom)

**Subject:** Build the meal-planner-specific shared components that all variants need.

**Files to create:** all under `packages/web/src/components/shared/`:

- `kyle-button.tsx` — re-export of `<Button>` with sane defaults, used inline (alternative: skip if `Button` is enough; this is for clarity in code review).
- `kyle-card.tsx` — re-export of `<Card>` with sane defaults.
- `jade-avatar.tsx` — the Electrolyte cyan circle with "J" inside. Props: `size: 24 | 36 | 96`, `state: 'idle' | 'thinking' | 'speaking'`. `thinking` adds `animate-pulse`. See `06_five_uiux_approaches.md` §0.3.
- `macro-bar.tsx` — a small `<div>` showing `123g C · 45g P · 8g F` in `font-apercu-mono text-caption tracking-wider`.
- `training-day-dot.tsx` — the small Electrolyte cyan dot suffix on key-workout day labels (`SAT●`).
- `carb-tier-badge.tsx` — colored dot + gram count (🟢/🟡/🟠/🔴 mapped to Mealvana brand colors per `06` §1.A and `05` §5.3 carb-tier table).
- `meal-cell.tsx` — the components-only meal card (icon + title + bulleted components + method tag + macro line). Props: `meal: MealAssembly`, `slot: MealSlot`, `density: 'compact' | 'normal'`. Used by A and D.
- `day-column.tsx` — a `<DayColumn>` rendering 7 stacked meal-cell slots with sticky header. Used by A and D.
- `macro-totals-rail.tsx` — the right-rail card showing week totals. Used by A and D.
- `swap-drawer.tsx` — the right-Sheet swap UI (current meal + 3 alternatives). Used by A and D.
- `jade-message-card.tsx` — used in chat surfaces (D, E) to render a single Jade turn (text + optional inline meal cards + optional chips). Internally consumes `JadeAvatar`.
- `jade-chat-panel.tsx` — wraps `useChat` from `@ai-sdk/react`. Props: `mode: 'drawer' | 'panel' | 'fullbleed'`. Drawer = A's "Ask Jade" right-sheet; panel = D's right column; fullbleed = E's whole screen.

For each component, write the file as a stub with prop types and a basic render — variants will exercise these and surface bugs. Don't over-build.

**Expected result:** All components import without errors and render placeholder content on `/styleguide` (step 14).

**Gotchas:** `<JadeChatPanel>` depends on the AI SDK endpoint at `/api/jade/chat` (step 11). Stub it to render an "AI not yet wired" state if `import.meta.env.VITE_AI_GATEWAY_KEY` is missing.

### 1.8 Step 8 — Clerk setup

**Subject:** Provision a Clerk dev project, wire the JWT bridge to Supabase.

**Manual steps in the Clerk dashboard:**

1. Create a new Clerk app (test mode).
2. Settings → API keys → copy `Publishable key` (`pk_test_...`) and `Secret key` (`sk_test_...`).
3. Settings → JWT Templates → New template named **`supabase`**:
   - Signing algorithm: **HS256**
   - Signing key: paste the **Supabase project's JWT secret** (from Supabase dashboard → Project Settings → API → JWT Settings → "JWT Secret"). Note: the project ID needs to be filled in by Lee — see step 9.
   - Claims:
     ```json
     {
       "aud": "authenticated",
       "role": "authenticated",
       "sub": "{{user.public_metadata.supabaseUserId}}",
       "email": "{{user.primary_email_address}}"
     }
     ```
4. Webhooks → New endpoint pointing at `https://<your-vercel-url>/api/clerk/webhook`. Add events: `user.created`, `user.updated`. Copy the signing secret.

**Files to create:**

- `packages/web/src/routes/sign-in.tsx`
- `packages/web/src/routes/sign-up.tsx`
- `packages/web/src/routes/onboarding/bridge.tsx`
- `packages/web/src/routes/api/clerk.webhook.tsx`
- `packages/web/src/lib/auth.ts` — server functions (`requireAuth`, `getAuthState`)

Pattern for sign-in (per `05_design_proposal.md` §4.1):

```tsx
import { SignIn } from "@clerk/tanstack-react-start";
import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/sign-in")({
  component: () => (
    <div className="min-h-screen flex items-center justify-center bg-background p-6">
      <SignIn
        routing="hash"
        forceRedirectUrl="/onboarding/bridge"
        appearance={{
          elements: {
            formButtonPrimary: "rounded-pill bg-primary text-primary-foreground font-sansita uppercase tracking-wider h-btn-h",
            card: "rounded-card border bg-card shadow-kyle-card dark:shadow-none",
            headerTitle: "font-sansita text-page-title",
          },
        }}
      />
    </div>
  ),
});
```

`api/clerk.webhook.tsx` verifies the svix signature, then for `user.created` looks up `users.email` in Supabase using a service-role client; if found, writes `publicMetadata.supabaseUserId` via Clerk's server SDK. See `05_design_proposal.md` §7.1 step 2.

`onboarding/bridge.tsx` handles three branches per `05_design_proposal.md` §4.2: existing match (skip to `/`), email match (auto-link, redirect to `/`), no match (show "set up in mobile app" wall).

**Expected result:** `/sign-in` renders Clerk UI; signing up + signing in both work; after auth, the user lands at `/onboarding/bridge` which redirects appropriately.

**Gotchas:**

- The Clerk template name is **`supabase`** (lowercase) and the claim is **`supabaseUserId`** (camelCase to match Clerk's convention) — note `MEMORY.md`'s mention of Lee's dev Mealvana user UUID `607f9dd5-6fa7-48ee-a628-720d4a0506a1`; Lee's `publicMetadata.supabaseUserId` should be set to that value during the onboarding bridge.
- Clerk's `SignIn` uses `routing="hash"` to avoid TanStack Router collisions — must use hash routing inside our shell.
- Webhook URL must be HTTPS — use Vercel preview URL or `ngrok` in local dev.

### 1.9 Step 9 — Supabase clients

**Subject:** A server-side Supabase client that takes the Clerk JWT, and a browser-side client for read-only queries.

**Files to create:**

- `packages/web/src/lib/supabase/server.ts`
- `packages/web/src/lib/supabase/client.ts`
- `packages/web/src/lib/supabase/types.ts` (auto-generated from Supabase CLI)

`lib/supabase/server.ts`:

```ts
import { auth } from "@clerk/tanstack-react-start/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "./types";

export async function getServerSupabase(): Promise<SupabaseClient<Database>> {
  const a = await auth();
  const token = a.userId ? await a.getToken({ template: "supabase" }) : null;
  return createClient<Database>(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_ANON_KEY!,
    {
      global: { headers: token ? { Authorization: `Bearer ${token}` } : {} },
      auth: { persistSession: false, autoRefreshToken: false },
    }
  );
}

export function getServiceRoleSupabase(): SupabaseClient<Database> {
  return createClient<Database>(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false, autoRefreshToken: false } }
  );
}
```

`lib/supabase/client.ts` (browser, used rarely — only for realtime read):

```ts
import { createClient } from "@supabase/supabase-js";
import { useAuth } from "@clerk/tanstack-react-start";
import { useMemo } from "react";
import type { Database } from "./types";

export function useBrowserSupabase() {
  const { getToken } = useAuth();
  return useMemo(() => createClient<Database>(
    import.meta.env.VITE_SUPABASE_URL,
    import.meta.env.VITE_SUPABASE_ANON_KEY,
    { accessToken: async () => (await getToken({ template: "supabase" })) ?? null },
  ), [getToken]);
}
```

**Generate types** — run from repo root:

```bash
SUPABASE_PROJECT_ID=<dev-project-id> pnpm supabase:types
```

The dev project ID needs to be filled in by Lee. The script is in the root `package.json`'s `supabase:types` script. Place the result at `packages/web/src/lib/supabase/types.ts`.

**Expected result:** A server function can call `getServerSupabase()` and run `supabase.from('users').select('*').single()` and get Lee's row when authenticated as Lee.

**Gotchas:**

- Browser-side calls with `accessToken` callback work in `@supabase/supabase-js` ≥ 2.45; older versions don't have this option.
- The service-role client is for the Clerk webhook only (lookup user by email before they're authenticated). Never expose service-role key to the browser.

### 1.10 Step 10 — Vercel AI SDK + AI Gateway

**Subject:** Install AI SDK 5+, wire it through the Vercel AI Gateway, prove a streaming call works.

**Commands:**

```bash
cd packages/web
pnpm add ai@latest @ai-sdk/react@latest @ai-sdk/openai@latest @ai-sdk/anthropic@latest @ai-sdk/gateway@latest zod
```

**Manual:** create or reuse a Vercel project and provision an AI Gateway key. In Vercel dashboard → AI → AI Gateway → create key. Copy `AI_GATEWAY_API_KEY`.

**Files to create:**

- `packages/web/src/server/jade/gateway.ts`
- `packages/web/src/routes/api/jade.hello.tsx`

`server/jade/gateway.ts`:

```ts
import { gateway } from "@ai-sdk/gateway";
import { createGateway } from "ai";

export const aiGateway = createGateway({
  apiKey: process.env.AI_GATEWAY_API_KEY!,
  // baseURL defaults to Vercel AI Gateway
});

// Default model — controlled by env var so we can flip without code change
export const defaultModel = aiGateway.languageModel(
  process.env.JADE_MODEL ?? "openai/gpt-5"
);

export const fallbackModel = aiGateway.languageModel(
  process.env.JADE_FALLBACK_MODEL ?? "anthropic/claude-sonnet-4-6"
);
```

`routes/api/jade.hello.tsx` (smoke test):

```ts
import { createFileRoute } from "@tanstack/react-router";
import { createServerFileRoute } from "@tanstack/react-start/server";
import { streamText } from "ai";
import { defaultModel } from "@/server/jade/gateway";

export const ServerRoute = createServerFileRoute("/api/jade/hello").methods({
  GET: async () => {
    const result = streamText({
      model: defaultModel,
      prompt: "Say 'Hello from Jade.' in one short line.",
      maxOutputTokens: 32,
    });
    return result.toTextStreamResponse();
  },
});
```

**Expected result:** Hitting `http://localhost:3000/api/jade/hello` streams "Hello from Jade." back.

**Gotchas:**

- Model id strings vary by provider on the Gateway. Verify available models with `curl https://ai-gateway.vercel.sh/v1/models -H "Authorization: Bearer $AI_GATEWAY_API_KEY"`.
- The `@ai-sdk/gateway` and `ai` package APIs evolve. If `createGateway` isn't exported, try `import { gateway } from "@ai-sdk/gateway"` and use `gateway("openai/gpt-5")` directly.
- TanStack Start's server-route file naming uses dot-separated paths: `api/jade.hello.tsx` → `/api/jade/hello`.

### 1.11 Step 11 — Jade backend (system prompt, tools, streaming endpoints)

**Subject:** The shared Jade module that all five variants call.

**Files to create:** all under `packages/web/src/server/jade/`:

- `persona.ts` — exports `JADE_BASE_SYSTEM_PROMPT` (the 290-word prompt from `06_five_uiux_approaches.md` §0.6) and surface adapters `JADE_ADAPTERS = { calendar, stack, columns, hybrid, coach }` each appending 50–150 words of surface-specific guidance.
- `schema.ts` — Zod schemas: `FoodComponent`, `MealAssembly`, `DayPlan`, `WeekPlan`, `MealChange`, `MealSwapResult`. Lift from `05_design_proposal.md` §6.1.
- `tools.ts` — 5 tools: `listFoods`, `listTemplates`, `getActivities`, `getMacroTargets`, `getUserPrefs`. Per `05_design_proposal.md` §6.2 + `06` §0.7. Each tool's `execute` calls `getServerSupabase()` so RLS applies.
- `proposers.ts` — 3 functions: `proposeWeekPlan(args)`, `proposeMealSwap(args)`, `applyTweak(args)`. Each calls `streamObject` or `generateObject` with the appropriate schema.
- `index.ts` — barrel exports.

**Streaming endpoints** at `packages/web/src/routes/api/jade/`:

- `chat.tsx` — `POST /api/jade/chat`. Consumes `useChat` messages from D and E; returns `toUIMessageStreamResponse()`. Uses `JADE_ADAPTERS[surface]` to pick system prompt by `surface` query param.
- `object.tsx` — `POST /api/jade/object`. Body: `{ kind: 'week' | 'swap' | 'tweak', input: ... }`. Returns `streamObject` SSE for week, `generateObject` JSON for swap/tweak.
- `hello.tsx` — already done in step 10, keep as smoke test.

The proposers + tools live server-side; variants never call the model directly.

**Expected result:** A signed-in user can `POST /api/jade/object` with `{ kind: 'week', input: { week_start: '2026-05-06' } }` and get back a streamed `WeekPlan` JSON object.

**Gotchas:**

- All tool `execute` functions must use the per-request Clerk auth context. Use `await auth()` inside `execute`, not at module load.
- Streaming SSE responses need the right headers: `'Content-Type': 'text/event-stream'`, `'Cache-Control': 'no-cache'`.
- `streamObject`'s schema validation will throw on partial outputs unless you use `streamObject({ ..., output: 'object' })` and let the AI SDK reconstruct progressively.

### 1.12 Step 12 — Database deltas + RLS

**Subject:** Create `meal_plans` and `meal_plan_meals` tables in dev Supabase.

**Files to create:** `supabase/migrations/20260507000000_create_meal_plans.sql`.

Copy the SQL from `06_five_uiux_approaches.md` §3.7 verbatim. Key columns:

- `meal_plans`: `id`, `user_id`, `week_start`, `iso_week`, `iso_year`, `coach_strip`, `rationale`, `generation_model`, `generation_input_hash`, `approach_used CHECK IN ('a','b','c','d','e')`, timestamps. `UNIQUE(user_id, week_start)`.
- `meal_plan_meals`: `id`, `meal_plan_id`, `user_id` (denormalized for RLS), `date`, `slot CHECK IN (...)`, `scheduled_time`, `title`, `method_tag`, `components JSONB`, `template_table`, `template_id`, `totals JSONB`, `locked BOOL`, timestamps. `UNIQUE(meal_plan_id, date, slot)`.
- RLS policies: `auth.uid() = user_id` for all/all on both tables, plus a service-role bypass.
- Indexes: `meal_plans_user_week_idx`, `meal_plan_meals_plan_date_idx`, `meal_plan_meals_user_date_idx`.

**Apply:**

```bash
# From the meal-planning-prototype repo root, NOT from mealvana_endurance
# Use Supabase CLI linked to the same dev project
pnpm dlx supabase link --project-ref <DEV_PROJECT_REF>
pnpm dlx supabase db push
```

Lee fills in `<DEV_PROJECT_REF>`. The migration runs against the same dev Supabase project that mealvana_endurance uses, so the new tables sit alongside the existing schema (no data migration needed).

**Expected result:** `select * from meal_plans` runs (empty) under Lee's session; INSERT-ing a row with `user_id = '607f9dd5-6fa7-48ee-a628-720d4a0506a1'` succeeds when authed as Lee.

**Gotchas:**

- The `auth.users(id)` foreign key only works if Supabase Auth has Lee's row. Mealvana's existing `users` table references `auth.users` — verify this is true; if not, drop the `REFERENCES auth.users(id)` and just keep `REFERENCES users(id)`.
- The `CHECK` constraint on `approach_used` is a simple enum-style check; expanding later (variant F) means an `ALTER TABLE` migration.

### 1.13 Step 13 — Landing page hub

**Subject:** The five-card landing at `/`.

**Files to create:** `packages/web/src/routes/index.tsx`, `packages/web/src/components/shared/variant-card.tsx`.

`variant-card.tsx` props: `letter: 'A'|'B'|'C'|'D'|'E'`, `codename`, `tagline`, `aiRating: 1|2|3|4|5`, `href`, `isFocus?: boolean`. Renders Sansita big letter, Compadre uppercase codename, Apercu tagline, mono AI rating like `★★★☆☆`, an orange "Try it" pill linking to `href`. If `isFocus`, show a small "Currently testing" pill above.

`routes/index.tsx`:

```tsx
import { createFileRoute } from "@tanstack/react-router";
import { VariantCard } from "@/components/shared/variant-card";

export const Route = createFileRoute("/")({
  component: () => (
    <div className="min-h-screen px-6 py-10 max-w-7xl mx-auto">
      <h1 className="font-sansita text-page-title">Five ways to plan your week</h1>
      <p className="font-apercu text-body text-muted-foreground mt-2 max-w-prose">
        Pick the one that feels right. They all build the same plan in the background.
      </p>
      <div className="mt-10 grid gap-4 grid-cols-1 sm:grid-cols-2 lg:grid-cols-5">
        <VariantCard letter="A" codename="Calendar" tagline="The whole week, one screen, one tap to build it." aiRating={2} href="/plan/a" isFocus={import.meta.env.VITE_FOCUS_VARIANT === 'a'} />
        <VariantCard letter="B" codename="Stack" tagline="Swipe through your week, one meal at a time." aiRating={3} href="/plan/b" isFocus={import.meta.env.VITE_FOCUS_VARIANT === 'b'} />
        <VariantCard letter="C" codename="Columns" tagline="Pick a protein, pick a carb, pick a veg. Done." aiRating={3} href="/plan/c" isFocus={import.meta.env.VITE_FOCUS_VARIANT === 'c'} />
        <VariantCard letter="D" codename="Hybrid" tagline="Plan on the left. Talk to Jade on the right." aiRating={4} href="/plan/d" isFocus={import.meta.env.VITE_FOCUS_VARIANT === 'd'} />
        <VariantCard letter="E" codename="Coach" tagline="Just talk to Jade. She'll handle the rest." aiRating={5} href="/plan/e" isFocus={import.meta.env.VITE_FOCUS_VARIANT === 'e'} />
      </div>
      <p className="mt-10 font-apercu text-body text-muted-foreground border-t border-border pt-4">
        Your data is shared across all five — switching approaches preserves your plan.
      </p>
    </div>
  ),
});
```

Also create dead-link stubs at `routes/plan.a.tsx` … `routes/plan.e.tsx` that just render `<h1>Variant {x} coming soon</h1>` so the landing links don't 404. Variants will fill these in during Phase 1.

**Expected result:** Visit `/`, see five cards, click any → land on a "coming soon" stub.

**Gotchas:** TanStack Router resolves `plan.a.tsx` to the literal path `/plan/a` when there's a dot in the filename. If you need nested children, switch to a directory layout (`plan/a.tsx`) — but for stubs, the dot pattern is shorter.

### 1.14 Step 14 — Settings page

**Subject:** Read-only display of user prefs, allergies, dietary preference, current macro targets, and upcoming-7-days training schedule. Used by all variants.

**Files to create:** `packages/web/src/routes/settings.tsx`, `packages/web/src/lib/queries/settings-data.ts`.

`lib/queries/settings-data.ts` — a server function that returns:

```ts
type SettingsData = {
  profile: { email: string; height_feet: number; height_inches: number; weight_pounds: number; cycling_ftp_watts?: number; swimming_css_seconds_per_100m?: number; };
  dietary: { dietary_preference: string; allergies: string[]; gut_training_level?: string; gi_sensitivity?: string; };
  food_preferences: { liked: { food_name: string; preference_level: number }[]; disliked: { food_name: string; preference_level: number }[]; };
  current_week_targets: { target_date: string; carb_g: number; prot_g: number; fat_g: number; }[];
  upcoming_activities: { id: string; scheduled_date_time: string; activity_type: string; title: string; duration_minutes: number; intensity_level?: string; distance_miles?: number; }[];
};
```

It calls `getServerSupabase()` and runs the queries from `05_design_proposal.md` §7.6 + §4.7 data dependencies, scoped to the next 7 days.

`routes/settings.tsx` renders sections per `05_design_proposal.md` §4.7 and `06` §3.5: PROFILE / DIETARY / FOOD PREFERENCES / TRAINING SCHEDULE. Each section has an "Edit in app" link (gray ghost button).

**Expected result:** `/settings` for Lee shows his real name, weight, allergies, food prefs, and the actual upcoming activities from his Garmin sync.

**Gotchas:**

- If `daily_macro_targets` is missing for a date in the next 7 days, render `--` for that day, **don't** call `generate-macros-v4` (that's the Flutter app's job per `05` §7.2).
- `food_preferences.preference_level > 0` filters out neutrals; `preference = 'like'` vs `'dislike'` separates the lists.

### 1.15 Step 15 — Styleguide page

**Subject:** Internal smoke-test page proving Kyle tokens are wired.

**Files to create:** `packages/web/src/routes/styleguide.tsx`.

Lift the page from `03_kyle_design_for_web.md` §9.6 and extend with: every shared component (JadeAvatar at 24/36/96, MealCell with mock data, CarbTierBadge for all four tiers, MacroBar, TrainingDayDot, KyleButton in default/outline/ghost/destructive variants, KyleCard with header/body, Sheet + Dialog open buttons).

**Expected result:** `/styleguide` looks like the screenshots in `docs/kyle/`.

**Gotchas:** Hide this route in production via `if (import.meta.env.PROD) throw redirect({ to: '/' })` in the loader.

### 1.16 Step 16 — Theme toggle

**Subject:** The sun/moon button in the app header.

**Files to create:** `packages/web/src/components/shared/theme-toggle.tsx`.

```tsx
import { useTheme } from "next-themes";
import { Sun, Moon } from "lucide-react";
import { Button } from "@/components/ui/button";

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const next = theme === "dark" ? "light" : "dark";
  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={() => setTheme(next)}
      aria-label={`Switch to ${next} mode`}
    >
      {theme === "dark" ? <Sun /> : <Moon />}
    </Button>
  );
}
```

Mount in `<AppHeader>`.

**Expected result:** Clicking toggles `class="dark"` on `<html>`; all colors flip.

**Gotchas:** SSR mismatch warnings unless `enableSystem` is set on `<ThemeProvider>` and you suppress hydration warnings on the `<html>` tag.

### 1.17 Step 17 — Env vars

**Subject:** Document and lock down all env vars.

**Files to create:** `.env.example`, `packages/web/.env.local` (not committed), `vercel.json`.

`.env.example`:

```dotenv
# Supabase
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...   # server-only, NEVER ship to browser
SUPABASE_JWT_SECRET=...             # used in Clerk JWT template; not at runtime
VITE_SUPABASE_URL=https://<project>.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...
SUPABASE_PROJECT_ID=<dev-project-id>

# Clerk
VITE_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...
CLERK_WEBHOOK_SECRET=whsec_...

# Vercel AI Gateway
AI_GATEWAY_API_KEY=...
JADE_MODEL=openai/gpt-5
JADE_FALLBACK_MODEL=anthropic/claude-sonnet-4-6

# Per-worktree dev port (overrides Vite default 3000)
PORT=3000

# Optional: which variant is the focus on the landing page
VITE_FOCUS_VARIANT=        # one of a|b|c|d|e or empty
```

Verify nothing client-side reads a server-only secret. `VITE_*` is browser; everything else is server-only.

**Expected result:** A clean checkout fails to run until `.env.local` is filled in; documentation tells you exactly what to set.

**Gotchas:** `SUPABASE_JWT_SECRET` is **only used to configure the Clerk JWT template** — it's not consumed by app code at runtime. The app uses Clerk's `getToken({ template: 'supabase' })` to mint JWTs.

### 1.18 Step 18 — ESLint + Prettier + Husky + lint-staged

**Subject:** Quality gates green from day one (the `me_website_new` source ships none).

**Commands:**

```bash
cd /Users/leemartin/development/mealplanning_prototype
pnpm add -Dw eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin \
  eslint-plugin-react eslint-plugin-react-hooks eslint-plugin-jsx-a11y \
  prettier prettier-plugin-tailwindcss husky lint-staged

pnpm dlx husky init
echo "pnpm lint-staged" > .husky/pre-commit
```

`eslint.config.js` (flat config, root):

```js
import tseslint from "@typescript-eslint/eslint-plugin";
import tsparser from "@typescript-eslint/parser";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import jsxA11y from "eslint-plugin-jsx-a11y";

export default [
  {
    files: ["**/*.{ts,tsx}"],
    languageOptions: { parser: tsparser, ecmaVersion: 2022, sourceType: "module" },
    plugins: { "@typescript-eslint": tseslint, react, "react-hooks": reactHooks, "jsx-a11y": jsxA11y },
    rules: {
      ...react.configs.recommended.rules,
      ...reactHooks.configs.recommended.rules,
      ...jsxA11y.configs.recommended.rules,
      "react/react-in-jsx-scope": "off",
    },
  },
];
```

`.prettierrc.json`:

```json
{
  "semi": true,
  "singleQuote": false,
  "trailingComma": "all",
  "tabWidth": 2,
  "plugins": ["prettier-plugin-tailwindcss"]
}
```

**Expected result:** `pnpm lint` and `pnpm format` exit 0; `git commit` runs lint-staged; failing lint blocks commit.

**Gotchas:** ESLint 9 flat config is incompatible with old `.eslintrc.json` files. Don't add both.

### 1.19 Step 19 — CI / Vercel deploy

**Subject:** Vercel project linked, preview deploys per branch.

`vercel.json`:

```json
{
  "buildCommand": "pnpm build",
  "installCommand": "pnpm install",
  "framework": null,
  "outputDirectory": "packages/web/.output"
}
```

**Manual:**

1. Lee runs `pnpm dlx vercel link` from the repo root, links to a new Vercel project named `mealplanning-prototype`.
2. In Vercel dashboard → Settings → Environment Variables — add every key from `.env.example` for Production, Preview, and Development environments. (Only `VITE_*` go to client; rest stay server-only.)
3. In Settings → Git, enable preview deploys for all branches (default).

**Expected result:** Pushing to `main` triggers a preview deploy at `mealplanning-prototype-leesteam.vercel.app`. Pushing variant branches creates `*-git-variant-{x}-leesteam.vercel.app` previews.

**Gotchas:**

- Nitro `node-server` preset is the default; if AI streaming latency is a problem in production, switch to `vercel-edge` preset (set `target: "vercel-edge"` in `tanstackStart` plugin config).
- Vercel detects the framework as null because we set it explicitly; this is correct.

### 1.20 Step 20 — Vitest + Playwright

**Subject:** Unit + e2e harness, with one trivial test each.

**Files to create:** `packages/web/vitest.config.ts`, `packages/web/playwright.config.ts`, `packages/web/tests/setup.ts`, `packages/web/tests/styleguide.spec.ts` (e2e), `packages/web/src/components/shared/jade-avatar.test.tsx` (unit).

Adapt configs from `me_website_new/packages/web/{vitest,playwright}.config.ts`. The unit test verifies `<JadeAvatar size={36} />` renders the "J" letter; the e2e test loads `/styleguide` and asserts the page title.

**Expected result:** `pnpm test` and `pnpm test:e2e` both green.

**Gotchas:** Playwright auto-spawns the dev server on port 3001 (override the project's default 3000 to avoid conflicts during the suite).

### 1.21 Step 21 — Observability scaffold

**Subject:** The `jade_calls` table for logging every Jade invocation.

**Files to create:** `supabase/migrations/20260507100000_create_jade_calls.sql`.

```sql
CREATE TABLE jade_calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  approach TEXT,            -- 'a'|'b'|'c'|'d'|'e' or 'shared'
  surface TEXT,             -- 'week'|'swap'|'tweak'|'chat'|'hello'
  model TEXT,
  prompt_tokens INTEGER,
  completion_tokens INTEGER,
  cached_tokens INTEGER,
  duration_ms INTEGER,
  tool_calls JSONB,         -- which tools were called and how many
  status TEXT,              -- 'ok'|'error'|'timeout'|'refused'
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX jade_calls_user_idx ON jade_calls (user_id, created_at DESC);
CREATE INDEX jade_calls_approach_idx ON jade_calls (approach, created_at DESC);

ALTER TABLE jade_calls ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own jade calls" ON jade_calls FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Service role full access" ON jade_calls FOR ALL TO service_role USING (true) WITH CHECK (true);
```

Plus a server util `server/jade/log.ts` that the proposers and chat endpoint call after every model invocation.

**Expected result:** Every Jade call writes a row; `select count(*), approach from jade_calls group by approach` shows the distribution after a few uses.

**Gotchas:** Don't log raw prompts or full responses to this table — it'd bloat fast and contain user data. Just metadata.

### 1.22 Step 22 — Rate limiting

**Subject:** Per-user rate limits to keep AI costs sane.

**Files to create:** `packages/web/src/server/jade/rate-limit.ts`.

Use Supabase's pg-row strategy (cheap, no external dep): a `rate_limit_buckets` table with `(user_id, bucket_key, count, window_start)`. Each Jade call increments and checks the bucket. Limits per `05_design_proposal.md` §6.6:

- Regenerate-week: 1 per 30s per user.
- Per-meal swap: 1 per 5s per user.
- Tweak-bar / chat tweak: 1 per 10s per user.
- General chat turns: 1 per 2s.

Failure mode: return 429 with `Retry-After` header; UI shows a sonner toast "Slow down — Jade's catching up."

**Expected result:** Hammering `/api/jade/object` 10× in 5s gets 429s on 9 of them.

**Gotchas:** Rate limits must run **before** the model call, otherwise we still spend tokens. Wrap every endpoint.

### 1.23 Step 23 — Error states catalog

**Subject:** Define the four error states all variants must handle, with shared rendering.

**Files to create:** `packages/web/src/components/shared/error-state.tsx`.

Variants render `<ErrorState kind="..." />` with kind:

- `jade-failed` — Jade endpoint returned 500 or timeout. Message: "Jade's having trouble — try again." Retry button.
- `rls-denied` — Supabase returned 401/403 (rare; probably a stale token). Message: "Your session expired — sign in again."
- `no-macro-targets` — `daily_macro_targets` empty for the requested week. Message: "Macros aren't computed for this week yet — open the mobile app to generate them." Link out.
- `no-activities` — `activities` empty for the requested week. Message: "No training scheduled this week. We can still build a rest-week plan." Continue button.

Variants **must** call into this component for these four cases; they don't render their own error UI for these.

**Expected result:** All four error states display correctly when forced via dev tools.

**Gotchas:** `no-macro-targets` is the most common — Lee may need to scroll back to a recently-computed week to test the happy path.

### 1.24 Step 24 — Definition-of-done sweep

**Subject:** Verify every Phase 0 DOD item from §1.0.

A short checklist Lee runs:

```
[ ] Repo exists, pnpm workspace works
[ ] /styleguide renders the Kyle smoke test correctly in light + dark
[ ] /sign-in, /sign-up, /onboarding/bridge all render and work end-to-end
[ ] /settings renders Lee's real Supabase data (RLS-filtered)
[ ] /api/jade/hello streams a response
[ ] /api/jade/object with kind='week' returns a streamed WeekPlan
[ ] meal_plans + meal_plan_meals + jade_calls migrations applied to dev Supabase
[ ] / renders the five-card landing; /plan/a..e are reachable as stubs
[ ] pnpm lint, pnpm typecheck, pnpm test all green
[ ] Vercel preview deploy from main is up
[ ] Variant worktrees can be created from main without issues
```

**Expected result:** All checked.

**Gotchas:** If any are red, fix on `main` before kicking off variants. The whole point of Phase 0 is to make variant work safe.

### 1.25 Step 25 — Cut variant branches

**Subject:** Final action of Phase 0.

```bash
cd /Users/leemartin/development/mealplanning_prototype

git add -A
git commit -m "phase 0: shared scaffold (closes #N)"
git push origin main

git branch variant/a variant/b variant/c variant/d variant/e
git push origin variant/a variant/b variant/c variant/d variant/e

git worktree add ../mealplanning_prototype-a variant/a
git worktree add ../mealplanning_prototype-b variant/b
git worktree add ../mealplanning_prototype-c variant/c
git worktree add ../mealplanning_prototype-d variant/d
git worktree add ../mealplanning_prototype-e variant/e

for d in mealplanning_prototype-{a,b,c,d,e}; do
  ( cd "/Users/leemartin/development/$d" && pnpm install )
done

# Set per-worktree PORT env
echo "PORT=3001" >> ../mealplanning_prototype-a/packages/web/.env.local
echo "PORT=3002" >> ../mealplanning_prototype-b/packages/web/.env.local
echo "PORT=3003" >> ../mealplanning_prototype-c/packages/web/.env.local
echo "PORT=3004" >> ../mealplanning_prototype-d/packages/web/.env.local
echo "PORT=3005" >> ../mealplanning_prototype-e/packages/web/.env.local
```

Post in `STATUS.md`: "Phase 0 complete. Variants A–E are unblocked."

---

## §2 — Phase 1A: Variant A "Calendar"

**Codename:** Calendar. **Tagline:** *The whole week, one screen, one tap to build it.* **AI level:** ★★☆☆☆ (2/5).

**Branch:** `variant/a` · **Worktree:** `/Users/leemartin/development/mealplanning_prototype-a` · **Dev port:** 3001 · **Preview URL:** `*-git-variant-a-*.vercel.app`.

### 2.1 Scope summary

A 7-day grid view inheriting heavily from `05_design_proposal.md` §4.3 and `06_five_uiux_approaches.md` §1.A. Three AI surfaces: regenerate-week, per-cell swap, coach strip. A floating "Ask Jade" pill opens a drawer-mode `<JadeChatPanel>`. Tweak bar at bottom with chips + custom input. Read-only macros from `daily_macro_targets`.

### 2.2 Files this variant creates or modifies

```
packages/web/src/routes/plan.a.tsx              [REPLACE stub from Phase 0]
packages/web/src/routes/plan.a.meal.$slotId.tsx [NEW — modal route for swap]
packages/web/src/components/variant-a/
  ├── week-grid.tsx
  ├── day-column-header.tsx                     [variant-A specific; uses shared <DayColumn>]
  ├── coach-strip.tsx
  ├── regenerate-week-button.tsx
  ├── tweak-bar.tsx
  ├── tweak-chip.tsx
  ├── empty-state.tsx
  ├── mobile-day-view.tsx
  ├── jade-pill.tsx                             [the floating "Ask Jade" CTA]
  └── tweak-diff-strip.tsx
packages/web/src/lib/queries/week-data.a.ts     [variant-A specific loader]
packages/web/src/lib/hooks/use-regenerate-week.ts [calls /api/jade/object]
packages/web/src/lib/hooks/use-swap-meal.ts
packages/web/src/lib/hooks/use-apply-tweak.ts
```

Variant A must NOT touch:

- `components/shared/*`, `components/ui/*`, `lib/auth.ts`, `lib/supabase/*`, `server/jade/*`, `routes/__root.tsx`, `routes/index.tsx`, `routes/settings.tsx`, `routes/api/jade/*`, `routes/sign-in.tsx`, `routes/sign-up.tsx`, `routes/onboarding/*`.
- Any `routes/plan.{b,c,d,e}.tsx` or `components/variant-{b,c,d,e}/`.

### 2.3 Sub-phase build order

**1.A.1 — Layout shell** (~2 hours)

Deliverable: `/plan/a` renders with a stub grid, a stub coach strip, a stub regenerate button, and the bottom tweak bar (no AI yet, no real data). The empty-state component is implemented.

Key files: `plan.a.tsx`, `week-grid.tsx`, `empty-state.tsx`, `regenerate-week-button.tsx` (button only, no handler).

Demo moment: `/plan/a` shows the empty state with a stubbed "your training this week" list; pressing the button does nothing.

**1.A.2 — Read real Supabase data** (~3 hours)

Deliverable: `lib/queries/week-data.a.ts` calls Supabase to fetch the user's activities, daily targets, and any existing meal plan for the current week. The grid renders day columns (using shared `<DayColumn>`), with carb tier badges (using shared `<CarbTierBadge>`), training summary lines, and meal cells (using shared `<MealCell>`) that show "—" if no `meal_plan_meals` rows exist.

Key files: `week-data.a.ts`, `plan.a.tsx` loader, `day-column-header.tsx`.

Demo moment: For Lee, the grid shows real Saturday-long-run training, real macro tier dots, and empty meal cells.

**1.A.3 — Regenerate-week** (~3 hours)

Deliverable: Click "Regenerate Week" → fetch `POST /api/jade/object` with `{ kind: 'week', input: {...} }`, stream the result, render days as they arrive. Persist to `meal_plans` + `meal_plan_meals` on stream completion.

Key files: `regenerate-week-button.tsx`, `use-regenerate-week.ts`, `routes/plan.a.tsx` (stream handler).

Demo moment: Click "Plan my week" → cells fill in left-to-right over ~10s. After completion, refresh: grid persists.

**1.A.4 — Per-cell swap drawer** (~3 hours)

Deliverable: Click any meal cell → opens shared `<SwapDrawer>` (right Sheet on desktop, bottom Sheet on mobile). Drawer fetches 3 alternatives via `/api/jade/object` with `{ kind: 'swap', input: {...} }`. Click "USE THIS" → optimistic cell update + DB upsert + sonner toast. Use `routes/plan.a.meal.$slotId.tsx` as the modal route so the URL changes.

Key files: `use-swap-meal.ts`, `plan.a.meal.$slotId.tsx`.

Demo moment: Click Wednesday lunch → drawer opens with 3 alternatives → pick one → cell updates, drawer closes.

**1.A.5 — Coach strip + macro totals rail** (~1 hour)

Deliverable: Coach strip displays `meal_plans.coach_strip` from the regen output; on swap accept, fire a small `streamText` call to refresh it (debounced 1s). Macro totals rail (shared `<MacroTotalsRail>`) renders the week's macro target sums from `daily_macro_targets`.

Key files: `coach-strip.tsx`, `plan.a.tsx`.

Demo moment: After regen, coach strip says "High-carb week — long run Saturday." After a swap, the line refreshes.

**1.A.6 — Tweak bar with chips + custom input** (~3 hours)

Deliverable: Bottom-pinned tweak bar renders 4 chips (`more protein`, `no fish`, `simpler dinners`, `+ custom…`). Chips toggle. "Apply" fires `/api/jade/object` with `{ kind: 'tweak', input: {...} }` → returns `MealChange[]` → diff strip renders ("4 of 21 meals will change") → user accepts/rejects.

Key files: `tweak-bar.tsx`, `tweak-chip.tsx`, `tweak-diff-strip.tsx`, `use-apply-tweak.ts`.

Demo moment: Tap "more protein" → "Apply" → diff appears → "Accept" → grid updates 4 cells.

**1.A.7 — "Ask Jade" floating pill + drawer** (~2 hours)

Deliverable: Floating bottom-right pill (Electrolyte cyan, "Ask Jade" Sansita uppercase). Click → shared `<JadeChatPanel mode="drawer">` opens with current week as context. User can ask "Why is Saturday so high-carb?" → Jade replies in chat. Asking "Make Wednesday lighter" runs the tweak path.

Key files: `jade-pill.tsx`. (`<JadeChatPanel>` is shared; just instantiate with `mode="drawer"` and `weekContext`.)

Demo moment: Click the pill → ask a natural question → get a streaming reply.

**1.A.8 — Polish + persistence + demoable** (~2 hours)

Deliverable: Mobile single-day view (`mobile-day-view.tsx`); keyboard nav on grid (arrow keys, Enter for swap, Cmd+R for regen with confirmation); auto-scroll today's column into view on mobile; sonner toasts on every persisted action; empty-state to populated grid crossfade animation; lock-cell context menu (right-click → `Lock this meal` / `Lock this whole day` / `Why this meal?`); the "Why this meal?" inline explanation panel calls `/api/jade/chat`.

Key files: all of the above, polished.

Demo moment: Full happy path on desktop and mobile, zero bugs in the swap → tweak → ask Jade flows.

### 2.4 Dependencies on Phase 0 primitives

- `<JadeAvatar>`, `<JadeChatPanel mode="drawer">` (variant A only uses drawer mode)
- `<MealCell>`, `<DayColumn>`, `<MacroTotalsRail>`, `<CarbTierBadge>`, `<TrainingDayDot>`, `<MacroBar>`
- `<SwapDrawer>` (the actual UI inside the swap modal route)
- `<Button>`, `<Card>`, `<Sheet>`, `<Badge>`, `<Tooltip>`, `<DropdownMenu>` (right-click menu), `<Dialog>` (regen-week confirmation when locked cells exist)
- `<ErrorState kind="...">` for the four error cases
- `getServerSupabase()`, `useBrowserSupabase()`
- `/api/jade/object` and `/api/jade/chat` endpoints

If any of these are missing or broken, variant A files a `shared:` PR to `main` per §0.5 and waits.

### 2.5 Variant-specific gotchas

- **Streaming partial WeekPlan rendering**: the `streamObject` API emits partial objects as days complete. Render each day cell as `dayPlan === undefined ? <Skeleton /> : <DayColumn dayPlan={dayPlan} />` so the user sees progressive fill. Don't wait for the full object.
- **Auto-scroll today's column** on mobile uses `IntersectionObserver` + `scrollIntoView` — race conditions with the empty-state crossfade. Use `useEffect` keyed on `data ? 'data' : 'empty'` so it only runs once per state.
- **Right-click context menu on web** must call `e.preventDefault()` to override the browser default. On touch, long-press is the same trigger — use a small `useLongPress` hook, don't rely on synthetic browser events.
- **Today marker logic**: `dayjs().format('YYYY-MM-DD') === dayPlan.date` — but Lee's locale matters. Use `dayjs.tz(undefined, userTimezone)` if you have it, otherwise UTC midnight is good enough for the prototype.
- **Tweak diff "4 of 21 meals will change"** is computed client-side from the `MealChange[]` array — don't ask the model to count.

### 2.6 Testing checklist (manual QA)

```
[ ] /plan/a empty state shows correct training summary for current week
[ ] "Plan my week" streams cells in left-to-right; coach strip arrives last
[ ] After regen, refresh /plan/a — plan persists
[ ] Click any meal cell → swap drawer opens with 3 alternatives
[ ] "Use this" updates the cell, closes drawer, shows toast, recomputes totals
[ ] Tweak bar chip "more protein" → diff strip shows changes → accept → grid updates
[ ] Custom tweak ("no rice this week") via tweak bar custom input works
[ ] "Ask Jade" pill → drawer opens → conversational reply works
[ ] Right-click meal → "Lock this meal" → cell shows lock glyph
[ ] Locked cells persist through a regen-week
[ ] Mobile view: single day visible, swipe between days
[ ] Theme toggle: cells re-render correctly (no contrast bugs)
[ ] No-macro-targets state: friendly banner with "Edit in app" link
```

### 2.7 Definition of done

`/plan/a` is shippable for preference testing when:

- All 12 manual QA items pass
- Lee can build, swap, tweak, and ask Jade end-to-end without hitting an error state
- The variant's preview deploy at `*-git-variant-a-*.vercel.app` is up and Lee can share the URL with a tester
- `STATUS.md` updated: variant A — done

---

## §3 — Phase 1B: Variant B "Stack"

**Codename:** Stack. **Tagline:** *Swipe through your week, one meal at a time.* **AI level:** ★★★☆☆ (3/5).

**Branch:** `variant/b` · **Worktree:** `/Users/leemartin/development/mealplanning_prototype-b` · **Dev port:** 3002.

### 3.1 Scope summary

A vertical card-deck UX (per `06` §1.B). Initial regen produces 21 cards (7 days × 3 main slots, plus pre/during/post on workout days). User swipes left (swap → triggers AI re-gen for that slot), right (keep), up (lock). Jade narrates progress at the bottom in one line. Done page shows summary + "view as week grid" toggle.

### 3.2 Files this variant creates or modifies

```
packages/web/src/routes/plan.b.tsx                [REPLACE stub]
packages/web/src/components/variant-b/
  ├── meal-stack.tsx                              [the card stack root]
  ├── stack-card.tsx                              [single card, draggable via Motion]
  ├── swipe-actions.tsx                           [the ✕/▲/✓ buttons under the stack]
  ├── progress-pips.tsx                           [the dot progress ●●●○○○]
  ├── jade-narrator.tsx                           [bottom Jade avatar + one-line]
  ├── jade-chat-stop.tsx                          [pause-stack chat sheet]
  ├── done-summary.tsx                            [final card with "view week grid" CTA]
  └── empty-state-b.tsx
packages/web/src/lib/queries/week-data.b.ts
packages/web/src/lib/hooks/use-meal-stack.ts     [stack state machine: queue, current, history]
packages/web/src/lib/hooks/use-swap-card.ts      [variant-B swap fires per-slot regen]
```

Variant B must NOT touch shared files or other variants.

### 3.3 Sub-phase build order

**1.B.1 — Layout shell** (~2 hours)

Deliverable: `/plan/b` renders the empty state ("Build your week") with a single CTA. After click, a placeholder card displays with the swipe-action buttons below. No AI, no swipe yet.

Key files: `plan.b.tsx`, `meal-stack.tsx` (skeleton), `stack-card.tsx` (static), `swipe-actions.tsx`, `progress-pips.tsx`, `empty-state-b.tsx`.

Demo: page renders, button clicks reveal a static card.

**1.B.2 — Read real Supabase data** (~2 hours)

Deliverable: Loader fetches activities + targets for the current week. The empty state shows the user's training week summary identical to variant A's.

Key files: `week-data.b.ts`, `plan.b.tsx` loader, `empty-state-b.tsx`.

Demo: empty state lists Lee's actual upcoming training.

**1.B.3 — Initial deck generation** (~3 hours)

Deliverable: "Build your week" → fire `/api/jade/object` `{ kind: 'week', ... }` → as days stream in, push cards into the stack queue. Show the first card as soon as available; subsequent cards stream in behind it.

Key files: `use-meal-stack.ts` (state machine), `meal-stack.tsx` (consumes the hook).

Demo: empty state crossfades to a stack with card 1 visible while cards 2–21 stream in behind.

**1.B.4 — Swipe gestures + actions** (~4 hours)

Deliverable: Use **Motion** (`motion/react`) for `drag="x"` + `onDragEnd` to detect left/right swipe with thresholds. Up gesture is `drag="y"` mapped to lock. Each gesture triggers the appropriate action:

- Right (keep): write the card's meal to `meal_plan_meals` (optimistic), advance to next card.
- Left (swap): fire `/api/jade/object` `{ kind: 'swap', input: { date, slot, current_meal_id } }` → replace current card with the response → user swipes again. Persist the eventually-kept meal only on right-swipe.
- Up (lock): same as keep but with `locked = true`.

Buttons (`✕/▲/✓`) below the stack trigger the same actions for accessibility.

Key files: `stack-card.tsx` (Motion), `swipe-actions.tsx`, `use-swap-card.ts`.

Demo: full swipe flow works on desktop trackpad and mobile touch.

**1.B.5 — Jade narrator** (~1.5 hours)

Deliverable: Bottom of the stack, a `<JadeNarrator>` (24px Jade avatar + one-line). Updates after each gesture: "Locked in Tuesday breakfast." / "Trying something different…" / "5 down, 16 to go." Ad-hoc lines come from a small templated string library, NOT from a separate AI call (cost control).

Key files: `jade-narrator.tsx`, `use-meal-stack.ts` (drives the line via state).

Demo: each swipe updates the narrator line; the lines feel natural.

**1.B.6 — Stop & chat** (~2 hours)

Deliverable: Tap Jade's avatar → stack pauses, a `<Sheet>` slides up to 60vh with a chat panel (shared `<JadeChatPanel mode="drawer">`). User asks a question, Jade answers. "Resume" returns to stack.

Key files: `jade-chat-stop.tsx`.

Demo: pause mid-stack, ask "What if I'm vegetarian Wed?", resume.

**1.B.7 — Done page + persistence** (~2 hours)

Deliverable: After the 21st card is dispatched, render `<DoneSummary>` showing total macros, locked count, and three CTAs: "view week grid" (links to `/plan/a` so users can preview their own plan in the calendar layout — yes, cross-variant), "edit any meal" (re-deal mode), "rebuild stack" (reset).

Persistence: `meal_plans` upsert with `approach_used = 'b'`; `meal_plan_meals` upsert per card on each keep/lock.

Key files: `done-summary.tsx`, `use-meal-stack.ts` (final commit).

Demo: complete a 21-swipe flow, see done page, click "view week grid" → land at `/plan/a` with the same data.

**1.B.8 — Polish + a11y** (~2 hours)

Deliverable: Keyboard equivalents (Left arrow = swap, Up = lock, Right or Enter = keep), screen-reader announcements for each action ("Tuesday breakfast locked"), card animations smoothed, swap latency mitigated by pre-fetching the next swap in the background.

Key files: all polished.

Demo: full keyboard flow works; screen reader (VoiceOver / NVDA) reads the right things.

### 3.4 Dependencies on Phase 0 primitives

- `<JadeAvatar size={24}>`, shared `<JadeChatPanel mode="drawer">`
- Shared `<MealCell>` (used inside `<StackCard>` for the meal body)
- `<Card>`, `<Button>`, `<Progress>`, `<Sheet>`, `<Badge>`
- `<ErrorState>`
- `motion` package (already in Phase 0 deps)

### 3.5 Variant-specific gotchas

- **Motion is the only animation library here.** The gesture detection is `drag="x" dragConstraints={{...}} onDragEnd` — read the live reference at https://motion.dev/docs/react-gestures, not stale Framer Motion docs. The package is `motion`, not `framer-motion`.
- **Swap latency is the killer UX risk.** A 4s wait between swipe and next card kills the flow. Pre-fetch: when the user is on card N, fire `/api/jade/object` for slot N+1's "what if user swipes left" alternative in the background. Cache it. If the user swipes right, discard. If left, instant render.
- **21 swipes is a lot.** Mitigation: on workout-day pre/during/post, auto-pre-lock the templated picks (no swipe needed) and just narrate "Pre-locked Saturday's pre-run bagel — based on your usual." User can tap to override.
- **State machine integrity.** The `use-meal-stack` hook holds: queue (incoming cards), current (visible card), history (for undo), locked (set of slot keys). All transitions go through reducer actions. Don't sprinkle `setState` calls.
- **Persistence on partial completion.** If the user closes the tab at card 12, the 11 already-kept cards must be saved. Persist on every keep/lock, not at the end.

### 3.6 Testing checklist

```
[ ] Empty state lists Lee's upcoming training accurately
[ ] "Build your week" fills the deck progressively
[ ] Right swipe → next card; meal saved to DB
[ ] Left swipe → AI generates new card; replaces current
[ ] Up swipe → meal locked, next card
[ ] ✕/▲/✓ buttons mirror the gestures
[ ] Jade narrator updates per swipe
[ ] Tap Jade → chat pauses stack; Resume returns
[ ] Done page shows correct totals
[ ] "View week grid" navigates to /plan/a with same data
[ ] Closing the tab mid-stack persists the kept cards
[ ] Keyboard: Left = swap, Right = keep, Up = lock works
[ ] Mobile: full-screen card; swipe gesture is buttery (no jank)
```

### 3.7 Definition of done

`/plan/b` shippable when all checklist items pass, plus: median time from "Build your week" click to "Done page" is < 90s on Lee's account, and swap latency feels < 1.5s with pre-fetching.

---

## §4 — Phase 1C: Variant C "Columns"

**Codename:** Columns. **Tagline:** *Pick a protein, pick a carb, pick a veg. Done.* **AI level:** ★★★☆☆ (3/5).

**Branch:** `variant/c` · **Worktree:** `/Users/leemartin/development/mealplanning_prototype-c` · **Dev port:** 3003.

### 4.1 Scope summary

Five-column picker (Day | Slot | Protein | Carb | Veg/Sauce) per `06` §1.C. Jade pre-curates each column's options server-side via `listFoods`; the user clicks to compose meals. A header "Fill my week with Jade" pill triggers a full week regen and pre-selects every column. "+ show more" in any column opens a small `<Popover>` with a free-text input that asks Jade for additions. Mobile: collapses to one slot at a time with a stepper.

### 4.2 Files this variant creates or modifies

```
packages/web/src/routes/plan.c.tsx              [REPLACE stub]
packages/web/src/components/variant-c/
  ├── column-grid.tsx                            [the 5-column desktop table]
  ├── column.tsx                                 [single column with options]
  ├── column-tile.tsx                            [62×74 selectable tile, per Kyle]
  ├── why-tooltip.tsx                            [the small "?" with Jade's rationale]
  ├── add-more-popover.tsx                       [+ show more flow]
  ├── running-totals-bar.tsx                     [bottom of each row]
  ├── workout-extras-row.tsx                     [pre/during/post extras for hard days]
  ├── jade-fill-button.tsx                       [header CTA]
  ├── mobile-stepper.tsx                         [single-slot mobile view]
  └── empty-state-c.tsx
packages/web/src/lib/queries/columns-data.c.ts   [server-side curation per slot]
packages/web/src/lib/hooks/use-column-picks.ts   [client state for selections]
packages/web/src/lib/hooks/use-jade-fill.ts
packages/web/src/lib/hooks/use-add-more.ts
```

Variant C must NOT touch shared files or other variants.

### 4.3 Sub-phase build order

**1.C.1 — Layout shell** (~2 hours)

Deliverable: `/plan/c` renders the 5-column grid with hardcoded mock data; user can click tiles and they show selected state. Header "Fill my week" pill is a stub.

Key files: `plan.c.tsx`, `column-grid.tsx`, `column.tsx`, `column-tile.tsx`.

Demo: visual grid with selectable tiles, no data.

**1.C.2 — Server-side curation per slot** (~4 hours)

Deliverable: A server function `loadColumns({ date, slot })` calls `listFoods` (the same shared tool, but executed server-side outside an LLM context) with the day's macro target + the slot type, and returns 4–6 options per column (protein/carb/veg). Each row in the grid (one per day per slot) prefetches its columns on the route loader.

This is the variant's biggest data-layer task: it pre-runs Jade's curation logic in deterministic SQL queries (no LLM call yet) so the UI loads instantly.

Key files: `columns-data.c.ts`, `plan.c.tsx` loader.

Demo: open `/plan/c`, see real foods from Lee's catalog filtered by his preferences in every column. No AI call yet.

**1.C.3 — Selection state + running totals** (~2 hours)

Deliverable: Click tiles → selections recorded in `use-column-picks` hook. Running totals bar at the bottom of each row updates live (client-side macro math from each food's denormalized macros). Target line shows `94g C · 48g P · 21g F · target 90–105g C · 45g P`.

Key files: `use-column-picks.ts`, `running-totals-bar.tsx`.

Demo: pick a chicken + rice + broccoli for Tuesday lunch, see totals turn green.

**1.C.4 — Save week + persistence** (~2 hours)

Deliverable: A persistent "Save week" button at the bottom right. On click: build a `WeekPlan` from the user's column picks + persisted Phase 0 schema; upsert to `meal_plans` + `meal_plan_meals`. Sonner toast confirms.

Key files: `plan.c.tsx`, hook for save.

Demo: pick all 21+ slots, save, refresh — picks persist.

**1.C.5 — Workout extras row** (~2 hours)

Deliverable: For workout days where pre/during/post applies, show a banner "TUE has an easy 6mi run. Include pre-run fuel? [Yes/Skip]". On Yes, render a 4th column row with template options (pre-curated server-side from `pre_workout_templates` etc., the same way main columns are).

Key files: `workout-extras-row.tsx`, `columns-data.c.ts` (extended).

Demo: Tuesday's workout-extras row shows 3 pre-run template options.

**1.C.6 — Jade fill** (~2 hours)

Deliverable: Header "Fill my week with Jade" pill → confirmation dialog ("Replace 18 unfilled selections with Jade's picks?") → on accept, `/api/jade/object` `{ kind: 'week', ... }` runs and pre-selects every unlocked column. Animate the picks into place.

Key files: `jade-fill-button.tsx`, `use-jade-fill.ts`.

Demo: click "Fill my week" → all unfilled columns animate to a Jade-recommended pick.

**1.C.7 — "+ show more" popover** (~2 hours)

Deliverable: At the bottom of any column, a "+ show more" row → opens a `<Popover>` with an input "Describe what you want." → fires `/api/jade/object` `{ kind: 'tweak', input: { scope: 'slot', tweak_text: 'chickpea-based' } }` → returns 3 new options that prepend to the column.

Key files: `add-more-popover.tsx`, `use-add-more.ts`.

Demo: in Tuesday's protein column, click "+ show more", type "chickpea", get 3 new options.

**1.C.8 — "Why these?" tooltips + mobile stepper + polish** (~3 hours)

Deliverable: Each column header has a small `?` icon → tooltip with a Jade one-line rationale ("Tempo day — leaner proteins so dinner can carry the carbs"). The rationale is pre-computed server-side per row at curation time, NOT a per-tooltip AI call. Mobile: collapse to a single-day-and-slot stepper. Polish all interactions.

Key files: `why-tooltip.tsx`, `mobile-stepper.tsx`.

Demo: full happy path on desktop and mobile.

### 4.4 Dependencies on Phase 0 primitives

- `<MealCell>` (used in column tiles for visual consistency in mobile stepper, optional)
- `<Card>`, `<Button>`, `<Tooltip>`, `<Popover>`, `<Dialog>` (Jade-fill confirm), `<Tabs>` (mobile day-stepper), `<Badge>`
- `<JadeAvatar size={24}>` (in Why tooltip and Jade-fill button)
- `<ErrorState>`
- `getServerSupabase()`, `listFoods` server-side (NOT through the LLM tool — directly call the same SQL-filter logic)

### 4.5 Variant-specific gotchas

- **Pre-curation is the variant's USP.** The SQL filter logic must match what Jade's `listFoods` tool would do — same allergy/diet filters, same `food_preferences` weighting. The cleanest implementation is to refactor the tool's `execute` body into a pure function `selectFoodsFor({ user, slot, date, targetMacros })` that both the LLM tool and the variant-C loader call.
- **Macro math drift.** The running totals bar uses denormalized macros from `foods.carbs_g` etc. — this matches what the LLM-generated meals use. Don't over-engineer with a separate "actual macros" path.
- **"Recommended" pre-selection.** On first paint, one option in each column should already be selected with a "Recommended" chip. The recommendation is whichever option scores highest in the same SQL filter (closest to target macros + most-liked food). This is rule-based; no LLM call.
- **Column tile size.** 62×74 is from Kyle's `selection_button.dart` (`03_kyle_design_for_web.md` §4 + §6). Don't deviate — this matches the existing Flutter app and is part of the brand consistency.
- **"+ show more" rate-limit.** This calls Jade. Rate-limit per `05_design_proposal.md` §6.6.

### 4.6 Testing checklist

```
[ ] /plan/c renders 5 columns × 3 main slots × 7 days with real Lee foods
[ ] Each column has a "Recommended" chip on the highest-scoring option
[ ] Selecting a different option recomputes running totals instantly
[ ] Workout-extras row appears on Saturday with template options
[ ] "Save week" persists; refresh keeps selections
[ ] "Fill my week with Jade" replaces all unfilled picks with AI selections
[ ] "+ show more" → typing → 3 chickpea options prepend
[ ] "?" tooltip on a column header shows a one-line rationale
[ ] Mobile: stepper through TUE → WED → THU works
[ ] Allergic foods never appear (e.g., add a fake peanut allergen, verify peanut foods missing)
[ ] Disliked foods are deprioritized but appear if necessary
```

### 4.7 Definition of done

`/plan/c` shippable when all 11 items pass and: a fresh-load `/plan/c` completes in < 2s (loader-time, no AI). The allergy/diet filter test is mandatory.

---

## §5 — Phase 1D: Variant D "Hybrid"

**Codename:** Hybrid. **Tagline:** *Plan on the left. Talk to Jade on the right.* **AI level:** ★★★★☆ (4/5).

**Branch:** `variant/d` · **Worktree:** `/Users/leemartin/development/mealplanning_prototype-d` · **Dev port:** 3004.

### 5.1 Scope summary

A 60/40 split: shared `<DayColumn>`-based grid on the left (a simplified variant-A grid), shared `<JadeChatPanel mode="panel">` on the right. Drag-from-chat: Jade's reply cards are draggable; day cells are droppable. Mobile: chat first, grid as a `<Sheet>`. Per `06` §1.D.

### 5.2 Files this variant creates or modifies

```
packages/web/src/routes/plan.d.tsx              [REPLACE stub]
packages/web/src/routes/plan.d.meal.$slotId.tsx [NEW — modal route for swap drawer]
packages/web/src/components/variant-d/
  ├── hybrid-shell.tsx                           [the resizable 60/40 split]
  ├── plan-side.tsx                              [the grid side; uses shared <MealCell>/<DayColumn>]
  ├── jade-side.tsx                              [the chat panel wrapper with toggle]
  ├── draggable-meal-card.tsx                    [Jade's reply cards, draggable via dnd-kit]
  ├── droppable-day-cell.tsx                     [grid cells that accept drops]
  ├── jade-chip.tsx                              [inline chips inside Jade's replies]
  ├── grid-sheet-mobile.tsx                      [mobile: grid as a sheet]
  └── empty-state-d.tsx
packages/web/src/lib/queries/week-data.d.ts      [variant-D loader]
packages/web/src/lib/hooks/use-hybrid-state.ts   [chat ↔ grid sync]
packages/web/src/lib/hooks/use-drag-meal.ts      [dnd-kit wrapper]
```

Variant D must NOT touch shared files or other variants. **Note:** D can read from variant A's grid via the shared `<DayColumn>` and `<MealCell>` — no copy-paste needed.

### 5.3 Sub-phase build order

**1.D.1 — Resizable shell** (~1.5 hours)

Deliverable: `/plan/d` renders a `<ResizablePanelGroup>` with two panels (60% grid, 40% chat). Both panels show placeholder content. Mobile: panels stack and grid is hidden behind a sheet trigger.

Key files: `plan.d.tsx`, `hybrid-shell.tsx`, `grid-sheet-mobile.tsx`.

Demo: split layout works on desktop; mobile shows chat full-width with a "open week grid" button.

**1.D.2 — Read real Supabase data + render grid** (~2.5 hours)

Deliverable: Grid side renders the 7-day grid using shared `<DayColumn>` + `<MealCell>` from Phase 0. Same data as variant A's loader.

Key files: `week-data.d.ts`, `plan-side.tsx`.

Demo: grid populates with real activities and an empty `meal_plans`.

**1.D.3 — Chat panel + initial regen** (~3 hours)

Deliverable: Right side renders `<JadeChatPanel mode="panel">`. On first load, Jade greets with "Hey — I built a high-carb week with Saturday's long run as the anchor." Simultaneously fires `/api/jade/object` `{ kind: 'week' }` and the result populates the grid AND becomes a chat message. Inline chips below the message: `[vegetarian week]` / `[more protein]` / `[no fish]` / `[simpler dinners]`.

Key files: `jade-side.tsx`, `jade-chip.tsx`, `use-hybrid-state.ts`.

Demo: open `/plan/d` → grid + chat both populate over ~10s; Jade's first message is the greeting + week summary.

**1.D.4 — Cell-click swap (escape hatch)** (~2 hours)

Deliverable: Click any cell in the grid → opens shared `<SwapDrawer>` (same as variant A). After swap accept, the grid updates AND Jade sends a chat message: "Got it — Wednesday lunch is now turkey + sweet potato burrito bowl."

Key files: `plan.d.meal.$slotId.tsx`, `use-hybrid-state.ts`.

Demo: cell-click swap works identically to variant A; chat reflects the change.

**1.D.5 — Chat-driven swap with reply cards** (~3 hours)

Deliverable: User types "swap Wednesday lunch for something with chickpeas" → Jade calls `proposeMealSwap` server-side → response is a chat message with 3 inline meal cards. Cards have `[Use]` button + `[drag onto a day]` affordance.

Key files: `jade-side.tsx` (custom MessagePart renderer), shared `<JadeMessageCard>` extended.

Demo: chat-driven swap returns 3 cards; clicking `[Use]` updates the grid.

**1.D.6 — Drag-from-chat to grid** (~3 hours)

Deliverable: Use **dnd-kit** to make `<DraggableMealCard>` draggable and `<DroppableDayCell>` droppable. On drop, the cell content replaces; flash Electrolyte cyan briefly; sonner toast confirms; persisted to `meal_plan_meals`. Keyboard mode (dnd-kit's `KeyboardSensor`) lets users tab to a card, press Space, arrow-key to a cell, press Enter.

Key files: `draggable-meal-card.tsx`, `droppable-day-cell.tsx`, `use-drag-meal.ts`.

Demo: drag a Jade-suggested card from chat onto Tuesday lunch → cell replaces with a sparkle animation.

**1.D.7 — Toggle chat panel + state persistence** (~1.5 hours)

Deliverable: Header button in the chat panel collapses it to a 56px right strip showing only Jade's avatar. Re-clicking expands. State persists in localStorage. The grid expands to full-width when the panel is collapsed.

Key files: `jade-side.tsx`, `hybrid-shell.tsx`.

Demo: toggle panel; refresh; toggle state preserved.

**1.D.8 — Polish + first-load tooltip + mobile** (~2 hours)

Deliverable: First-time tooltip on landing: "Drag any of Jade's cards onto a day cell to use it." Mobile: chat is the dominant surface; grid is a sheet triggered from a top-bar button. Drag-and-drop works on touch via dnd-kit's `TouchSensor`.

Key files: all polished.

Demo: full happy path, desktop + mobile.

### 5.4 Dependencies on Phase 0 primitives

- Shared `<JadeChatPanel mode="panel">`, `<JadeAvatar>`, `<MealCell>`, `<DayColumn>`, `<MacroTotalsRail>`, `<SwapDrawer>`, `<JadeMessageCard>`
- `<ResizablePanelGroup>`, `<ResizablePanel>`, `<ResizableHandle>` from shadcn (added in Phase 0 step 6)
- `<Sheet>` for mobile grid drawer
- dnd-kit (already in Phase 0 deps)

### 5.5 Variant-specific gotchas

- **dnd-kit setup**: wrap the entire route in `<DndContext sensors={[mouse, touch, keyboard]}>`. Without sensors, drag won't work on touch. The `<DroppableDayCell>` must use the `useDroppable` hook with a unique `id` per cell (e.g., `${date}-${slot}`).
- **Drag-and-drop discoverability**: users may not realize cards are draggable. Add a small drag handle icon on the card edge + the first-time tooltip.
- **Two surfaces compete**: when the user clicks a cell AND types in chat at the same time, both fire AI calls. Add a small mutex in `use-hybrid-state` so only one call is in-flight.
- **`useChat` vs `streamObject`**: chat uses `@ai-sdk/react`'s `useChat` against `/api/jade/chat`, but the meal-card replies need structured output. Pattern: the chat endpoint streams text + a JSON tool-call payload that the message-part renderer parses into draggable cards. See `06` §1.D's wireframe for the visual.
- **Mobile blurs into variant E**: this is acknowledged in `06` §1.D. On mobile, the grid is a sheet; the experience is closer to variant E. That's intentional — don't fight it.

### 5.6 Testing checklist

```
[ ] /plan/d split layout works; resize handle works
[ ] Initial load: grid + chat both populate from one regen
[ ] Cell click → swap drawer opens (same as variant A)
[ ] After swap accept, Jade sends a chat acknowledgment
[ ] Chat-driven "swap Wednesday lunch for chickpeas" returns 3 cards in chat
[ ] [Use] on a chat card updates the grid
[ ] Drag a chat card onto a day cell → cell replaces
[ ] Drag-and-drop works via keyboard (Tab + Space + Arrows + Enter)
[ ] Toggle panel → grid expands; state persists across reloads
[ ] First-time tooltip explains drag-and-drop
[ ] Mobile: chat dominant, grid behind a sheet trigger
[ ] Mobile drag-and-drop works on touch
[ ] No double AI calls when clicking a cell while chat is in-flight
```

### 5.7 Definition of done

`/plan/d` shippable when all 13 items pass and: drag-and-drop works on both touch and keyboard. The keyboard test is non-negotiable for accessibility.

---

## §6 — Phase 1E: Variant E "Coach"

**Codename:** Coach. **Tagline:** *Just talk to Jade. She'll handle the rest.* **AI level:** ★★★★★ (5/5).

**Branch:** `variant/e` · **Worktree:** `/Users/leemartin/development/mealplanning_prototype-e` · **Dev port:** 3005.

### 6.1 Scope summary

Full-bleed chat. Per `06` §1.E. Jade greets, optionally asks 3–4 onboarding questions, then offers a streaming markdown summary card representing the week. Edits via natural language or slash commands. A "View as plan" toggle reveals a read-only `<Sheet>` with the week rendered as cards. The chat thread IS the source of truth.

### 6.2 Files this variant creates or modifies

```
packages/web/src/routes/plan.e.tsx              [REPLACE stub]
packages/web/src/components/variant-e/
  ├── jade-shell.tsx                             [full-bleed shell]
  ├── message-list.tsx                           [scrollable chat history]
  ├── message-part-text.tsx                      [text bubble]
  ├── message-part-week-card.tsx                 [the streaming week summary card]
  ├── message-part-meal-card.tsx                 [single-meal swap response]
  ├── message-part-chips.tsx                     [inline chip suggestions]
  ├── jade-composer.tsx                          [the input bar with slash command hints]
  ├── view-as-plan-sheet.tsx                     [read-only week-as-cards overlay]
  ├── slash-command-parser.ts                    [/swap /lock /why parsing]
  ├── onboarding-flow.tsx                        [3–4 question warm-start]
  └── empty-state-e.tsx
packages/web/src/lib/queries/week-data.e.ts
packages/web/src/lib/hooks/use-coach-chat.ts    [wraps useChat with persistence]
```

Variant E must NOT touch shared files or other variants.

### 6.3 Sub-phase build order

**1.E.1 — Layout shell + greeting** (~2 hours)

Deliverable: `/plan/e` renders a full-bleed chat with Jade's 96px avatar at the top, a single greeting message ("Hey, I'm Jade. I help endurance athletes plan their week of meals around their training. Want me to build this week for you?"), 3 inline chip CTAs ([yes, build it] / [first ask me a few things] / [show me an example]), and the composer bar pinned at the bottom.

Key files: `plan.e.tsx`, `jade-shell.tsx`, `message-list.tsx`, `jade-composer.tsx`, `empty-state-e.tsx`.

Demo: page renders the greeting; chips are clickable but no-ops yet.

**1.E.2 — Read real Supabase data + chat plumbing** (~3 hours)

Deliverable: Wire `useChat` from `@ai-sdk/react` against `/api/jade/chat?surface=coach`. The chat endpoint loads Lee's full context (week data, prefs, activities, targets) on every chat call (cacheable via prompt caching).

Key files: `use-coach-chat.ts`, `week-data.e.ts`.

Demo: type "hi" → get a coherent reply.

**1.E.3 — Build-the-week from chat** (~3 hours)

Deliverable: Click [yes, build it] or type "build my week" → Jade replies with "Got it. Pulling your training: Sat is your long run (18 mi), the rest is moderate. Building…" → fires `streamObject` for the WeekPlan → as it streams, the message renders a streaming markdown card (the wireframe in `06` §1.E).

Key files: `message-part-week-card.tsx`, `use-coach-chat.ts`.

Demo: full week generation in chat with the rich card response.

**1.E.4 — Persistence + "View as plan"** (~2 hours)

Deliverable: The week-card has [view as plan] and [save this week] buttons. [save] upserts to `meal_plans` + `meal_plan_meals` with `approach_used = 'e'`. [view as plan] opens a `<Sheet>` rendering the week as scrollable Day cards (read-only). Subsequent edits in chat update the persisted rows.

Key files: `view-as-plan-sheet.tsx`, save handler in `use-coach-chat.ts`.

Demo: save the week; refresh; chat history (last week-card) re-displays from `meal_plans`. Open the sheet to view as cards.

**1.E.5 — Chat-driven swap** (~2 hours)

Deliverable: User types "swap Wednesday lunch for something with chickpeas" → Jade calls `proposeMealSwap` → response is a chat message with 1 meal card + [keep] [undo] [swap again] buttons. Persisted to DB.

Key files: `message-part-meal-card.tsx`, swap handler in `use-coach-chat.ts`.

Demo: full swap loop in chat, with undo working.

**1.E.6 — Tweak chips** (~1.5 hours)

Deliverable: After the initial week is built, Jade's reply ends with chip suggestions: `[more protein]` / `[no fish]` / `[simpler dinners]` / `[vegetarian]`. Clicking a chip is shorthand for typing the same constraint; fires the tweak path; updates the persisted plan.

Key files: `message-part-chips.tsx`.

Demo: tap a chip → diff applies.

**1.E.7 — Slash commands + onboarding flow** (~3 hours)

Deliverable: Composer footer lists `/swap [day] [slot]` / `/lock [day] [slot]` / `/why [day]`. Slash commands are parsed client-side and translated into structured tool calls (no LLM round-trip for the parsing). Onboarding flow: clicking [first ask me a few things] launches a 3-question wizard ("How many days are you training this week?" / "Anything you want to avoid this week?" / "Any travel I should know about?") whose answers are appended as soft constraints to the build prompt.

Key files: `slash-command-parser.ts`, `onboarding-flow.tsx`, `jade-composer.tsx` (slash hint).

Demo: `/lock fri dinner` works; onboarding wizard works.

**1.E.8 — Polish + refusal handling** (~2 hours)

Deliverable: Wire all four refusals from `06` §0.5 — when the user types medical / restrictive / ED / diagnostic, Jade's reply is the static refusal + offer to redirect. Add the 10-prompt refusal eval set to `tests/refusal.spec.ts`. Polish all interactions (markdown sanitization is tricky because Jade outputs markdown; use `react-markdown` with `remark-gfm` and a strict allowlist of nodes — no raw HTML, no `<script>`).

Key files: refusal handling in the `JADE_BASE_SYSTEM_PROMPT` + a small client-side guardrail; `tests/refusal.spec.ts`.

Demo: every refusal class returns the correct response; eval set passes 10/10.

### 6.4 Dependencies on Phase 0 primitives

- Shared `<JadeChatPanel mode="fullbleed">` (variant E uses fullbleed mode)
- `<JadeAvatar size={96}>`, `<MealCell>` (inside meal-card message parts), `<JadeMessageCard>`
- `<Card>`, `<Button>`, `<Badge>`, `<Sheet>`, `<Avatar>`, `<ScrollArea>`, `<Input>`, `<Tooltip>`, `<Sonner>`
- `<ErrorState>`
- `useChat` from `@ai-sdk/react`
- `react-markdown` + `remark-gfm` (NOT in Phase 0 deps; variant E adds via shared `pnpm add` PR)

### 6.5 Variant-specific gotchas

- **Markdown rendering with code-block-safe sanitization.** Jade outputs markdown. Use `react-markdown` with `remark-gfm`, set `disallowedElements={['script','iframe','style']}` and `unwrapDisallowed={true}`. Don't use `dangerouslySetInnerHTML`.
- **Streaming markdown is tricky.** Partial responses can have unclosed code fences or tables. Handle "in-progress" rendering by buffering the last ~80 chars and only flushing on a newline boundary, or accept some flicker.
- **Persistence is text-driven, not structured.** A user's "swap Wednesday lunch" command implies a structured update to `meal_plan_meals`. The chat endpoint must call the `proposeMealSwap` tool AND persist the result before sending the user-facing reply, otherwise the user sees a swap that isn't saved.
- **Slash command parsing client-side**: regex `^\/(swap|lock|unlock|why)\s+(\w+)\s+(\w+)$` then map to API calls. Don't send slash commands to the LLM.
- **No grid means no scan-ability.** The "view as plan" sheet is the user's only way to see all 21 meals at once. Make sure the sheet renders fast (< 200ms after click).
- **Hardest hallucination risk.** Tighten the system prompt with "Every food_id you reference must come from a prior listFoods call. Never invent a food name." Plus, refuse-and-replace if the model emits a `food_id` that doesn't exist (server-side validation rejects the response and asks the model to retry).
- **Refusal eval set is mandatory for launch.** Don't ship E without all 10 refusal prompts returning the correct refusal.

### 6.6 Testing checklist

```
[ ] /plan/e shows greeting + 3 chip CTAs
[ ] [yes, build it] streams a week-card response
[ ] [save this week] persists; refresh shows previously saved week-card
[ ] [view as plan] opens a sheet with the week rendered as Day cards
[ ] Type "swap Wednesday lunch for something with chickpeas" → meal-card response
[ ] [keep] / [undo] / [swap again] all work
[ ] Tweak chip "more protein" applies and persists
[ ] /lock fri dinner works
[ ] /why sat returns Jade's rationale
[ ] Onboarding flow [first ask me a few things] gathers 3–4 answers
[ ] All 10 refusal eval prompts return correct refusals
[ ] Markdown renders without XSS (try injecting <script> via free-form text)
[ ] Mobile: chat is the entire UX, no horizontal scroll
```

### 6.7 Definition of done

`/plan/e` shippable when all 13 items pass and: the refusal eval is 10/10 and a markdown XSS injection attempt fails. Refusal + XSS are both blockers.

---

## §7 — Cross-cutting Build Concerns

These apply to all five variants. Do NOT duplicate in the per-variant sections.

### 7.1 Cost controls

Per `05_design_proposal.md` §6.6 + `06` §2 cost row:

- **Rate limit Jade endpoints** per user (Phase 0 step 22).
- **Cache `getUserPrefs` per request** — every Jade call reloads user prefs; memoize for the lifetime of one request via a `Map<userId, prefs>` in module scope.
- **Cache `WeekPlan` per `(user_id, week_start)` in `meal_plans`** — on reload, no AI call.
- **Cap `maxOutputTokens`** per surface: week-regen 4000, swap 800, tweak 1200, chat-turn 600.
- **Set temperature**: 0.3 for week-regen (we want stable output); 0.7 for swap (we want variety); 0.5 for chat.
- **Use AI Gateway logging** (Phase 0 step 21's `jade_calls` table mirrors this).
- **Prompt caching for the system prompt**: the 290-word `JADE_BASE_SYSTEM_PROMPT` + tool definitions + user profile are stable across regens. With Anthropic's prompt caching or OpenAI's automatic caching, this drops 50–70% of input cost.

### 7.2 Observability

- Every Jade call logs to `jade_calls` (Phase 0 step 21) with: user_id, approach, surface, model, prompt_tokens, completion_tokens, cached_tokens, duration_ms, tool_calls JSONB, status, error_message.
- Vercel AI Gateway has a built-in dashboard — surface the gateway dashboard URL in `STATUS.md` for Lee.
- Sentry is NOT wired in Phase 0. If error rate becomes a problem, install per `mealvana_endurance/docs/technical/sentry-integration.md` lessons learned.

### 7.3 Error states

All four states use shared `<ErrorState kind="...">` from Phase 0 step 23:

- `jade-failed` — toast + retry button. Fall back to `JADE_FALLBACK_MODEL` automatically before showing this.
- `rls-denied` — full-page error + "sign in again" CTA. Almost certainly a stale Clerk JWT; force a `signOut()` + redirect to `/sign-in`.
- `no-macro-targets` — banner + "Edit in app" deep link. Variants render gracefully (e.g., A's grid still shows the structure with `--` placeholders).
- `no-activities` — banner: "No training scheduled — we can build a rest-week plan." Continue button.

Variants that hit a brand-new error condition file a `shared:` PR to extend `<ErrorState>` instead of inventing local error UIs.

### 7.4 Accessibility

- **Calendar grid (variant A)**: cells are `<button>` elements inside a `<table>` with proper `<th>` / `<td>` semantics. Arrow keys navigate; Enter triggers swap; Cmd+R triggers regenerate-week. Use `aria-label` on the macro tier badges ("very high carb day, 320 grams") and on training day dots.
- **Swap drawer (A, D)**: focus trap on open; Esc closes; Tab cycles through alternatives; Enter on focused alternative = "USE THIS".
- **Card stack (B)**: gestures have keyboard equivalents (Left = swap, Right = keep, Up = lock); each gesture announces "[day] [slot] [action]" via `aria-live="polite"`.
- **Chat (D, E)**: messages are in a `<div role="log" aria-live="polite">`; chips inside replies are `<button>` not `<a>`; the composer is `<textarea aria-label="Message Jade">`.
- **Drag-and-drop (D)**: dnd-kit ships a `KeyboardSensor` — wire it; document the keyboard flow in the first-time tooltip.
- **Color contrast**: Mango orange (`#F78B14`) on Cream (`#F8F6EB`) is borderline at 12px; never use orange text on cream — orange is a fill color. Verify all text colors against `--background` with axe-core.

### 7.5 Performance budgets

- **TTFB on `/plan/*`**: < 500ms (server-side fetch is fast; Supabase's PostgREST is sub-100ms for the loader queries).
- **Streaming first token from Jade**: < 1.5s (depends on model + gateway latency; AI Gateway adds ~50ms).
- **Full WeekPlan stream complete**: < 12s for variants A, D; < 15s for B (it builds 21 cards but streams them as days).
- **Route bundle size**: < 300 KB gzipped per variant route. Variants D and E are at risk because of `useChat` + markdown deps; use `defineRoute({ ssr: 'data-only' })` to keep client JS lean if possible.
- **Lighthouse score**: ≥ 90 on each variant route in production.

---

## §8 — Parallel Execution Playbook

This is the most actionable section.

### 8.1 The 5+1 tab orchestration

Open six terminal/Claude Code windows:

```
TAB 1 — main worktree                         [/Users/leemartin/development/mealplanning_prototype]
        Lee + a Phase-0 code-executor agent
        Branch: main
        Job: Phase 0 (§1). Stays open after Phase 0 to handle shared:* PRs from variants.

TAB 2 — variant A worktree                    [.../mealplanning_prototype-a]
        Variant-A code-executor agent
        Branch: variant/a
        Port: 3001
        Job: §2

TAB 3 — variant B worktree                    [.../mealplanning_prototype-b]
        Variant-B code-executor agent
        Branch: variant/b
        Port: 3002
        Job: §3

TAB 4 — variant C worktree                    [.../mealplanning_prototype-c]
        Variant-C code-executor agent
        Branch: variant/c
        Port: 3003
        Job: §4

TAB 5 — variant D worktree                    [.../mealplanning_prototype-d]
        Variant-D code-executor agent
        Branch: variant/d
        Port: 3004
        Job: §5

TAB 6 — variant E worktree                    [.../mealplanning_prototype-e]
        Variant-E code-executor agent
        Branch: variant/e
        Port: 3005
        Job: §6
```

Tabs 2–6 are blocked until tab 1 finishes Phase 0. After tab 1 commits Phase 0 to `main`, Lee runs the worktree-creation script from §0.2, then opens tabs 2–6 each with an agent kicked off via the prompts in §8.2.

### 8.2 Variant kickoff prompts

Copy-paste into each variant's Claude Code session as the first message after the agent boots.

#### Prompt for variant A (Calendar):

```
You are building Variant A (Calendar) of the Mealvana meal-planning prototype.

Working directory: /Users/leemartin/development/mealplanning_prototype-a (a git worktree on branch variant/a)

Read these documents in full before writing any code:
- docs/mealplanning_prototype/06_five_uiux_approaches.md §1.A and §0 (Jade persona)
- docs/mealplanning_prototype/07_parallel_build_plans.md §0 (parallelization rules) and §2 (your full plan)
- docs/mealplanning_prototype/05_design_proposal.md §4.3, §4.5 (week view, swap drawer)
- docs/mealplanning_prototype/03_kyle_design_for_web.md (brand)

Implement Phase 1.A.1 first (Layout shell). Run `pnpm dev` on port 3001 and confirm /plan/a renders the empty state. Update STATUS.md when 1.A.1 is done. Continue through 1.A.2, 1.A.3, ... in order.

CRITICAL RULES:
- DO NOT touch any file in components/shared/, components/ui/, lib/, server/jade/, routes/__root.tsx, routes/index.tsx, routes/settings.tsx, routes/api/jade/, routes/sign-in.tsx, routes/sign-up.tsx, routes/onboarding/. If you need a change there, OPEN A PR to main titled "shared: <thing>" and wait.
- DO NOT touch routes/plan.{b,c,d,e}.tsx or components/variant-{b,c,d,e}/.
- Only create files matching the patterns in §0.4 of 07_parallel_build_plans.md.
- After every sub-phase, run `pnpm typecheck && pnpm lint && pnpm test`. Fix anything red before moving on.
- Update STATUS.md after every sub-phase.

Begin with 1.A.1.
```

#### Prompt for variant B (Stack):

```
You are building Variant B (Stack) of the Mealvana meal-planning prototype.

Working directory: /Users/leemartin/development/mealplanning_prototype-b (branch variant/b)

Read these documents in full:
- docs/mealplanning_prototype/06_five_uiux_approaches.md §1.B and §0 (Jade persona)
- docs/mealplanning_prototype/07_parallel_build_plans.md §0 (parallelization) and §3 (your plan)
- docs/mealplanning_prototype/03_kyle_design_for_web.md (brand)

Implement Phase 1.B.1 first (Layout shell). Run `pnpm dev` on port 3002. Confirm /plan/b renders empty state.

KEY VARIANT-B GOTCHAS:
- Use `motion` (NOT framer-motion) for the swipe gesture: `drag="x" dragConstraints={...} onDragEnd`.
- Pre-fetch the next swap in the background to keep latency under 1.5s.
- Persist on every keep/lock, not at the end. A user closing the tab at card 12 must keep their 11 saved cards.
- Auto-pre-lock workout-day pre/during/post template picks; don't force a swipe for those.

CRITICAL RULES:
- DO NOT touch shared files or other variants' files (see §0.4 of 07_parallel_build_plans.md).
- After every sub-phase, run typecheck/lint/test.
- Update STATUS.md after every sub-phase.

Begin with 1.B.1.
```

#### Prompt for variant C (Columns):

```
You are building Variant C (Columns) of the Mealvana meal-planning prototype.

Working directory: /Users/leemartin/development/mealplanning_prototype-c (branch variant/c)

Read:
- docs/mealplanning_prototype/06_five_uiux_approaches.md §1.C and §0
- docs/mealplanning_prototype/07_parallel_build_plans.md §0 and §4
- docs/mealplanning_prototype/03_kyle_design_for_web.md §4 (selection_button), §6 (Inputs)

Run `pnpm dev` on port 3003.

KEY VARIANT-C GOTCHAS:
- The pre-curation that fills each column is the variant's USP — it's deterministic SQL, NOT an LLM call. The function `selectFoodsFor({ user, slot, date, targetMacros })` should be a refactor of the listFoods tool's body. Implement it server-side so the loader is fast (< 2s for the whole grid).
- Allergy/diet filters are SQL-level (defense in depth). Add a manual test: assert peanut foods never appear if user has peanut allergy.
- The column tile is 62×74 (per Kyle's selection_button). Don't deviate.
- "+ show more" calls Jade and is rate-limited.

CRITICAL RULES: see other prompts.

Begin with 1.C.1.
```

#### Prompt for variant D (Hybrid):

```
You are building Variant D (Hybrid) of the Mealvana meal-planning prototype.

Working directory: /Users/leemartin/development/mealplanning_prototype-d (branch variant/d)

Read:
- docs/mealplanning_prototype/06_five_uiux_approaches.md §1.D and §0
- docs/mealplanning_prototype/07_parallel_build_plans.md §0 and §5
- docs/mealplanning_prototype/05_design_proposal.md §4.5 (swap drawer, you reuse it)

Run `pnpm dev` on port 3004.

KEY VARIANT-D GOTCHAS:
- Use **dnd-kit** (`@dnd-kit/core` + `@dnd-kit/modifiers`) for drag-and-drop. Wire all three sensors (mouse, touch, keyboard) — keyboard mode is non-negotiable for accessibility.
- The chat endpoint streams text + structured tool-call payloads; the message-part renderer parses these into draggable meal cards.
- Two surfaces (chat, grid) compete; add a mutex in use-hybrid-state so only one AI call is in-flight.
- Mobile blurs into Approach E (chat-dominant); accept it.

CRITICAL RULES: see other prompts.

Begin with 1.D.1.
```

#### Prompt for variant E (Coach):

```
You are building Variant E (Coach) of the Mealvana meal-planning prototype.

Working directory: /Users/leemartin/development/mealplanning_prototype-e (branch variant/e)

Read:
- docs/mealplanning_prototype/06_five_uiux_approaches.md §1.E, §0 (Jade persona, REFUSALS!)
- docs/mealplanning_prototype/07_parallel_build_plans.md §0 and §6
- docs/mealplanning_prototype/05_design_proposal.md §6 (AI Surface Specifications)

Run `pnpm dev` on port 3005.

KEY VARIANT-E GOTCHAS:
- Use `react-markdown` + `remark-gfm` for chat rendering. SET `disallowedElements={['script','iframe','style']}` and DO NOT use `dangerouslySetInnerHTML`. The XSS injection test is a launch blocker.
- Chat-driven swaps must persist BEFORE Jade replies "Done — Wednesday lunch is now…" — otherwise the user sees an unsaved swap. The endpoint must call proposeMealSwap, write to meal_plan_meals, AND THEN send the user-facing reply.
- Slash commands are parsed client-side. Don't send /lock /swap /why to the LLM.
- The 10-prompt refusal eval set MUST pass 10/10 before launch. Add tests/refusal.spec.ts.
- Streaming markdown can render with unclosed code fences mid-stream; buffer the last ~80 chars on a newline boundary.

CRITICAL RULES: see other prompts.

Begin with 1.E.1.
```

### 8.3 STATUS.md template

Place at the repo root (in `main`). Variants append their lines, never delete.

```markdown
# STATUS

Last updated: 2026-MM-DD HH:MM

## Phase 0
- [ ] 1.1 Init the repo
- [ ] 1.2 Bootstrap @mealplanning/web
- [ ] 1.3 Tailwind v4 + Kyle tokens
- [ ] 1.4 Fonts
- [ ] 1.5 Root route + app shell
- [ ] 1.6 shadcn primitives, Kyle-themed
- [ ] 1.7 Shared UI primitives
- [ ] 1.8 Clerk setup
- [ ] 1.9 Supabase clients
- [ ] 1.10 AI SDK + Gateway
- [ ] 1.11 Jade backend
- [ ] 1.12 Database deltas + RLS
- [ ] 1.13 Landing page hub
- [ ] 1.14 Settings page
- [ ] 1.15 Styleguide
- [ ] 1.16 Theme toggle
- [ ] 1.17 Env vars
- [ ] 1.18 ESLint + Prettier + Husky
- [ ] 1.19 Vercel deploy
- [ ] 1.20 Vitest + Playwright
- [ ] 1.21 Observability scaffold
- [ ] 1.22 Rate limiting
- [ ] 1.23 Error states
- [ ] 1.24 DOD sweep
- [ ] 1.25 Cut variant branches

## Variant A (Calendar)
- [ ] 1.A.1 Layout shell
- [ ] 1.A.2 Read real Supabase data
- [ ] 1.A.3 Regenerate-week
- [ ] 1.A.4 Per-cell swap drawer
- [ ] 1.A.5 Coach strip + macro totals
- [ ] 1.A.6 Tweak bar
- [ ] 1.A.7 Ask Jade pill + drawer
- [ ] 1.A.8 Polish + persistence
Preview URL: <fill in>

## Variant B (Stack)
- [ ] 1.B.1 Layout shell
- [ ] 1.B.2 Read real Supabase data
- [ ] 1.B.3 Initial deck generation
- [ ] 1.B.4 Swipe gestures + actions
- [ ] 1.B.5 Jade narrator
- [ ] 1.B.6 Stop & chat
- [ ] 1.B.7 Done page + persistence
- [ ] 1.B.8 Polish + a11y
Preview URL: <fill in>

## Variant C (Columns)
- [ ] 1.C.1 Layout shell
- [ ] 1.C.2 Server-side curation
- [ ] 1.C.3 Selection state + running totals
- [ ] 1.C.4 Save week + persistence
- [ ] 1.C.5 Workout extras row
- [ ] 1.C.6 Jade fill
- [ ] 1.C.7 + show more
- [ ] 1.C.8 Why tooltips + mobile + polish
Preview URL: <fill in>

## Variant D (Hybrid)
- [ ] 1.D.1 Resizable shell
- [ ] 1.D.2 Read real Supabase data + grid
- [ ] 1.D.3 Chat panel + initial regen
- [ ] 1.D.4 Cell-click swap
- [ ] 1.D.5 Chat-driven swap
- [ ] 1.D.6 Drag-from-chat
- [ ] 1.D.7 Toggle panel
- [ ] 1.D.8 Polish + first-load tooltip + mobile
Preview URL: <fill in>

## Variant E (Coach)
- [ ] 1.E.1 Layout shell + greeting
- [ ] 1.E.2 Chat plumbing
- [ ] 1.E.3 Build the week from chat
- [ ] 1.E.4 Persistence + view as plan
- [ ] 1.E.5 Chat-driven swap
- [ ] 1.E.6 Tweak chips
- [ ] 1.E.7 Slash commands + onboarding
- [ ] 1.E.8 Refusal handling + polish
Preview URL: <fill in>

## Open shared:* PRs
(none)

## Risks hit
(none yet)
```

Each variant agent updates its own column when a sub-phase ships. Lee scans once a day.

### 8.4 Merge-back plan

Variants are NOT merged back into `main` during the prototype phase. The plan:

1. All 5 variants reach DOD.
2. Lee runs preference testing on the five preview URLs.
3. The winning variant gets a new branch `winner/x` rebased onto `main`.
4. Lee or a code-executor runs cleanup: rename `routes/plan.{x}.tsx` → `routes/plan.tsx`, delete the four losing variants' folders, drop the landing-page hub from `/`.
5. PR `winner/x` → `main`, deploy.

Until then: variant branches stay alive, preview URLs stay live, no merging.

For mid-build adjustments to shared files: any variant agent who needs a shared change opens a PR titled `shared: <thing>` against `main`. Lee reviews. After merge, all variants run:

```bash
git fetch origin
git rebase origin/main
# resolve any conflicts in shared files by accepting main's version
pnpm install
```

---

## §9 — Risk Register

| # | Risk | Severity | Likelihood | Owner | Mitigation |
|---|---|---|---|---|---|
| 1 | Clerk → Supabase JWT bridge silently fails (sub claim missing for new users) | High | Medium | Phase 0 | Step 8 onboarding-bridge route handles all 3 cases; manual test with Lee's account first; service-role lookup if email match fails |
| 2 | AI tool calls hallucinate food IDs (model invents UUIDs) | High | Medium | Phase 0 (server/jade/proposers.ts) | Server-side validation rejects responses with non-existent food_ids; auto-retry with stricter prompt; `listFoods` results are passed back into the prompt as a strict "you may only choose from this list" constraint |
| 3 | Tailwind v4 + shadcn registry incompatibility (shadcn CLI generates v3 config) | Medium | High | Phase 0 step 6 | Delete the auto-generated `tailwind.config.ts`; only use the CSS-first `@theme` block. Document this as a recurring trap for new contributors |
| 4 | User has no `daily_macro_targets` cached for the upcoming week | Medium | High | All variants | The `<ErrorState kind="no-macro-targets">` banner with a "Edit in app" link is the answer. Variants render gracefully with `--` placeholders |
| 5 | Compadre Wide font licensing for web is unresolved | Low | High | Phase 0 step 4 | Use Work Sans + tracking-wider as a known-good fallback (per `03_kyle_design_for_web.md` §3.2). Document; revisit pre-launch |
| 6 | CORS / Auth issues from Supabase against Vercel preview URLs | Medium | Low | Phase 0 step 19 | Supabase's CORS allows `*` for the anon API by default; Clerk's allowed origins must include the preview domain (`*.vercel.app`); add to Clerk dashboard's allowed origins list |
| 7 | AI cost explodes if a variant's loop fires too many regens | High | Medium | Phase 0 step 22 | Rate limits; AI Gateway dashboard alerts at $X/day; `jade_calls` table makes it queryable per variant |
| 8 | Variant E refusal eval set fails after model upgrade | High | Medium | Variant E §6.6 | Refusal tests are in `tests/refusal.spec.ts` — run on every model change |
| 9 | dnd-kit keyboard mode misses a sensor, breaking variant D's a11y | Medium | Medium | Variant D §5.3 | Wire all three sensors explicitly; manual keyboard test in 1.D.6 demo |
| 10 | Drag-from-chat to grid drops on the wrong cell on mobile | Medium | Medium | Variant D §5.5 | Use dnd-kit's `pointerWithin` collision detection; test on iOS Safari and Android Chrome explicitly |
| 11 | `streamObject` partial outputs fail Zod validation mid-stream | Medium | Medium | Phase 0 step 11 | The AI SDK's `streamObject({ output: 'object' })` reconstructs progressively — validate only at end. If using strict, set `mode: 'tool'` |
| 12 | Worktrees diverge on shared file changes (variants forget to rebase) | Medium | High | All variants | Document in §0.5 + §8.4. STATUS.md tracks open shared PRs. Lee pings variant agents when shared changes land |
| 13 | Vercel preview deploy hits unauthenticated Supabase calls (anon key + RLS denies) | Low | Medium | All variants | Verify with a fresh incognito tab on each preview URL; sign in; confirm `/settings` loads real data |
| 14 | Variant B's swipe latency makes the deck feel broken | High | High | Variant B §3.5 | Pre-fetch next-up alternatives in the background; document the median latency target (< 1.5s) |
| 15 | Markdown XSS in variant E (free-text from Jade with embedded HTML) | High | Low | Variant E §6.5 | `react-markdown` + `disallowedElements`; never use `dangerouslySetInnerHTML`; injection test in QA checklist |

---

## §10 — Suggested Daily-Scrum Milestone Calendar

This is **a suggestion, not a contract**. Times assume Lee + 5 parallel Claude code-executor agents working roughly 6 productive hours per day each.

### Day 1 — Phase 0 + variant stubs

- 09:00–17:00 — Tab 1 (main): Phase 0 steps 1.1 → 1.25
- End of day:
  - `/styleguide`, `/sign-in`, `/onboarding/bridge`, `/settings`, `/api/jade/hello` all green on `main`
  - Migrations applied to dev Supabase
  - Variant branches cut, worktrees created
  - Variants A–E each render a "coming soon" stub at `/plan/{x}`
  - `STATUS.md` shows Phase 0 complete

### Day 2 — Read real Supabase data (sub-phase 2 for each variant)

- All 5 variant agents start in parallel.
- 09:00–11:00 — Each variant: 1.{x}.1 Layout shell.
- 11:00–17:00 — Each variant: 1.{x}.2 Read real Supabase data.
- End of day:
  - All 5 variants render real activities + macro targets (no AI yet)
  - Lee can open `/plan/a` … `/plan/e` and see a stubbed UI populated with his own training week

### Day 3 — Working "Ask Jade" minimum integration

- 09:00–17:00 — Each variant: 1.{x}.3 (regen, deck, columns, chat panel + initial regen, chat plumbing).
- End of day:
  - Variant A: clicking "Plan my week" streams a real grid
  - Variant B: deck of 21 cards generates and reveals card 1
  - Variant C: pre-curated columns visible (server-side `listFoods`); "Fill my week" still stub
  - Variant D: grid + chat both populate from one regen
  - Variant E: type "build my week" → streaming week-card

### Day 4 — Variant-specific hero interaction works

- 09:00–17:00 — Each variant: 1.{x}.4–1.{x}.6.
- End of day:
  - Variant A: per-cell swap drawer + tweak bar + coach strip
  - Variant B: full swipe gesture system + Jade narrator + stop & chat
  - Variant C: selection state + save + workout extras + Jade fill
  - Variant D: cell-click swap + chat-driven swap + drag-from-chat
  - Variant E: chat-driven swap + tweak chips + view-as-plan sheet

### Day 5 — Polish, persistence, demoable preview deploys

- 09:00–14:00 — Each variant: 1.{x}.7 + 1.{x}.8 (polish, mobile, a11y, error states, refusal eval for E).
- 14:00–16:00 — Manual QA on every preview URL by Lee.
- 16:00–17:00 — STATUS.md final update; preference-test invitations sent.
- End of day:
  - All five variants pass their full QA checklists
  - Five distinct preview URLs are live and shareable
  - The landing page at `/` (production) links to all five

If a variant slips behind on any day, Lee's escalation path: pause the slipping variant, surge the lead variant agent to help, or descope a sub-phase into a "stretch" item for a Day 6.

---

## Appendix A — File Ownership Matrix

A reminder of who-touches-what. Cross-reference §0.4.

| File / directory | Owner | Variants that read |
|---|---|---|
| `package.json`, lockfile, configs | `main` only | all (read-only) |
| `packages/web/src/styles/globals.css` | `main` only | all |
| `packages/web/src/components/ui/**` | `main` only | all |
| `packages/web/src/components/shared/**` | `main` only (variants propose via shared:* PR) | all |
| `packages/web/src/lib/**` | `main` only | all |
| `packages/web/src/server/jade/**` | `main` only | all |
| `packages/web/src/routes/__root.tsx`, `index.tsx`, `settings.tsx`, `styleguide.tsx`, `sign-in.tsx`, `sign-up.tsx`, `onboarding/bridge.tsx` | `main` only | all |
| `packages/web/src/routes/api/jade/**` | `main` only | all |
| `packages/web/src/routes/plan.a.tsx`, `plan.a.meal.$slotId.tsx` | `variant/a` only | A |
| `packages/web/src/routes/plan.b.tsx` | `variant/b` only | B |
| `packages/web/src/routes/plan.c.tsx` | `variant/c` only | C |
| `packages/web/src/routes/plan.d.tsx`, `plan.d.meal.$slotId.tsx` | `variant/d` only | D |
| `packages/web/src/routes/plan.e.tsx` | `variant/e` only | E |
| `packages/web/src/components/variant-{x}/**` | `variant/{x}` only | {x} |
| `packages/web/src/lib/queries/week-data.{x}.ts`, `lib/hooks/use-{x-feature}.ts` (variant-specific) | `variant/{x}` only | {x} |
| `supabase/migrations/**` | `main` only | all (DB shared) |
| `STATUS.md` | append-only by all variants and main | all |

---

## Appendix B — Quick Reference of Commands

```bash
# === Repo bootstrap (Phase 0, run once) ===
mkdir -p /Users/leemartin/development/mealplanning_prototype
cd /Users/leemartin/development/mealplanning_prototype
git init -b main
pnpm init
# ... (steps 1.1–1.25 of §1)

# === Worktree setup (after Phase 0) ===
cd /Users/leemartin/development/mealplanning_prototype
git branch variant/a variant/b variant/c variant/d variant/e
for x in a b c d e; do
  git worktree add ../mealplanning_prototype-$x variant/$x
  ( cd ../mealplanning_prototype-$x && pnpm install && echo "PORT=300$(echo $x | tr 'abcde' '12345')" >> packages/web/.env.local )
done

# === Per-worktree daily flow ===
cd /Users/leemartin/development/mealplanning_prototype-a   # or -b, -c, -d, -e
git fetch origin
git rebase origin/main                                      # sync shared changes
pnpm install                                                # if package.json changed
pnpm dev                                                    # PORT comes from .env.local
# ... build sub-phase ...
pnpm typecheck && pnpm lint && pnpm test
git add -A && git commit -m "1.A.3: regenerate-week stream"
git push origin variant/a                                   # triggers preview deploy

# === Generate Supabase types (after schema change) ===
SUPABASE_PROJECT_ID=<dev-id> pnpm supabase:types

# === Apply migration ===
pnpm dlx supabase db push

# === Run a single variant's e2e test ===
pnpm --filter @mealplanning/web test:e2e plan-a

# === Tail Vercel preview build logs ===
pnpm dlx vercel logs <deployment-url>

# === List worktrees ===
git worktree list

# === Remove a worktree ===
git worktree remove ../mealplanning_prototype-a
git branch -D variant/a    # only if you want to drop the branch too
```

---

End of `07_parallel_build_plans.md`.
