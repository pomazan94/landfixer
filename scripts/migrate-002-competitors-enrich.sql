-- Migration 002: Enrich competitors table for spy module
-- Adds unique constraint to prevent duplicates and landing_url tracking

-- Unique constraint: same title on same site = same competitor teaser
CREATE UNIQUE INDEX IF NOT EXISTS idx_competitors_site_title
  ON competitors (site_url, title)
  WHERE site_url IS NOT NULL AND title IS NOT NULL;

-- Index for quick lookups by destination
CREATE INDEX IF NOT EXISTS idx_competitors_destination
  ON competitors (destination_url)
  WHERE destination_url IS NOT NULL;

-- Update ON CONFLICT behavior: update last_seen and times_seen
-- (This is used by the Save Competitors node in workflow 15)
