-- Widen formula_pins.template_kind to allow 'personal_formula'.
-- Idempotent: detect & drop existing CHECK on template_kind, then re-add.
DO $$
DECLARE
  constraint_name TEXT;
BEGIN
  SELECT con.conname INTO constraint_name
  FROM pg_constraint con
  JOIN pg_class rel ON rel.oid = con.conrelid
  JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
  WHERE nsp.nspname = 'public'
    AND rel.relname = 'formula_pins'
    AND con.contype = 'c'
    AND pg_get_constraintdef(con.oid) ILIKE '%template_kind%';

  IF constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.formula_pins DROP CONSTRAINT %I', constraint_name);
  END IF;
END $$;

ALTER TABLE public.formula_pins
  ADD CONSTRAINT formula_pins_template_kind_check
    CHECK (template_kind IN
      ('pre_system', 'during_system', 'post_system', 'personal_formula'));

COMMENT ON COLUMN public.formula_pins.template_kind IS
  'Polymorphic ref into pre_workout_templates, during_workout_templates, '
  'post_workout_templates, or personal_formulas. Intentionally text, not FK. '
  'Widened to ''personal_formula'' when personal formulas became pinnable.';
