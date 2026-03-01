#!/bin/bash
# Создаёт дополнительные БД для второго (и последующих) n8n-инстансов
# Запускается автоматически при первом старте PostgreSQL

set -e

# Создаём БД для второго n8n-инстанса
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE n8n2'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'n8n2')\gexec
EOSQL

echo "Database n8n2 created (or already exists)"
