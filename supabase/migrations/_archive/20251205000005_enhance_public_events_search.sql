-- Migration: Enhance public_events search with fuzzy matching and relevance scoring
-- Date: 2025-12-05
-- Description: Adds pg_trgm extension for typo tolerance and creates hybrid search function

-- 1. Enable pg_trgm extension for fuzzy/similarity matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Create trigram indexes for fuzzy matching on key text fields
-- These indexes enable fast similarity searches with typo tolerance
CREATE INDEX IF NOT EXISTS idx_public_events_name_trgm
  ON public.public_events USING gin(event_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_public_events_city_trgm
  ON public.public_events USING gin(city gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_public_events_location_trgm
  ON public.public_events USING gin(location gin_trgm_ops);

-- 3. Create hybrid search function combining full-text search and fuzzy matching
-- This provides both precision (FTS) and recall (fuzzy) with relevance ranking
CREATE OR REPLACE FUNCTION search_public_events_hybrid(
  search_term TEXT,
  limit_count INT DEFAULT 20,
  event_type_filter TEXT DEFAULT NULL,
  state_filter TEXT DEFAULT NULL,
  min_similarity FLOAT DEFAULT 0.2
)
RETURNS TABLE (
  id BIGINT,
  event_name TEXT,
  event_type TEXT,
  event_subtype TEXT,
  location TEXT,
  city TEXT,
  state TEXT,
  country TEXT,
  event_date DATE,
  start_time TIME,
  registration_url TEXT,
  website_url TEXT,
  description TEXT,
  organizer_name TEXT,
  match_type TEXT,
  relevance_score REAL
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  fts_query TEXT;
  today_date DATE := CURRENT_DATE;
BEGIN
  -- Convert search term to tsquery (handle special characters)
  fts_query := websearch_to_tsquery('english', search_term)::text;

  -- Return combined results from both full-text and fuzzy search
  RETURN QUERY
  WITH fts_matches AS (
    -- Full-text search using the existing search_vector
    SELECT
      e.id,
      e.event_name,
      e.event_type::TEXT,
      e.event_subtype::TEXT,
      e.location,
      e.city,
      e.state,
      e.country,
      e.event_date,
      e.start_time,
      e.registration_url,
      e.website_url,
      e.description,
      e.organizer_name,
      'exact'::TEXT AS match_type,
      -- Weighted ranking: event_name weighted highest
      ts_rank_cd(
        '{0.1, 0.2, 0.4, 1.0}',
        e.search_vector,
        websearch_to_tsquery('english', search_term)
      )::REAL AS relevance_score
    FROM public.public_events e
    WHERE
      e.is_active = true
      AND e.event_date >= today_date
      AND e.search_vector @@ websearch_to_tsquery('english', search_term)
      -- Apply optional filters
      AND (event_type_filter IS NULL OR e.event_type::TEXT = event_type_filter)
      AND (state_filter IS NULL OR e.state ILIKE state_filter)
  ),
  fuzzy_matches AS (
    -- Fuzzy matching using pg_trgm similarity for typo tolerance
    SELECT
      e.id,
      e.event_name,
      e.event_type::TEXT,
      e.event_subtype::TEXT,
      e.location,
      e.city,
      e.state,
      e.country,
      e.event_date,
      e.start_time,
      e.registration_url,
      e.website_url,
      e.description,
      e.organizer_name,
      'fuzzy'::TEXT AS match_type,
      -- Combined similarity score (event_name weighted 60%, city 40%)
      (
        0.6 * similarity(e.event_name, search_term) +
        0.4 * COALESCE(similarity(e.city, search_term), 0)
      )::REAL AS relevance_score
    FROM public.public_events e
    WHERE
      e.is_active = true
      AND e.event_date >= today_date
      -- Use similarity operator (%) for fuzzy matching
      AND (
        e.event_name % search_term
        OR e.city % search_term
        OR COALESCE(e.location, '') % search_term
      )
      -- Exclude events already found by FTS
      AND e.id NOT IN (SELECT id FROM fts_matches)
      -- Apply optional filters
      AND (event_type_filter IS NULL OR e.event_type::TEXT = event_type_filter)
      AND (state_filter IS NULL OR e.state ILIKE state_filter)
      -- Only include results above similarity threshold
      AND (
        similarity(e.event_name, search_term) >= min_similarity
        OR similarity(COALESCE(e.city, ''), search_term) >= min_similarity
        OR similarity(COALESCE(e.location, ''), search_term) >= min_similarity
      )
  ),
  combined_results AS (
    -- Combine both result sets
    SELECT * FROM fts_matches
    UNION ALL
    SELECT * FROM fuzzy_matches
  )
  -- Return sorted by relevance score (highest first), then by event date (nearest first)
  SELECT * FROM combined_results
  ORDER BY relevance_score DESC, event_date ASC
  LIMIT limit_count;
END;
$$;

-- 4. Add helpful comment explaining the function
COMMENT ON FUNCTION search_public_events_hybrid IS
'Hybrid search function combining full-text search (exact matches) with fuzzy matching (typo tolerance).
Returns results ranked by relevance score with match_type indicator (exact/fuzzy).
Parameters:
- search_term: Query string (e.g., "Boston Marathon")
- limit_count: Max results to return (default: 20)
- event_type_filter: Optional activity type filter (e.g., "running")
- state_filter: Optional state filter (e.g., "MA")
- min_similarity: Minimum fuzzy match threshold 0-1 (default: 0.2)';

-- 5. Grant execute permission to authenticated and anon roles
GRANT EXECUTE ON FUNCTION search_public_events_hybrid TO authenticated;
GRANT EXECUTE ON FUNCTION search_public_events_hybrid TO anon;
GRANT EXECUTE ON FUNCTION search_public_events_hybrid TO service_role;
