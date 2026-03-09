-- Migration: Add API statistics and metadata columns to teasers
-- These fields come from Geozo /v1/advertiser/ads/all → statistic object

-- Lifetime stats from API (cumulative, not daily)
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_shows INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_clicks INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_money DECIMAL(12,4) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_cpc DECIMAL(8,4) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_ctr DECIMAL(8,4) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_roi DECIMAL(10,2) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_leads INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_leads_confirmed_money DECIMAL(12,4) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_cr DECIMAL(8,4) DEFAULT 0;

-- Geo/bid info extracted from bids structure
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS country_code VARCHAR(5);
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS geo_id INTEGER;

-- Metadata from API
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS geozo_created_at TIMESTAMP;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS ad_rating VARCHAR(10);

-- Index for country_code filtering
CREATE INDEX IF NOT EXISTS idx_teasers_country_code ON teasers(country_code);
