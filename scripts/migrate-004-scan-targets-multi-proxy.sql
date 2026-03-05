-- Migration 004: Allow multiple proxies per site in scan_targets
-- Enables: INSERT INTO scan_targets (site_url, country_code, proxy_url) VALUES ('site', 'cz', 'proxy1'), ('site', 'cz', 'proxy2');

-- Drop old unique constraint (site_url, country_code) — only allows 1 proxy per site+geo
ALTER TABLE scan_targets DROP CONSTRAINT IF EXISTS scan_targets_site_url_country_code_key;
DROP INDEX IF EXISTS scan_targets_site_url_country_code_key;

-- New unique constraint: same site + geo + proxy = same target
CREATE UNIQUE INDEX IF NOT EXISTS idx_scan_targets_site_geo_proxy
  ON scan_targets (site_url, country_code, proxy_url)
  WHERE proxy_url IS NOT NULL;
