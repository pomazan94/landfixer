-- Migration: Add ping health check columns to scan_targets
-- Run this on existing databases to add site health monitoring

ALTER TABLE scan_targets ADD COLUMN IF NOT EXISTS ping_ok BOOLEAN;
ALTER TABLE scan_targets ADD COLUMN IF NOT EXISTS last_ping_at TIMESTAMPTZ;
ALTER TABLE scan_targets ADD COLUMN IF NOT EXISTS ping_error TEXT;
