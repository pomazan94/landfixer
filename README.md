# GEOZO AUTOMATION MEGA-SYSTEM (ТИЗЕР-МАШИНА)

Полностью автоматизированная система управления нативной рекламой на платформе Geozo через n8n.

---

## Что где лежит

```
landfixer/
│
├── docker-compose.yml          ← Запускает ВСЁ (n8n + БД + Redis + Grafana)
├── .env.example                ← Шаблон настроек (скопировать в .env)
│
├── workflows/                  ← 19 n8n workflow-ов (импортируются в n8n)
│   ├── 01-stats-puller.json       Сбор статистики (каждые 15 мин)
│   ├── 02-balance-watchdog.json   Мониторинг баланса
│   ├── 03-smart-bidder.json       Автоуправление ставками
│   ├── 04-geo-bidder.json         Оптимизация ставок по гео
│   ├── 05-budget-pacer.json       Контроль дневного бюджета
│   ├── 06-trend-hunter.json       Парсинг трендов + генерация заголовков
│   ├── 07-image-factory.json      Генерация картинок (Stable Diffusion)
│   ├── 08-uploader.json           Заливка тизеров через API
│   ├── 09-remoderator.json        Автоперефраз забаненных тизеров
│   ├── 10-ab-tester.json          A/B тестирование тизеров
│   ├── 11-daily-report.json       Ежедневный отчёт в Telegram
│   ├── 12-anomaly-detector.json   Детектор аномалий (боты, CTR-дропы)
│   ├── 13-block-optimizer.json    Чёрный/белый списки площадок
│   ├── 14-coefficient-tuner.json  Коэффициенты OS/Browser/ISP
│   ├── 15-position-scanner.json   Сканер позиций через прокси
│   ├── 16-spy-module.json         Анализ конкурентов
│   ├── 17-campaign-cloner.json    Клонирование кампаний
│   ├── 18-time-optimizer.json     Оптимизация расписания показов
│   └── 19-master-orchestrator.json  ГЛАВНЫЙ — управляет всеми остальными
│
├── scripts/
│   ├── init-db.sql             ← Схема БД (применяется автоматически)
│   ├── import-workflows.sh     ← Скрипт импорта workflows в n8n
│   ├── test-api-connection.sh  ← Проверка связи с Geozo API
│   └── validate-workflows.js   ← Валидация JSON-файлов workflows
│
├── openapi/
│   └── geozo-api.yaml          ← OpenAPI спецификация Geozo API
│
├── config/grafana/             ← Автонастройка Grafana
├── templates/                  ← Шаблоны Telegram-сообщений
└── docs/                       ← Документация
```

---

## Запуск за 5 шагов

### Шаг 1: Подготовь токены

Тебе нужны:
- **Geozo API Token** — из личного кабинета Geozo (Настройки → API)
- **Telegram Bot Token** — создай бота через [@BotFather](https://t.me/BotFather)
- **Telegram Chat ID** — узнай через [@userinfobot](https://t.me/userinfobot)
- **Claude API Key** — из [console.anthropic.com](https://console.anthropic.com)

### Шаг 2: Настрой конфиг

```bash
cd landfixer
cp .env.example .env
nano .env   # или любой редактор
```

Заполни обязательные поля:
```
GEOZO_API_TOKEN=твой_токен_geozo
TELEGRAM_BOT_TOKEN=токен_от_botfather
TELEGRAM_CHAT_ID=твой_chat_id
CLAUDE_API_KEY=sk-ant-...
```

Остальное можно оставить по умолчанию.

### Шаг 3: Запусти инфраструктуру

```bash
docker-compose up -d
```

Это поднимет:
| Сервис | Адрес | Логин |
|--------|-------|-------|
| **n8n** (управление workflows) | http://localhost:5678 | admin / changeme |
| **Grafana** (дашборды) | http://localhost:3000 | admin / admin |
| **PostgreSQL** (база данных) | localhost:5432 | n8n / n8n_secret |
| **Redis** (кэш) | localhost:6379 | — |

Проверь что всё работает:
```bash
docker-compose ps   # все сервисы должны быть Up / healthy
```

### Шаг 4: Импортируй workflows в n8n

**Вариант А — через веб-интерфейс (рекомендуется):**

1. Открой http://localhost:5678
2. Нажми **"Add workflow"** → **"Import from file"**
3. Загрузи **сначала** `workflows/19-master-orchestrator.json`
4. Потом загрузи все остальные (01-18) в любом порядке

**Вариант Б — через скрипт:**
```bash
# Сначала получи API-ключ n8n: Settings → API → Create API Key
export N8N_API_KEY=твой_n8n_api_ключ
./scripts/import-workflows.sh
```

### Шаг 5: Настрой credentials в n8n

В n8n UI: **Settings → Credentials → Add Credential**

Создай 4 credentials:

**1. Geozo API Token** (тип: Header Auth)
```
Name:  Geozo API Token
Header Name:  Private-Token
Header Value: твой_geozo_токен
```

**2. Claude API Key** (тип: Header Auth)
```
Name:  Claude API Key
Header Name:  x-api-key
Header Value: sk-ant-...

+ добавь ещё один header:
Header Name:  anthropic-version
Header Value: 2023-06-01
```

**3. Telegram Bot** (тип: Telegram API)
```
Name:  Telegram Bot
Bot Token: токен_от_botfather
```

**4. PostgreSQL** (тип: Postgres)
```
Name:  PostgreSQL
Host:  postgres
Port:  5432
Database: n8n
User:  n8n
Password: n8n_secret
```

---

## Как запускать

### Минимальный старт (MVP)

Активируй только **1 workflow** — Master Orchestrator (#19).
Он сам запустит всё остальное по расписанию.

В n8n: открой workflow `19 - Master Orchestrator` → включи тумблер **Active**.

Всё. Система работает.

### Что будет происходить

```
06:00  → Orchestrator запускает утреннюю последовательность
         → Stats Puller, Balance Watchdog, Trend Hunter,
           Image Factory, Uploader, Remoderator, Position Scanner
         → Отправляет утренний статус в Telegram

Каждые 15 мин → Stats Puller собирает статистику
Каждые 30 мин → Smart Bidder корректирует ставки
                Remoderator проверяет баны
Каждый час    → Balance Watchdog, Image Factory, Uploader,
                Anomaly Detector
Каждые 2 часа → Budget Pacer, Trend Hunter, Position Scanner
Каждые 4 часа → A/B Tester проверяет результаты

23:55  → Orchestrator запускает вечернюю последовательность
         → Daily Report, Block Optimizer, Geo Bidder, Spy Module

Понедельник 03:00 → Coefficient Tuner, Time Optimizer
```

### Ручной запуск отдельного workflow

Если нужно запустить что-то вручную:
1. Открой нужный workflow в n8n
2. Нажми **"Test workflow"** (кнопка Play)

---

## Проверка работоспособности

### 1. Проверь связь с Geozo API
```bash
./scripts/test-api-connection.sh
```

### 2. Проверь что все workflow JSON-ы валидны
```bash
node scripts/validate-workflows.js
```

### 3. Проверь логи
```bash
docker-compose logs -f n8n      # логи n8n
docker-compose logs -f postgres  # логи БД
```

### 4. Проверь БД
```bash
docker-compose exec postgres psql -U n8n -d n8n -c "SELECT COUNT(*) FROM ad_stats;"
```

---

## Устранение проблем

| Проблема | Решение |
|----------|---------|
| n8n не стартует | `docker-compose logs n8n` — посмотри ошибку |
| "Invalid credentials" в workflow | Перепроверь credentials в Settings → Credentials |
| Telegram не приходят | Проверь CHAT_ID: `curl https://api.telegram.org/bot<TOKEN>/getMe` |
| API возвращает 401 | Неверный Geozo токен — обнови в credentials |
| Workflow не запускается | Убедись что он Active (тумблер включён) |
| PostgreSQL connection refused | `docker-compose ps` — убедись что postgres healthy |

## Остановка системы

```bash
docker-compose down        # остановить всё
docker-compose down -v     # остановить + удалить данные (осторожно!)
```
