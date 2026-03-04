-- ============================================
-- TEST DATA - для проверки всего flow
-- ============================================
-- Сценарии:
--   Teaser 1001: active, хороший ROI, немного дней данных → Smart Bidder должен оставить
--   Teaser 1002: active, высокий CPL → Smart Bidder должен понизить ставку / эскалация
--   Teaser 1003: active, warmup фаза 1 → Smart Bidder должен продвинуть warmup
--   Teaser 1004: paused_low_ctr, пауза 25 часов → Recovery Engine должен подобрать
--   Teaser 1005: active, подозрение на ботов (много кликов, 0 конверсий) → Anomaly Detector
--   Teaser 1006: active, A/B тест variant A
--   Teaser 1007: active, A/B тест variant B (лучше)

-- ============================================
-- TEASERS
-- ============================================
INSERT INTO teasers (id, ad_id, ad_group_id, campaign_id, account_id, title, original_url, status, bid, state, state_changed_at, state_reason, warmup_phase, escalation_level, escalation_failures, bid_changes_today, bid_changes_reset_date, cumulative_bid_change_today, total_spend_lifetime, created_at)
VALUES
  -- Хороший тизер, активный, стабильный
  (1, 1001, 100, 10, 1, 'Bitcoin Reaches New Heights in 2026', 'https://landing.example.com/btc-gb', 'uploaded', 0.08, 'active', NOW() - INTERVAL '5 days', 'uploaded and moderated', 4, 0, 0, 0, CURRENT_DATE, 1.0, 120.00, NOW() - INTERVAL '7 days'),

  -- Плохой тизер, высокий CPL, нужна эскалация
  (2, 1002, 100, 10, 1, 'Crypto Millionaire Secret Method', 'https://landing.example.com/crypto-de', 'uploaded', 0.10, 'active', NOW() - INTERVAL '3 days', 'uploaded and moderated', 4, 1, 2, 1, CURRENT_DATE, 1.1, 85.00, NOW() - INTERVAL '5 days'),

  -- Новый тизер на warmup фазе 1
  (3, 1003, 101, 10, 1, 'Elon Musk Reveals New Investment Platform', 'https://landing.example.com/elon-fr', 'uploaded', 0.10, 'active', NOW() - INTERVAL '6 hours', 'warmup phase 1', 1, 0, 0, 0, CURRENT_DATE, 1.0, 5.00, NOW() - INTERVAL '8 hours'),

  -- Паузнутый тизер, ждёт recovery
  (4, 1004, 100, 10, 1, 'EU Regulator Approves Bitcoin Trading', 'https://landing.example.com/eu-it', 'uploaded', 0.06, 'paused_low_ctr', NOW() - INTERVAL '25 hours', 'CTR below threshold for 3 consecutive checks', 4, 2, 1, 0, CURRENT_DATE, 1.0, 45.00, NOW() - INTERVAL '10 days'),

  -- Ботовый трафик - anomaly detector должен поймать
  (5, 1005, 102, 11, 1, 'Trading Robot Makes $5000 Daily', 'https://landing.example.com/robot-es', 'uploaded', 0.07, 'active', NOW() - INTERVAL '2 days', 'uploaded and moderated', 4, 0, 0, 0, CURRENT_DATE, 1.0, 60.00, NOW() - INTERVAL '4 days'),

  -- A/B тест вариант A
  (6, 1006, 103, 12, 1, 'Swiss Bank Launches Crypto Service', 'https://landing.example.com/swiss-a', 'uploaded', 0.09, 'testing', NOW() - INTERVAL '3 days', 'A/B test variant A', 4, 0, 0, 0, CURRENT_DATE, 1.0, 30.00, NOW() - INTERVAL '3 days'),

  -- A/B тест вариант B (лучше)
  (7, 1007, 103, 12, 1, 'Swiss Banks Now Accept Bitcoin Deposits', 'https://landing.example.com/swiss-b', 'uploaded', 0.09, 'testing', NOW() - INTERVAL '3 days', 'A/B test variant B', 4, 0, 0, 0, CURRENT_DATE, 1.0, 28.00, NOW() - INTERVAL '3 days')

ON CONFLICT (id) DO NOTHING;

-- ============================================
-- AD_STATS - последние 7 дней
-- ============================================

-- Teaser 1001: хороший, стабильный (GB, max_cpl = $77)
INSERT INTO ad_stats (ad_id, date, shows, clicks, money, postbacks_count, postbacks_confirmed_money, ctr, cpc, roi, profit) VALUES
  (1001, CURRENT_DATE - 6, 15000, 45, 3.60, 2, 140.00, 0.3000, 0.0800, 3788.89, 136.40),
  (1001, CURRENT_DATE - 5, 16000, 50, 4.00, 2, 140.00, 0.3125, 0.0800, 3400.00, 136.00),
  (1001, CURRENT_DATE - 4, 14500, 42, 3.36, 1, 70.00, 0.2897, 0.0800, 1983.33, 66.64),
  (1001, CURRENT_DATE - 3, 17000, 55, 4.40, 3, 210.00, 0.3235, 0.0800, 4672.73, 205.60),
  (1001, CURRENT_DATE - 2, 15500, 48, 3.84, 2, 140.00, 0.3097, 0.0800, 3545.83, 136.16),
  (1001, CURRENT_DATE - 1, 16500, 52, 4.16, 2, 140.00, 0.3152, 0.0800, 3265.38, 135.84),
  (1001, CURRENT_DATE,     8000,  25, 2.00, 1, 70.00,  0.3125, 0.0800, 3400.00, 68.00)
ON CONFLICT (ad_id, date) DO NOTHING;

-- Teaser 1002: плохой CPL, тратит деньги без конверсий (DE, max_cpl = $60)
INSERT INTO ad_stats (ad_id, date, shows, clicks, money, postbacks_count, postbacks_confirmed_money, ctr, cpc, roi, profit) VALUES
  (1002, CURRENT_DATE - 6, 12000, 35, 3.50, 1, 60.00,  0.2917, 0.1000, 1614.29, 56.50),
  (1002, CURRENT_DATE - 5, 11000, 30, 3.00, 0, 0.00,   0.2727, 0.1000, -100.00, -3.00),
  (1002, CURRENT_DATE - 4, 13000, 40, 4.00, 1, 60.00,  0.3077, 0.1000, 1400.00, 56.00),
  (1002, CURRENT_DATE - 3, 10000, 28, 2.80, 0, 0.00,   0.2800, 0.1000, -100.00, -2.80),
  (1002, CURRENT_DATE - 2, 11500, 33, 3.30, 0, 0.00,   0.2870, 0.1000, -100.00, -3.30),
  (1002, CURRENT_DATE - 1, 12500, 38, 3.80, 0, 0.00,   0.3040, 0.1000, -100.00, -3.80),
  (1002, CURRENT_DATE,     9000,  32, 3.20, 0, 0.00,   0.3556, 0.1000, -100.00, -3.20)
ON CONFLICT (ad_id, date) DO NOTHING;

-- Teaser 1003: warmup, мало данных (FR, max_cpl = $49.50)
INSERT INTO ad_stats (ad_id, date, shows, clicks, money, postbacks_count, postbacks_confirmed_money, ctr, cpc, roi, profit) VALUES
  (1003, CURRENT_DATE, 2000, 8, 0.80, 0, 0.00, 0.4000, 0.1000, -100.00, -0.80)
ON CONFLICT (ad_id, date) DO NOTHING;

-- Teaser 1004: паузнутый, был плохой CTR (IT, max_cpl = $50)
INSERT INTO ad_stats (ad_id, date, shows, clicks, money, postbacks_count, postbacks_confirmed_money, ctr, cpc, roi, profit) VALUES
  (1004, CURRENT_DATE - 6, 20000, 15, 0.90, 0, 0.00, 0.0750, 0.0600, -100.00, -0.90),
  (1004, CURRENT_DATE - 5, 22000, 18, 1.08, 0, 0.00, 0.0818, 0.0600, -100.00, -1.08),
  (1004, CURRENT_DATE - 4, 19000, 12, 0.72, 0, 0.00, 0.0632, 0.0600, -100.00, -0.72),
  (1004, CURRENT_DATE - 3, 21000, 16, 0.96, 1, 50.00, 0.0762, 0.0600, 5108.33, 49.04),
  (1004, CURRENT_DATE - 2, 18000, 10, 0.60, 0, 0.00, 0.0556, 0.0600, -100.00, -0.60)
ON CONFLICT (ad_id, date) DO NOTHING;

-- Teaser 1005: бот-трафик (ES, max_cpl = $45)
-- Сегодня: 50 кликов, 0 конверсий, $3.50 потрачено. Исторически были конверсии.
INSERT INTO ad_stats (ad_id, date, shows, clicks, money, postbacks_count, postbacks_confirmed_money, ctr, cpc, roi, profit) VALUES
  (1005, CURRENT_DATE - 6, 10000, 25, 1.75, 2, 90.00, 0.2500, 0.0700, 5042.86, 88.25),
  (1005, CURRENT_DATE - 5, 11000, 28, 1.96, 1, 45.00, 0.2545, 0.0700, 2195.92, 43.04),
  (1005, CURRENT_DATE - 4, 9500,  22, 1.54, 2, 90.00, 0.2316, 0.0700, 5744.16, 88.46),
  (1005, CURRENT_DATE - 3, 10500, 26, 1.82, 1, 45.00, 0.2476, 0.0700, 2372.53, 43.18),
  (1005, CURRENT_DATE - 2, 11500, 30, 2.10, 2, 90.00, 0.2609, 0.0700, 4185.71, 87.90),
  (1005, CURRENT_DATE - 1, 10000, 24, 1.68, 1, 45.00, 0.2400, 0.0700, 2578.57, 43.32),
  (1005, CURRENT_DATE,     3000,  50, 3.50, 0, 0.00,  1.6667, 0.0700, -100.00, -3.50)
ON CONFLICT (ad_id, date) DO NOTHING;

-- Teaser 1006: A/B вариант A (CH, max_cpl = $96)
INSERT INTO ad_stats (ad_id, date, shows, clicks, money, postbacks_count, postbacks_confirmed_money, ctr, cpc, roi, profit) VALUES
  (1006, CURRENT_DATE - 2, 8000,  22, 1.98, 1, 80.00, 0.2750, 0.0900, 3939.39, 78.02),
  (1006, CURRENT_DATE - 1, 9000,  28, 2.52, 1, 80.00, 0.3111, 0.0900, 3074.60, 77.48),
  (1006, CURRENT_DATE,     5000,  15, 1.35, 0, 0.00,  0.3000, 0.0900, -100.00, -1.35)
ON CONFLICT (ad_id, date) DO NOTHING;

-- Teaser 1007: A/B вариант B - лучше (CH, max_cpl = $96)
INSERT INTO ad_stats (ad_id, date, shows, clicks, money, postbacks_count, postbacks_confirmed_money, ctr, cpc, roi, profit) VALUES
  (1007, CURRENT_DATE - 2, 8500,  30, 2.70, 2, 160.00, 0.3529, 0.0900, 5825.93, 157.30),
  (1007, CURRENT_DATE - 1, 9200,  35, 3.15, 2, 160.00, 0.3804, 0.0900, 4979.37, 156.85),
  (1007, CURRENT_DATE,     5500,  18, 1.62, 1, 80.00,  0.3273, 0.0900, 4838.27, 78.38)
ON CONFLICT (ad_id, date) DO NOTHING;

-- ============================================
-- BID_HISTORY - история ставок
-- ============================================
INSERT INTO bid_history (id, ad_id, old_bid, new_bid, reason, rule_applied, roi_at_change, clicks_at_change, changed_at) VALUES
  (1, 1001, 0.06, 0.08, 'Initial bid set during upload', 'upload', 0, 0, NOW() - INTERVAL '7 days'),
  (2, 1002, 0.08, 0.10, 'Bid increase for more traffic', 'manual', 0, 10, NOW() - INTERVAL '5 days'),
  (3, 1002, 0.10, 0.12, 'Escalation L1 - trying higher bid', 'escalation_l1', -100, 30, NOW() - INTERVAL '3 days'),
  (4, 1002, 0.12, 0.10, 'Bid decrease - no improvement', 'smart_bidder', -100, 60, NOW() - INTERVAL '1 day'),
  (5, 1003, 0.00, 0.10, 'Warmup phase 1 - MAX bid for geo', 'warmup', 0, 0, NOW() - INTERVAL '8 hours'),
  (6, 1004, 0.08, 0.06, 'Low CTR - reducing bid', 'smart_bidder', -100, 15, NOW() - INTERVAL '2 days'),
  (7, 1005, 0.07, 0.07, 'Bid unchanged - good performance', 'no_change', 2578, 24, NOW() - INTERVAL '1 day'),
  (8, 1006, 0.09, 0.09, 'A/B test - bid locked', 'ab_test', 3939, 22, NOW() - INTERVAL '2 days'),
  (9, 1007, 0.09, 0.09, 'A/B test - bid locked', 'ab_test', 5825, 30, NOW() - INTERVAL '2 days')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- BALANCE_HISTORY - баланс аккаунта
-- ============================================
INSERT INTO balance_history (account_id, balance, spend_rate_per_hour, hours_remaining, collected_at) VALUES
  (1, 350.00, 2.50, 140.00, NOW() - INTERVAL '4 hours'),
  (1, 345.00, 2.80, 123.21, NOW() - INTERVAL '3 hours'),
  (1, 340.00, 2.60, 130.77, NOW() - INTERVAL '2 hours'),
  (1, 335.50, 2.70, 124.26, NOW() - INTERVAL '1 hour'),
  (1, 331.00, 2.50, 132.40, NOW());

-- ============================================
-- GEO_STATS - привязка тизеров к гео
-- ============================================
INSERT INTO geo_stats (ad_id, country_code, date, shows, clicks, money, postbacks_confirmed_money, roi) VALUES
  (1001, 'GB', CURRENT_DATE, 8000, 25, 2.00, 70.00, 3400.00),
  (1002, 'DE', CURRENT_DATE, 9000, 32, 3.20, 0.00, -100.00),
  (1003, 'FR', CURRENT_DATE, 2000, 8,  0.80, 0.00, -100.00),
  (1004, 'IT', CURRENT_DATE - 2, 18000, 10, 0.60, 0.00, -100.00),
  (1005, 'ES', CURRENT_DATE, 3000, 50, 3.50, 0.00, -100.00),
  (1006, 'CH', CURRENT_DATE, 5000, 15, 1.35, 0.00, -100.00),
  (1007, 'CH', CURRENT_DATE, 5500, 18, 1.62, 80.00, 4838.27);

-- ============================================
-- A/B TEST - активный тест
-- ============================================
INSERT INTO ab_tests (id, test_name, landing_url, status, generation, variants, started_at) VALUES
  (1, 'Swiss Crypto Landing v1', 'https://landing.example.com/swiss', 'running', 1,
   '[{"ad_id": 1006, "group": "A", "title": "Swiss Bank Launches Crypto Service"}, {"ad_id": 1007, "group": "B", "title": "Swiss Banks Now Accept Bitcoin Deposits"}]',
   NOW() - INTERVAL '3 days')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- TEASER_STATE_LOG - история состояний
-- ============================================
INSERT INTO teaser_state_log (ad_id, old_state, new_state, reason, triggered_by) VALUES
  (1001, 'created', 'active', 'Moderation passed, warmup complete', 'teaser_uploader'),
  (1002, 'created', 'active', 'Moderation passed, warmup complete', 'teaser_uploader'),
  (1003, 'created', 'active', 'Uploaded, warmup phase 1', 'teaser_uploader'),
  (1004, 'active', 'paused_low_ctr', 'CTR below threshold for 3 consecutive checks', 'smart_bidder'),
  (1005, 'created', 'active', 'Moderation passed, warmup complete', 'teaser_uploader'),
  (1006, 'active', 'testing', 'A/B test started', 'ab_tester'),
  (1007, 'active', 'testing', 'A/B test started', 'ab_tester');

-- ============================================
-- DAILY_PNL - P&L за предыдущие дни
-- ============================================
INSERT INTO daily_pnl (date, total_spend, total_revenue, gross_profit, roi_percent, balance_start, balance_end) VALUES
  (CURRENT_DATE - 3, 18.50, 355.00, 336.50, 1818.92, 370.00, 351.50),
  (CURRENT_DATE - 2, 15.80, 460.00, 444.20, 2811.39, 351.50, 335.70),
  (CURRENT_DATE - 1, 17.20, 415.00, 397.80, 2312.79, 335.70, 318.50)
ON CONFLICT (date) DO NOTHING;

-- ============================================
-- Готово! Теперь Smart Bidder увидит:
--   1001: прибыльный → оставить/поднять
--   1002: убыточный, $16+ потрачено без конверсий → эскалация
--   1003: warmup phase 1, мало данных → продвинуть warmup
--   1004: paused_low_ctr 25h → Recovery Engine подберёт
--   1005: 50 кликов / 0 конверсий сегодня → Anomaly Detector
--   1006/1007: A/B тест, B лучше → A/B Tester может объявить победителя
-- ============================================
