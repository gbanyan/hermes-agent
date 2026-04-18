#!/bin/bash
# triage-fetch.sh - Fetch all unread articles (slim JSON)
# Usage: bash scripts/triage-fetch.sh [max_articles]

source "$(dirname "$0")/freshrss-auth.sh"

MAX="${1:-100}"
FRESHRSS_URL="${FRESHRSS_URL:-}"
AUTH="${FRESHRSS_AUTH:-}"

# Fetch unread articles via Google Reader API
# Fixed: Use URL query parameters instead of POST data (-d flags)
export MAX_ARTICLES="$MAX"
curl -s "https://freshrss.gbanyan.net/api/greader.php/reader/api/0/stream/contents/user/-/state/com.google/reading-list?n=$MAX&xt=user/-/state/com.google/reading-list&unread-only=true&ot=1" \
    -H "Authorization: GoogleLogin auth=$AUTH" | \
python3 -c "
import sys, json, os

try:
    data = json.load(sys.stdin)
    articles = data.get('items', [])
    
    # Slim down to essential fields
    result = []
    # Use MAX parameter from shell, default to 150 if not specified
    max_articles = int(os.environ.get('MAX_ARTICLES', 150))
    for a in articles[:max_articles]:
        # Extract feed title
        feed_orig = a.get('origin', {})
        feed_title = feed_orig.get('title', 'Unknown')
        
        # Extract snippet (content)
        content = a.get('content', {}).get('content', '')
        if not content:
            content = a.get('summary', {}).get('content', '')
        snippet = content[:500] if content else ''
        
        # Extract published timestamp
        published = a.get('published', '')
        
        result.append({
            'id': a.get('id', ''),
            'title': a.get('title', 'Untitled'),
            'feed': feed_title,
            'published': published,
            'snippet': snippet
        })
    
    print(json.dumps(result, ensure_ascii=False, indent=2))
except Exception as e:
    print(f'Error parsing response: {e}', file=sys.stderr)
    print(json.dumps([]))
"
