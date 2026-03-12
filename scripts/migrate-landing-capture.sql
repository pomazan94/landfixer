-- Migration: Add landing page capture columns to creatives table
-- Run: psql -U n8n -d n8n -f scripts/migrate-landing-capture.sql

ALTER TABLE creatives ADD COLUMN IF NOT EXISTS screenshot_path TEXT;
ALTER TABLE creatives ADD COLUMN IF NOT EXISTS archive_path TEXT;
ALTER TABLE creatives ADD COLUMN IF NOT EXISTS captured_at TIMESTAMPTZ;
