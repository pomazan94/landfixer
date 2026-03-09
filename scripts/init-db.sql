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
    collected_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(block_id, date)
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
-- BOT CONFIG (all constants editable via UI)
-- ============================================
CREATE TABLE bot_config (
    id SERIAL PRIMARY KEY,
    category VARCHAR(50) NOT NULL,
    key VARCHAR(100) NOT NULL,
    value TEXT NOT NULL,
    value_type VARCHAR(20) DEFAULT 'number',
    label VARCHAR(200),
    description TEXT,
    min_value TEXT,
    max_value TEXT,
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(category, key)
);

-- Smart Bidder constants
INSERT INTO bot_config (category, key, value, value_type, label, description, min_value, max_value) VALUES
    ('smart_bidder', 'max_bid_changes_per_day', '3', 'integer', 'Max bid changes per day', 'Maximum number of bid changes per ad per day', '1', '20'),
    ('smart_bidder', 'min_cooldown_hours', '2', 'number', 'Min cooldown hours', 'Minimum hours between bid changes for the same ad', '0.5', '24'),
    ('smart_bidder', 'max_cumulative_change_down', '0.5', 'number', 'Max cumulative decrease', 'Max cumulative bid decrease per day (0.5 = 50%)', '0.1', '1.0'),
    ('smart_bidder', 'max_cumulative_change_up', '2.0', 'number', 'Max cumulative increase', 'Max cumulative bid increase per day (2.0 = 2x)', '1.0', '10.0'),
    ('smart_bidder', 'min_spend_for_decision', '200', 'number', 'Min spend for decision ($)', 'Minimum spend before making bid decisions', '10', '2000'),
    ('smart_bidder', 'min_spend_for_stop', '600', 'number', 'Min spend for stop ($)', 'Minimum spend before considering STOP', '50', '5000'),
    ('smart_bidder', 'min_clicks_for_stop', '500', 'integer', 'Min clicks for stop', 'Minimum clicks before allowing STOP action', '50', '5000'),
    ('smart_bidder', 'stats_lookback_days', '3', 'integer', 'Stats lookback days', 'Number of days to look back for statistics', '1', '30'),
    ('smart_bidder', 'api_fetch_count', '500', 'integer', 'API fetch count', 'Number of ads to fetch from Geozo API per call', '50', '1000'),
    -- Escalation levels
    ('smart_bidder', 'escalation_l1_multiplier', '0.92', 'number', 'L1: Soft correction multiplier', 'Bid multiplier for Level 1 escalation (-8%)', '0.5', '0.99'),
    ('smart_bidder', 'escalation_l1_cooldown', '2', 'number', 'L1: Cooldown hours', 'Hours cooldown after L1 correction', '1', '24'),
    ('smart_bidder', 'escalation_l2_multiplier', '0.85', 'number', 'L2: Moderate correction multiplier', 'Bid multiplier for Level 2 escalation (-15%)', '0.5', '0.99'),
    ('smart_bidder', 'escalation_l2_cooldown', '4', 'number', 'L2: Cooldown hours', 'Hours cooldown after L2 correction', '1', '24'),
    ('smart_bidder', 'escalation_l3_multiplier', '0.75', 'number', 'L3: Aggressive correction multiplier', 'Bid multiplier for Level 3 escalation (-25%)', '0.3', '0.99'),
    ('smart_bidder', 'escalation_l3_cooldown', '6', 'number', 'L3: Cooldown hours', 'Hours cooldown after L3 correction', '1', '48'),
    ('smart_bidder', 'escalation_l2_cpl_threshold', '1.3', 'number', 'L2: CPL threshold multiplier', 'Trigger L2 when CPL > maxCPL * this value', '1.0', '5.0'),
    ('smart_bidder', 'escalation_l3_cpl_threshold', '2.0', 'number', 'L3: CPL threshold multiplier', 'Trigger L3 when CPL > maxCPL * this value', '1.5', '10.0'),
    ('smart_bidder', 'escalation_max_failures', '3', 'integer', 'Max escalation failures', 'Failed attempts before STOP', '1', '10'),
    -- Profitable logic
    ('smart_bidder', 'profitable_raise_high_pct', '0.15', 'number', 'Profitable raise % (high)', 'Raise bid by this % when very profitable (CPL < 0.5*maxCPL)', '0.05', '0.50'),
    ('smart_bidder', 'profitable_raise_high_cap', '0.30', 'number', 'Profitable raise cap (high)', 'Cap raise at this % for very profitable', '0.10', '1.0'),
    ('smart_bidder', 'profitable_raise_good_pct', '0.10', 'number', 'Profitable raise % (good)', 'Raise bid by this % when good (CPL < 0.75*maxCPL)', '0.05', '0.50'),
    ('smart_bidder', 'profitable_raise_good_cap', '0.20', 'number', 'Profitable raise cap (good)', 'Cap raise at this % for good CPL', '0.05', '0.50'),
    ('smart_bidder', 'profitable_min_leads_high', '3', 'integer', 'Min leads for high raise', 'Minimum leads to qualify for high raise', '1', '50'),
    ('smart_bidder', 'profitable_min_leads_good', '2', 'integer', 'Min leads for good raise', 'Minimum leads to qualify for good raise', '1', '50'),
    ('smart_bidder', 'profitable_cpl_ratio_high', '0.5', 'number', 'CPL ratio for high profit', 'CPL <= maxCPL * this ratio = very profitable', '0.1', '1.0'),
    ('smart_bidder', 'profitable_cpl_ratio_good', '0.75', 'number', 'CPL ratio for good profit', 'CPL <= maxCPL * this ratio = good profit', '0.3', '1.0'),
    -- Time multipliers
    ('time_multipliers', 'evening_start', '19', 'integer', 'Evening start hour', 'Hour when evening (cheap auction) starts', '0', '23'),
    ('time_multipliers', 'evening_end', '2', 'integer', 'Evening end hour', 'Hour when evening period ends', '0', '23'),
    ('time_multipliers', 'evening_multiplier', '1.5', 'number', 'Evening multiplier', 'Bid multiplier during evening (cheap auction)', '0.5', '3.0'),
    ('time_multipliers', 'night_start', '2', 'integer', 'Night start hour', 'Hour when night (low traffic) starts', '0', '23'),
    ('time_multipliers', 'night_end', '8', 'integer', 'Night end hour', 'Hour when night period ends', '0', '23'),
    ('time_multipliers', 'night_multiplier', '0.7', 'number', 'Night multiplier', 'Bid multiplier during night', '0.1', '3.0'),
    ('time_multipliers', 'morning_start', '8', 'integer', 'Morning start hour', 'Hour when morning (expensive auction) starts', '0', '23'),
    ('time_multipliers', 'morning_end', '12', 'integer', 'Morning end hour', 'Hour when morning period ends', '0', '23'),
    ('time_multipliers', 'morning_multiplier', '0.8', 'number', 'Morning multiplier', 'Bid multiplier during morning', '0.1', '3.0'),
    ('time_multipliers', 'afternoon_multiplier', '1.0', 'number', 'Afternoon multiplier', 'Bid multiplier during afternoon (default)', '0.1', '3.0'),
    -- Warmup phases
    ('warmup', 'phase0_max_spend', '10', 'number', 'Phase 0 max spend ($)', 'Max spend for Phase 0 (set to max bid)', '1', '100'),
    ('warmup', 'phase1_max_spend', '100', 'number', 'Phase 1 max spend ($)', 'Max spend for Phase 1 (collect data)', '10', '500'),
    ('warmup', 'phase2_max_spend', '300', 'number', 'Phase 2 max spend ($)', 'Max spend for Phase 2 (evaluate)', '50', '1000'),
    ('warmup', 'phase1_dead_clicks', '10', 'integer', 'Phase 1 dead clicks threshold', 'Clicks below this with shows > threshold = dead creative', '1', '100'),
    ('warmup', 'phase1_dead_shows', '3000', 'integer', 'Phase 1 dead shows threshold', 'Shows above this with clicks below threshold = dead creative', '500', '50000'),
    ('warmup', 'phase2_low_ctr', '0.1', 'number', 'Phase 2 low CTR (%)', 'CTR below this in Phase 2 = stop', '0.01', '1.0'),
    ('warmup', 'phase2_min_shows', '5000', 'integer', 'Phase 2 min shows', 'Minimum shows to evaluate CTR in Phase 2', '1000', '50000'),
    -- ROI classification thresholds
    ('roi_classification', 'profit_high_threshold', '100', 'number', 'PROFIT_HIGH ROI threshold (%)', 'ROI above this = PROFIT_HIGH', '50', '500'),
    ('roi_classification', 'profit_threshold', '50', 'number', 'PROFIT ROI threshold (%)', 'ROI above this = PROFIT', '10', '200'),
    ('roi_classification', 'losing_threshold', '-30', 'number', 'LOSING ROI threshold (%)', 'ROI below 0 but above this = LOSING', '-90', '0'),
    ('roi_classification', 'burning_threshold', '-50', 'number', 'BURNING ROI threshold (%)', 'ROI below LOSING but above this = BURNING', '-99', '0'),
    ('roi_classification', 'critical_min_spend', '3', 'number', 'CRITICAL min spend ($)', 'Minimum spend for CRITICAL status', '0.5', '50'),
    -- Emergency controller
    ('emergency', 'daily_budget', '200', 'number', 'Daily budget ($)', 'Maximum daily spend before emergency', '10', '10000'),
    ('emergency', 'min_balance_critical', '5', 'number', 'Critical balance ($)', 'Balance below this = EMERGENCY STOP', '1', '100'),
    ('emergency', 'min_balance_warning', '20', 'number', 'Warning balance ($)', 'Balance below this = WARNING', '5', '200'),
    ('emergency', 'max_bid_changes_per_hour', '30', 'integer', 'Max bid changes per hour', 'Bid changes above this = suspicious activity', '5', '200'),
    ('emergency', 'critical_anomaly_threshold', '3', 'integer', 'Critical anomaly threshold', 'Number of unresolved critical anomalies to trigger emergency', '1', '20'),
    ('emergency', 'budget_emergency_pct', '95', 'number', 'Budget emergency % ', 'Budget usage % to trigger EMERGENCY', '50', '100'),
    ('emergency', 'budget_conservative_pct', '80', 'number', 'Budget conservative %', 'Budget usage % to trigger conservative mode', '30', '95'),
    ('emergency', 'min_hours_remaining_warning', '4', 'number', 'Min hours remaining warning', 'Hours remaining below this = warning', '1', '24'),
    ('emergency', 'emergency_auto_deactivate_hours', '2', 'number', 'Emergency auto-deactivate hours', 'Hours after which emergency auto-deactivates', '0.5', '24'),
    ('emergency', 'conservative_lock_minutes', '30', 'integer', 'Conservative lock minutes', 'Duration of conservative mode lock', '5', '120'),
    ('emergency', 'emergency_stop_batch_size', '50', 'integer', 'Emergency stop batch size', 'Number of ads per batch in emergency stop', '10', '500'),
    -- Balance watchdog
    ('balance', 'min_balance_alert', '10', 'number', 'Min balance alert ($)', 'Alert when balance drops below this', '1', '100'),
    ('balance', 'low_hours_warning', '6', 'number', 'Low hours warning', 'Alert when hours remaining below this', '1', '24'),
    -- Anomaly detector
    ('anomaly', 'std_dev_threshold', '3', 'number', 'Std dev threshold', 'Number of standard deviations for anomaly detection', '1', '10'),
    ('anomaly', 'rolling_avg_days', '7', 'integer', 'Rolling average days', 'Number of days for rolling average', '3', '30'),
    -- Position
    ('position', 'top_position_threshold', '2', 'integer', 'Top position threshold', 'Position <= this is considered TOP', '1', '5'),
    ('position', 'good_position_threshold', '5', 'integer', 'Good position threshold', 'Position <= this is considered GOOD', '1', '10'),
    ('position', 'lookback_hours', '24', 'integer', 'Position lookback hours', 'Hours to look back for position data', '1', '72'),
    -- Workflow schedules (minutes)
    ('schedules', 'stats_puller_interval', '15', 'integer', 'Stats puller interval (min)', 'How often to pull stats from Geozo', '5', '60'),
    ('schedules', 'balance_watchdog_interval', '60', 'integer', 'Balance watchdog interval (min)', 'How often to check balance', '15', '180'),
    ('schedules', 'smart_bidder_interval', '30', 'integer', 'Smart bidder interval (min)', 'How often to run bid optimization', '15', '120'),
    ('schedules', 'budget_pacer_interval', '120', 'integer', 'Budget pacer interval (min)', 'How often to run budget pacing', '30', '360'),
    ('schedules', 'image_factory_interval', '60', 'integer', 'Image factory interval (min)', 'How often to generate images', '30', '360'),
    ('schedules', 'uploader_interval', '60', 'integer', 'Uploader interval (min)', 'How often to upload teasers', '30', '360'),
    ('schedules', 'ab_tester_interval', '240', 'integer', 'A/B tester interval (min)', 'How often to evaluate A/B tests', '60', '720'),
    ('schedules', 'anomaly_detector_interval', '60', 'integer', 'Anomaly detector interval (min)', 'How often to run anomaly detection', '15', '180'),
    ('schedules', 'position_scanner_interval', '120', 'integer', 'Position scanner interval (min)', 'How often to scan ad positions', '60', '360'),
    ('schedules', 'recovery_engine_interval', '240', 'integer', 'Recovery engine interval (min)', 'How often to attempt recovery', '60', '720'),
    ('schedules', 'bid_outcome_interval', '60', 'integer', 'Bid outcome checker interval (min)', 'How often to check bid expectations', '30', '180'),
    ('schedules', 'emergency_interval', '15', 'integer', 'Emergency controller interval (min)', 'How often to run emergency checks', '5', '60'),
    ('schedules', 'rollback_engine_interval', '60', 'integer', 'Rollback engine interval (min)', 'How often to check for rollbacks', '30', '180'),
    -- General defaults
    ('general', 'default_bid', '0.01', 'number', 'Default bid ($)', 'Default starting bid for new ads', '0.001', '1.0'),
    ('general', 'max_bid_ceiling', '0.10', 'number', 'Max bid ceiling ($)', 'Global maximum bid ceiling', '0.01', '1.0'),
    ('general', 'timezone', 'Europe/Moscow', 'string', 'Timezone', 'System timezone', NULL, NULL),
    ('general', 'telegram_chat_id', '591828204', 'string', 'Telegram Chat ID', 'Telegram chat for notifications', NULL, NULL),
    -- Dead creative detection
    ('dead_creative', 'min_shows_no_clicks', '5000', 'integer', 'Min shows (no clicks)', 'Shows threshold with minimal clicks to consider dead', '500', '50000'),
    ('dead_creative', 'max_clicks_dead', '10', 'integer', 'Max clicks (dead)', 'If clicks below this with shows above threshold = dead', '1', '100'),
    -- Rollback settings
    ('rollback', 'threshold_hours', '2', 'integer', 'Rollback threshold hours', 'Hours after which to check for rollback', '1', '12'),
    ('rollback', 'measurement_window_hours', '4', 'integer', 'Measurement window hours', 'Window for measuring bid change outcomes', '1', '24'),
    -- Default geo payout (fallback)
    ('default_payout', 'avg_payout', '1350', 'number', 'Default avg payout ($)', 'Fallback average payout for unknown geos', '100', '5000'),
    ('default_payout', 'avg_approval', '0.055', 'number', 'Default avg approval rate', 'Fallback approval rate for unknown geos', '0.01', '0.50'),
    ('default_payout', 'min_bid', '0.01', 'number', 'Default min bid ($)', 'Fallback minimum bid for unknown geos', '0.001', '0.50'),
    ('default_payout', 'max_bid', '0.15', 'number', 'Default max bid ($)', 'Fallback maximum bid for unknown geos', '0.01', '1.0');

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_ad_stats_ad_date ON ad_stats(ad_id, date);
CREATE INDEX idx_ad_stats_date ON ad_stats(date);
CREATE INDEX idx_geo_stats_date ON geo_stats(date);
CREATE INDEX idx_block_stats_date ON block_stats(date);
CREATE INDEX idx_block_stats_block ON block_stats(block_id);
CREATE INDEX idx_balance_history_time ON balance_history(collected_at);
CREATE INDEX idx_bid_history_ad ON bid_history(ad_id);
CREATE INDEX idx_bid_history_changed ON bid_history(changed_at);
CREATE INDEX idx_position_tracking_time ON position_tracking(scanned_at);
CREATE INDEX idx_scan_targets_active ON scan_targets(is_active, country_code);
CREATE UNIQUE INDEX idx_scan_targets_site_geo_proxy ON scan_targets(site_url, country_code, proxy_url) WHERE proxy_url IS NOT NULL;
CREATE INDEX idx_teasers_ad_id ON teasers(ad_id);
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
CREATE UNIQUE INDEX idx_emergency_state_active ON emergency_state(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_emergency_state_active_all ON emergency_state(is_active);
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

-- ============================================
-- Admin Auth
-- ============================================
CREATE TABLE admin_auth (
    id          SERIAL PRIMARY KEY,
    password_hash TEXT NOT NULL,
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Пароль по умолчанию: geozo2024
INSERT INTO admin_auth (password_hash)
VALUES ('0ea97442cce68ac959b508f79e64e5943ab7d48ce6faab8905da3baf7145183d');
