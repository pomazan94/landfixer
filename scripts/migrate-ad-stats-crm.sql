-- Add CRM columns to ad_stats table for per-day CRM data
-- This allows period-based aggregation of CRM leads/revenue alongside Geozo stats

ALTER TABLE ad_stats ADD COLUMN IF NOT EXISTS crm_leads INTEGER DEFAULT 0;
ALTER TABLE ad_stats ADD COLUMN IF NOT EXISTS crm_depositors INTEGER DEFAULT 0;
ALTER TABLE ad_stats ADD COLUMN IF NOT EXISTS crm_revenue DECIMAL(12,2) DEFAULT 0;
