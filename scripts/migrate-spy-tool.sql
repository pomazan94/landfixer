-- Migration: Spy Tool enhancements for Position Scanner workflow
-- Run after init-db.sql

-- scan_targets: geo-aware scanning + caching
ALTER TABLE scan_targets ADD COLUMN IF NOT EXISTS timezone INT DEFAULT 3;
ALTER TABLE scan_targets ADD COLUMN IF NOT EXISTS accept_language TEXT;
ALTER TABLE scan_targets ADD COLUMN IF NOT EXISTS render_domain TEXT;
ALTER TABLE scan_targets ADD COLUMN IF NOT EXISTS block_uuids JSONB;
ALTER TABLE scan_targets ADD COLUMN IF NOT EXISTS extra_params JSONB;
ALTER TABLE scan_targets ADD COLUMN IF NOT EXISTS last_scan_at TIMESTAMPTZ;
ALTER TABLE scan_targets ADD COLUMN IF NOT EXISTS last_error TEXT;

-- competitors: extended ad data
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS render_domain TEXT;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS short_description TEXT;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS full_description TEXT;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS button_text TEXT;
