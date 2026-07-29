# `me_website_new` Stack — Reference for the Meal-Planning Prototype

**Audience:** Engineers spinning up the new `mealplanning_prototype` at `/Users/leemartin/development/mealplanning_prototype`.
**Source of truth:** `/Users/leemartin/development/me_website_new/`.
**Goal:** Capture every load-bearing piece of the existing marketing-site stack so the new prototype can reuse the same toolchain (and we know what to add for an AI-heavy meal planner).

> Important callout up front: this stack is **NOT Next.js, NOT Supabase**. The brief asked about Next.js + Supabase patterns, but the actual `me_website_new` is a **TanStack Start (Vite + Nitro) app** with **Convex** as the backend, **Clerk** for auth, and **Sanity** as the CMS. There are zero references to Next.js or Supabase in the source. If the goal is "use the same stack so Lee doesn't learn a new toolchain," that means TanStack Start + Convex + Clerk + Sanity + shadcn/ui (Tailwind v4) + pnpm + Turbo, **not** Next.js App Router + Supabase SSR.

---

## 1. Top-level structure

It is a **pnpm + Turborepo monorepo** with four workspace packages.

```text
me_website_new/
├── package.json                # root, name "mealvana-endurance", private
├── pnpm-workspace.yaml         # packages: ["packages/*"]
├── pnpm-lock.yaml              # ~600 KB
├── turbo.json                  # tasks: build / dev / typecheck / test
├── tsconfig.json               # references each package
├── vercel.json                 # outputs packages/web/.output
├── .env.example                # see §11
├── packages/
│   ├── web/                    # @mealvana/web — TanStack Start + Vite + Nitro
│   ├── convex/                 # @mealvana/convex — Convex backend (queries/mutations/actions)
│   ├── sanity/                 # @mealvana/sanity — Sanity Studio v5
│   └── shared/                 # @mealvana/shared — constants + types only
├── scripts/migrate-content.ts  # one-off Sanity content migration script
├── aeo/                        # AEO (answer-engine optimization) docs/skills, unrelated to runtime
└── docs/screenshots/           # marketing screenshots
```

`pnpm-workspace.yaml`:

```yaml
packages:
  - "packages/*"

onlyBuiltDependencies:
  - esbuild
  - "@clerk/shared"
```

`turbo.json` — minimal, only declares task dependencies; **no remote cache config in the file**:

```json
{
  "tasks": {
    "build":      { "dependsOn": ["^build"], "outputs": [".output/**", "dist/**"] },
    "dev":        { "cache": false, "persistent": true },
    "typecheck":  { "dependsOn": ["^build"] },
    "test":       { "dependsOn": ["^build"] }
  }
}
```

Root `package.json` does **not** invoke turbo directly — scripts shell out via `pnpm --filter`:

```json
{
  "scripts": {
    "dev":         "pnpm --filter @mealvana/web dev",
    "build":       "pnpm --filter @mealvana/web build",
    "dev:convex":  "pnpm --filter @mealvana/convex dev",
    "dev:sanity":  "pnpm --filter @mealvana/sanity dev",
    "typecheck":   "pnpm -r typecheck",
    "test":        "pnpm -r test",
    "test:e2e":    "pnpm --filter @mealvana/web test:e2e"
  },
  "engines": { "node": ">=20", "pnpm": ">=9" }
}
```

So `turbo` is installed transitively but the root scripts use plain `pnpm -r`/`pnpm --filter`. Turbo is wired up but underused.

---

## 2. Frameworks & versions

Pulled from `packages/web/package.json` (caret-pinned, so these are minimums):

| Concern | Tool | Version |
| --- | --- | --- |
| App framework | **TanStack Start** | `^1.167.16` |
| Router | `@tanstack/react-router` | `^1.168.10` |
| Router/Query SSR bridge | `@tanstack/react-router-ssr-query` | `^1.166.10` |
| Bundler | **Vite** | `^8.0.7` |
| Server runtime | **Nitro** (`nitro-nightly`) | latest nightly, preset `node-server` (see `.output/nitro.json`) |
| React | `react` / `react-dom` | `^19.2.4` |
| Auth | `@clerk/tanstack-react-start` + `@clerk/react` | `^1.0.11` / `^6.2.1` |
| Backend | **Convex** | `^1.34.1` |
| CMS | **Sanity** Studio | `^5.20.0` (root package), client `@sanity/client` `^7.20.0` |
| Styling | **Tailwind CSS v4** | `^4.2.2`, via `@tailwindcss/vite` |
| Component metadata | **shadcn** CLI | `^3.8.0` (registered via `components.json`, **no components installed yet**) |
| Forms / validation | `zod` | `^4.3.6` (no react-hook-form) |
| Data fetching | `@tanstack/react-query` | `^5.96.2` |
| Animations | `motion` (Framer Motion successor) | `^12.38.0` |
| Toaster | `sonner` | `^2.0.7` |
| Icons | `lucide-react` | `^0.564.0` |
| Math rendering | `katex` | `^0.16.45` |
| Stripe (browser) | `@stripe/stripe-js` | `^9.1.0` |
| Stripe (server) | `stripe` (in Convex) | `^22.0.0` |
| Email | Resend (REST in Convex) | n/a |
| Analytics | `mixpanel-browser` | `^2.77.0` |
| Tests (unit) | `vitest` | `^4.1.3` |
| Tests (e2e) | `@playwright/test` | `^1.52.0` |

**Node:** `>=20`. **pnpm:** `>=9`. There is **no `.nvmrc`** in the repo, only the `engines` field.

**TypeScript:** `^5.9.x` everywhere. Root `tsconfig.json` uses project references:

```json
{
  "compilerOptions": {
    "target": "ES2022", "module": "ESNext", "moduleResolution": "bundler",
    "esModuleInterop": true, "strict": true, "skipLibCheck": true,
    "isolatedModules": true, "jsx": "react-jsx"
  },
  "references": [
    { "path": "./packages/shared" },
    { "path": "./packages/convex" },
    { "path": "./packages/web" },
    { "path": "./packages/sanity" }
  ]
}
```

---

## 3. Package manager & tooling

- **pnpm** is the package manager (lockfile committed, workspace declared).
- **Turbo** is configured but underused — root scripts mostly shell out via `pnpm --filter`. The pipeline is fine to keep; just be aware that `pnpm dev` runs only the web app, not Convex or Sanity.
- **Per-package scripts:**
  - `@mealvana/web`: `dev` (`vite dev --port 3000`), `build` (`vite build`), `start` (`node .output/server/index.mjs`), `typecheck`, `test`, `test:e2e`, `ui` (`pnpm dlx shadcn@latest`).
  - `@mealvana/convex`: `dev` (`convex dev`), `deploy` (`convex deploy`), `typecheck`, `test` (`vitest run`).
  - `@mealvana/sanity`: `dev` (`sanity dev`), `build`, `deploy`.
  - `@mealvana/shared`: `typecheck` only — it's source-only (`"main": "./src/index.ts"`).

There is a `.vscode/launch.json` with debug configurations for "Dev Server (Web)", "Convex Dev", "Sanity Studio", and a compound "Full Stack (Web + Convex)".

---

## 4. Styling — Tailwind v4 + shadcn (registry only)

`globals.css` is the central style file. Notable bits:

```css
@import "tailwindcss" source("../");

@import "tw-animate-css";
@import "shadcn/tailwind.css";
```

- **Tailwind v4** is configured **via the new `@tailwindcss/vite` plugin and `@theme inline { ... }` block in CSS** — there is **no `tailwind.config.js`/`.ts` file**. All theme tokens (colors, fonts, radii) live in CSS custom properties with `oklch(...)` values, then mapped through `@theme inline` so `bg-blackberry`, `text-orange`, `font-heading`, etc. just work.
- **`tw-animate-css`** is included for shadcn's animation utilities.
- **Custom theme tokens** (excerpt — see `packages/web/src/styles/globals.css`):
  ```css
  :root {
    --blackberry: oklch(0.25 0.06 310);
    --cream: oklch(0.96 0.01 85);
    --orange: oklch(0.72 0.16 55);
    --electrolyte: oklch(0.84 0.12 175);
    --dragonfruit: oklch(0.60 0.20 350);
    /* ...full shadcn tokens (background/foreground/primary/...) mapped to brand */
    --radius: 0.9375rem;
    --font-sans: "Apercu", ui-sans-serif, system-ui, sans-serif;
    --font-heading: "Sansita", ui-sans-serif, system-ui, sans-serif;
  }
  ```
- **Fonts:** Sansita is loaded via Google Fonts (`@import url(...sansita...)`); Apercu is loaded via local `@font-face` from `/public/fonts/`.

`components.json` (shadcn config):

```json
{
  "style": "base-vega",
  "rsc": false,
  "tsx": true,
  "tailwind": { "css": "src/styles/globals.css", "baseColor": "neutral", "cssVariables": true },
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

**Important gotcha:** `packages/web/src/components/ui/` is **empty**. shadcn is initialized but no components have been added yet. The site uses bespoke Tailwind classes everywhere (e.g. `rounded-full bg-orange px-8 py-3 font-heading text-sm font-bold text-white`). That's fine for a marketing site, but the meal-planning prototype will want `pnpm dlx shadcn@latest add button card dialog input form select tabs toast skeleton ...` from day one.

The standard `cn()` helper is in `src/lib/utils.ts`:

```ts
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";
export function cn(...inputs: ClassValue[]) { return twMerge(clsx(inputs)); }
```

---

## 5. Component library / UI patterns

- **No installed shadcn primitives yet** (see §4) — but the registry is wired and `pnpm ui` runs the shadcn CLI. The plan has clearly always been "shadcn lite, install on demand."
- **Radix is not directly installed** (only what shadcn would pull in transitively when you add components).
- **Custom components** in `packages/web/src/components/`:
  - `portable-text.tsx` — large (440-line) Sanity Portable Text renderer with custom blocks (callouts, KaTeX, image sizes, internal links to TanStack Router, code blocks, video embeds, nutrition fact callouts, product recommendations). Worth reading if the prototype renders rich content.
  - `katex-block.tsx` — math renderer using `katex.renderToString` + `dangerouslySetInnerHTML`.
  - `newsletter-form.tsx` — example of a Convex-mutation-backed form (no react-hook-form, just `useState`).
  - `viewport-fade.tsx` — IntersectionObserver-based fade-in wrapper used liberally.
  - `integration-page.tsx` — large reusable hero/details page used by `/integrations/garmin`, `/integrations/strava`, etc., with `motion/react` animations.
- **Icons:** `lucide-react`, configured as the icon library for shadcn.
- **Animations:** `motion` (the rebranded Framer Motion).

---

## 6. Data layer — Convex (NOT Supabase)

There is **no Supabase code anywhere in this repo**. The data layer is **Convex** (`convex.dev`), Sanity (CMS), and Clerk (auth).

### 6a. Convex client setup (browser, reactive)

`packages/web/src/lib/convex.ts`:

```ts
import { ConvexReactClient } from "convex/react";
export const convexClient = new ConvexReactClient(import.meta.env.VITE_CONVEX_URL);
```

`packages/web/src/lib/convex-server.ts` (HTTP client for server functions):

```ts
import { ConvexHttpClient } from "convex/browser";
export const httpClient = new ConvexHttpClient(import.meta.env.VITE_CONVEX_URL);
```

The Convex client is wired into the React tree in `routes/__root.tsx`, **wrapped by Clerk**, so Convex queries automatically carry the Clerk JWT:

```tsx
<ClerkProvider publishableKey={import.meta.env.VITE_CLERK_PUBLISHABLE_KEY} afterSignOutUrl="/">
  <ConvexProviderWithClerk client={convexClient} useAuth={useAuth}>
    <AppShell />
  </ConvexProviderWithClerk>
</ClerkProvider>
```

### 6b. Convex backend code

Lives at `packages/convex/convex/`. Key files:

- `schema.ts` — `defineSchema({ users, contactSubmissions, newsletterSubscribers, discussions, discussionReplies, blogComments, orders })` with named indexes (`by_clerkId`, `by_email`, `by_status`, etc.) and a search index (`search_title` on discussions).
- `auth.config.ts` — single Clerk JWT issuer:
  ```ts
  export default {
    providers: [{ domain: process.env.CLERK_JWT_ISSUER_DOMAIN, applicationID: "convex" }],
  };
  ```
- `users.ts` — `sync` (internalMutation, called by Clerk webhook), `getCurrent` (query), `updateProfile` (mutation).
- `discussions.ts` — full forum CRUD with auth checks via `ctx.auth.getUserIdentity()` and the `users.by_clerkId` index.
- `comments.ts` — blog post comments keyed by Sanity post id (cross-system join).
- `newsletter.ts` — subscribe + Mailchimp sync action.
- `contact.ts` — submit + Resend notification scheduled via `ctx.scheduler.runAfter`.
- `orders.ts` — Stripe order tracking.
- `stripe.ts` — `createCheckoutSession` action (`"use node"`, uses `stripe` SDK).
- `email.ts` — `sendContactNotification` / `sendOrderConfirmation` actions, calls Resend REST API directly (`"use node"`).
- `http.ts` — `/clerk-webhook` (svix-verified, syncs users) and `/stripe-webhook` (basic) HTTP endpoints.
- `_generated/` — types generated by `convex dev`. The `web` `tsconfig.json` includes `../../packages/convex/convex/**/*.ts` and aliases `@convex/*` so the frontend imports types directly:
  ```ts
  import { api } from "@convex/_generated/api";
  const discussions = useQuery(api.discussions.list, { category });
  const createDiscussion = useMutation(api.discussions.create);
  ```

That `@convex` alias is the magic that gives the web app fully-typed mutation/query references end-to-end. Worth replicating in the prototype.

### 6c. Sanity client setup

`packages/web/src/lib/sanity.ts` wraps `@sanity/client` with a fault-tolerant `fetch`:

```ts
const rawClient = createClient({
  projectId: import.meta.env.VITE_SANITY_PROJECT_ID,
  dataset: import.meta.env.VITE_SANITY_DATASET || "production",
  apiVersion: "2026-04-07",
  useCdn: true,
});

export const sanityClient = {
  ...rawClient,
  async fetch<T = unknown>(query: string, params?: QueryParams): Promise<T> {
    try {
      return params ? await rawClient.fetch<T>(query, params) : await rawClient.fetch<T>(query);
    } catch (err) {
      console.warn("[sanity] fetch failed:", (err as Error).message);
      return (query.includes("[0]") ? null : []) as T; // fallback
    }
  },
};
```

Sanity is used **only** for marketing content (blog posts, FAQs, changelog, team, integration partners, legal docs, catalog products). It is **not** used as the meal-planner database — that would be Convex.

### 6d. Generated types

- Convex generates `_generated/api.d.ts`, `dataModel.d.ts`, `server.d.ts` on every `convex dev` run.
- Sanity types are **hand-written** at `packages/web/src/lib/sanity-types.ts` (kept intentionally permissive). There is no `sanity-codegen` setup.

---

## 7. AI / Vercel AI SDK

**Nothing is installed.** A full search for `@ai-sdk`, `from "ai"`, `from 'ai'`, `@anthropic`, `openai`, `generateText`, `streamText` across `packages/` and `scripts/` (excluding `node_modules` and Sanity built artifacts) returned **zero hits in source code**. The marketing copy mentions "AI-Powered Nutrition Plans" but the website itself ships no AI generation code, no streaming routes, no chat UI, no generative-UI primitives.

This is the biggest gap for the meal planner: we have to add Vercel AI SDK + (most likely) Vercel AI Gateway from scratch. See §17.

---

## 8. Routing & layouts

**TanStack Router file-based routing** under `packages/web/src/routes/`. The route tree is generated into `routeTree.gen.ts` (committed; auto-updates when the dev server runs).

Layout & top-level structure:

- `__root.tsx` — root route with `<html>/<body>`, `<HeadContent>` (TanStack head management), `<Scripts>`, the Clerk + Convex providers, the `<Header>`/`<Footer>` shell, and a global `<Toaster richColors position="top-right" />`. This is the only place where the providers and global CSS (`@/styles/globals.css?url`) are wired.
- `(auth)/sign-in.tsx`, `(auth)/sign-up.tsx` — route group rendered by Clerk's `<SignIn routing="hash" forceRedirectUrl="/community" />` component.
- `index.tsx` — the marketing homepage (~1100 lines, lots of `motion/react`).
- `blog/`, `community/`, `compare/`, `integrations/`, `checkout/` — feature directories.
- Dynamic params: `blog/$slug.tsx`, `blog/category/$slug.tsx`, `blog/author/$slug.tsx`, `community/$discussionId.tsx`.
- `sitemap.xml.tsx` — generated sitemap as a route.

**Server functions** are TanStack Start's mechanism (`createServerFn`). Example from `routes/blog/index.tsx`:

```ts
const getBlogPosts = createServerFn({ method: "GET" }).handler(
  async (): Promise<BlogPostCard[]> => {
    return sanityClient.fetch<BlogPostCard[]>(`...GROQ...`);
  },
);

export const Route = createFileRoute("/blog/")({
  loader: async () => {
    const [posts, categories] = await Promise.all([getBlogPosts(), getCategories()]);
    return { posts, categories };
  },
  component: BlogIndex,
});
```

**Middleware:** there's no Next-style file-based middleware. Instead, `packages/web/src/start.ts` registers a request middleware via `createStart`:

```ts
import { clerkMiddleware } from "@clerk/tanstack-react-start/server";
import { createStart } from "@tanstack/react-start";

const clerkKey = import.meta.env.VITE_CLERK_PUBLISHABLE_KEY;
const useClerk = clerkKey && clerkKey.startsWith("pk_");

export const startInstance = createStart(() => ({
  requestMiddleware: useClerk ? [clerkMiddleware()] : [],
}));
```

The router context carries a `QueryClient` (see `router.tsx`), and `setupRouterSsrQueryIntegration` glues react-query to the SSR pipeline so server-loaded data hydrates the same query cache.

```ts
const queryClient = new QueryClient({
  defaultOptions: { queries: { refetchOnWindowFocus: false, staleTime: 1000 * 60 * 2 } },
});
const router = createRouter({ routeTree, context: { queryClient }, defaultPreload: "intent", scrollRestoration: true });
setupRouterSsrQueryIntegration({ router, queryClient, handleRedirects: true, wrapQueryClient: true });
```

---

## 9. State / forms

- **Forms:** plain `useState` + native HTML form elements. **No `react-hook-form`** is installed. **No `@hookform/resolvers`**.
- **Validation:** `zod` is in deps but I found no usage in `packages/web/src` outside types. Convex args are validated by Convex's own `v.string()/v.number()/v.union(...)` validators.
- **Server actions:** TanStack Start's `createServerFn({ method: "GET"|"POST" }).inputValidator(...).handler(...)` is the equivalent of Next server actions. Already used for Sanity reads and auth checks (`packages/web/src/lib/auth.ts`).
- **Reactive data:** Convex `useQuery`/`useMutation` (websocket-driven, no manual cache busting needed). React-Query is configured but mostly serves SSR hydration of `loader` data.
- **Toasts:** `sonner`'s `toast.success(...)` / `toast.error(...)` everywhere.

---

## 10. Auth — Clerk + Convex (NOT Supabase)

End-to-end Clerk:

1. **Provider** wraps the tree in `__root.tsx`:
   ```tsx
   <ClerkProvider publishableKey={import.meta.env.VITE_CLERK_PUBLISHABLE_KEY} afterSignOutUrl="/">
     <ConvexProviderWithClerk client={convexClient} useAuth={useAuth}>...</ConvexProviderWithClerk>
   </ClerkProvider>
   ```
2. **UI components** are Clerk's prebuilt `<SignIn />`, `<SignUp />`, `<UserButton />` (mounted in `(auth)/sign-in.tsx`, `(auth)/sign-up.tsx`, and `__root.tsx` header).
3. **Server-side checks** via Clerk's TanStack server adapter (`packages/web/src/lib/auth.ts`):
   ```ts
   import { auth } from "@clerk/tanstack-react-start/server";
   export const requireAuth = createServerFn({ method: "GET" }).handler(async () => {
     const state = await auth();
     if (!state.userId) throw redirect({ to: "/sign-in" });
     return { userId: state.userId };
   });
   ```
4. **Convex authentication** flows automatically — `ConvexProviderWithClerk` sends the Clerk JWT on every Convex call. In Convex functions: `const identity = await ctx.auth.getUserIdentity(); if (!identity) throw new Error("Not authenticated");`.
5. **User sync** via Clerk webhook → Convex HTTP action → `internal.users.sync` (`packages/convex/convex/http.ts` verifies the svix signature, then upserts a `users` row keyed by `clerkId`).
6. **Request middleware** (`start.ts`, see §8) attaches the Clerk session to every Nitro request.
7. **Vite SSR config** explicitly bundles Clerk (`ssr.noExternal: ["@clerk/tanstack-react-start", "@clerk/clerk-react", "@clerk/shared"]`).

Protected routes are achieved by calling `requireAuth` (or its non-throwing sibling `getAuthState`) inside a route's `loader` and either redirecting or branching the UI.

---

## 11. Env vars

`.env.example` (root) — these are the canonical names:

```dotenv
CLERK_PUBLISHABLE_KEY=pk_test_...
VITE_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...
CLERK_WEBHOOK_SECRET=whsec_...

VITE_CONVEX_URL=https://...convex.cloud

STRIPE_SECRET_KEY=sk_test_...
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

VITE_SANITY_PROJECT_ID=...
VITE_SANITY_DATASET=production
SANITY_API_TOKEN=...

VITE_MIXPANEL_TOKEN=...

MAILCHIMP_API_KEY=...
MAILCHIMP_AUDIENCE_ID=...
MAILCHIMP_SERVER_PREFIX=us...

RESEND_API_KEY=re_...
```

**Public vs server-only:**

- `VITE_*` — exposed to the browser (Vite's convention; replaces `NEXT_PUBLIC_*`). Includes `VITE_CLERK_PUBLISHABLE_KEY`, `VITE_CONVEX_URL`, `VITE_STRIPE_PUBLISHABLE_KEY`, `VITE_SANITY_PROJECT_ID`, `VITE_SANITY_DATASET`, `VITE_MIXPANEL_TOKEN`.
- Everything else is server-only. Note that **server-only secrets that the Convex functions need** (`STRIPE_SECRET_KEY`, `RESEND_API_KEY`, `MAILCHIMP_*`, `CLERK_WEBHOOK_SECRET`) are **set inside Convex**, not in the Vite/Vercel env — Convex keeps its own env via `npx convex env set ...`. The web app only needs the `VITE_*` keys at runtime.
- `SANITY_API_TOKEN` is used by `scripts/migrate-content.ts` (one-off script run from `.claude/settings.local.json`'s saved invocation).
- `CLERK_JWT_ISSUER_DOMAIN` is referenced by `packages/convex/convex/auth.config.ts` and must be set as a Convex env var.

`packages/web/.env.local` and `packages/convex/.env.local` are committed (with real test keys — Lee's dev project, not production). The Convex one declares `CONVEX_DEPLOYMENT=dev:uncommon-swan-944`.

---

## 12. Deployment

`vercel.json`:

```json
{
  "buildCommand": "pnpm build",
  "installCommand": "pnpm install",
  "framework": null,
  "outputDirectory": "packages/web/.output",
  "redirects": [
    { "source": "/blog/:year(\\d{4})/:month(\\d{2})/:day(\\d{2})/:slug", "destination": "/blog/:slug", "permanent": true },
    { "source": "/blog/:year(\\d{4})/:month(\\d{2})/:day(\\d{2})/:slug/", "destination": "/blog/:slug", "permanent": true }
  ]
}
```

- `framework: null` — Vercel doesn't auto-detect; the build is `pnpm build` (which runs `vite build` inside `@mealvana/web`), and the output is the **Nitro `.output/` directory** (preset `node-server`, see `packages/web/.output/nitro.json`).
- Convex deploys are **separate** — `pnpm --filter @mealvana/convex deploy` runs `convex deploy` (typically wired into a CI step or done manually). Convex isn't deployed by Vercel.
- Sanity Studio is deployed via `pnpm --filter @mealvana/sanity deploy` → `sanity deploy` (hosts the studio at `<projectId>.sanity.studio`). It's also embeddable but they ship the standalone version.
- Production domain (per `shared/constants.ts`): `https://endurance.mealvana.io`.

There is no `vercel/project.json` linked in the repo (probably linked outside source via the Vercel CLI).

---

## 13. Linting / formatting / git hooks

**Almost nothing.** I found:

- **No `.eslintrc*`, no `eslint.config.*`** in any package or at root.
- **No `.prettierrc*` / `prettier.config.*`**.
- **No `biome.json`**.
- **No `.husky/` directory**, **no `lint-staged` config**.
- **No `lint` or `format` script** in any `package.json`.

The only quality gate is `tsc --noEmit` (the `typecheck` script) and the test suites. The new prototype should add ESLint + Prettier (or Biome) from day one, plus Husky + lint-staged.

---

## 14. Testing

- **Vitest** for unit + component tests in `packages/web/tests/` (`components/`, `integration/`) and `packages/convex/tests/`. Setup file `tests/setup.ts` heavily mocks Convex (`@convex/_generated/api`), Sanity client, Clerk hooks, and `motion/react`.
- **Playwright** for e2e in `packages/web/tests/e2e/` (`blog.spec.ts`, `community.spec.ts`, `homepage.spec.ts`, `pages.spec.ts`). Config in `packages/web/playwright.config.ts` — runs against `http://localhost:3001` with `chromium` and `mobile-chrome` projects, auto-spawns the dev server.
- `convex-test` is the Convex unit-test helper (`^0.0.41`).
- No coverage tooling configured.

---

## 15. Existing AI features

There are **no AI features in the runtime**. The only AI-adjacent items are:

- Sanity's `@sanity/assist` plugin (helps editors generate copy inside the Studio — not customer-facing).
- The `aeo/` directory at the repo root, which contains an "answer-engine optimization" guide and skill, plus drafts. It's documentation tooling, not application code.
- Marketing copy in `shared/constants.ts` claims "AI-Powered Nutrition Plans" — but the relevant features live in the Flutter app, not this site.
- `.claude/mcp.json` registers the Sanity MCP server. `packages/convex/.claude/skills/` has Convex skill definitions for agents (`convex-create-component`, `convex-migration-helper`, etc.). Those are Claude-Code dev-time helpers, not runtime AI.

So: **nothing to reuse for AI generation — we're building greenfield AI.** This is the biggest delta versus the prototype's needs.

---

## 16. Key shared packages (under `packages/`)

### `@mealvana/shared`

Source-only TS package (`"main": "./src/index.ts"`). Three files:

- `src/types.ts` — `UserRole`, `ContactStatus`, `DiscussionCategory`, `OrderStatus`, `NewsletterSource`. Plain string literal unions, no zod.
- `src/constants.ts` — `APP_NAME`, `APP_URL`, `WEB_APP_URL`, `APP_STORE_LINK`, `PLAY_STORE_LINK`, `IOS_APP_ID`, `ANDROID_PACKAGE`, `CONTACT_EMAIL`, `COMPANY_NAME`, `SOCIAL_LINKS`, and a `FEATURES` array used on the homepage.
- `src/index.ts` — barrel `export * from "./types"; export * from "./constants";`.

Imported as `import { APP_NAME, type DiscussionCategory } from "@mealvana/shared";`. The `tsconfig` resolves it via the workspace `references`.

### `@mealvana/convex`

Convex backend (see §6b). Has its own `.env.local` declaring `CONVEX_DEPLOYMENT=dev:uncommon-swan-944`. Tests via `convex-test`. The `_generated/` directory is committed and rewritten on every `convex dev`. There is also a `_generated/ai/guidelines.md` referenced by the package-level `CLAUDE.md` — Convex's own AI skill kit.

### `@mealvana/sanity`

Sanity Studio v5. Schema types in `schemaTypes/` (`blogPost`, `author`, `blogCategory`, `blockContent`, `faq`, `changelog`, `legalDoc`, `teamMember`, `integrationPartner`, `catalogProduct`). Studio config in `sanity.config.ts` registers a long list of plugins: `structureTool`, `presentationTool`, `visionTool`, `codeInput`, `colorInput`, `table`, `media`, `assist`, `unsplashImageAsset`, `iconPicker`, `markdownSchema`, `vercelDeployTool`, `taxonomyManager`. Custom desk structure groups content into Blog / Product / Company sections. `sanity.cli.ts` declares `projectId: "sigrvh1t"`, `dataset: "production"`.

### `@mealvana/web`

The actual app. See §2/§4/§8/§9.

---

## Bootstrap recipe — spinning up `mealplanning_prototype`

> Decision required up front: do we keep this stack as-is, or pivot to Next.js? The brief asked about Next.js + Supabase, neither of which exist here. If the goal is **"reuse what Lee already knows,"** keep TanStack Start + Convex + Clerk. If the goal is **"use the AI ecosystem's most-traveled paths (App Router, Server Components, Vercel AI SDK)"**, pivot to Next.js. Recommendation below assumes **keep the stack**, with explicit pivot notes at the end.

### 1. Init the monorepo

```bash
mkdir -p /Users/leemartin/development/mealplanning_prototype && \
  cd /Users/leemartin/development/mealplanning_prototype && \
  git init && \
  pnpm init
```

Edit root `package.json` to:

```json
{
  "name": "mealplanning-prototype",
  "private": true,
  "scripts": {
    "dev":         "pnpm --filter @mealplanning/web dev",
    "dev:convex":  "pnpm --filter @mealplanning/convex dev",
    "build":       "pnpm --filter @mealplanning/web build",
    "typecheck":   "pnpm -r typecheck",
    "test":        "pnpm -r test",
    "test:e2e":    "pnpm --filter @mealplanning/web test:e2e",
    "lint":        "pnpm -r lint",
    "format":      "prettier --write ."
  },
  "engines": { "node": ">=20", "pnpm": ">=9" },
  "devDependencies": {
    "typescript": "^5.9.3",
    "vitest": "^4.1.3",
    "prettier": "^3.3.0",
    "eslint": "^9.0.0"
  }
}
```

Create `pnpm-workspace.yaml`:

```yaml
packages:
  - "packages/*"

onlyBuiltDependencies:
  - esbuild
  - "@clerk/shared"
```

Copy `turbo.json` verbatim from `me_website_new`.

Add `.nvmrc` (the source repo lacks one but we should have one):

```text
20
```

### 2. Workspace packages

Create the same four packages:

```bash
mkdir -p packages/{web,convex,sanity,shared}
```

For each, copy/adapt:

- **`packages/shared/package.json`** — copy from `me_website_new/packages/shared/package.json`, rename to `@mealplanning/shared`. Replace `src/constants.ts` content with prototype-relevant constants.
- **`packages/web/package.json`** — copy verbatim, rename to `@mealplanning/web`. Add `react-hook-form`, `@hookform/resolvers`, plus the AI SDK packages (next section).
- **`packages/convex/package.json`** — copy verbatim, rename. (Skip the Stripe + svix deps if the prototype doesn't need payments / Clerk webhooks yet — but keep them on hand.)
- **`packages/sanity/package.json`** — only copy if the prototype needs editorial content. For an internal AI prototype, **skip Sanity** entirely; the meal-planner data lives in Convex.

### 3. Drop in the web scaffolding

From `me_website_new/packages/web/`, copy:

- `vite.config.ts`, `vitest.config.ts`, `playwright.config.ts`
- `tsconfig.json` (adjust the `@convex` path alias if you keep the Convex layout)
- `components.json` (shadcn config)
- `src/router.tsx`, `src/start.ts`
- `src/styles/globals.css` — strip the Mealvana Endurance brand tokens, keep the structure (`@import "tailwindcss"`, `@import "tw-animate-css"`, `@import "shadcn/tailwind.css"`, `@theme inline { ... }`). For the prototype, swap in Kyle's web design tokens from `docs/mealplanning_prototype/03_kyle_design_for_web.md`.
- `src/lib/utils.ts` (the `cn()` helper)
- `src/lib/convex.ts` + `convex-server.ts`
- `src/lib/auth.ts` (Clerk server functions)
- `src/lib/analytics.ts` (only if we want Mixpanel; otherwise skip)
- `src/components/viewport-fade.tsx` (handy)
- `src/routes/__root.tsx` — strip the marketing-site header/footer and replace with the prototype shell. Keep the `<ClerkProvider>` + `<ConvexProviderWithClerk>` wrap, the `<Toaster>`, and the `<HeadContent>` / `<Scripts>` skeleton.

Install shadcn primitives day one:

```bash
cd packages/web
pnpm dlx shadcn@latest init   # already done if components.json exists
pnpm dlx shadcn@latest add button card dialog form input label select \
  textarea tabs toast sonner skeleton dropdown-menu sheet avatar badge \
  separator scroll-area
```

(The exact list will depend on the meal-planner UI, but those cover most needs.)

### 4. Convex backend

From `me_website_new/packages/convex/`:

- Copy `convex/auth.config.ts` (Clerk JWT issuer config).
- Copy `convex/schema.ts` as a starting point — strip the `discussions`, `blogComments`, `orders`, `contactSubmissions`, `newsletterSubscribers` tables; **keep `users`** and add the meal-planner tables (`recipes`, `mealPlans`, `pantryItems`, `dietaryProfiles`, etc.).
- Copy `convex/users.ts` and `convex/http.ts` (Clerk webhook → user sync). Drop the Stripe webhook half of `http.ts` unless you need it.
- Run `pnpm --filter @mealplanning/convex dev` to spin up a new Convex deployment and generate `_generated/`.

### 5. Auth wiring (Clerk)

- Create a new Clerk dev project, copy `pk_test_...` and `sk_test_...` into `packages/web/.env.local` and `CLERK_WEBHOOK_SECRET` into Convex env (`npx convex env set CLERK_WEBHOOK_SECRET ...`).
- Set `CLERK_JWT_ISSUER_DOMAIN` in Convex env (this is the Clerk-issued JWT-issuer URL — visible in Clerk dashboard → JWT templates → "Convex").
- Configure the Clerk webhook to POST to `https://<your-convex>.convex.site/clerk-webhook`.

### 6. Environment variables

Create `.env.example` adapted from `me_website_new/.env.example`:

```dotenv
# Clerk
VITE_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...
CLERK_WEBHOOK_SECRET=whsec_...

# Convex
VITE_CONVEX_URL=https://...convex.cloud

# AI (NEW — see below)
AI_GATEWAY_API_KEY=...               # if using Vercel AI Gateway
ANTHROPIC_API_KEY=...                # fallback / direct
OPENAI_API_KEY=...                   # only if needed for embeddings
```

### 7. Vercel deployment

Copy `vercel.json` verbatim, adjust redirects (likely none needed). The prototype's framework will be `null`, build `pnpm build`, output `packages/web/.output`.

### 8. Tooling we should ADD that `me_website_new` lacks

- **ESLint + Prettier (or Biome).** The source repo has neither. Add `eslint.config.js` (flat config) with `@typescript-eslint`, `eslint-plugin-react-hooks`, `eslint-plugin-jsx-a11y` and a `.prettierrc` (or run `biome init`).
- **Husky + lint-staged.** `pnpm dlx husky-init && pnpm install -D lint-staged` and wire the pre-commit hook to run typecheck + lint on staged files.
- **`react-hook-form` + `zod` + `@hookform/resolvers`.** The source uses raw `useState` for forms; that won't scale for a meal-planner with complex inputs (servings, swap rules, macro overrides).
- **`.nvmrc`.** Pin Node 20 explicitly.

### 9. AI stack to add (the whole point of the prototype)

The source ships **zero** AI code. Add:

- **Vercel AI SDK 5+:** `pnpm add ai @ai-sdk/react @ai-sdk/anthropic @ai-sdk/openai`.
- **Vercel AI Gateway** (recommended over per-provider keys for prototype velocity): set `AI_GATEWAY_API_KEY`, then call models as `"anthropic/claude-opus-4-7"` etc. through the gateway. This gives us provider failover and unified billing.
- **Streaming endpoints** as TanStack Start server functions (`createServerFn` + `streamText` + `toUIMessageStreamResponse`) or, alternatively, as Convex HTTP actions (since Convex actions can run `"use node"`).
- **Generative UI / structured output:** use `generateObject` with zod schemas matching the Convex `recipes` / `mealPlans` table types so generated meals can be persisted directly.
- **Tool calling:** define tools for `searchPantry`, `applyDietaryFilter`, `swapIngredient`, etc. backed by Convex queries/mutations.
- **Chat UI:** use `@ai-sdk/react`'s `useChat` (no built-in shadcn chat in this stack — we build it on top of shadcn primitives).
- **Persistence:** store chat threads + messages in Convex (`chatThreads`, `chatMessages` tables). Convex's reactive queries make multi-tab / multi-device chat sync trivial.

Things in the existing stack that are **less ideal for an AI-heavy app**:

- **TanStack Start server functions are still maturing** vs. Next.js Server Components / Route Handlers; the AI SDK's Next.js examples assume `app/api/chat/route.ts`. They work in Start, but you'll be translating examples. If AI-SDK ergonomics matter more than stack continuity, this is the strongest reason to consider a Next.js pivot.
- **No edge runtime** is configured — Nitro currently uses `node-server` preset. AI streaming benefits from running closer to the user; consider switching the Nitro preset to `vercel`/`vercel-edge` (or running the AI handlers as Convex HTTP actions, which run in V8 isolates close to the data).
- **No file-storage primitive** is set up. The meal planner may need image uploads (recipe photos, pantry scans). Convex has built-in file storage (`ctx.storage.generateUploadUrl()`), so add that. Avoid Vercel Blob unless we need the public CDN semantics.
- **No vector-search infra.** If the prototype ranks recipes/foods by semantic similarity, add either Convex's vector indexes (`defineTable(...).vectorIndex("by_embedding", { vectorField: "embedding", dimensions: 1536 })`) or pull in `@upstash/vector` / `pgvector`. Convex vector indexes are the lowest-friction option given the rest of the stack.

### 10. Sanity (optional)

Skip Sanity unless the prototype needs editor-managed content (e.g. curated recipe collections written by a nutritionist). For a pure AI-generation prototype, all data should live in Convex.

If we *do* keep Sanity, copy `packages/sanity/sanity.config.ts` and trim the plugin list (drop `vercelDeployTool`, `taxonomyManager`, `markdownSchema`, `unsplashImageAsset`, `assist`, `iconPicker`, `presentationTool`, `media`, `colorInput`, `codeInput`, `table` until needed).

### 11. First commit plan

1. Repo skeleton (`pnpm-workspace.yaml`, `turbo.json`, `tsconfig.json`, `.nvmrc`, `vercel.json`, `.gitignore` cribbed from `me_website_new/.gitignore`).
2. `@mealplanning/shared` minimal export.
3. `@mealplanning/web` boots a TanStack Start app with Clerk + Convex providers and a working `/sign-in` route, no other content.
4. `@mealplanning/convex` deployed with `users` table + Clerk webhook.
5. ESLint + Prettier + Husky.
6. `/chat` route powered by `useChat` + a `/api/chat` server function streaming from Anthropic via AI Gateway.
7. Start adding meal-planner-specific routes/components.

---

## TL;DR for the prototype

- **Same as `me_website_new`:** pnpm + Turbo monorepo, TanStack Start + Vite + Nitro, React 19, TypeScript 5.9, Tailwind v4 (CSS-first, no config file), shadcn (registry + on-demand install), Convex backend, Clerk auth, react-query for SSR hydration, sonner toasts, lucide icons, motion animations, Vitest + Playwright.
- **Skip from `me_website_new`:** Sanity (unless editorial content is needed), Stripe, Mailchimp/Resend, the marketing-only `viewport-fade` patterns, Mixpanel.
- **Add for the prototype:** Vercel AI SDK + AI Gateway, react-hook-form + zod resolver, ESLint + Prettier (or Biome), Husky + lint-staged, `.nvmrc`, Convex vector indexes for recipe similarity, Convex file storage for images, possibly switch the Nitro preset to `vercel`/`vercel-edge` for streaming latency.
- **Confirm before scaffolding:** is the goal really "same stack as `me_website_new`" (TanStack Start / Convex / Clerk), or did the brief's "Next.js + Supabase" wording reflect an actual desire to use that other stack? The two are mutually exclusive.
