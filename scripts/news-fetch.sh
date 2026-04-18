#!/bin/bash
# news-fetch.sh - Fetch unread articles from Taiwan News and International News categories
# Usage: bash scripts/news-fetch.sh [max]

source "$(dirname "$0")/freshrss-auth.sh"

MAX="${1:-80}"

# Taiwan News feeds: 中央社 (19), 公視 (20)
# International News feeds: BBC (21), Google News World (22)
TAIWAN_FEEDS=("19" "20")
INTERNATIONAL_FEEDS=("21" "22")

# Temporary file to collect all items
TEMP_FILE=$(mktemp)

# Fetch from all feeds
for feed_id in "${TAIWAN_FEEDS[@]}"; do
    curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/stream/contents/feed/$feed_id?n=$MAX&xt=user/-/state/com.google/reading-list&output=json" \
        -H "Authorization: GoogleLogin auth=$FRESHRSS_AUTH" > "$TEMP_FILE.tw$feed_id"
done

for feed_id in "${INTERNATIONAL_FEEDS[@]}"; do
    curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/stream/contents/feed/$feed_id?n=$MAX&xt=user/-/state/com.google/reading-list&output=json" \
        -H "Authorization: GoogleLogin auth=$FRESHRSS_AUTH" > "$TEMP_FILE.int$feed_id"
done

# Process and output as JSON array with category info
python3 -c "
import json
import os

temp_prefix = '$TEMP_FILE'
TAIWAN_FEEDS = ['中央社', '公視']

all_articles = []

# Process Taiwan feeds
for feed_id in ['19', '20']:
    filepath = f'{temp_prefix}.tw{feed_id}'
    if not os.path.exists(filepath):
        continue
    
    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
        
        for item in data.get('items', []):
            feed_orig = item.get('origin', {})
            feed_title = feed_orig.get('title', 'Unknown')
            
            content = item.get('content', {}).get('content', '')
            if not content:
                content = item.get('summary', {}).get('content', '')
            snippet = content[:500] if content else ''
            
            all_articles.append({
                'id': item.get('id', ''),
                'title': item.get('title', 'Untitled'),
                'feed': feed_title,
                'category': 'taiwan',
                'published': item.get('published', ''),
                'snippet': snippet
            })
    except:
        continue

# Process International feeds
for feed_id in ['21', '22']:
    filepath = f'{temp_prefix}.int{feed_id}'
    if not os.path.exists(filepath):
        continue
    
    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
        
        for item in data.get('items', []):
            feed_orig = item.get('origin', {})
            feed_title = feed_orig.get('title', 'Unknown')
            
            content = item.get('content', {}).get('content', '')
            if not content:
                content = item.get('summary', {}).get('content', '')
            snippet = content[:500] if content else ''
            
            all_articles.append({
                'id': item.get('id', ''),
                'title': item.get('title', 'Untitled'),
                'feed': feed_title,
                'category': 'international',
                'published': item.get('published', ''),
                'snippet': snippet
            })
    except:
        continue

print(json.dumps(all_articles, ensure_ascii=False, indent=2))
"

# Clean up temp files
rm -f "$TEMP_FILE".tw* "$TEMP_FILE".int*
