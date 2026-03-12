-- Migration: Position Scanner v2 — metrics, history, re-checks
-- Run this BEFORE deploying the updated workflow

-- 1. Fix unique index on media_id: allow same media_id on different site_urls
DROP INDEX IF EXISTS idx_competitors_media_id;
CREATE UNIQUE INDEX IF NOT EXISTS idx_competitors_media_site ON competitors(media_id, site_url) WHERE media_id IS NOT NULL;

-- 2. New metric columns on competitors
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS show_rate DECIMAL(5,4) DEFAULT 0;
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS avg_position DECIMAL(5,2);
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS position_stability DECIMAL(5,4);
ALTER TABLE competitors ADD COLUMN IF NOT EXISTS last_rechecked_at TIMESTAMPTZ;

-- 3. Competitor history table
CREATE TABLE IF NOT EXISTS competitor_history (
    id SERIAL PRIMARY KEY,
    competitor_id INTEGER REFERENCES competitors(id),
    media_id INTEGER,
    site_url TEXT,
    position INTEGER,
    cost DECIMAL(10,4),
    show_rate DECIMAL(5,4),
    scanned_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_competitor_history_competitor ON competitor_history(competitor_id);
CREATE INDEX IF NOT EXISTS idx_competitor_history_time ON competitor_history(scanned_at);
CREATE INDEX IF NOT EXISTS idx_competitor_history_media_site ON competitor_history(media_id, site_url);
