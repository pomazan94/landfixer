-- Fix: remove duplicate placements created by migration
-- Run this on the live database to clean up existing duplicates

-- 1. Remove placements without country_code when a matching one with country_code exists
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

-- 2. Recalculate aggregate stats on creatives
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

-- 3. Rebuild daily stats
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
