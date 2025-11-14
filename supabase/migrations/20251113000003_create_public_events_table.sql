-- Create public_events table for event autocomplete and population
-- This table stores publicly available race events (marathons, triathlons, etc.)
-- Used for autocomplete when users create events

CREATE TABLE IF NOT EXISTS public_events (
  id BIGSERIAL PRIMARY KEY,

  -- Event identification
  event_name TEXT NOT NULL,
  event_type activity_type_enum NOT NULL,
  event_subtype event_subtype_enum,

  -- Location details
  location TEXT, -- Full address or venue name
  city TEXT,
  state TEXT, -- For filtering like "alabama", "california"
  country TEXT DEFAULT 'USA',

  -- Event timing
  event_date DATE,
  start_time TIME,

  -- Registration and details
  registration_url TEXT,
  website_url TEXT,
  description TEXT,
  organizer_name TEXT,

  -- Data quality and lifecycle
  is_active BOOLEAN DEFAULT true,
  source TEXT, -- Where we got this data (runsignup, active.com, manual, etc.)
  external_id TEXT, -- ID from the source system

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Full-text search optimization
-- Generates search vector from event name, location, city, and state
ALTER TABLE public_events
  ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english',
      COALESCE(event_name, '') || ' ' ||
      COALESCE(location, '') || ' ' ||
      COALESCE(city, '') || ' ' ||
      COALESCE(state, '')
    )
  ) STORED;

-- Indexes for fast searching
CREATE INDEX idx_public_events_search ON public_events USING gin(search_vector);
CREATE INDEX idx_public_events_date ON public_events(event_date) WHERE event_date >= CURRENT_DATE;
CREATE INDEX idx_public_events_type ON public_events(event_type, event_subtype);
CREATE INDEX idx_public_events_state ON public_events(state);
CREATE INDEX idx_public_events_active ON public_events(is_active) WHERE is_active = true;

-- Index for deduplication
CREATE UNIQUE INDEX idx_public_events_unique_external
  ON public_events(source, external_id)
  WHERE external_id IS NOT NULL;

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_public_events_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_public_events_timestamp
  BEFORE UPDATE ON public_events
  FOR EACH ROW
  EXECUTE FUNCTION update_public_events_updated_at();

-- RLS Policies (public read, admin write)
ALTER TABLE public_events ENABLE ROW LEVEL SECURITY;

-- Anyone can read active events
CREATE POLICY "Public events are viewable by everyone"
  ON public_events
  FOR SELECT
  USING (is_active = true);

-- Only service role can insert/update/delete
CREATE POLICY "Only service role can modify public events"
  ON public_events
  FOR ALL
  USING (auth.role() = 'service_role');

-- Add comment for documentation
COMMENT ON TABLE public_events IS 'Publicly available race events used for autocomplete when users create events. Data sourced from RunSignUp, Active.com, and manual entry.';
