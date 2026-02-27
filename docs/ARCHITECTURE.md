# GEOZO AUTOMATION MEGA-SYSTEM — Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    COMMAND CENTER (n8n)                       │
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ CREATOR  │  │ MONITOR  │  │ OPTIMIZER│  │ SCRAPER  │    │
│  │ 06-09    │  │ 01-02,12 │  │ 03-05,14 │  │ 15-16    │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │              │              │              │          │
│  ┌────┴──────────────┴──────────────┴──────────────┴────┐    │
│  │              MESSAGE BUS / STATE STORE                │    │
│  │              (Redis / PostgreSQL)                      │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                          │                                    │
│  ┌──────────────────────┴───────────────────────────────┐    │
│  │                  EXTERNAL APIs                        │    │
│  │  Geozo API │ Claude API │ Proxy Pool │ Image Gen     │    │
│  └──────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Modules

### Module 1: CREATOR (Workflows 06-09)
Auto-generates and uploads teasers.
- **06 - Trend Hunter**: Parses Google Trends & news RSS, generates headlines via Claude
- **07 - Image Factory**: Creates images via Stable Diffusion/DALL-E
- **08 - Uploader**: Uploads teasers to Geozo via API
- **09 - Re-moderator**: Auto-rephrases banned teasers and resubmits

### Module 2: MONITOR (Workflows 01-02, 12)
Real-time monitoring and alerting.
- **01 - Stats Puller**: Collects stats every 15 min, calculates ROI/CTR
- **02 - Balance Watchdog**: Tracks balance, spend rate, alerts on low balance
- **12 - Anomaly Detector**: Detects statistical anomalies (CTR drops, bot traffic)

### Module 3: OPTIMIZER (Workflows 03-05, 14)
Automatic bid and budget optimization.
- **03 - Smart Bidder**: Rule-based bid management (7 rules based on ROI/CTR)
- **04 - Geo Bidder**: Per-country bid optimization
- **05 - Budget Pacer**: Daily budget pacing control
- **14 - Coefficient Tuner**: OS/Browser/ISP coefficient optimization

### Module 4: SCRAPER (Workflows 15-16)
Position monitoring and competitive intelligence.
- **15 - Position Scanner**: Scans publisher sites for teaser positions
- **16 - Spy Module**: Analyzes competitor teasers and suggests improvements

### Module 5: A/B TESTING (Workflow 10)
- **10 - A/B Tester**: Creates test variants, monitors results, picks winners

### Module 6: SCALE (Workflow 17)
- **17 - Campaign Cloner**: Replicates profitable campaigns across accounts

### Module 7: REPORTING (Workflows 11, 13)
- **11 - Daily Report**: AI-generated daily P&L report
- **13 - Block Optimizer**: Blacklist/whitelist management for ad blocks

### Module 8: TIME (Workflow 18)
- **18 - Time Optimizer**: Weekly time targeting optimization via AI analysis

### Module 9: ORCHESTRATION (Workflow 19)
- **19 - Master Orchestrator**: System health check and daily status report

## Schedule

| Frequency | Workflows |
|---|---|
| Every 15 min | 01-Stats Puller |
| Every 30 min | 03-Smart Bidder, 09-Remoderator |
| Every 1 hour | 02-Balance Watchdog, 07-Image Factory, 08-Uploader, 12-Anomaly Detector |
| Every 2 hours | 05-Budget Pacer, 06-Trend Hunter, 15-Position Scanner |
| Every 4 hours | 10-AB Tester |
| Daily | 04-Geo Bidder (02:00), 11-Daily Report (23:55), 13-Block Optimizer (00:10), 16-Spy Module (04:00), 19-Orchestrator (06:00) |
| Weekly | 14-Coefficient Tuner (Mon 03:00), 18-Time Optimizer (Mon 05:00) |
| Manual | 17-Campaign Cloner |

## Data Flow

```
Geozo API → Stats Puller → PostgreSQL → Smart Bidder → Geozo API
                                      → Anomaly Detector → Telegram
                                      → Daily Report → Telegram

Trends RSS → Trend Hunter → Content Queue → Image Factory → Uploader → Geozo API

Geozo API → Re-moderator → Claude API → Geozo API

Publisher Sites → Position Scanner → PostgreSQL → Spy Module → Claude API → Telegram
```

## Tech Stack

| Component | Technology |
|---|---|
| Orchestration | n8n (self-hosted) |
| Database | PostgreSQL 16 |
| Cache/Queues | Redis 7 |
| AI | Claude API (Sonnet) |
| Images | Stable Diffusion / DALL-E |
| Dashboard | Grafana |
| Alerts | Telegram Bot API |
| Scraping | HTTP + Proxy rotation |
| Hosting | Docker Compose |
