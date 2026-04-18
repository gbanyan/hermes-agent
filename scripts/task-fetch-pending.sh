#!/usr/bin/env bash
# task-fetch-pending.sh — Fetch ONE pending task from Memos, or ONE stuck running task.
#
# Checks stuck tasks first (#task/running older than 30 min), then #task/pending.
# Priority: #task/prio/high > normal > #task/prio/low, then oldest first.
#
# Outputs JSON: {"name", "content", "createTime", "type": "pending|stuck", "task_type": "fetch|classify|research|draft|general"}
# Or "NO_CANDIDATES"
#
# Requires: MEMOS_URL, MEMOS_TOKEN, curl, jq

set -euo pipefail

if [ -z "${MEMOS_URL:-}" ]; then echo "ERROR: MEMOS_URL not set" >&2; exit 2; fi
if [ -z "${MEMOS_TOKEN:-}" ]; then echo "ERROR: MEMOS_TOKEN not set" >&2; exit 2; fi
if ! command -v jq &>/dev/null; then echo "ERROR: jq required" >&2; exit 2; fi

BASE="${MEMOS_URL%/}"
AUTH="Authorization: Bearer $MEMOS_TOKEN"
STUCK_THRESHOLD=1800  # 30 minutes in seconds
NOW=$(date +%s)

all_memos=$(curl -s -H "$AUTH" "$BASE/api/v1/memos?pageSize=100&filter=visibilities%20%3D%3D%20%5B%22PRIVATE%22%5D")

# Check for stuck tasks first (#task/running)
stuck=$(echo "$all_memos" | jq --argjson now "$NOW" --argjson thresh "$STUCK_THRESHOLD" '
  [.memos // [] | .[] |
    select(.content | test("#task/running")) |
    {name: .name, content: .content[0:2000], createTime: .createTime,
     age_secs: ($now - (.createTime | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 // 0))} |
    select(.age_secs > $thresh)
  ] | first // empty |
  if . then . + {type: "stuck"} else empty end
')

if [ -n "$stuck" ] && [ "$stuck" != "null" ]; then
  # Detect task type
  task_type=$(echo "$stuck" | jq -r '
    if (.content | test("#task/type/fetch")) then "fetch"
    elif (.content | test("#task/type/classify")) then "classify"
    elif (.content | test("#task/type/research")) then "research"
    elif (.content | test("#task/type/draft")) then "draft"
    else "general" end
  ')
  echo "$stuck" | jq --arg tt "$task_type" '. + {task_type: $tt}'
  exit 0
fi

# Then check pending tasks, sorted by priority
pending=$(echo "$all_memos" | jq '
  [.memos // [] | .[] |
    select(.content | test("#task/pending")) |
    {name: .name, content: .content[0:2000], createTime: .createTime,
     prio: (if (.content | test("#task/prio/high")) then 0
            elif (.content | test("#task/prio/low")) then 2
            else 1 end)}
  ] | sort_by(.prio, .createTime) | first // empty |
  if . then . + {type: "pending"} else empty end
')

if [ -z "$pending" ] || [ "$pending" = "null" ]; then
  echo "NO_CANDIDATES"
  exit 1
fi

# Detect task type
task_type=$(echo "$pending" | jq -r '
  if (.content | test("#task/type/fetch")) then "fetch"
  elif (.content | test("#task/type/classify")) then "classify"
  elif (.content | test("#task/type/research")) then "research"
  elif (.content | test("#task/type/draft")) then "draft"
  else "general" end
')
echo "$pending" | jq --arg tt "$task_type" '. + {task_type: $tt}'
