#!/usr/bin/env bash
# issue-classify-select.sh — Find ONE unlabeled open Gitea issue.
#
# Outputs JSON: {"repo": "...", "number": N, "title": "...", "body": "..."}
# Or "NO_CANDIDATES" if none found.
#
# Requires: GITEA_TOKEN, curl, jq

set -euo pipefail

GITEA_URL="https://git.gbanyan.net"
OWNER="gbanyan"

if [ -z "${GITEA_TOKEN:-}" ]; then echo "ERROR: GITEA_TOKEN not set" >&2; exit 2; fi
if ! command -v jq &>/dev/null; then echo "ERROR: jq required" >&2; exit 2; fi

AUTH="Authorization: token $GITEA_TOKEN"
API="$GITEA_URL/api/v1"

repos=$(curl -s -H "$AUTH" "$API/repos/search?owner=$OWNER&limit=50" \
  | jq -r '.data[] | select(.open_issues_count > 0) | .name')

if [ -z "$repos" ]; then echo "NO_CANDIDATES"; exit 1; fi

for repo in $repos; do
  issues=$(curl -s -H "$AUTH" \
    "$API/repos/$OWNER/$repo/issues?state=open&type=issues&limit=50")

  # Find issues with NO labels
  candidate=$(echo "$issues" | jq -r --arg repo "$repo" '
    [.[] | select((.labels | length) == 0)] | first // empty |
    {repo: $repo, number: .number, title: .title, body: (.body // "")[0:2000]}
  ')

  if [ -n "$candidate" ] && [ "$candidate" != "null" ]; then
    echo "$candidate"
    exit 0
  fi
done

echo "NO_CANDIDATES"
exit 1
