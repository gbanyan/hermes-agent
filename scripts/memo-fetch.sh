#!/usr/bin/env bash
# memo-fetch.sh — Fetch memos by pipeline stage.
#
# Usage: bash scripts/memo-fetch.sh <stage> [limit]
#   stage: unenriched | unclassified | triageable
#   limit: max results (default: 1, except triageable defaults to 5)
#
# Outputs JSON array of memos, or "NO_CANDIDATES".
#
# Requires: MEMOS_URL, MEMOS_TOKEN, curl, jq

set -euo pipefail

STAGE="${1:?Usage: memo-fetch.sh <unenriched|unclassified|triageable> [limit]}"

if [ -z "${MEMOS_URL:-}" ]; then echo "ERROR: MEMOS_URL not set" >&2; exit 2; fi
if [ -z "${MEMOS_TOKEN:-}" ]; then echo "ERROR: MEMOS_TOKEN not set" >&2; exit 2; fi
if ! command -v jq &>/dev/null; then echo "ERROR: jq required" >&2; exit 2; fi

BASE="${MEMOS_URL%/}"
AUTH="Authorization: Bearer $MEMOS_TOKEN"

# Fetch recent memos (last 100)
all_memos=$(curl -s -H "$AUTH" "$BASE/api/v1/memos?pageSize=100&filter=visibility%20%3D%3D%20%22PRIVATE%22")

case "$STAGE" in
  unenriched)
    LIMIT="${2:-1}"
    # Has NO #enriched tag, skip #task/ and #reference
    selected=$(echo "$all_memos" | jq --argjson limit "$LIMIT" '
      [.memos // [] | .[] |
        select(.content | test("#enriched") | not) |
        select(.content | test("#task/") | not) |
        select(.content | test("#reference") | not) |
        select((.content | length) < 200 or (.content | test("https?://"))) |
        {name: .name, content: .content[0:1000], createTime: .createTime}
      ] | .[0:$limit]
    ')
    ;;
  unclassified)
    LIMIT="${2:-1}"
    # Has #enriched but NO #topic/
    selected=$(echo "$all_memos" | jq --argjson limit "$LIMIT" '
      [.memos // [] | .[] |
        select(.content | test("#enriched")) |
        select(.content | test("#topic/") | not) |
        select(.content | test("#reference") | not) |
        {name: .name, content: .content[0:2000], createTime: .createTime}
      ] | .[0:$limit]
    ')
    ;;
  triageable)
    LIMIT="${2:-5}"
    # Has #enriched AND #topic/ but NO #triaged, skip #task/ and #reference
    selected=$(echo "$all_memos" | jq --argjson limit "$LIMIT" '
      [.memos // [] | .[] |
        select(.content | test("#enriched")) |
        select(.content | test("#topic/")) |
        select(.content | test("#triaged") | not) |
        select(.content | test("#task/") | not) |
        select(.content | test("#reference") | not) |
        {name: .name, content: .content[0:2000], createTime: .createTime}
      ] | .[0:$limit]
    ')
    ;;
  *)
    echo "ERROR: Unknown stage '$STAGE'. Use: unenriched, unclassified, triageable" >&2
    exit 2
    ;;
esac

count=$(echo "$selected" | jq 'length')
if [ "$count" -eq 0 ]; then
  echo "NO_CANDIDATES"
  exit 1
fi

echo "$selected"
