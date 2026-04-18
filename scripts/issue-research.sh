#!/usr/bin/env bash
# issue-research.sh — Send a research question to GPT Researcher and return the report.
#
# Usage: bash scripts/issue-research.sh "<research question>"
#
# Outputs the report text to stdout.
# Exit codes:
#   0 — report received
#   1 — GPT Researcher unreachable or returned error
#
# Requires: curl, jq

set -euo pipefail

GPT_RESEARCHER_URL="${GPT_RESEARCHER_URL:-http://192.168.30.64:8002}"
QUESTION="${1:?Usage: issue-research.sh \"<research question>\"}"

# Submit research request (up to 10 min timeout)
response=$(curl -s --max-time 600 -X POST "$GPT_RESEARCHER_URL/report/" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg task "$QUESTION" '{
    task: $task,
    report_type: "research_report",
    report_source: "web",
    tone: "Objective",
    repo_name: "",
    branch_name: "",
    generate_in_background: false
  }')" 2>&1) || {
  echo "ERROR: GPT Researcher unreachable at $GPT_RESEARCHER_URL" >&2
  exit 1
}

# Extract report field
report=$(echo "$response" | jq -r '.report // empty')

if [ -z "$report" ]; then
  echo "ERROR: GPT Researcher returned no report" >&2
  echo "Raw response: $response" >&2
  exit 1
fi

# Cap report length to avoid burning model iterations on summarization.
# GPT Researcher reports can be 5000+ words; the model only needs the
# key findings to distill into a comment.
MAX_CHARS="${2:-3000}"
if [ ${#report} -gt "$MAX_CHARS" ]; then
  echo "${report:0:$MAX_CHARS}"
  echo ""
  echo "[Report truncated at $MAX_CHARS chars — full report was ${#report} chars]"
else
  echo "$report"
fi
