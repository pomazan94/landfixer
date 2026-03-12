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
DROP TABLE IF EXISTS ad_groups CASCADE;
DROP TABLE IF EXISTS campaigns CASCADE;

-- ============================================
-- TABLES
-- ============================================

CREATE TABLE campaigns (
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

CREATE TABLE ad_groups (
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
    geozo_status_id INTEGER,
    short_description TEXT,
    bot_intent VARCHAR(100),
    bot_intent_reason TEXT,
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
    campaign_name VARCHAR(255),
    group_ad_name VARCHAR(255),
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
    timezone INT DEFAULT 3,
    accept_language TEXT,
    render_domain TEXT,
    block_uuids JSONB,
    extra_params JSONB,
    last_scan_at TIMESTAMPTZ,
    last_error TEXT,
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
    render_domain TEXT,
    short_description TEXT,
    full_description TEXT,
    button_text TEXT,
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

-- Умный биддер
INSERT INTO bot_config (category, key, value, value_type, label, description, min_value, max_value) VALUES
    ('smart_bidder', 'max_bid_changes_per_day', '3', 'integer', 'Макс. изменений ставок в день', 'Максимальное количество изменений ставки на объявление в день', '1', '20'),
    ('smart_bidder', 'min_cooldown_hours', '2', 'number', 'Мин. пауза между изменениями (ч)', 'Минимум часов между изменениями ставки одного объявления', '0.5', '24'),
    ('smart_bidder', 'max_cumulative_change_down', '0.5', 'number', 'Макс. кумулятивное снижение', 'Макс. суммарное снижение ставки за день (0.5 = 50%)', '0.1', '1.0'),
    ('smart_bidder', 'max_cumulative_change_up', '2.0', 'number', 'Макс. кумулятивное повышение', 'Макс. суммарное повышение ставки за день (2.0 = в 2 раза)', '1.0', '10.0'),
    ('smart_bidder', 'min_spend_for_decision', '200', 'number', 'Мин. расход для решения ($)', 'Минимальный расход перед принятием решений по ставке', '10', '2000'),
    ('smart_bidder', 'min_spend_for_stop', '600', 'number', 'Мин. расход для остановки ($)', 'Минимальный расход перед рассмотрением СТОП', '50', '5000'),
    ('smart_bidder', 'min_clicks_for_stop', '500', 'integer', 'Мин. кликов для остановки', 'Минимум кликов перед разрешением действия СТОП', '50', '5000'),
    ('smart_bidder', 'stats_lookback_days', '3', 'integer', 'Дней для анализа статистики', 'Количество дней для сбора статистики', '1', '30'),
    ('smart_bidder', 'api_fetch_count', '500', 'integer', 'Объявлений за запрос API', 'Количество объявлений за один запрос к Geozo API', '50', '1000'),
    -- Уровни эскалации
    ('smart_bidder', 'escalation_l1_multiplier', '0.92', 'number', 'L1: Множитель мягкой коррекции', 'Множитель ставки на уровне 1 эскалации (-8%)', '0.5', '0.99'),
    ('smart_bidder', 'escalation_l1_cooldown', '2', 'number', 'L1: Пауза после коррекции (ч)', 'Часы паузы после коррекции L1', '1', '24'),
    ('smart_bidder', 'escalation_l2_multiplier', '0.85', 'number', 'L2: Множитель умеренной коррекции', 'Множитель ставки на уровне 2 эскалации (-15%)', '0.5', '0.99'),
    ('smart_bidder', 'escalation_l2_cooldown', '4', 'number', 'L2: Пауза после коррекции (ч)', 'Часы паузы после коррекции L2', '1', '24'),
    ('smart_bidder', 'escalation_l3_multiplier', '0.75', 'number', 'L3: Множитель агрессивной коррекции', 'Множитель ставки на уровне 3 эскалации (-25%)', '0.3', '0.99'),
    ('smart_bidder', 'escalation_l3_cooldown', '6', 'number', 'L3: Пауза после коррекции (ч)', 'Часы паузы после коррекции L3', '1', '48'),
    ('smart_bidder', 'escalation_l2_cpl_threshold', '1.3', 'number', 'L2: Порог CPL (множитель)', 'Активация L2 при CPL > maxCPL * значение', '1.0', '5.0'),
    ('smart_bidder', 'escalation_l3_cpl_threshold', '2.0', 'number', 'L3: Порог CPL (множитель)', 'Активация L3 при CPL > maxCPL * значение', '1.5', '10.0'),
    ('smart_bidder', 'escalation_max_failures', '3', 'integer', 'Макс. неудач эскалации', 'Количество провалов до полной остановки', '1', '10'),
    -- Логика повышения ставок для прибыльных
    ('smart_bidder', 'profitable_raise_high_pct', '0.15', 'number', 'Повышение % (высокая прибыль)', 'Повысить ставку на X% при высокой прибыли (CPL < 0.5*maxCPL)', '0.05', '0.50'),
    ('smart_bidder', 'profitable_raise_high_cap', '0.30', 'number', 'Потолок повышения (высокая)', 'Макс. повышение для высокоприбыльных', '0.10', '1.0'),
    ('smart_bidder', 'profitable_raise_good_pct', '0.10', 'number', 'Повышение % (хорошая прибыль)', 'Повысить ставку на X% при хорошей прибыли (CPL < 0.75*maxCPL)', '0.05', '0.50'),
    ('smart_bidder', 'profitable_raise_good_cap', '0.20', 'number', 'Потолок повышения (хорошая)', 'Макс. повышение для хорошего CPL', '0.05', '0.50'),
    ('smart_bidder', 'profitable_min_leads_high', '3', 'integer', 'Мин. лидов для высокого повышения', 'Минимум лидов для повышения при высокой прибыли', '1', '50'),
    ('smart_bidder', 'profitable_min_leads_good', '2', 'integer', 'Мин. лидов для хорошего повышения', 'Минимум лидов для повышения при хорошей прибыли', '1', '50'),
    ('smart_bidder', 'profitable_cpl_ratio_high', '0.5', 'number', 'Коэфф. CPL (высокая прибыль)', 'CPL <= maxCPL * коэфф. = высокая прибыль', '0.1', '1.0'),
    ('smart_bidder', 'profitable_cpl_ratio_good', '0.75', 'number', 'Коэфф. CPL (хорошая прибыль)', 'CPL <= maxCPL * коэфф. = хорошая прибыль', '0.3', '1.0'),
    -- Мультипликаторы времени
    ('time_multipliers', 'evening_start', '19', 'integer', 'Начало вечера (час)', 'Час начала вечернего периода (дешёвый аукцион)', '0', '23'),
    ('time_multipliers', 'evening_end', '2', 'integer', 'Конец вечера (час)', 'Час окончания вечернего периода', '0', '23'),
    ('time_multipliers', 'evening_multiplier', '1.5', 'number', 'Вечерний множитель', 'Множитель ставки вечером (дешёвый аукцион)', '0.5', '3.0'),
    ('time_multipliers', 'night_start', '2', 'integer', 'Начало ночи (час)', 'Час начала ночного периода (мало трафика)', '0', '23'),
    ('time_multipliers', 'night_end', '8', 'integer', 'Конец ночи (час)', 'Час окончания ночного периода', '0', '23'),
    ('time_multipliers', 'night_multiplier', '0.7', 'number', 'Ночной множитель', 'Множитель ставки ночью', '0.1', '3.0'),
    ('time_multipliers', 'morning_start', '8', 'integer', 'Начало утра (час)', 'Час начала утреннего периода (дорогой аукцион)', '0', '23'),
    ('time_multipliers', 'morning_end', '12', 'integer', 'Конец утра (час)', 'Час окончания утреннего периода', '0', '23'),
    ('time_multipliers', 'morning_multiplier', '0.8', 'number', 'Утренний множитель', 'Множитель ставки утром', '0.1', '3.0'),
    ('time_multipliers', 'afternoon_multiplier', '1.0', 'number', 'Дневной множитель', 'Множитель ставки днём (по умолчанию)', '0.1', '3.0'),
    -- Фазы прогрева
    ('warmup', 'phase0_max_spend', '10', 'number', 'Фаза 0: макс. расход ($)', 'Макс. расход для Фазы 0 (устанавливается макс. ставка)', '1', '100'),
    ('warmup', 'phase1_max_spend', '100', 'number', 'Фаза 1: макс. расход ($)', 'Макс. расход для Фазы 1 (сбор данных)', '10', '500'),
    ('warmup', 'phase2_max_spend', '300', 'number', 'Фаза 2: макс. расход ($)', 'Макс. расход для Фазы 2 (оценка)', '50', '1000'),
    ('warmup', 'phase1_dead_clicks', '10', 'integer', 'Фаза 1: порог кликов (мёртвый)', 'Кликов меньше этого при показах > порога = мёртвый креатив', '1', '100'),
    ('warmup', 'phase1_dead_shows', '3000', 'integer', 'Фаза 1: порог показов (мёртвый)', 'Показов больше этого при кликах < порога = мёртвый креатив', '500', '50000'),
    ('warmup', 'phase2_low_ctr', '0.1', 'number', 'Фаза 2: низкий CTR (%)', 'CTR ниже этого в Фазе 2 = остановка', '0.01', '1.0'),
    ('warmup', 'phase2_min_shows', '5000', 'integer', 'Фаза 2: мин. показов', 'Минимум показов для оценки CTR в Фазе 2', '1000', '50000'),
    -- Пороги классификации ROI
    ('roi_classification', 'profit_high_threshold', '100', 'number', 'Порог ВЫСОКАЯ прибыль (%)', 'ROI выше этого = ВЫСОКАЯ ПРИБЫЛЬ', '50', '500'),
    ('roi_classification', 'profit_threshold', '50', 'number', 'Порог ПРИБЫЛЬ (%)', 'ROI выше этого = ПРИБЫЛЬ', '10', '200'),
    ('roi_classification', 'losing_threshold', '-30', 'number', 'Порог УБЫТОК (%)', 'ROI ниже 0, но выше этого = УБЫТОК', '-90', '0'),
    ('roi_classification', 'burning_threshold', '-50', 'number', 'Порог СЛИВАЕТ (%)', 'ROI ниже УБЫТКА, но выше этого = СЛИВАЕТ', '-99', '0'),
    ('roi_classification', 'critical_min_spend', '3', 'number', 'Мин. расход для КРИТИЧЕСКОГО ($)', 'Минимальный расход для статуса КРИТИЧЕСКИЙ', '0.5', '50'),
    -- Аварийный контроллер
    ('emergency', 'daily_budget', '200', 'number', 'Дневной бюджет ($)', 'Максимальный дневной расход до аварийного режима', '10', '10000'),
    ('emergency', 'min_balance_critical', '5', 'number', 'Критический баланс ($)', 'Баланс ниже этого = АВАРИЙНАЯ ОСТАНОВКА', '1', '100'),
    ('emergency', 'min_balance_warning', '20', 'number', 'Баланс предупреждения ($)', 'Баланс ниже этого = ПРЕДУПРЕЖДЕНИЕ', '5', '200'),
    ('emergency', 'max_bid_changes_per_hour', '30', 'integer', 'Макс. изменений ставок в час', 'Больше этого = подозрительная активность', '5', '200'),
    ('emergency', 'critical_anomaly_threshold', '3', 'integer', 'Порог критических аномалий', 'Количество нерешённых критических аномалий для аварии', '1', '20'),
    ('emergency', 'budget_emergency_pct', '95', 'number', 'Бюджет: порог аварии (%)', 'Использование бюджета (%) для аварийного режима', '50', '100'),
    ('emergency', 'budget_conservative_pct', '80', 'number', 'Бюджет: порог консервативного (%)', 'Использование бюджета (%) для консервативного режима', '30', '95'),
    ('emergency', 'min_hours_remaining_warning', '4', 'number', 'Мин. часов осталось (предупр.)', 'Часов осталось менее этого = предупреждение', '1', '24'),
    ('emergency', 'emergency_auto_deactivate_hours', '2', 'number', 'Автоотключение аварии (ч)', 'Часов до автоматического отключения аварийного режима', '0.5', '24'),
    ('emergency', 'conservative_lock_minutes', '30', 'integer', 'Длительность консервативного (мин)', 'Время блокировки консервативного режима', '5', '120'),
    ('emergency', 'emergency_stop_batch_size', '50', 'integer', 'Размер пачки при аварии', 'Количество объявлений в пачке при аварийной остановке', '10', '500'),
    -- Наблюдатель баланса
    ('balance', 'min_balance_alert', '10', 'number', 'Мин. баланс для алерта ($)', 'Оповещение при балансе ниже этого', '1', '100'),
    ('balance', 'low_hours_warning', '6', 'number', 'Мало часов (предупреждение)', 'Оповещение при остатке часов ниже этого', '1', '24'),
    -- Детектор аномалий
    ('anomaly', 'std_dev_threshold', '3', 'number', 'Порог стд. отклонений', 'Количество стандартных отклонений для обнаружения аномалии', '1', '10'),
    ('anomaly', 'rolling_avg_days', '7', 'integer', 'Дней скользящего среднего', 'Количество дней для скользящего среднего', '3', '30'),
    -- Позиции
    ('position', 'top_position_threshold', '2', 'integer', 'Порог ТОП-позиции', 'Позиция <= этого считается ТОП', '1', '5'),
    ('position', 'good_position_threshold', '5', 'integer', 'Порог хорошей позиции', 'Позиция <= этого считается ХОРОШЕЙ', '1', '10'),
    ('position', 'lookback_hours', '24', 'integer', 'Глубина анализа позиций (ч)', 'Часов назад для анализа данных позиций', '1', '72'),
    -- Расписания воркфлоу (минуты)
    ('schedules', 'stats_puller_interval', '15', 'integer', 'Сбор статистики (мин)', 'Как часто забирать статистику из Geozo', '5', '60'),
    ('schedules', 'balance_watchdog_interval', '60', 'integer', 'Проверка баланса (мин)', 'Как часто проверять баланс', '15', '180'),
    ('schedules', 'smart_bidder_interval', '30', 'integer', 'Умный биддер (мин)', 'Как часто запускать оптимизацию ставок', '15', '120'),
    ('schedules', 'budget_pacer_interval', '120', 'integer', 'Бюджет-пейсер (мин)', 'Как часто запускать распределение бюджета', '30', '360'),
    ('schedules', 'image_factory_interval', '60', 'integer', 'Генерация картинок (мин)', 'Как часто генерировать изображения', '30', '360'),
    ('schedules', 'uploader_interval', '60', 'integer', 'Загрузчик тизеров (мин)', 'Как часто загружать тизеры', '30', '360'),
    ('schedules', 'ab_tester_interval', '240', 'integer', 'A/B тестирование (мин)', 'Как часто оценивать A/B тесты', '60', '720'),
    ('schedules', 'anomaly_detector_interval', '60', 'integer', 'Детектор аномалий (мин)', 'Как часто запускать обнаружение аномалий', '15', '180'),
    ('schedules', 'position_scanner_interval', '120', 'integer', 'Сканер позиций (мин)', 'Как часто сканировать позиции объявлений', '60', '360'),
    ('schedules', 'recovery_engine_interval', '240', 'integer', 'Движок восстановления (мин)', 'Как часто пытаться восстановить объявления', '60', '720'),
    ('schedules', 'bid_outcome_interval', '60', 'integer', 'Проверка результатов ставок (мин)', 'Как часто проверять ожидания по ставкам', '30', '180'),
    ('schedules', 'emergency_interval', '15', 'integer', 'Аварийный контроллер (мин)', 'Как часто запускать аварийные проверки', '5', '60'),
    ('schedules', 'rollback_engine_interval', '60', 'integer', 'Движок откатов (мин)', 'Как часто проверять необходимость отката', '30', '180'),
    -- Общие настройки
    ('general', 'default_bid', '0.01', 'number', 'Ставка по умолчанию ($)', 'Начальная ставка для новых объявлений', '0.001', '1.0'),
    ('general', 'max_bid_ceiling', '0.10', 'number', 'Потолок ставки ($)', 'Глобальный максимум ставки', '0.01', '1.0'),
    ('general', 'timezone', 'Europe/Moscow', 'string', 'Часовой пояс', 'Системный часовой пояс', NULL, NULL),
    ('general', 'telegram_chat_id', '591828204', 'string', 'Telegram Chat ID', 'Чат Telegram для уведомлений', NULL, NULL),
    -- Детекция мёртвых креативов
    ('dead_creative', 'min_shows_no_clicks', '5000', 'integer', 'Мин. показов без кликов', 'Порог показов при минимуме кликов для признания мёртвым', '500', '50000'),
    ('dead_creative', 'max_clicks_dead', '10', 'integer', 'Макс. кликов (мёртвый)', 'Если кликов меньше при показах выше порога = мёртвый', '1', '100'),
    -- Настройки отката
    ('rollback', 'threshold_hours', '2', 'integer', 'Порог для отката (ч)', 'Часов после которых проверяется необходимость отката', '1', '12'),
    ('rollback', 'measurement_window_hours', '4', 'integer', 'Окно измерения (ч)', 'Временное окно для оценки результатов изменения ставки', '1', '24'),
    -- Фоллбэк-выплаты (по умолчанию)
    ('default_payout', 'avg_payout', '1350', 'number', 'Средняя выплата по умолч. ($)', 'Фоллбэк-выплата для неизвестных гео', '100', '5000'),
    ('default_payout', 'avg_approval', '0.055', 'number', 'Средний апрув по умолч.', 'Фоллбэк-апрув для неизвестных гео', '0.01', '0.50'),
    ('default_payout', 'min_bid', '0.01', 'number', 'Мин. ставка по умолч. ($)', 'Фоллбэк-мин. ставка для неизвестных гео', '0.001', '0.50'),
    ('default_payout', 'max_bid', '0.15', 'number', 'Макс. ставка по умолч. ($)', 'Фоллбэк-макс. ставка для неизвестных гео', '0.01', '1.0'),
    -- DataImpulse Proxy
    ('proxy', 'dataimpulse_login', '', 'string', 'DataImpulse логин', 'Логин от DataImpulse аккаунта', NULL, NULL),
    ('proxy', 'dataimpulse_password', '', 'password', 'DataImpulse пароль', 'Пароль от DataImpulse аккаунта', NULL, NULL),
    ('proxy', 'dataimpulse_host', 'gw.dataimpulse.com', 'string', 'DataImpulse хост', 'Gateway хост прокси', NULL, NULL),
    ('proxy', 'dataimpulse_port', '823', 'integer', 'DataImpulse порт', 'Gateway порт прокси', '1', '65535'),
    ('proxy', 'dataimpulse_proxy_type', 'datacenter', 'string', 'Тип прокси', 'datacenter или residential', NULL, NULL);

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
CREATE INDEX idx_campaigns_campaign_id ON campaigns(campaign_id);
CREATE INDEX idx_ad_groups_ad_group_id ON ad_groups(ad_group_id);
CREATE INDEX idx_ad_groups_campaign_id ON ad_groups(campaign_id);
CREATE INDEX idx_teasers_ad_id ON teasers(ad_id);
CREATE UNIQUE INDEX idx_teasers_ad_id_uniq ON teasers(ad_id) WHERE ad_id IS NOT NULL;
CREATE INDEX idx_teasers_ad_group_id ON teasers(ad_group_id);
CREATE INDEX idx_teasers_campaign_id ON teasers(campaign_id);
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
