-- ============================================
-- GEOZO AUTOMATION - Database Schema
-- ============================================
-- Single file: drop everything, create fresh, seed geo_payouts.
-- Usage: psql -f scripts/init-db.sql

-- ============================================
-- DROP ALL (order matters: FK dependencies)
-- ============================================
DROP TABLE IF EXISTS teaser_state_log CASCADE;
DROP TABLE IF EXISTS bid_expectations CASCADE;
DROP TABLE IF EXISTS bid_rollback_snapshots CASCADE;
DROP TABLE IF EXISTS workflow_locks CASCADE;
DROP TABLE IF EXISTS emergency_state CASCADE;
DROP TABLE IF EXISTS block_lists CASCADE;
DROP TABLE IF EXISTS daily_pnl CASCADE;
DROP TABLE IF EXISTS ab_tests CASCADE;
DROP TABLE IF EXISTS position_tracking CASCADE;
DROP TABLE IF EXISTS scan_targets CASCADE;
DROP TABLE IF EXISTS competitors CASCADE;
DROP TABLE IF EXISTS anomalies CASCADE;
DROP TABLE IF EXISTS content_queue CASCADE;
DROP TABLE IF EXISTS balance_history CASCADE;
DROP TABLE IF EXISTS bid_history CASCADE;
DROP TABLE IF EXISTS block_stats CASCADE;
DROP TABLE IF EXISTS geo_stats CASCADE;
DROP TABLE IF EXISTS ad_stats CASCADE;
DROP TABLE IF EXISTS geo_payouts CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS teasers CASCADE;

-- ============================================
-- TABLES
-- ============================================

CREATE TABLE teasers (
    id SERIAL PRIMARY KEY,
    ad_id INTEGER,
    ad_group_id INTEGER,
    campaign_id INTEGER,
    account_id INTEGER DEFAULT 1,
    title VARCHAR(255) NOT NULL,
    original_url TEXT NOT NULL,
    image_square_path TEXT,
    image_horizontal_path TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    bid DECIMAL(10, 4),
    ban_reason TEXT,
    remoderation_attempts INTEGER DEFAULT 0,
    generation_source VARCHAR(50),
    ab_test_group VARCHAR(50),
    -- State machine
    state VARCHAR(30) DEFAULT 'created',
    state_changed_at TIMESTAMP DEFAULT NOW(),
    state_reason TEXT,
    pause_count INTEGER DEFAULT 0,
    recovery_attempts INTEGER DEFAULT 0,
    last_bid_change_at TIMESTAMP,
    bid_changes_today INTEGER DEFAULT 0,
    bid_changes_reset_date DATE DEFAULT CURRENT_DATE,
    cumulative_bid_change_today DECIMAL(8,4) DEFAULT 1.0,
    escalation_level INTEGER DEFAULT 0,
    escalation_failures INTEGER DEFAULT 0,
    warmup_phase INTEGER DEFAULT 0,
    total_spend_lifetime DECIMAL(12,4) DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE ad_stats (
    id SERIAL PRIMARY KEY,
    ad_id INTEGER NOT NULL,
    date DATE NOT NULL,
    shows INTEGER DEFAULT 0,
    confirmed_shows INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    money DECIMAL(12, 4) DEFAULT 0,
    postbacks_count INTEGER DEFAULT 0,
    postbacks_confirmed_money DECIMAL(12, 4) DEFAULT 0,
    ctr DECIMAL(8, 4) DEFAULT 0,
    cpc DECIMAL(8, 4) DEFAULT 0,
    roi DECIMAL(10, 2) DEFAULT 0,
    profit DECIMAL(12, 4) DEFAULT 0,
    collected_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(ad_id, date)
);

CREATE TABLE geo_stats (
    id SERIAL PRIMARY KEY,
    ad_id INTEGER,
    country_code VARCHAR(5) NOT NULL,
    date DATE NOT NULL,
    shows INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    money DECIMAL(12, 4) DEFAULT 0,
    postbacks_confirmed_money DECIMAL(12, 4) DEFAULT 0,
    roi DECIMAL(10, 2) DEFAULT 0,
    collected_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (ad_id, country_code, date)
);

CREATE TABLE block_stats (
    id SERIAL PRIMARY KEY,
    block_id INTEGER NOT NULL,
    ad_id INTEGER,
    date DATE NOT NULL,
    shows INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    money DECIMAL(12, 4) DEFAULT 0,
    postbacks_confirmed_money DECIMAL(12, 4) DEFAULT 0,
    ctr DECIMAL(8, 4) DEFAULT 0,
    roi DECIMAL(10, 2) DEFAULT 0,
    classification VARCHAR(20) DEFAULT 'yellow',
    collected_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE balance_history (
    id SERIAL PRIMARY KEY,
    account_id INTEGER DEFAULT 1,
    balance DECIMAL(12, 4) NOT NULL,
    spend_rate_per_hour DECIMAL(10, 4),
    hours_remaining DECIMAL(8, 2),
    collected_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE bid_history (
    id SERIAL PRIMARY KEY,
    ad_id INTEGER NOT NULL,
    old_bid DECIMAL(10, 4),
    new_bid DECIMAL(10, 4),
    reason VARCHAR(255),
    rule_applied VARCHAR(100),
    roi_at_change DECIMAL(10, 2),
    clicks_at_change INTEGER,
    changed_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE scan_targets (
    id SERIAL PRIMARY KEY,
    site_url TEXT NOT NULL,
    country_code VARCHAR(5) NOT NULL,
    proxy_url TEXT,
    proxy_type VARCHAR(20) DEFAULT 'socks5',
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE position_tracking (
    id SERIAL PRIMARY KEY,
    site_url TEXT NOT NULL,
    ad_id INTEGER,
    position INTEGER,
    total_teasers_in_block INTEGER,
    competitor_titles JSONB,
    scanned_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE ab_tests (
    id SERIAL PRIMARY KEY,
    test_name VARCHAR(255) NOT NULL,
    landing_url TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'running',
    generation INTEGER DEFAULT 1,
    variants JSONB,
    winner_ad_id INTEGER,
    started_at TIMESTAMP DEFAULT NOW(),
    finished_at TIMESTAMP
);

CREATE TABLE daily_pnl (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    total_spend DECIMAL(12, 4) DEFAULT 0,
    total_revenue DECIMAL(12, 4) DEFAULT 0,
    gross_profit DECIMAL(12, 4) DEFAULT 0,
    roi_percent DECIMAL(10, 2) DEFAULT 0,
    best_campaign_id INTEGER,
    worst_campaign_id INTEGER,
    balance_start DECIMAL(12, 4),
    balance_end DECIMAL(12, 4),
    deposits DECIMAL(12, 4) DEFAULT 0,
    teasers_created INTEGER DEFAULT 0,
    teasers_banned INTEGER DEFAULT 0,
    teasers_stopped INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    api_token TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    balance DECIMAL(12, 4) DEFAULT 0,
    daily_budget DECIMAL(10, 4),
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE content_queue (
    id SERIAL PRIMARY KEY,
    trend_source VARCHAR(100),
    trend_topic TEXT NOT NULL,
    generated_titles JSONB,
    generated_image_prompts JSONB,
    status VARCHAR(50) DEFAULT 'pending',
    priority INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP
);

CREATE TABLE competitors (
    id SERIAL PRIMARY KEY,
    media_id INTEGER,
    site_url TEXT,
    title TEXT NOT NULL,
    image_url TEXT,
    destination_url TEXT,
    position INTEGER,
    block_id INTEGER,
    landing_domain TEXT,
    geozo_ad_id INTEGER,
    geozo_adgroup_id INTEGER,
    geozo_site_id INTEGER,
    country_code VARCHAR(5),
    cost DECIMAL(10, 4),
    first_seen_at TIMESTAMP DEFAULT NOW(),
    last_seen_at TIMESTAMP DEFAULT NOW(),
    times_seen INTEGER DEFAULT 1
);

CREATE TABLE anomalies (
    id SERIAL PRIMARY KEY,
    ad_id INTEGER,
    anomaly_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) DEFAULT 'warning',
    description TEXT,
    metric_name VARCHAR(50),
    expected_value DECIMAL(12, 4),
    actual_value DECIMAL(12, 4),
    deviation_percent DECIMAL(8, 2),
    resolved BOOLEAN DEFAULT FALSE,
    detected_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP
);

CREATE TABLE geo_payouts (
    id SERIAL PRIMARY KEY,
    country_code VARCHAR(5) NOT NULL UNIQUE,
    country_name VARCHAR(100),
    geo_id INTEGER,
    vertical VARCHAR(50) DEFAULT 'crypto',
    avg_payout DECIMAL(10, 2) NOT NULL,
    avg_approval DECIMAL(6, 4) NOT NULL,
    max_cpl DECIMAL(10, 2) GENERATED ALWAYS AS (avg_payout * avg_approval) STORED,
    min_bid DECIMAL(10, 4) DEFAULT 0.01,
    max_bid DECIMAL(10, 4) DEFAULT 0.15,
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE block_lists (
    id SERIAL PRIMARY KEY,
    block_id INTEGER NOT NULL,
    list_type VARCHAR(20) NOT NULL CHECK (list_type IN ('blacklist', 'whitelist')),
    ad_group_id INTEGER,
    reason VARCHAR(255),
    roi_at_decision DECIMAL(10, 2),
    added_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE teaser_state_log (
    id SERIAL PRIMARY KEY,
    teaser_id INTEGER REFERENCES teasers(id),
    ad_id INTEGER,
    old_state VARCHAR(30),
    new_state VARCHAR(30),
    reason TEXT,
    triggered_by VARCHAR(50),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE bid_expectations (
    id SERIAL PRIMARY KEY,
    ad_id INTEGER NOT NULL,
    bid_history_id INTEGER REFERENCES bid_history(id),
    old_bid DECIMAL(10,4),
    new_bid DECIMAL(10,4),
    action VARCHAR(20),
    expected_metric VARCHAR(20),
    expected_direction VARCHAR(10),
    baseline_value DECIMAL(12,4),
    measurement_window_hours INTEGER DEFAULT 4,
    outcome VARCHAR(20),
    actual_value DECIMAL(12,4),
    checked BOOLEAN DEFAULT FALSE,
    checked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE workflow_locks (
    lock_name VARCHAR(100) PRIMARY KEY,
    locked_by VARCHAR(100) NOT NULL,
    locked_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL
);

CREATE TABLE emergency_state (
    id SERIAL PRIMARY KEY,
    is_active BOOLEAN DEFAULT FALSE,
    trigger_reason TEXT,
    triggered_by VARCHAR(50),
    activated_at TIMESTAMP DEFAULT NOW(),
    deactivated_at TIMESTAMP,
    auto_deactivate_at TIMESTAMP
);

CREATE TABLE bid_rollback_snapshots (
    id SERIAL PRIMARY KEY,
    ad_id INTEGER NOT NULL,
    bid_history_id INTEGER REFERENCES bid_history(id),
    snapshot_bid DECIMAL(10,4) NOT NULL,
    snapshot_cpl DECIMAL(12,4),
    snapshot_ctr DECIMAL(8,4),
    rollback_threshold_hours INTEGER DEFAULT 2,
    rollback_triggered BOOLEAN DEFAULT FALSE,
    checked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_ad_stats_ad_date ON ad_stats(ad_id, date);
CREATE INDEX idx_ad_stats_date ON ad_stats(date);
CREATE INDEX idx_geo_stats_date ON geo_stats(date);
CREATE INDEX idx_block_stats_date ON block_stats(date);
CREATE INDEX idx_balance_history_time ON balance_history(collected_at);
CREATE INDEX idx_bid_history_ad ON bid_history(ad_id);
CREATE INDEX idx_bid_history_changed ON bid_history(changed_at);
CREATE INDEX idx_position_tracking_time ON position_tracking(scanned_at);
CREATE INDEX idx_scan_targets_active ON scan_targets(is_active, country_code);
CREATE UNIQUE INDEX idx_scan_targets_site_geo_proxy ON scan_targets(site_url, country_code, proxy_url) WHERE proxy_url IS NOT NULL;
CREATE INDEX idx_teasers_status ON teasers(status);
CREATE INDEX idx_teasers_state ON teasers(state);
CREATE INDEX idx_teasers_state_changed ON teasers(state_changed_at);
CREATE INDEX idx_anomalies_detected ON anomalies(detected_at);
CREATE INDEX idx_daily_pnl_date ON daily_pnl(date);
CREATE INDEX idx_geo_payouts_cc ON geo_payouts(country_code);
CREATE INDEX idx_teaser_state_log_ad ON teaser_state_log(ad_id);
CREATE INDEX idx_teaser_state_log_time ON teaser_state_log(created_at);
CREATE INDEX idx_bid_expectations_ad ON bid_expectations(ad_id);
CREATE INDEX idx_bid_expectations_unchecked ON bid_expectations(checked, created_at);
CREATE INDEX idx_bid_rollback_unchecked ON bid_rollback_snapshots(rollback_triggered, created_at);
CREATE INDEX idx_emergency_state_active ON emergency_state(is_active);
CREATE UNIQUE INDEX idx_competitors_site_title ON competitors(site_url, title);
CREATE UNIQUE INDEX idx_competitors_media_id ON competitors(media_id) WHERE media_id IS NOT NULL;

-- ============================================
-- SEED DATA: geo payouts (crypto)
-- ============================================
INSERT INTO geo_payouts (country_code, country_name, geo_id, vertical, avg_payout, avg_approval, min_bid, max_bid) VALUES
    ('GB', 'United Kingdom',  119, 'crypto', 1400, 0.055, 0.05, 0.15),
    ('DE', 'Germany',         56,  'crypto', 1200, 0.050, 0.04, 0.12),
    ('FR', 'France',          73,  'crypto', 1100, 0.045, 0.03, 0.10),
    ('IT', 'Italy',           105, 'crypto', 1000, 0.050, 0.03, 0.10),
    ('ES', 'Spain',           199, 'crypto', 1000, 0.045, 0.03, 0.10),
    ('NL', 'Netherlands',     151, 'crypto', 1300, 0.055, 0.04, 0.12),
    ('SE', 'Sweden',          204, 'crypto', 1500, 0.060, 0.05, 0.15),
    ('NO', 'Norway',          160, 'crypto', 1500, 0.060, 0.05, 0.15),
    ('AT', 'Austria',         14,  'crypto', 1200, 0.050, 0.04, 0.12),
    ('CH', 'Switzerland',     206, 'crypto', 1600, 0.060, 0.06, 0.18),
    ('AU', 'Australia',       13,  'crypto', 1500, 0.055, 0.05, 0.15),
    ('CA', 'Canada',          38,  'crypto', 1400, 0.055, 0.05, 0.15),
    ('NZ', 'New Zealand',     157, 'crypto', 1400, 0.055, 0.04, 0.12);
