-- Migration 003: Add media_id as primary identifier for competitors
-- media_id comes from Geozo render API (click URL param media=XXXXXX)

-- Add media_id column
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS media_id INTEGER;

-- Add cost column for tracking
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS cost DECIMAL(10, 4);

-- Unique index on media_id — this is the main dedup key now
CREATE UNIQUE INDEX IF NOT EXISTS idx_competitors_media_id
  ON competitors (media_id)
  WHERE media_id IS NOT NULL;

-- Keep site_url+title as fallback for teasers without media_id
-- (idx_competitors_site_title already exists from migration 002)
