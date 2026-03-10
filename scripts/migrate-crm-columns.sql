-- Add CRM data columns to teasers table
-- These store leads/revenue from MySQL CRM (synced by 06-ads-sync)

-- Lifetime totals from Geozo API (may already exist from sync attempts)
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_shows INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_clicks INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_money DECIMAL(12,4) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_cpc DECIMAL(8,4) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_ctr DECIMAL(8,4) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_roi DECIMAL(10,2) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_leads INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_leads_confirmed_money DECIMAL(12,4) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_cr DECIMAL(8,4) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS ad_rating VARCHAR(50);
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS geozo_created_at TIMESTAMP;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS country_code VARCHAR(5);
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS geo_id INTEGER;

-- CRM data (from MySQL leads table via param5=ad_id)
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS crm_leads INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS crm_depositors INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS crm_revenue DECIMAL(12,2) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS crm_leads_today INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS crm_revenue_today DECIMAL(12,2) DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS crm_synced_at TIMESTAMP;

-- Campaign/group names stored directly on teasers for reliable display
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS campaign_name VARCHAR(255);
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS group_ad_name VARCHAR(255);
