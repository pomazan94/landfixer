-- ============================================
-- MIGRATION: Ads Hierarchy (campaigns, ad_groups, teasers columns)
-- Run once: psql -f scripts/migrate-ads-hierarchy.sql
-- Safe to re-run (all operations are IF NOT EXISTS / IF EXISTS checks)
-- ============================================

-- 1. Create campaigns table
CREATE TABLE IF NOT EXISTS campaigns (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER NOT NULL UNIQUE,
    name VARCHAR(255),
    campaign_type_id INTEGER,
    traffic_source_id INTEGER,
    status VARCHAR(50) DEFAULT 'unknown',
    daily_money_limit DECIMAL(12,2) DEFAULT 0,
    total_money_limit DECIMAL(12,2) DEFAULT 0,
    synced_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. Create ad_groups table
CREATE TABLE IF NOT EXISTS ad_groups (
    id SERIAL PRIMARY KEY,
    ad_group_id INTEGER NOT NULL UNIQUE,
    campaign_id INTEGER NOT NULL,
    name VARCHAR(255),
    status VARCHAR(50) DEFAULT 'unknown',
    ad_count INTEGER DEFAULT 0,
    ad_started_count INTEGER DEFAULT 0,
    auto_start_ads BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- 3. Add new columns to teasers (safe — skips if already exist)
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS geozo_status_id INTEGER;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS short_description TEXT;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS bot_intent VARCHAR(100);
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS bot_intent_reason TEXT;

-- 4. Indexes for new tables
CREATE INDEX IF NOT EXISTS idx_campaigns_campaign_id ON campaigns(campaign_id);
CREATE INDEX IF NOT EXISTS idx_ad_groups_ad_group_id ON ad_groups(ad_group_id);
CREATE INDEX IF NOT EXISTS idx_ad_groups_campaign_id ON ad_groups(campaign_id);
CREATE INDEX IF NOT EXISTS idx_teasers_ad_group_id ON teasers(ad_group_id);
CREATE INDEX IF NOT EXISTS idx_teasers_campaign_id ON teasers(campaign_id);

-- 5. Unique index on ad_id (for upsert in sync workflow)
-- Drop old non-unique index first if exists, then create unique
DROP INDEX IF EXISTS idx_teasers_ad_id;
CREATE UNIQUE INDEX IF NOT EXISTS idx_teasers_ad_id_uniq ON teasers(ad_id) WHERE ad_id IS NOT NULL;

-- Done
SELECT 'Migration complete' as result;
