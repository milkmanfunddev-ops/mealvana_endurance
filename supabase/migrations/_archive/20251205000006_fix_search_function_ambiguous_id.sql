-- Migration: Fix ambiguous column reference in search_public_events_hybrid
-- Date: 2025-12-05
-- Description: Fixes "column reference id is ambiguous" error by fully qualifying column names

-- Drop and recreate the function with proper column qualification
DROP FUNCTION IF EXISTS search_public_events_hybrid(TEXT, INT, TEXT, TEXT, FLOAT);

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
      -- Exclude events already found by FTS (FIXED: fully qualified column name)
      AND NOT EXISTS (
        SELECT 1 FROM fts_matches fm WHERE fm.id = e.id
      )
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

-- Update comment
COMMENT ON FUNCTION search_public_events_hybrid IS
'Hybrid search function combining full-text search (exact matches) with fuzzy matching (typo tolerance).
Returns results ranked by relevance score with match_type indicator (exact/fuzzy).
Fixed: Column reference ambiguity in NOT IN clause.
Parameters:
- search_term: Query string (e.g., "Boston Marathon")
- limit_count: Max results to return (default: 20)
- event_type_filter: Optional activity type filter (e.g., "running")
- state_filter: Optional state filter (e.g., "MA")
- min_similarity: Minimum fuzzy match threshold 0-1 (default: 0.2)';

-- Ensure permissions are set
GRANT EXECUTE ON FUNCTION search_public_events_hybrid TO authenticated;
GRANT EXECUTE ON FUNCTION search_public_events_hybrid TO anon;
GRANT EXECUTE ON FUNCTION search_public_events_hybrid TO service_role;
