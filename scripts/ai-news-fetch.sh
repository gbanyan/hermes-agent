#!/usr/bin/env bash
# ai-news-fetch.sh — Crawl AI news sources via Crawl4AI.
#
# Outputs combined markdown from 5 sources, each prefixed with [SOURCE_NAME].
# Truncated per source to keep total manageable for model.
#
# Requires: curl, jq, Crawl4AI on localhost:11235

set -euo pipefail

CRAWL4AI_URL="${CRAWL4AI_URL:-http://localhost:11235}"
MAX_CHARS="${1:-2000}"  # per source truncation

# Use arrays instead of associative arrays for bash 3.2 compatibility
declare -a NAMES=("The Verge AI" "Wired AI" "TechCrunch AI" "Anthropic News" "MIT Tech Review")
declare -a URLS=("https://www.theverge.com/ai-artificial-intelligence" "https://www.wired.com/tag/artificial-intelligence/" "https://techcrunch.com/category/artificial-intelligence/" "https://www.anthropic.com/news" "https://www.technologyreview.com/topic/artificial-intelligence/")

errors=0

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  url="${URLS[$i]}"
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
    echo "${markdown:0:$MAX_CHARS}"
  fi
  echo ""
done

if [ "$errors" -eq 5 ]; then
  echo "ERROR: All sources failed" >&2
  exit 1
fi
