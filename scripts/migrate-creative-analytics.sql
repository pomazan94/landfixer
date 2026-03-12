-- Migration: Creative Analytics — restructure competitors into creatives + placements
-- Run this BEFORE deploying updated workflows

-- ============================================
-- 1. CREATE NEW TABLES
-- ============================================

CREATE TABLE IF NOT EXISTS creatives (
    id SERIAL PRIMARY KEY,
    media_id INTEGER,
    title TEXT NOT NULL,
    image_url TEXT,
    landing_url TEXT,
    landing_domain TEXT,
    short_description TEXT,
    full_description TEXT,
    button_text TEXT,
    -- Geozo metadata
    geozo_ad_id INTEGER,
    geozo_adgroup_id INTEGER,
    geozo_site_id INTEGER,
    -- Computed metrics
    gravity DECIMAL(8,2) DEFAULT 0,
    strength DECIMAL(8,2) DEFAULT 0,
    trend VARCHAR(10) DEFAULT 'new',
    -- Aggregated stats
    total_placements INTEGER DEFAULT 0,
    unique_sites INTEGER DEFAULT 0,
    unique_blocks INTEGER DEFAULT 0,
    countries TEXT[] DEFAULT '{}',
    avg_position DECIMAL(5,2),
    avg_cost DECIMAL(10,4),
    avg_show_rate DECIMAL(5,4),
    days_running INTEGER DEFAULT 0,
    -- Timestamps
    first_seen_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_creatives_media_id ON creatives(media_id) WHERE media_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_creatives_title ON creatives(title);
CREATE INDEX IF NOT EXISTS idx_creatives_landing_domain ON creatives(landing_domain);
CREATE INDEX IF NOT EXISTS idx_creatives_last_seen ON creatives(last_seen_at);
CREATE INDEX IF NOT EXISTS idx_creatives_gravity ON creatives(gravity DESC);

CREATE TABLE IF NOT EXISTS placements (
    id SERIAL PRIMARY KEY,
    creative_id INTEGER REFERENCES creatives(id),
    publisher_site TEXT NOT NULL,
    block_id INTEGER,
    country_code VARCHAR(5),
    position INTEGER,
    cost DECIMAL(10,4),
    show_rate DECIMAL(5,4),
    render_domain TEXT,
    click_url TEXT,
    scanned_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_placements_creative ON placements(creative_id);
CREATE INDEX IF NOT EXISTS idx_placements_publisher ON placements(publisher_site);
CREATE INDEX IF NOT EXISTS idx_placements_time ON placements(scanned_at);
CREATE INDEX IF NOT EXISTS idx_placements_block ON placements(block_id);

CREATE TABLE IF NOT EXISTS creative_daily_stats (
    id SERIAL PRIMARY KEY,
    creative_id INTEGER REFERENCES creatives(id),
    stat_date DATE NOT NULL,
    placements_count INTEGER DEFAULT 0,
    unique_sites INTEGER DEFAULT 0,
    avg_position DECIMAL(5,2),
    min_position INTEGER,
    max_position INTEGER,
    avg_cost DECIMAL(10,4),
    max_cost DECIMAL(10,4),
    avg_show_rate DECIMAL(5,4),
    UNIQUE(creative_id, stat_date)
);

CREATE INDEX IF NOT EXISTS idx_creative_daily_creative ON creative_daily_stats(creative_id);
CREATE INDEX IF NOT EXISTS idx_creative_daily_date ON creative_daily_stats(stat_date);

-- ============================================
-- 2. MIGRATE DATA FROM competitors → creatives
-- ============================================

-- Insert unique creatives (dedup by media_id, then by title for no-media-id)
INSERT INTO creatives (
    media_id, title, image_url, landing_url, landing_domain,
    short_description, full_description, button_text,
    geozo_ad_id, geozo_adgroup_id, geozo_site_id,
    total_placements, avg_position, avg_cost, avg_show_rate,
    first_seen_at, last_seen_at, days_running
)
SELECT DISTINCT ON (COALESCE(media_id::text, title))
    media_id, title, image_url, destination_url, landing_domain,
    short_description, full_description, button_text,
    geozo_ad_id, geozo_adgroup_id, geozo_site_id,
    times_seen,
    COALESCE(avg_position, position::decimal),
    cost,
    COALESCE(show_rate, 0),
    first_seen_at, last_seen_at,
    GREATEST(0, EXTRACT(DAY FROM last_seen_at - first_seen_at)::int)
FROM competitors
WHERE title IS NOT NULL AND title != '' AND title != 'undefined'
ORDER BY COALESCE(media_id::text, title), last_seen_at DESC;

-- Set countries array from existing data
UPDATE creatives c SET countries = sub.geos
FROM (
    SELECT COALESCE(media_id::text, title) AS key,
           array_agg(DISTINCT country_code) FILTER (WHERE country_code IS NOT NULL) AS geos
    FROM competitors
    WHERE title IS NOT NULL AND title != '' AND title != 'undefined'
    GROUP BY COALESCE(media_id::text, title)
) sub
WHERE COALESCE(c.media_id::text, c.title) = sub.key;

-- ============================================
-- 3. MIGRATE competitors → placements
-- ============================================

INSERT INTO placements (creative_id, publisher_site, block_id, country_code, position, cost, show_rate, render_domain, scanned_at)
SELECT
    cr.id,
    regexp_replace(co.site_url, '^(https?://[^/]+).*$', '\1'),
    co.block_id,
    co.country_code,
    co.position,
    co.cost,
    COALESCE(co.show_rate, 0),
    co.render_domain,
    co.last_seen_at
FROM competitors co
JOIN creatives cr ON (
    (co.media_id IS NOT NULL AND cr.media_id = co.media_id)
    OR (co.media_id IS NULL AND cr.media_id IS NULL AND cr.title = co.title)
)
WHERE co.title IS NOT NULL AND co.title != '' AND co.title != 'undefined';

-- ============================================
-- 4. MIGRATE competitor_history → placements
--    (skip rows that overlap with competitors — those were already inserted in step 3)
-- ============================================

INSERT INTO placements (creative_id, publisher_site, block_id, country_code, position, cost, show_rate, scanned_at)
SELECT
    cr.id,
    regexp_replace(ch.site_url, '^(https?://[^/]+).*$', '\1'),
    NULL,
    NULL,
    ch.position,
    ch.cost,
    COALESCE(ch.show_rate, 0),
    ch.scanned_at
FROM competitor_history ch
JOIN creatives cr ON (
    (ch.media_id IS NOT NULL AND cr.media_id = ch.media_id)
    OR (ch.media_id IS NULL AND cr.media_id IS NULL AND cr.title IN (SELECT title FROM competitors WHERE id = ch.competitor_id))
)
WHERE ch.scanned_at IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM placements p
    WHERE p.creative_id = cr.id
      AND p.publisher_site = regexp_replace(ch.site_url, '^(https?://[^/]+).*$', '\1')
      AND p.scanned_at = ch.scanned_at
  );

-- ============================================
-- 5. BUILD INITIAL DAILY STATS
-- ============================================

INSERT INTO creative_daily_stats (creative_id, stat_date, placements_count, unique_sites, avg_position, min_position, max_position, avg_cost, max_cost, avg_show_rate)
SELECT
    creative_id,
    scanned_at::date,
    COUNT(*),
    COUNT(DISTINCT publisher_site),
    ROUND(AVG(position)::numeric, 2),
    MIN(position),
    MAX(position),
    ROUND(AVG(cost)::numeric, 4),
    MAX(cost),
    ROUND(AVG(show_rate)::numeric, 4)
FROM placements
GROUP BY creative_id, scanned_at::date
ON CONFLICT (creative_id, stat_date) DO NOTHING;

-- ============================================
-- 6. UPDATE AGGREGATE STATS ON CREATIVES
-- ============================================

UPDATE creatives c SET
    total_placements = sub.total_p,
    unique_sites = sub.sites,
    unique_blocks = sub.blocks
FROM (
    SELECT creative_id,
           COUNT(*) AS total_p,
           COUNT(DISTINCT publisher_site) AS sites,
           COUNT(DISTINCT block_id) FILTER (WHERE block_id IS NOT NULL) AS blocks
    FROM placements
    GROUP BY creative_id
) sub
WHERE c.id = sub.creative_id;

-- ============================================
-- 7. DEDUPLICATE PLACEMENTS
--    Remove rows without country_code when a duplicate with country_code exists
-- ============================================

DELETE FROM placements p1
WHERE p1.country_code IS NULL
  AND EXISTS (
    SELECT 1 FROM placements p2
    WHERE p2.creative_id = p1.creative_id
      AND p2.publisher_site = p1.publisher_site
      AND p2.position = p1.position
      AND p2.scanned_at = p1.scanned_at
      AND p2.country_code IS NOT NULL
  );

-- Recalculate aggregate stats after dedup
UPDATE creatives c SET
    total_placements = sub.total_p,
    unique_sites = sub.sites,
    unique_blocks = sub.blocks
FROM (
    SELECT creative_id,
           COUNT(*) AS total_p,
           COUNT(DISTINCT publisher_site) AS sites,
           COUNT(DISTINCT block_id) FILTER (WHERE block_id IS NOT NULL) AS blocks
    FROM placements
    GROUP BY creative_id
) sub
WHERE c.id = sub.creative_id;

-- Rebuild daily stats after dedup
TRUNCATE creative_daily_stats;
INSERT INTO creative_daily_stats (creative_id, stat_date, placements_count, unique_sites, avg_position, min_position, max_position, avg_cost, max_cost, avg_show_rate)
SELECT
    creative_id,
    scanned_at::date,
    COUNT(*),
    COUNT(DISTINCT publisher_site),
    ROUND(AVG(position)::numeric, 2),
    MIN(position),
    MAX(position),
    ROUND(AVG(cost)::numeric, 4),
    MAX(cost),
    ROUND(AVG(show_rate)::numeric, 4)
FROM placements
GROUP BY creative_id, scanned_at::date
ON CONFLICT (creative_id, stat_date) DO NOTHING;

-- ============================================
-- 8. RENAME OLD TABLES (keep as backup)
-- ============================================

ALTER TABLE IF EXISTS competitors RENAME TO competitors_legacy;
ALTER TABLE IF EXISTS competitor_history RENAME TO competitor_history_legacy;
