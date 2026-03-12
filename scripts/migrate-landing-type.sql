-- Migration: Add landing_type column to creatives table
-- Tracks type of landing: 'landing' (real), 'luckyfeed' (news showcase TDS)
-- Run: psql -U n8n -d n8n -f scripts/migrate-landing-type.sql

ALTER TABLE creatives ADD COLUMN IF NOT EXISTS landing_type VARCHAR(20) DEFAULT 'landing';

-- Backfill existing luckyfeed creatives based on URL pattern
UPDATE creatives SET landing_type = 'luckyfeed'
WHERE landing_url ~ '/v1/(full|short)/\d+'
  AND (landing_type IS NULL OR landing_type = 'landing');
