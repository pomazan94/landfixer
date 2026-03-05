-- Migration 002: Enrich competitors table for spy module
-- Adds block_id, landing_domain, tracking params

-- Add new columns for Geozo tracking params extracted from landing URLs
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS block_id INTEGER;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS landing_domain TEXT;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS geozo_ad_id INTEGER;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS geozo_adgroup_id INTEGER;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS geozo_site_id INTEGER;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS country_code VARCHAR(5);

-- Single unique constraint: same title on same site = same competitor teaser
CREATE UNIQUE INDEX IF NOT EXISTS idx_competitors_site_title
  ON competitors (site_url, title)
  WHERE site_url IS NOT NULL AND title IS NOT NULL;

-- Index for quick lookups by block_id
CREATE INDEX IF NOT EXISTS idx_competitors_block_id
  ON competitors (block_id)
  WHERE block_id IS NOT NULL;

-- Index for quick lookups by destination domain
CREATE INDEX IF NOT EXISTS idx_competitors_landing_domain
  ON competitors (landing_domain)
  WHERE landing_domain IS NOT NULL;

-- Index for destination_url lookups
CREATE INDEX IF NOT EXISTS idx_competitors_destination
  ON competitors (destination_url)
  WHERE destination_url IS NOT NULL;
