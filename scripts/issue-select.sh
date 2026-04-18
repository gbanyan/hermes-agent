#!/usr/bin/env bash
# issue-select.sh — Pick one open needs-research issue from Gitea.
#
# Selection policy:
#   1. Prefer issues whose latest activity is at least STALE_DAYS old
#   2. Among those, pick the oldest by latest activity timestamp
#   3. If none are that stale, fall back to the oldest created issue
#
# Outputs a single JSON object to stdout:
#   {
#     "repo": "...",
#     "number": N,
#     "title": "...",
#     "body": "...",
#     "last_comment": "..." or null,
#     "last_comment_author": "..." or null,
#     "last_comment_at": "..." or null,
#     "previous_comment": "..." or null,
#     "previous_comment_at": "..." or null,
#     "days_since_activity": N,
#     "selection_reason": "stale_activity" | "oldest_fallback"
#   }
#
# Exit codes:
#   0 — candidate found (JSON on stdout)
#   1 — no candidates (prints "NO_CANDIDATES" to stdout)
#   2 — error (prints error message to stderr)
#
# Requires: GITEA_TOKEN env var, curl, jq, python3

set -euo pipefail

GITEA_URL="https://git.gbanyan.net"
OWNER="gbanyan"
STALE_DAYS="${1:-3}"  # prefer issues whose latest activity is at least this old

if [ -z "${GITEA_TOKEN:-}" ]; then
  echo "ERROR: GITEA_TOKEN not set" >&2
  exit 2
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed" >&2
  exit 2
fi

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is required but not installed" >&2
  exit 2
fi

AUTH="Authorization: token $GITEA_TOKEN"
API="$GITEA_URL/api/v1"

append_paginated_array() {
  local url="$1"
  local page=1
  local result='[]'
  local sep='?'

  if [[ "$url" == *\?* ]]; then
    sep='&'
  fi

  while true; do
    local batch
    batch=$(curl -s -H "$AUTH" "${url}${sep}limit=100&page=$page")

    local count
    count=$(echo "$batch" | jq 'if type == "array" then length else 0 end')
    if [ "$count" -eq 0 ]; then
      break
    fi

    result=$(jq -n --argjson a "$result" --argjson b "$batch" '$a + $b')
    if [ "$count" -lt 100 ]; then
      break
    fi
    page=$((page + 1))
  done

  echo "$result"
}

to_epoch() {
  local ts="${1:-}"
  if [ -z "$ts" ] || [ "$ts" = "null" ]; then
    return 0
  fi

  python3 - "$ts" <<'PY'
import sys
from datetime import datetime

raw = sys.argv[1]
try:
    normalized = raw.replace("Z", "+00:00")
    dt = datetime.fromisoformat(normalized)
except ValueError:
    sys.exit(1)
print(int(dt.timestamp()))
PY
}

# Step 1: Get all repos with open issues
repos=$(curl -s -H "$AUTH" "$API/repos/search?owner=$OWNER&limit=50" \
  | jq -r '.data[] | select(.open_issues_count > 0) | .name')

if [ -z "$repos" ]; then
  echo "NO_CANDIDATES"
  exit 1
fi

# Step 2: For each repo, fetch needs-research issues
candidates='[]'
now_epoch=$(date "+%s")

for repo in $repos; do
  issues=$(curl -s -H "$AUTH" \
    "$API/repos/$OWNER/$repo/issues?state=open&type=issues&labels=needs-research&limit=50")

  # Parse each issue
  count=$(echo "$issues" | jq 'length')
  for ((i=0; i<count; i++)); do
    number=$(echo "$issues" | jq -r ".[$i].number")
    title=$(echo "$issues" | jq -r ".[$i].title")
    body=$(echo "$issues" | jq -r ".[$i].body // \"\"" | head -c 2000)
    created_at=$(echo "$issues" | jq -r ".[$i].created_at // empty")
    updated_at=$(echo "$issues" | jq -r ".[$i].updated_at // empty")

    # Step 3: Read the issue's full comment history.
    comments=$(append_paginated_array "$API/repos/$OWNER/$repo/issues/$number/comments")

    # Latest visible comment, regardless of whether it is a research update.
    last_comment=$(echo "$comments" | jq -r '
      sort_by(.created_at) | last // empty | .body // empty
    ')
    last_comment_at=$(echo "$comments" | jq -r '
      sort_by(.created_at) | last // empty | .created_at // empty
    ')
    last_comment_author=$(echo "$comments" | jq -r '
      sort_by(.created_at) | last // empty | .user.login // empty
    ')

    # Preserve the cumulative-summary context from the latest research comment.
    research_comment=$(echo "$comments" | jq -r '
      [.[] | select(.body | startswith("[Research Update"))] | sort_by(.created_at) | last // empty | .body // empty
    ')
    research_date=$(echo "$comments" | jq -r '
      [.[] | select(.body | startswith("[Research Update"))] | sort_by(.created_at) | last // empty | .created_at // empty
    ')

    # Use latest issue activity for scheduling. If there are comments, prefer the
    # latest comment timestamp; otherwise fall back to the issue's updated_at or
    # created_at timestamp.
    activity_at="$last_comment_at"
    if [ -z "$activity_at" ] || [ "$activity_at" = "null" ]; then
      activity_at="$updated_at"
    fi
    if [ -z "$activity_at" ] || [ "$activity_at" = "null" ]; then
      activity_at="$created_at"
    fi

    activity_epoch=$(to_epoch "$activity_at" || echo "")
    created_epoch=$(to_epoch "$created_at" || echo "")
    if [ -z "$activity_epoch" ] || [ -z "$created_epoch" ]; then
      continue
    fi

    days_since_activity=$(( (now_epoch - activity_epoch) / 86400 ))
    if [ "$days_since_activity" -ge "$STALE_DAYS" ]; then
      selection_reason="stale_activity"
      selection_rank=0
    else
      selection_reason="oldest_fallback"
      selection_rank=1
    fi

    # Build candidate JSON.
    prev_comment="null"
    if [ -n "$research_comment" ]; then
      prev_comment=$(echo "$research_comment" | jq -Rs .)
    fi

    prev_comment_at="null"
    if [ -n "$research_date" ] && [ "$research_date" != "null" ]; then
      prev_comment_at=$(jq -Rn --arg v "$research_date" '$v')
    fi

    last_comment_json="null"
    if [ -n "$last_comment" ]; then
      last_comment_json=$(echo "$last_comment" | jq -Rs .)
    fi

    last_comment_at_json="null"
    if [ -n "$last_comment_at" ] && [ "$last_comment_at" != "null" ]; then
      last_comment_at_json=$(jq -Rn --arg v "$last_comment_at" '$v')
    fi

    last_comment_author_json="null"
    if [ -n "$last_comment_author" ] && [ "$last_comment_author" != "null" ]; then
      last_comment_author_json=$(jq -Rn --arg v "$last_comment_author" '$v')
    fi

    candidate=$(jq -n \
      --arg repo "$repo" \
      --argjson number "$number" \
      --arg title "$title" \
      --arg body "$body" \
      --argjson last_comment "$last_comment_json" \
      --argjson last_comment_author "$last_comment_author_json" \
      --argjson last_comment_at "$last_comment_at_json" \
      --argjson prev "$prev_comment" \
      --argjson prev_at "$prev_comment_at" \
      --argjson days "$days_since_activity" \
      --arg selection_reason "$selection_reason" \
      --argjson selection_rank "$selection_rank" \
      --argjson created_epoch "$created_epoch" \
      --argjson activity_epoch "$activity_epoch" \
      '{
        repo: $repo,
        number: $number,
        title: $title,
        body: $body,
        last_comment: $last_comment,
        last_comment_author: $last_comment_author,
        last_comment_at: $last_comment_at,
        previous_comment: $prev,
        previous_comment_at: $prev_at,
        days_since_activity: $days,
        selection_reason: $selection_reason,
        _selection_rank: $selection_rank,
        _created_epoch: $created_epoch,
        _activity_epoch: $activity_epoch
      }')

    candidates=$(echo "$candidates" | jq --argjson c "$candidate" '. + [$c]')
  done
done

# Step 4: Pick the best candidate.
count=$(echo "$candidates" | jq 'length')

if [ "$count" -eq 0 ]; then
  echo "NO_CANDIDATES"
  exit 1
fi

best=$(echo "$candidates" | jq '
  sort_by(
    ._selection_rank,
    if ._selection_rank == 0 then ._activity_epoch else ._created_epoch end,
    .repo,
    .number
  ) | .[0] |
  del(._selection_rank, ._created_epoch, ._activity_epoch)
')

echo "$best"
