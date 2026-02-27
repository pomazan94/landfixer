# GEOZO AUTOMATION MEGA-SYSTEM — Setup Guide

## Prerequisites

- Docker & Docker Compose
- Geozo advertiser account with API token
- Telegram bot (for alerts)
- Claude API key (for AI features)
- (Optional) Stable Diffusion API or DALL-E API for image generation
- (Optional) Proxy provider for position scanning

## Quick Start

### 1. Clone and configure

```bash
git clone <repo-url> landfixer
cd landfixer
cp .env.example .env
```

Edit `.env` with your credentials:

```
GEOZO_API_TOKEN=your_token_here
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id
CLAUDE_API_KEY=your_claude_key
```

### 2. Start infrastructure

```bash
docker-compose up -d
```

This starts:
- **n8n** on port 5678
- **PostgreSQL** on port 5432
- **Redis** on port 6379
- **Grafana** on port 3000

### 3. Test API connection

```bash
./scripts/test-api-connection.sh
```

### 4. Validate workflows

```bash
node scripts/validate-workflows.js
```

### 5. Import workflows into n8n

Option A — via n8n API:
```bash
export N8N_API_KEY=your_n8n_api_key
./scripts/import-workflows.sh
```

Option B — manual import:
1. Open n8n at http://localhost:5678
2. Go to Workflows → Import
3. Import each JSON file from `workflows/` directory

### 6. Configure n8n credentials

In n8n UI, create the following credentials:

| Credential Name | Type | Details |
|---|---|---|
| Geozo API Token | Header Auth | Name: `Private-Token`, Value: your API token |
| Claude API Key | Header Auth | Name: `x-api-key`, Value: your Claude key + `anthropic-version: 2023-06-01` |
| Telegram Bot | Telegram API | Bot token from BotFather |
| PostgreSQL | Postgres | Host: postgres, DB: n8n, User: n8n, Password: from .env |

### 7. Activate workflows

Start with MVP workflows (Phase 1):
1. **01-Stats Puller** — core monitoring
2. **02-Balance Watchdog** — balance alerts
3. **03-Smart Bidder** — auto bid management
4. **11-Daily Report** — daily summary

Then gradually enable others.

## Database

The PostgreSQL database is auto-initialized with schema from `scripts/init-db.sql`.

Key tables:
- `ad_stats` — per-ad performance metrics
- `balance_history` — balance over time
- `bid_history` — all bid change logs
- `teasers` — managed teasers
- `daily_pnl` — daily P&L tracking
- `anomalies` — detected anomalies

## Grafana

Access at http://localhost:3000 (admin/admin).
PostgreSQL datasource is auto-provisioned.

## Troubleshooting

**n8n can't connect to PostgreSQL:**
- Ensure postgres container is healthy: `docker-compose ps`
- Check logs: `docker-compose logs postgres`

**API returns 401:**
- Verify GEOZO_API_TOKEN is correct
- Check token in n8n credentials

**Telegram alerts not working:**
- Verify bot token with: `curl https://api.telegram.org/bot<TOKEN>/getMe`
- Ensure chat_id is correct (use @userinfobot in Telegram)
