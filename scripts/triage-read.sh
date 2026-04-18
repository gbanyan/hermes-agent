#!/bin/bash
# triage-read.sh - Fetch full content of one article
# Usage: bash scripts/triage-read.sh <article_id>

source "$(dirname "$0")/freshrss-auth.sh"

ARTICLE_ID="$1"
FRESHRSS_URL="${FRESHRSS_URL:-}"
AUTH="${FRESHRSS_AUTH:-}"

if [ -z "$ARTICLE_ID" ]; then
    echo "Usage: triage-read.sh <article_id>" >&2
    exit 1
fi

# Get article details with full content
curl -s "https://freshrss.gbanyan.net/api/greader.php/reader/api/0/item" \
    -H "Authorization: GoogleLogin auth=$AUTH" \
    -d "id=$ARTICLE_ID" \
    -d "ot=1"
