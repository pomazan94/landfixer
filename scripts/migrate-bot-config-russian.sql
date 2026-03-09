-- ============================================
-- МИГРАЦИЯ: Перевод bot_config на русский язык
-- Обновляет label и description для всех строк
-- Запуск: psql -f scripts/migrate-bot-config-russian.sql
-- ============================================

BEGIN;

-- ── Умный биддер ──
UPDATE bot_config SET label = 'Макс. изменений ставок в день', description = 'Максимальное количество изменений ставки на объявление в день' WHERE category = 'smart_bidder' AND key = 'max_bid_changes_per_day';
UPDATE bot_config SET label = 'Мин. пауза между изменениями (ч)', description = 'Минимум часов между изменениями ставки одного объявления' WHERE category = 'smart_bidder' AND key = 'min_cooldown_hours';
UPDATE bot_config SET label = 'Макс. кумулятивное снижение', description = 'Макс. суммарное снижение ставки за день (0.5 = 50%)' WHERE category = 'smart_bidder' AND key = 'max_cumulative_change_down';
UPDATE bot_config SET label = 'Макс. кумулятивное повышение', description = 'Макс. суммарное повышение ставки за день (2.0 = в 2 раза)' WHERE category = 'smart_bidder' AND key = 'max_cumulative_change_up';
UPDATE bot_config SET label = 'Мин. расход для решения ($)', description = 'Минимальный расход перед принятием решений по ставке' WHERE category = 'smart_bidder' AND key = 'min_spend_for_decision';
UPDATE bot_config SET label = 'Мин. расход для остановки ($)', description = 'Минимальный расход перед рассмотрением СТОП' WHERE category = 'smart_bidder' AND key = 'min_spend_for_stop';
UPDATE bot_config SET label = 'Мин. кликов для остановки', description = 'Минимум кликов перед разрешением действия СТОП' WHERE category = 'smart_bidder' AND key = 'min_clicks_for_stop';
UPDATE bot_config SET label = 'Дней для анализа статистики', description = 'Количество дней для сбора статистики' WHERE category = 'smart_bidder' AND key = 'stats_lookback_days';
UPDATE bot_config SET label = 'Объявлений за запрос API', description = 'Количество объявлений за один запрос к Geozo API' WHERE category = 'smart_bidder' AND key = 'api_fetch_count';

-- Уровни эскалации
UPDATE bot_config SET label = 'L1: Множитель мягкой коррекции', description = 'Множитель ставки на уровне 1 эскалации (-8%)' WHERE category = 'smart_bidder' AND key = 'escalation_l1_multiplier';
UPDATE bot_config SET label = 'L1: Пауза после коррекции (ч)', description = 'Часы паузы после коррекции L1' WHERE category = 'smart_bidder' AND key = 'escalation_l1_cooldown';
UPDATE bot_config SET label = 'L2: Множитель умеренной коррекции', description = 'Множитель ставки на уровне 2 эскалации (-15%)' WHERE category = 'smart_bidder' AND key = 'escalation_l2_multiplier';
UPDATE bot_config SET label = 'L2: Пауза после коррекции (ч)', description = 'Часы паузы после коррекции L2' WHERE category = 'smart_bidder' AND key = 'escalation_l2_cooldown';
UPDATE bot_config SET label = 'L3: Множитель агрессивной коррекции', description = 'Множитель ставки на уровне 3 эскалации (-25%)' WHERE category = 'smart_bidder' AND key = 'escalation_l3_multiplier';
UPDATE bot_config SET label = 'L3: Пауза после коррекции (ч)', description = 'Часы паузы после коррекции L3' WHERE category = 'smart_bidder' AND key = 'escalation_l3_cooldown';
UPDATE bot_config SET label = 'L2: Порог CPL (множитель)', description = 'Активация L2 при CPL > maxCPL * значение' WHERE category = 'smart_bidder' AND key = 'escalation_l2_cpl_threshold';
UPDATE bot_config SET label = 'L3: Порог CPL (множитель)', description = 'Активация L3 при CPL > maxCPL * значение' WHERE category = 'smart_bidder' AND key = 'escalation_l3_cpl_threshold';
UPDATE bot_config SET label = 'Макс. неудач эскалации', description = 'Количество провалов до полной остановки' WHERE category = 'smart_bidder' AND key = 'escalation_max_failures';

-- Логика повышения ставок для прибыльных
UPDATE bot_config SET label = 'Повышение % (высокая прибыль)', description = 'Повысить ставку на X% при высокой прибыли (CPL < 0.5*maxCPL)' WHERE category = 'smart_bidder' AND key = 'profitable_raise_high_pct';
UPDATE bot_config SET label = 'Потолок повышения (высокая)', description = 'Макс. повышение для высокоприбыльных' WHERE category = 'smart_bidder' AND key = 'profitable_raise_high_cap';
UPDATE bot_config SET label = 'Повышение % (хорошая прибыль)', description = 'Повысить ставку на X% при хорошей прибыли (CPL < 0.75*maxCPL)' WHERE category = 'smart_bidder' AND key = 'profitable_raise_good_pct';
UPDATE bot_config SET label = 'Потолок повышения (хорошая)', description = 'Макс. повышение для хорошего CPL' WHERE category = 'smart_bidder' AND key = 'profitable_raise_good_cap';
UPDATE bot_config SET label = 'Мин. лидов для высокого повышения', description = 'Минимум лидов для повышения при высокой прибыли' WHERE category = 'smart_bidder' AND key = 'profitable_min_leads_high';
UPDATE bot_config SET label = 'Мин. лидов для хорошего повышения', description = 'Минимум лидов для повышения при хорошей прибыли' WHERE category = 'smart_bidder' AND key = 'profitable_min_leads_good';
UPDATE bot_config SET label = 'Коэфф. CPL (высокая прибыль)', description = 'CPL <= maxCPL * коэфф. = высокая прибыль' WHERE category = 'smart_bidder' AND key = 'profitable_cpl_ratio_high';
UPDATE bot_config SET label = 'Коэфф. CPL (хорошая прибыль)', description = 'CPL <= maxCPL * коэфф. = хорошая прибыль' WHERE category = 'smart_bidder' AND key = 'profitable_cpl_ratio_good';

-- ── Мультипликаторы времени ──
UPDATE bot_config SET label = 'Начало вечера (час)', description = 'Час начала вечернего периода (дешёвый аукцион)' WHERE category = 'time_multipliers' AND key = 'evening_start';
UPDATE bot_config SET label = 'Конец вечера (час)', description = 'Час окончания вечернего периода' WHERE category = 'time_multipliers' AND key = 'evening_end';
UPDATE bot_config SET label = 'Вечерний множитель', description = 'Множитель ставки вечером (дешёвый аукцион)' WHERE category = 'time_multipliers' AND key = 'evening_multiplier';
UPDATE bot_config SET label = 'Начало ночи (час)', description = 'Час начала ночного периода (мало трафика)' WHERE category = 'time_multipliers' AND key = 'night_start';
UPDATE bot_config SET label = 'Конец ночи (час)', description = 'Час окончания ночного периода' WHERE category = 'time_multipliers' AND key = 'night_end';
UPDATE bot_config SET label = 'Ночной множитель', description = 'Множитель ставки ночью' WHERE category = 'time_multipliers' AND key = 'night_multiplier';
UPDATE bot_config SET label = 'Начало утра (час)', description = 'Час начала утреннего периода (дорогой аукцион)' WHERE category = 'time_multipliers' AND key = 'morning_start';
UPDATE bot_config SET label = 'Конец утра (час)', description = 'Час окончания утреннего периода' WHERE category = 'time_multipliers' AND key = 'morning_end';
UPDATE bot_config SET label = 'Утренний множитель', description = 'Множитель ставки утром' WHERE category = 'time_multipliers' AND key = 'morning_multiplier';
UPDATE bot_config SET label = 'Дневной множитель', description = 'Множитель ставки днём (по умолчанию)' WHERE category = 'time_multipliers' AND key = 'afternoon_multiplier';

-- ── Фазы прогрева ──
UPDATE bot_config SET label = 'Фаза 0: макс. расход ($)', description = 'Макс. расход для Фазы 0 (устанавливается макс. ставка)' WHERE category = 'warmup' AND key = 'phase0_max_spend';
UPDATE bot_config SET label = 'Фаза 1: макс. расход ($)', description = 'Макс. расход для Фазы 1 (сбор данных)' WHERE category = 'warmup' AND key = 'phase1_max_spend';
UPDATE bot_config SET label = 'Фаза 2: макс. расход ($)', description = 'Макс. расход для Фазы 2 (оценка)' WHERE category = 'warmup' AND key = 'phase2_max_spend';
UPDATE bot_config SET label = 'Фаза 1: порог кликов (мёртвый)', description = 'Кликов меньше этого при показах > порога = мёртвый креатив' WHERE category = 'warmup' AND key = 'phase1_dead_clicks';
UPDATE bot_config SET label = 'Фаза 1: порог показов (мёртвый)', description = 'Показов больше этого при кликах < порога = мёртвый креатив' WHERE category = 'warmup' AND key = 'phase1_dead_shows';
UPDATE bot_config SET label = 'Фаза 2: низкий CTR (%)', description = 'CTR ниже этого в Фазе 2 = остановка' WHERE category = 'warmup' AND key = 'phase2_low_ctr';
UPDATE bot_config SET label = 'Фаза 2: мин. показов', description = 'Минимум показов для оценки CTR в Фазе 2' WHERE category = 'warmup' AND key = 'phase2_min_shows';

-- ── Пороги классификации ROI ──
UPDATE bot_config SET label = 'Порог ВЫСОКАЯ прибыль (%)', description = 'ROI выше этого = ВЫСОКАЯ ПРИБЫЛЬ' WHERE category = 'roi_classification' AND key = 'profit_high_threshold';
UPDATE bot_config SET label = 'Порог ПРИБЫЛЬ (%)', description = 'ROI выше этого = ПРИБЫЛЬ' WHERE category = 'roi_classification' AND key = 'profit_threshold';
UPDATE bot_config SET label = 'Порог УБЫТОК (%)', description = 'ROI ниже 0, но выше этого = УБЫТОК' WHERE category = 'roi_classification' AND key = 'losing_threshold';
UPDATE bot_config SET label = 'Порог СЛИВАЕТ (%)', description = 'ROI ниже УБЫТКА, но выше этого = СЛИВАЕТ' WHERE category = 'roi_classification' AND key = 'burning_threshold';
UPDATE bot_config SET label = 'Мин. расход для КРИТИЧЕСКОГО ($)', description = 'Минимальный расход для статуса КРИТИЧЕСКИЙ' WHERE category = 'roi_classification' AND key = 'critical_min_spend';

-- ── Аварийный контроллер ──
UPDATE bot_config SET label = 'Дневной бюджет ($)', description = 'Максимальный дневной расход до аварийного режима' WHERE category = 'emergency' AND key = 'daily_budget';
UPDATE bot_config SET label = 'Критический баланс ($)', description = 'Баланс ниже этого = АВАРИЙНАЯ ОСТАНОВКА' WHERE category = 'emergency' AND key = 'min_balance_critical';
UPDATE bot_config SET label = 'Баланс предупреждения ($)', description = 'Баланс ниже этого = ПРЕДУПРЕЖДЕНИЕ' WHERE category = 'emergency' AND key = 'min_balance_warning';
UPDATE bot_config SET label = 'Макс. изменений ставок в час', description = 'Больше этого = подозрительная активность' WHERE category = 'emergency' AND key = 'max_bid_changes_per_hour';
UPDATE bot_config SET label = 'Порог критических аномалий', description = 'Количество нерешённых критических аномалий для аварии' WHERE category = 'emergency' AND key = 'critical_anomaly_threshold';
UPDATE bot_config SET label = 'Бюджет: порог аварии (%)', description = 'Использование бюджета (%) для аварийного режима' WHERE category = 'emergency' AND key = 'budget_emergency_pct';
UPDATE bot_config SET label = 'Бюджет: порог консервативного (%)', description = 'Использование бюджета (%) для консервативного режима' WHERE category = 'emergency' AND key = 'budget_conservative_pct';
UPDATE bot_config SET label = 'Мин. часов осталось (предупр.)', description = 'Часов осталось менее этого = предупреждение' WHERE category = 'emergency' AND key = 'min_hours_remaining_warning';
UPDATE bot_config SET label = 'Автоотключение аварии (ч)', description = 'Часов до автоматического отключения аварийного режима' WHERE category = 'emergency' AND key = 'emergency_auto_deactivate_hours';
UPDATE bot_config SET label = 'Длительность консервативного (мин)', description = 'Время блокировки консервативного режима' WHERE category = 'emergency' AND key = 'conservative_lock_minutes';
UPDATE bot_config SET label = 'Размер пачки при аварии', description = 'Количество объявлений в пачке при аварийной остановке' WHERE category = 'emergency' AND key = 'emergency_stop_batch_size';

-- ── Наблюдатель баланса ──
UPDATE bot_config SET label = 'Мин. баланс для алерта ($)', description = 'Оповещение при балансе ниже этого' WHERE category = 'balance' AND key = 'min_balance_alert';
UPDATE bot_config SET label = 'Мало часов (предупреждение)', description = 'Оповещение при остатке часов ниже этого' WHERE category = 'balance' AND key = 'low_hours_warning';

-- ── Детектор аномалий ──
UPDATE bot_config SET label = 'Порог стд. отклонений', description = 'Количество стандартных отклонений для обнаружения аномалии' WHERE category = 'anomaly' AND key = 'std_dev_threshold';
UPDATE bot_config SET label = 'Дней скользящего среднего', description = 'Количество дней для скользящего среднего' WHERE category = 'anomaly' AND key = 'rolling_avg_days';

-- ── Позиции ──
UPDATE bot_config SET label = 'Порог ТОП-позиции', description = 'Позиция <= этого считается ТОП' WHERE category = 'position' AND key = 'top_position_threshold';
UPDATE bot_config SET label = 'Порог хорошей позиции', description = 'Позиция <= этого считается ХОРОШЕЙ' WHERE category = 'position' AND key = 'good_position_threshold';
UPDATE bot_config SET label = 'Глубина анализа позиций (ч)', description = 'Часов назад для анализа данных позиций' WHERE category = 'position' AND key = 'lookback_hours';

-- ── Расписания воркфлоу ──
UPDATE bot_config SET label = 'Сбор статистики (мин)', description = 'Как часто забирать статистику из Geozo' WHERE category = 'schedules' AND key = 'stats_puller_interval';
UPDATE bot_config SET label = 'Проверка баланса (мин)', description = 'Как часто проверять баланс' WHERE category = 'schedules' AND key = 'balance_watchdog_interval';
UPDATE bot_config SET label = 'Умный биддер (мин)', description = 'Как часто запускать оптимизацию ставок' WHERE category = 'schedules' AND key = 'smart_bidder_interval';
UPDATE bot_config SET label = 'Бюджет-пейсер (мин)', description = 'Как часто запускать распределение бюджета' WHERE category = 'schedules' AND key = 'budget_pacer_interval';
UPDATE bot_config SET label = 'Генерация картинок (мин)', description = 'Как часто генерировать изображения' WHERE category = 'schedules' AND key = 'image_factory_interval';
UPDATE bot_config SET label = 'Загрузчик тизеров (мин)', description = 'Как часто загружать тизеры' WHERE category = 'schedules' AND key = 'uploader_interval';
UPDATE bot_config SET label = 'A/B тестирование (мин)', description = 'Как часто оценивать A/B тесты' WHERE category = 'schedules' AND key = 'ab_tester_interval';
UPDATE bot_config SET label = 'Детектор аномалий (мин)', description = 'Как часто запускать обнаружение аномалий' WHERE category = 'schedules' AND key = 'anomaly_detector_interval';
UPDATE bot_config SET label = 'Сканер позиций (мин)', description = 'Как часто сканировать позиции объявлений' WHERE category = 'schedules' AND key = 'position_scanner_interval';
UPDATE bot_config SET label = 'Движок восстановления (мин)', description = 'Как часто пытаться восстановить объявления' WHERE category = 'schedules' AND key = 'recovery_engine_interval';
UPDATE bot_config SET label = 'Проверка результатов ставок (мин)', description = 'Как часто проверять ожидания по ставкам' WHERE category = 'schedules' AND key = 'bid_outcome_interval';
UPDATE bot_config SET label = 'Аварийный контроллер (мин)', description = 'Как часто запускать аварийные проверки' WHERE category = 'schedules' AND key = 'emergency_interval';
UPDATE bot_config SET label = 'Движок откатов (мин)', description = 'Как часто проверять необходимость отката' WHERE category = 'schedules' AND key = 'rollback_engine_interval';

-- ── Общие настройки ──
UPDATE bot_config SET label = 'Ставка по умолчанию ($)', description = 'Начальная ставка для новых объявлений' WHERE category = 'general' AND key = 'default_bid';
UPDATE bot_config SET label = 'Потолок ставки ($)', description = 'Глобальный максимум ставки' WHERE category = 'general' AND key = 'max_bid_ceiling';
UPDATE bot_config SET label = 'Часовой пояс', description = 'Системный часовой пояс' WHERE category = 'general' AND key = 'timezone';
UPDATE bot_config SET label = 'Telegram Chat ID', description = 'Чат Telegram для уведомлений' WHERE category = 'general' AND key = 'telegram_chat_id';

-- ── Детекция мёртвых креативов ──
UPDATE bot_config SET label = 'Мин. показов без кликов', description = 'Порог показов при минимуме кликов для признания мёртвым' WHERE category = 'dead_creative' AND key = 'min_shows_no_clicks';
UPDATE bot_config SET label = 'Макс. кликов (мёртвый)', description = 'Если кликов меньше при показах выше порога = мёртвый' WHERE category = 'dead_creative' AND key = 'max_clicks_dead';

-- ── Настройки отката ──
UPDATE bot_config SET label = 'Порог для отката (ч)', description = 'Часов после которых проверяется необходимость отката' WHERE category = 'rollback' AND key = 'threshold_hours';
UPDATE bot_config SET label = 'Окно измерения (ч)', description = 'Временное окно для оценки результатов изменения ставки' WHERE category = 'rollback' AND key = 'measurement_window_hours';

-- ── Фоллбэк-выплаты ──
UPDATE bot_config SET label = 'Средняя выплата по умолч. ($)', description = 'Фоллбэк-выплата для неизвестных гео' WHERE category = 'default_payout' AND key = 'avg_payout';
UPDATE bot_config SET label = 'Средний апрув по умолч.', description = 'Фоллбэк-апрув для неизвестных гео' WHERE category = 'default_payout' AND key = 'avg_approval';
UPDATE bot_config SET label = 'Мин. ставка по умолч. ($)', description = 'Фоллбэк-мин. ставка для неизвестных гео' WHERE category = 'default_payout' AND key = 'min_bid';
UPDATE bot_config SET label = 'Макс. ставка по умолч. ($)', description = 'Фоллбэк-макс. ставка для неизвестных гео' WHERE category = 'default_payout' AND key = 'max_bid';

-- Обновить updated_at для всех строк
UPDATE bot_config SET updated_at = NOW();

COMMIT;

-- Проверка: показать все строки после обновления
SELECT category, key, label, description FROM bot_config ORDER BY category, id;
