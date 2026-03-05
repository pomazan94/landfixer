-- ============================================
-- GEOZO AUTOMATION - Database Schema
-- ============================================

-- Тизеры и их статусы
CREATE TABLE IF NOT EXISTS teasers (
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
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Статистика по объявлениям
CREATE TABLE IF NOT EXISTS ad_stats (
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

-- Статистика по гео
CREATE TABLE IF NOT EXISTS geo_stats (
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

-- Статистика по блокам (площадкам)
CREATE TABLE IF NOT EXISTS block_stats (
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

-- История баланса
CREATE TABLE IF NOT EXISTS balance_history (
    id SERIAL PRIMARY KEY,
    account_id INTEGER DEFAULT 1,
    balance DECIMAL(12, 4) NOT NULL,
    spend_rate_per_hour DECIMAL(10, 4),
    hours_remaining DECIMAL(8, 2),
    collected_at TIMESTAMP DEFAULT NOW()
);

-- История изменения ставок
CREATE TABLE IF NOT EXISTS bid_history (
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

-- Позиции тизеров на площадках
CREATE TABLE IF NOT EXISTS position_tracking (
    id SERIAL PRIMARY KEY,
    site_url TEXT NOT NULL,
    ad_id INTEGER,
    position INTEGER,
    total_teasers_in_block INTEGER,
    competitor_titles JSONB,
    scanned_at TIMESTAMP DEFAULT NOW()
);

-- A/B тесты
CREATE TABLE IF NOT EXISTS ab_tests (
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

-- Ежедневные P&L
CREATE TABLE IF NOT EXISTS daily_pnl (
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

-- Аккаунты (для мульти-аккаунт системы)
CREATE TABLE IF NOT EXISTS accounts (
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

-- Очередь контента для генерации
CREATE TABLE IF NOT EXISTS content_queue (
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

-- Конкуренты (данные из скрапинга)
CREATE TABLE IF NOT EXISTS competitors (
    id SERIAL PRIMARY KEY,
    site_url TEXT,
    title TEXT NOT NULL,
    image_url TEXT,
    destination_url TEXT,
    position INTEGER,
    first_seen_at TIMESTAMP DEFAULT NOW(),
    last_seen_at TIMESTAMP DEFAULT NOW(),
    times_seen INTEGER DEFAULT 1
);

-- Аномалии
CREATE TABLE IF NOT EXISTS anomalies (
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

-- Матрица выплат по GEO (payout * approval = maxCPL)
CREATE TABLE IF NOT EXISTS geo_payouts (
    id SERIAL PRIMARY KEY,
    country_code VARCHAR(5) NOT NULL UNIQUE,
    country_name VARCHAR(100),
    geo_id INTEGER,                              -- geozo geo_id из API bids
    vertical VARCHAR(50) DEFAULT 'crypto',       -- вертикаль (crypto, gambling, etc)
    avg_payout DECIMAL(10, 2) NOT NULL,          -- средняя выплата за деп ($)
    avg_approval DECIMAL(6, 4) NOT NULL,         -- средний % апрува (0.055 = 5.5%)
    max_cpl DECIMAL(10, 2) GENERATED ALWAYS AS (avg_payout * avg_approval) STORED,  -- автоматический breakeven CPL
    min_bid DECIMAL(10, 4) DEFAULT 0.01,         -- минимальный бид для гео
    max_bid DECIMAL(10, 4) DEFAULT 0.15,         -- потолок бида для гео
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Начальные данные по основным гео (crypto вертикаль)
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
    ('NZ', 'New Zealand',     157, 'crypto', 1400, 0.055, 0.04, 0.12)
ON CONFLICT (country_code) DO NOTHING;

-- Black/White lists блоков
CREATE TABLE IF NOT EXISTS block_lists (
    id SERIAL PRIMARY KEY,
    block_id INTEGER NOT NULL,
    list_type VARCHAR(20) NOT NULL CHECK (list_type IN ('blacklist', 'whitelist')),
    ad_group_id INTEGER,
    reason VARCHAR(255),
    roi_at_decision DECIMAL(10, 2),
    added_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- STATE MACHINE: расширение таблицы teasers
-- ============================================

-- Состояния жизненного цикла тизера:
--   created -> pending_moderation -> active -> testing/scaling/optimizing
--   active -> paused_low_ctr / paused_high_cpl / paused_budget / paused_anomaly
--   paused_* -> recovery_queue -> active / stopped
--   stopped -> dead (финал)
--   banned -> remoderation -> pending_moderation / dead

ALTER TABLE teasers ADD COLUMN IF NOT EXISTS state VARCHAR(30) DEFAULT 'created';
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS state_changed_at TIMESTAMP DEFAULT NOW();
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS state_reason TEXT;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS pause_count INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS recovery_attempts INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS last_bid_change_at TIMESTAMP;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS bid_changes_today INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS bid_changes_reset_date DATE DEFAULT CURRENT_DATE;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS cumulative_bid_change_today DECIMAL(8,4) DEFAULT 1.0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS escalation_level INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS escalation_failures INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS warmup_phase INTEGER DEFAULT 0;
ALTER TABLE teasers ADD COLUMN IF NOT EXISTS total_spend_lifetime DECIMAL(12,4) DEFAULT 0;

-- Аудит-лог переходов состояний тизеров
CREATE TABLE IF NOT EXISTS teaser_state_log (
    id SERIAL PRIMARY KEY,
    teaser_id INTEGER REFERENCES teasers(id),
    ad_id INTEGER,
    old_state VARCHAR(30),
    new_state VARCHAR(30),
    reason TEXT,
    triggered_by VARCHAR(50),  -- 'smart_bidder', 'budget_pacer', 'emergency_controller', 'anomaly_detector', 'manual'
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Ожидания от изменений ставок (feedback loop)
CREATE TABLE IF NOT EXISTS bid_expectations (
    id SERIAL PRIMARY KEY,
    ad_id INTEGER NOT NULL,
    bid_history_id INTEGER REFERENCES bid_history(id),
    old_bid DECIMAL(10,4),
    new_bid DECIMAL(10,4),
    action VARCHAR(20),
    expected_metric VARCHAR(20),   -- 'cpl', 'ctr', 'position'
    expected_direction VARCHAR(10), -- 'up', 'down'
    baseline_value DECIMAL(12,4),
    measurement_window_hours INTEGER DEFAULT 4,
    outcome VARCHAR(20),           -- 'success', 'failure', 'neutral', 'insufficient_data'
    actual_value DECIMAL(12,4),
    checked BOOLEAN DEFAULT FALSE,
    checked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Distributed lock для координации workflows (Smart Bidder vs Budget Pacer)
CREATE TABLE IF NOT EXISTS workflow_locks (
    lock_name VARCHAR(100) PRIMARY KEY,
    locked_by VARCHAR(100) NOT NULL,
    locked_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL
);

-- Emergency controller state
CREATE TABLE IF NOT EXISTS emergency_state (
    id SERIAL PRIMARY KEY,
    is_active BOOLEAN DEFAULT FALSE,
    trigger_reason TEXT,
    triggered_by VARCHAR(50),
    activated_at TIMESTAMP DEFAULT NOW(),
    deactivated_at TIMESTAMP,
    auto_deactivate_at TIMESTAMP  -- NULL = requires manual deactivation
);

-- Rollback snapshots для отката ставок
CREATE TABLE IF NOT EXISTS bid_rollback_snapshots (
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

-- Индексы для быстрых запросов
CREATE INDEX IF NOT EXISTS idx_ad_stats_ad_date ON ad_stats(ad_id, date);
CREATE INDEX IF NOT EXISTS idx_ad_stats_date ON ad_stats(date);
CREATE INDEX IF NOT EXISTS idx_geo_stats_date ON geo_stats(date);
CREATE INDEX IF NOT EXISTS idx_block_stats_date ON block_stats(date);
CREATE INDEX IF NOT EXISTS idx_balance_history_time ON balance_history(collected_at);
CREATE INDEX IF NOT EXISTS idx_bid_history_ad ON bid_history(ad_id);
CREATE INDEX IF NOT EXISTS idx_bid_history_changed ON bid_history(changed_at);
CREATE INDEX IF NOT EXISTS idx_position_tracking_time ON position_tracking(scanned_at);
CREATE INDEX IF NOT EXISTS idx_teasers_status ON teasers(status);
CREATE INDEX IF NOT EXISTS idx_teasers_state ON teasers(state);
CREATE INDEX IF NOT EXISTS idx_teasers_state_changed ON teasers(state_changed_at);
CREATE INDEX IF NOT EXISTS idx_anomalies_detected ON anomalies(detected_at);
CREATE INDEX IF NOT EXISTS idx_daily_pnl_date ON daily_pnl(date);
CREATE INDEX IF NOT EXISTS idx_geo_payouts_cc ON geo_payouts(country_code);
CREATE INDEX IF NOT EXISTS idx_teaser_state_log_ad ON teaser_state_log(ad_id);
CREATE INDEX IF NOT EXISTS idx_teaser_state_log_time ON teaser_state_log(created_at);
CREATE INDEX IF NOT EXISTS idx_bid_expectations_ad ON bid_expectations(ad_id);
CREATE INDEX IF NOT EXISTS idx_bid_expectations_unchecked ON bid_expectations(checked, created_at);
CREATE INDEX IF NOT EXISTS idx_bid_rollback_unchecked ON bid_rollback_snapshots(rollback_triggered, created_at);
CREATE INDEX IF NOT EXISTS idx_emergency_state_active ON emergency_state(is_active);
