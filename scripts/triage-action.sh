#!/bin/bash
# triage-action.sh - Mark articles as read / star (batch operation)
# Usage: echo '{"markRead":["id1","id2"],"star":["id3"]}' | bash scripts/triage-action.sh

source "$(dirname "$0")/freshrss-auth.sh"

AUTH="${FRESHRSS_AUTH:-}"

# Read JSON from stdin
INPUT=$(cat)

# Parse and execute actions using Python
echo "$INPUT" | python3 -c "
import sys, json, subprocess, os

data = json.load(sys.stdin)
auth = os.environ.get('FRESHRSS_AUTH', '')

results = {'marked': [], 'starred': [], 'errors': []}

# Mark as read
for article_id in data.get('markRead', []):
    try:
        # Use Google Reader API edit endpoint
        cmd = ['curl', '-s', '-X', 'POST',
               'https://freshrss.gbanyan.net/api/greader.php/reader/api/0/edit-item',
               '-H', 'Authorization: GoogleLogin auth=' + auth,
               '-d', f'a=user/-/state/com.google/reading-list',
               '-d', f'i={article_id}']
        subprocess.run(cmd, check=True, capture_output=True)
        results['marked'].append(article_id)
    except Exception as e:
        results['errors'].append(f'markRead {article_id}: {e}')

# Star articles
for article_id in data.get('star', []):
    try:
        cmd = ['curl', '-s', '-X', 'POST',
               'https://freshrss.gbanyan.net/api/greader.php/reader/api/0/edit-item',
               '-H', 'Authorization: GoogleLogin auth=' + auth,
               '-d', 'a=user/-/state/com.google/starred',
               '-d', f'i={article_id}']
        subprocess.run(cmd, check=True, capture_output=True)
        results['starred'].append(article_id)
    except Exception as e:
        results['errors'].append(f'star {article_id}: {e}')

print(json.dumps(results, indent=2))
"
