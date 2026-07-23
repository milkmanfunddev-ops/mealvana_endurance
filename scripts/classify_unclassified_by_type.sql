-- Classify-new fallback for the catalog refresh routine (B2).
--
-- Assigns product_type_id + categories + is_electrolyte/is_liquid to any
-- catalog_products row that is still UNCLASSIFIED (classification_source IS NULL),
-- based on its Shopify product_type. The mapping mirrors the dominant convention
-- already present in the classified catalog. Existing classifications (e.g.
-- 'claude') are never touched. Idempotent — safe to re-run after every import.
--
-- Run AFTER update_catalog.js. Anything whose Shopify type isn't mapped here is
-- left unclassified for a human/Claude pass.

UPDATE public.catalog_products p SET
  product_type_id = t.ptype,
  categories = t.cats,
  is_electrolyte = t.elec,
  is_liquid = t.liq,
  classification_source = 'auto',
  classification_confidence = 0.70,
  classified_at = now()
FROM (
  SELECT id,
    CASE shopify_product_type
      WHEN 'Bars'                   THEN 'bar'
      WHEN 'Chews'                  THEN 'chew'
      WHEN 'Gels'                   THEN 'gel'
      WHEN 'Waffles'                THEN 'waffle'
      WHEN 'Protein'                THEN 'recovery_shake'
      WHEN 'Snacks'                 THEN 'real_food'
      WHEN 'Breakfast'              THEN 'real_food'
      WHEN 'Pack'                   THEN 'gel'
      WHEN 'Supplements'            THEN 'supplement'
      WHEN 'Vitamins & Supplements' THEN 'supplement'
      WHEN 'Hydration' THEN
        CASE WHEN title ~* 'electrolyte' AND title !~* 'carb'
             THEN 'electrolyte_only' ELSE 'drink_mix' END
    END AS ptype,
    CASE shopify_product_type
      WHEN 'Bars'                   THEN ARRAY['before_run','during_run']
      WHEN 'Chews'                  THEN ARRAY['during_run']
      WHEN 'Gels'                   THEN ARRAY['during_run']
      WHEN 'Waffles'                THEN ARRAY['before_run','during_run']
      WHEN 'Protein'                THEN ARRAY['after_run']
      WHEN 'Snacks'                 THEN ARRAY['before_run','after_run']
      WHEN 'Breakfast'              THEN ARRAY['before_run','after_run']
      WHEN 'Pack'                   THEN ARRAY['during_run']
      WHEN 'Supplements'            THEN ARRAY['before_run','during_run','after_run']
      WHEN 'Vitamins & Supplements' THEN ARRAY['before_run','during_run','after_run']
      WHEN 'Hydration'              THEN ARRAY['during_run']
    END AS cats,
    (shopify_product_type = 'Hydration' AND title ~* 'electrolyte' AND title !~* 'carb')
      OR (shopify_product_type = 'Chews' AND title ~* 'electrolyte') AS elec,
    (shopify_product_type IN ('Hydration','Protein')) AS liq
  FROM public.catalog_products
  WHERE classification_source IS NULL
) t
WHERE p.id = t.id AND t.ptype IS NOT NULL;
