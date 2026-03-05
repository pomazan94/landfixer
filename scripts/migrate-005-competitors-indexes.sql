-- Migration 005: Ensure competitors has all columns and unique indexes
-- Safe to run multiple times (IF NOT EXISTS / IF NOT EXISTS)

ALTER TABLE competitors ADD COLUMN IF NOT EXISTS media_id INTEGER;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS block_id INTEGER;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS landing_domain TEXT;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS geozo_ad_id INTEGER;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS geozo_adgroup_id INTEGER;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS geozo_site_id INTEGER;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS country_code VARCHAR(5);
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS cost DECIMAL(10, 4);

CREATE UNIQUE INDEX IF NOT EXISTS idx_competitors_site_title
  ON competitors (site_url, title);

CREATE UNIQUE INDEX IF NOT EXISTS idx_competitors_media_id
  ON competitors (media_id)
  WHERE media_id IS NOT NULL;
