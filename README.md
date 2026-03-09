# LandFixer

Автоматизация нативной рекламы Geozo через n8n.

## Запуск

```bash
cp .env.example .env
# Заполнить токены: GEOZO_API_TOKEN, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, CLAUDE_API_KEY
docker-compose up -d
```

| Сервис | Порт | Назначение |
|--------|------|-----------|
| n8n | 5678 | Workflow-движок |
| Admin UI | 8585 | Панель управления ботом |
| PostgreSQL | 5432 | База данных |
| Redis | 6379 | Кэш |

## Структура

```
workflows/     17 n8n workflow-ов (импорт через n8n UI)
admin-ui/      Веб-панель управления (все настройки бота)
scripts/       init-db.sql — схема БД
config/nginx/  Nginx reverse proxy сниппет
```

## Credentials в n8n

Settings → Credentials → Add:

1. **Geozo** (Header Auth): `Private-Token: <токен>`
2. **Claude** (Header Auth): `x-api-key: <ключ>`, `anthropic-version: 2023-06-01`
3. **Telegram** (Telegram API): bot token
4. **PostgreSQL**: host=postgres, db=n8n, user=n8n, pass=n8n_secret
