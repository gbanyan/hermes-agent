#!/usr/bin/env bash
# coffee-fetch.sh — Crawl 5 coffee chain promotion pages via Crawl4AI.
#
# Outputs combined markdown from all sources.
# Each section prefixed with [SOURCE_NAME].
#
# Requires: curl, jq, Crawl4AI on localhost:11235

set -euo pipefail

CRAWL4AI_URL="${CRAWL4AI_URL:-http://localhost:11235}"

declare -A SOURCES=(
  ["GoodLife"]="https://cafe.goodlife.tw/"
  ["Louisa"]="https://www.louisacoffee.co/news"
  ["Starbucks"]="https://www.starbucks.com.tw/stores/allevent.jspx"
  ["7-Eleven"]="https://www.citycafe.com.tw/notice.aspx"
  ["FamilyMart"]="https://www.family.com.tw/Marketing/zh/Event"
)

errors=0

for name in GoodLife Louisa Starbucks 7-Eleven FamilyMart; do
  url="${SOURCES[$name]}"
  echo "=== [$name] ==="

  response=$(curl -s --max-time 30 -X POST "$CRAWL4AI_URL/crawl" \
    -H "Content-Type: application/json" \
    -d "{\"urls\": [\"$url\"], \"priority\": 5}" 2>&1) || {
    echo "ERROR: Failed to crawl $name ($url)"
    errors=$((errors + 1))
    echo ""
    continue
  }

  markdown=$(echo "$response" | jq -r '.results[0].markdown.raw_markdown // empty' 2>/dev/null)

  if [ -z "$markdown" ]; then
    echo "ERROR: No content returned for $name"
    errors=$((errors + 1))
  else
    # Truncate to 3000 chars per source to keep total manageable
    echo "${markdown:0:3000}"
  fi
  echo ""
done

if [ "$errors" -eq 5 ]; then
  echo "ERROR: All sources failed" >&2
  exit 1
fi
