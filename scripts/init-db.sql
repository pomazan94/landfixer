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
    hour INTEGER,
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
    UNIQUE(ad_id, date, hour)
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
    collected_at TIMESTAMP DEFAULT NOW()
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

-- Индексы для быстрых запросов
CREATE INDEX IF NOT EXISTS idx_ad_stats_ad_date ON ad_stats(ad_id, date);
CREATE INDEX IF NOT EXISTS idx_ad_stats_date ON ad_stats(date);
CREATE INDEX IF NOT EXISTS idx_geo_stats_date ON geo_stats(date);
CREATE INDEX IF NOT EXISTS idx_block_stats_date ON block_stats(date);
CREATE INDEX IF NOT EXISTS idx_balance_history_time ON balance_history(collected_at);
CREATE INDEX IF NOT EXISTS idx_bid_history_ad ON bid_history(ad_id);
CREATE INDEX IF NOT EXISTS idx_position_tracking_time ON position_tracking(scanned_at);
CREATE INDEX IF NOT EXISTS idx_teasers_status ON teasers(status);
CREATE INDEX IF NOT EXISTS idx_anomalies_detected ON anomalies(detected_at);
CREATE INDEX IF NOT EXISTS idx_daily_pnl_date ON daily_pnl(date);
