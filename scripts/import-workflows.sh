#!/bin/bash

# Import all workflow JSON files into n8n via CLI
# Usage: ./scripts/import-workflows.sh
#
# Prerequisites:
# - n8n must be running
# - n8n CLI must be available (npm install -g n8n)
# - Or use the n8n API directly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOWS_DIR="$SCRIPT_DIR/../workflows"
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"

echo "=== n8n Workflow Importer ==="
echo "Workflows dir: $WORKFLOWS_DIR"
echo "n8n URL: $N8N_URL"
echo ""

# Check if workflows directory exists
if [ ! -d "$WORKFLOWS_DIR" ]; then
  echo "Error: Workflows directory not found: $WORKFLOWS_DIR"
  exit 1
fi

# Count workflow files
WORKFLOW_COUNT=$(ls -1 "$WORKFLOWS_DIR"/*.json 2>/dev/null | wc -l)
if [ "$WORKFLOW_COUNT" -eq 0 ]; then
  echo "No workflow files found in $WORKFLOWS_DIR"
  exit 0
fi

echo "Found $WORKFLOW_COUNT workflow files."
echo ""

# Import each workflow via n8n API
IMPORTED=0
FAILED=0

for workflow_file in "$WORKFLOWS_DIR"/*.json; do
  filename=$(basename "$workflow_file")
  echo -n "Importing $filename... "

  if [ -n "$N8N_API_KEY" ]; then
    # Use n8n REST API
    response=$(curl -s -w "\n%{http_code}" \
      -X POST "$N8N_URL/api/v1/workflows" \
      -H "Content-Type: application/json" \
      -H "X-N8N-API-KEY: $N8N_API_KEY" \
      -d @"$workflow_file" 2>&1)

    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | head -n -1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
      echo "OK"
      IMPORTED=$((IMPORTED + 1))
    else
      echo "FAILED (HTTP $http_code)"
      FAILED=$((FAILED + 1))
    fi
  else
    # Use n8n CLI if available
    if command -v n8n &>/dev/null; then
      if n8n import:workflow --input="$workflow_file" 2>/dev/null; then
        echo "OK"
        IMPORTED=$((IMPORTED + 1))
      else
        echo "FAILED"
        FAILED=$((FAILED + 1))
      fi
    else
      echo "SKIPPED (no API key and n8n CLI not found)"
      echo ""
      echo "Set N8N_API_KEY environment variable or install n8n CLI."
      echo "  export N8N_API_KEY=your_api_key"
      echo "  npm install -g n8n"
      exit 1
    fi
  fi
done

echo ""
echo "=== Import Summary ==="
echo "Total: $WORKFLOW_COUNT"
echo "Imported: $IMPORTED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
