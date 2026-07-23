-- ============================================================================
-- MEAL LOGGING + JADE — Supabase schema (2026-06-11)
-- Apply to BOTH dev and prod via DataGrip (idempotent; safe to re-run).
--
-- Feature: meal logging on the Daily Macros tab (photo / manual / describe /
-- saved / recipe) + the Jade AI coach (persisted chat, token observability).
-- Decisions doc: memory project_meal_logging_jade; design follows the
-- mealplanning_prototype web build adapted to mobile.
-- ============================================================================


-- ── 1. meal_logs — one row per logged meal (offline-first, Drift mirror) ────
-- Slots are breakfast/lunch/dinner/snack; multiple snack rows per day are
-- expected (no uniqueness on (user, date, slot)). Soft-deleted via is_deleted
-- so deletes propagate through upsert-only sync (user_foods convention).
-- `items` is an array of food components, the same conceptual shape as the
-- prototype's FoodComponent: { name, portion, calories, carb_g, protein_g,
-- fat_g, sodium_mg } — stored opaque; totals are denormalized on the row.

CREATE TABLE IF NOT EXISTS public.meal_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  log_date      DATE NOT NULL,            -- local calendar day the meal counts toward
  slot          TEXT NOT NULL
                  CHECK (slot IN ('breakfast', 'lunch', 'dinner', 'snack')),

  name          TEXT NOT NULL,            -- display title, e.g. "Oatmeal + banana"

  -- How the entry was created.
  source        TEXT NOT NULL
                  CHECK (source IN
                    ('photo', 'manual', 'describe', 'saved', 'recipe',
                     'jade_baseline')),   -- jade_baseline = created by Jade from chat

  -- Component breakdown (AI analysis or recipe ingredients); opaque array.
  items         JSONB NOT NULL DEFAULT '[]'::jsonb,

  -- Denormalized totals (what the Daily Macros consumed layer reads).
  calories      INT,
  carbs_g       NUMERIC,
  protein_g     NUMERIC,
  fat_g         NUMERIC,
  sodium_mg     NUMERIC,

  -- Photo logging: object path inside the meal-photos bucket (not a URL).
  photo_path    TEXT,

  -- Recipe logging provenance (no FK — recipe rows may be retired later).
  recipe_id     UUID,

  -- Saved-meal provenance (no FK — saved meal may be deleted independently).
  saved_meal_id UUID,

  notes         TEXT,

  -- When the meal was eaten (user-adjustable), distinct from created_at.
  eaten_at      TIMESTAMPTZ,

  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted    BOOLEAN NOT NULL DEFAULT false
);

-- Day view: the Daily Macros tab reads one user-day at a time.
CREATE INDEX IF NOT EXISTS meal_logs_user_date
  ON public.meal_logs (user_id, log_date)
  WHERE NOT is_deleted;

ALTER TABLE public.meal_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own meal logs" ON public.meal_logs;
CREATE POLICY "Users manage own meal logs"
  ON public.meal_logs FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.meal_logs_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS meal_logs_updated_at_trigger ON public.meal_logs;
CREATE TRIGGER meal_logs_updated_at_trigger
  BEFORE UPDATE ON public.meal_logs
  FOR EACH ROW EXECUTE FUNCTION public.meal_logs_set_updated_at();


-- ── 2. saved_meals — explicit user favorites ("My Meals") ───────────────────
-- Recents come from meal_logs directly; this table only holds meals the user
-- starred with a custom name. Offline-first Drift mirror; soft delete.

CREATE TABLE IF NOT EXISTS public.saved_meals (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  name          TEXT NOT NULL,
  items         JSONB NOT NULL DEFAULT '[]'::jsonb,

  calories      INT,
  carbs_g       NUMERIC,
  protein_g     NUMERIC,
  fat_g         NUMERIC,
  sodium_mg     NUMERIC,

  photo_path    TEXT,

  -- Bumped each time the saved meal is re-logged (sorts the picker).
  last_used_at  TIMESTAMPTZ,

  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted    BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS saved_meals_user
  ON public.saved_meals (user_id, last_used_at DESC)
  WHERE NOT is_deleted;

ALTER TABLE public.saved_meals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own saved meals" ON public.saved_meals;
CREATE POLICY "Users manage own saved meals"
  ON public.saved_meals FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.saved_meals_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS saved_meals_updated_at_trigger ON public.saved_meals;
CREATE TRIGGER saved_meals_updated_at_trigger
  BEFORE UPDATE ON public.saved_meals
  FOR EACH ROW EXECUTE FUNCTION public.saved_meals_set_updated_at();


-- ── 3. recipes — curated endurance recipe catalog (read-only content) ───────
-- Replaces the in-app mock RecipeRepository. Seeded/managed by us (service
-- role); clients only read. Column names mirror the existing Recipe domain
-- model. `type` keeps the app's existing enum wire values.

CREATE TABLE IF NOT EXISTS public.recipes (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name               TEXT NOT NULL,
  description        TEXT NOT NULL DEFAULT '',
  ingredients        JSONB NOT NULL DEFAULT '[]'::jsonb,  -- array of strings
  instructions       JSONB NOT NULL DEFAULT '[]'::jsonb,  -- array of strings
  prep_time_minutes  INT NOT NULL DEFAULT 0,
  servings           INT NOT NULL DEFAULT 1,
  type               TEXT NOT NULL DEFAULT 'mains'
                       CHECK (type IN ('breakfast', 'mains', 'snacks', 'workout_fuel', 'recovery')),

  -- Per-serving nutrition.
  calories           NUMERIC NOT NULL DEFAULT 0,
  carbs_g            NUMERIC NOT NULL DEFAULT 0,
  protein_g          NUMERIC NOT NULL DEFAULT 0,
  fat_g              NUMERIC NOT NULL DEFAULT 0,
  fiber_g            NUMERIC NOT NULL DEFAULT 0,
  sugar_g            NUMERIC NOT NULL DEFAULT 0,
  sodium_mg          NUMERIC NOT NULL DEFAULT 0,

  image_url          TEXT,
  tags               JSONB,                               -- array of strings

  is_active          BOOLEAN NOT NULL DEFAULT true,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users read recipes" ON public.recipes;
CREATE POLICY "Authenticated users read recipes"
  ON public.recipes FOR SELECT
  TO authenticated
  USING (is_active);
-- No insert/update/delete policies: content is managed via service role.


-- ── 4. jade_conversations + jade_messages — persisted chat ──────────────────
-- Online-only (no Drift mirror); the jade-chat edge function writes messages
-- with the service role after verifying the caller's JWT, and the app reads
-- history directly via PostgREST under RLS.

CREATE TABLE IF NOT EXISTS public.jade_conversations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title       TEXT,                       -- first-user-message snippet
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted  BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS jade_conversations_user
  ON public.jade_conversations (user_id, updated_at DESC)
  WHERE NOT is_deleted;

ALTER TABLE public.jade_conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own jade conversations" ON public.jade_conversations;
CREATE POLICY "Users manage own jade conversations"
  ON public.jade_conversations FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TABLE IF NOT EXISTS public.jade_messages (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id  UUID NOT NULL
                     REFERENCES public.jade_conversations(id) ON DELETE CASCADE,
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  role             TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content          TEXT NOT NULL,

  -- Optional structured payload (tool results Jade surfaced, baseline meals
  -- she created, etc.) for richer rendering later; opaque for MVP.
  metadata         JSONB,

  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS jade_messages_conversation
  ON public.jade_messages (conversation_id, created_at);

ALTER TABLE public.jade_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own jade messages" ON public.jade_messages;
CREATE POLICY "Users manage own jade messages"
  ON public.jade_messages FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- ── 5. jade_calls — AI observability (every model invocation) ───────────────
-- Written by edge functions with the service role; users can read their own
-- rows but never write.

CREATE TABLE IF NOT EXISTS public.jade_calls (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  conversation_id  UUID,                  -- null for photo/describe analysis calls
  function_name    TEXT NOT NULL,         -- 'jade-chat' | 'analyze-meal-photo' | 'describe-meal'
  model            TEXT NOT NULL,
  input_tokens     INT,
  output_tokens    INT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS jade_calls_user
  ON public.jade_calls (user_id, created_at DESC);

ALTER TABLE public.jade_calls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own jade calls" ON public.jade_calls;
CREATE POLICY "Users read own jade calls"
  ON public.jade_calls FOR SELECT
  USING (user_id = auth.uid());


-- ── 6. meal-photos storage bucket ────────────────────────────────────────────
-- Private bucket; objects live under {user_id}/{uuid}.jpg. Users read/write
-- only their own folder; the analyze-meal-photo edge function reads via
-- service role.

INSERT INTO storage.buckets (id, name, public)
VALUES ('meal-photos', 'meal-photos', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users upload own meal photos" ON storage.objects;
CREATE POLICY "Users upload own meal photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'meal-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users read own meal photos" ON storage.objects;
CREATE POLICY "Users read own meal photos"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'meal-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users delete own meal photos" ON storage.objects;
CREATE POLICY "Users delete own meal photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'meal-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );


-- ── 7. recipe-images storage bucket ─────────────────────────────────────────
-- Public bucket; objects are bare filenames (e.g. 'overnight-oats.jpg').
-- Uploaded by us (service role) via the Supabase dashboard or CLI.
-- Clients resolve filenames to public URLs via the Storage SDK — no auth
-- required for reads.  No authenticated-write policy: uploads are service-role
-- only.

INSERT INTO storage.buckets (id, name, public)
VALUES ('recipe-images', 'recipe-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public read recipe images" ON storage.objects;
CREATE POLICY "Public read recipe images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'recipe-images');


-- ============================================================================
-- END — after applying, bump nothing in app_config yet; the Drift schema bump
-- to v11 ships with the app build (delete-and-resync handles upgrades).
-- ============================================================================
