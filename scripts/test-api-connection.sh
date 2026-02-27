#!/bin/bash

# Test connectivity to Geozo API
# Usage: ./scripts/test-api-connection.sh
#
# Requires GEOZO_API_BASE_URL and GEOZO_API_TOKEN environment variables
# or .env file in project root

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

# Load .env if exists
if [ -f "$PROJECT_DIR/.env" ]; then
  echo "Loading .env file..."
  set -a
  source "$PROJECT_DIR/.env"
  set +a
fi

API_URL="${GEOZO_API_BASE_URL:-https://api.geozo.com/v1}"
API_TOKEN="${GEOZO_API_TOKEN:-}"

echo "=== Geozo API Connection Test ==="
echo "API URL: $API_URL"
echo ""

if [ -z "$API_TOKEN" ]; then
  echo "Error: GEOZO_API_TOKEN is not set."
  echo "Set it in .env file or export GEOZO_API_TOKEN=your_token"
  exit 1
fi

# Test 1: Balance endpoint
echo -n "1. Testing /advertiser/balance... "
response=$(curl -s -w "\n%{http_code}" \
  -H "Private-Token: $API_TOKEN" \
  "$API_URL/advertiser/balance" 2>&1)

http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" = "200" ]; then
  echo "OK (HTTP 200)"
  echo "   Response: $body"
else
  echo "FAILED (HTTP $http_code)"
  echo "   Response: $body"
fi
echo ""

# Test 2: Campaigns endpoint
echo -n "2. Testing /advertiser/campaigns... "
response=$(curl -s -w "\n%{http_code}" \
  -H "Private-Token: $API_TOKEN" \
  "$API_URL/advertiser/campaigns?per_page=1" 2>&1)

http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" = "200" ]; then
  echo "OK (HTTP 200)"
else
  echo "FAILED (HTTP $http_code)"
fi
echo ""

# Test 3: Stats endpoint
echo -n "3. Testing /advertiser/stats/tmp_with_postbacks... "
today=$(date +%Y-%m-%d)
response=$(curl -s -w "\n%{http_code}" \
  -H "Private-Token: $API_TOKEN" \
  "$API_URL/advertiser/stats/tmp_with_postbacks?filters[date_from]=$today&filters[date_to]=$today&per_page=1" 2>&1)

http_code=$(echo "$response" | tail -1)

if [ "$http_code" = "200" ]; then
  echo "OK (HTTP 200)"
else
  echo "FAILED (HTTP $http_code)"
fi
echo ""

# Test 4: Targeting endpoint
echo -n "4. Testing /targeting/countries... "
response=$(curl -s -w "\n%{http_code}" \
  -H "Private-Token: $API_TOKEN" \
  "$API_URL/targeting/countries" 2>&1)

http_code=$(echo "$response" | tail -1)

if [ "$http_code" = "200" ]; then
  echo "OK (HTTP 200)"
else
  echo "FAILED (HTTP $http_code)"
fi
echo ""

echo "=== Test Complete ==="
