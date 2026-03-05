-- Migration 001: Add unique constraint to geo_stats for UPSERT support
-- Run this on existing database before deploying updated 04-geo-bidder workflow

-- First remove any duplicates (keep latest)
DELETE FROM geo_stats a
USING geo_stats b
WHERE a.id < b.id
  AND a.ad_id = b.ad_id
  AND a.country_code = b.country_code
  AND a.date = b.date;

-- Add unique constraint
ALTER TABLE geo_stats
  ADD CONSTRAINT geo_stats_ad_country_date_unique
  UNIQUE (ad_id, country_code, date);
