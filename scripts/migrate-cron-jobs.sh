#!/bin/bash
# Migrate OpenClaw cron jobs to Hermes
# Maps OpenClaw model names to Hermes-compatible ones:
#   github-copilot/gpt-5-mini -> (default model, hermes picks)
#   vllm-dgx/qwen3.5-122b -> litellm/qwen3.5-auto (via LiteLLM)
#   openai-codex/gpt-5.4-mini -> (default model)
#
# Delivery mapping:
#   discord channel IDs are passed directly
#   NO_REPLY pattern -> hermes [SILENT] pattern

set -e

echo "Creating 17 cron jobs in Hermes..."

# 1. openclaw-update-review (every 2 days -> "48h")
# SKIP - this was OpenClaw-specific, no longer needed
echo "SKIP: openclaw-update-review (OpenClaw-specific)"

# 2. 每日天氣預報（台南）
hermes cron create --name "每日天氣預報（台南）" \
  --deliver "discord:1481652297376202883" \
  "0 22 * * *" \
  "請查詢台南明天的天氣預報。用繁體中文簡短回覆：1) 明日天氣概況 2) 高低溫 3) 是否比今天明顯變冷或變熱 4) 是否建議帶雨傘。若有降雨機率、溫差或明顯升降溫，請主動提醒。回覆保持 3-6 句，適合直接發到 Discord 頻道。"
echo "✓ 每日天氣預報"

# 3. 每日咖啡優惠
hermes cron create --name "每日咖啡優惠" \
  --deliver "discord:1481652297376202883" \
  --skill coffee-promotions \
  "0 7 * * *" \
  "Use the coffee-promotions skill. You MUST fetch ALL 5 source URLs listed in the skill's Source Registry using web fetch. After fetching, extract structured promotions. Then merge, deduplicate, and output the final summary. All output in Traditional Chinese."
echo "✓ 每日咖啡優惠"

# 4. 每週醫美學術活動
hermes cron create --name "每週醫美學術活動" \
  --deliver "discord:1485647872899944558" \
  --skill aesthetic-medicine-events \
  "0 21 * * 0" \
  "請使用 aesthetic-medicine-events skill 回報近期台灣醫美學術活動，只列出尚未結束的活動，依學會分組輸出。"
echo "✓ 每週醫美學術活動"

# 5. 午間信箱整理
hermes cron create --name "午間信箱整理" \
  --deliver "discord:1481652297376202883" \
  --skill apple-mail-triage \
  "30 11 * * *" \
  "使用 apple-mail-triage skill 整理 iCloud 收件匣。完成分類後回報結果。"
echo "✓ 午間信箱整理"

# 6. 晚間信箱整理
hermes cron create --name "晚間信箱整理" \
  --deliver "discord:1481652297376202883" \
  --skill apple-mail-triage \
  "0 20 * * *" \
  "使用 apple-mail-triage skill 整理 iCloud 收件匣。完成分類後回報結果。"
echo "✓ 晚間信箱整理"

# 7. Issue Classifier
hermes cron create --name "Issue Classifier" \
  --deliver "discord:1482361174983970877" \
  --skill issue-classifier \
  "0 */3 * * *" \
  "If no unlabeled issues are found, begin your response with [SILENT].

請使用 issue-classifier skill 掃描 Gitea open issues，找出一個未標記的 issue，分類為 needs-research、needs-debug 或 direction 並加上 label。"
echo "✓ Issue Classifier"

# 8. Gitea Issue Researcher
hermes cron create --name "Gitea Issue Researcher" \
  --deliver "discord:1482361174983970877" \
  --skill issue-researcher \
  "30 1-5 * * *" \
  "If no needs-research issues are found, begin your response with [SILENT].

請使用 issue-researcher skill 從所有 Gitea repos 中選擇一個標記為 needs-research 的 open issue。選擇最久未研究的 issue，用 web_search 搜尋網路資訊，若有新發現則在 issue 上留言。完成後回報結果。"
echo "✓ Gitea Issue Researcher"

# 9. Memo Enrich
hermes cron create --name "Memo Enrich" \
  --deliver "discord:1481652297376202883" \
  --skill memo-enrich \
  "40 */3 * * *" \
  "If no unenriched memos are found, begin your response with [SILENT].

請使用 memo-enrich skill 找出一個未處理的 memo 並補充內容。"
echo "✓ Memo Enrich"

# 10. Memo Classify
hermes cron create --name "Memo Classify" \
  --deliver "discord:1481652297376202883" \
  --skill memo-classify \
  "50 */3 * * *" \
  "If no unclassified memos are found, begin your response with [SILENT].

請使用 memo-classify skill 找出一個已 enriched 但未分類的 memo，分析內容並加上 topic tag。"
echo "✓ Memo Classify"

# 11. AI 科技日報
hermes cron create --name "AI 科技日報" \
  --deliver "discord:1485648962965733376" \
  --skill ai-news-zh \
  "0 0 * * *" \
  "請使用 ai-news-zh skill 採集今日 AI 科技新聞，整理為繁體中文日報並推送。"
echo "✓ AI 科技日報"

# 12. 美股熱門掃描
hermes cron create --name "美股熱門掃描" \
  --deliver "discord:1485648962965733376" \
  --skill stock-analysis \
  "0 6 * * 2-6" \
  "請使用 stock-analysis skill 執行以下步驟：

1. 先執行 hot scanner 找出今日熱門股票與加密貨幣
2. 從熱門結果中挑選前 3 檔最值得關注的股票，加上 TSM，使用 --verbose 模式逐一分析
3. 用繁體中文整理報告，每檔股票包含：
   - 建議方向（BUY/HOLD/SELL）與信心度
   - 信心度拆解：哪些維度拉高、哪些拉低
   - 關鍵風險
4. 最後一段：對今日台股的整體參考意義

報告保持精簡，適合直接發到 Discord。"
echo "✓ 美股熱門掃描"

# 13. 每日肯定語
hermes cron create --name "每日肯定語" \
  --deliver "discord:1481652297376202883" \
  --skill affirmations \
  "30 8 * * *" \
  "請使用 affirmations skill 傳送今日的 3 則肯定語。用溫和務實的風格，繁體中文。如果 ~/affirmations/favorites.md 存在，混合最愛與新語句。"
echo "✓ 每日肯定語"

# 14. 醫學研究摘要
hermes cron create --name "醫學研究摘要" \
  --deliver "discord:1485647872899944558" \
  --skill medical-specialty-briefs \
  "30 7 * * *" \
  "請使用 medical-specialty-briefs skill 產生內科/家醫科研究摘要。搜尋過去 7 天 NEJM、JAMA、Lancet、BMJ 的最新文章，挑出 3 則最有臨床意義的，用繁體中文整理。專業術語保留英文原文（如 SGLT2 inhibitor、GLP-1 receptor agonist、hazard ratio 等）。每則包含：標題、一句話重點、來源、臨床相關性（🔴🟡🟢）、連結。"
echo "✓ 醫學研究摘要"

# 15. Task Executor
hermes cron create --name "Task Executor" \
  --deliver "discord:1481652297376202883" \
  --skill task-executor \
  "*/30 * * * *" \
  "If no pending tasks are found and no stuck tasks need recovery, begin your response with [SILENT].

Use the task-executor skill to process one pending task from the Memos bulletin board. First check for stuck tasks (#task/running older than 30min), then pick one #task/pending memo (highest priority first, oldest first), claim it, execute it, and post the result as a comment. Report what you did."
echo "✓ Task Executor"

# 16. 天氣異常警報
hermes cron create --name "天氣異常警報" \
  --deliver "discord:1481652297376202883" \
  "0 */4 * * *" \
  "Check Tainan (台南) current weather conditions. Only post if ANY of these conditions are met: (1) rain probability > 40%, (2) temperature change > 5°C compared to yesterday, (3) severe weather warnings (typhoon, thunderstorm, heat wave, cold front). If none of these conditions are met, begin your response with [SILENT]. If conditions are met, post a short alert in Traditional Chinese: what's happening, when, and what to prepare. Keep it under 3 sentences."
echo "✓ 天氣異常警報"

# 17. Memo Triage
hermes cron create --name "Memo Triage" \
  --deliver "discord:1481652297376202883" \
  --skill memo-triage \
  "13 2,8,14,20 * * *" \
  "If no triageable memos are found, begin your response with [SILENT].

請使用 memo-triage skill 找出已 enriched + classified 但未 triaged 的 memos（最多 5 個），根據內容類型路由到 Obsidian vault 或保留在 Memos。

規則：
1) 有 Source URL + Key points 的文章摘要 → Obsidian Excerpts 摘要/Clippings 摘錄/
2) 想法、創意、腦力激盪 → Obsidian Knowledge Base 綜合筆記/Ideas 發想/
3) 醫療知識、臨床筆記 → Obsidian Knowledge Base 綜合筆記/ 或 Medical Aesthetics 醫美/
4) 可執行任務 → Obsidian 加上 Status/Undone tag
5) 書籤、短筆記 → 留在 Memos
6) 不確定 → 留在 Memos

建立 Obsidian 筆記時必須包含 YAML frontmatter（created, date modified, tags）。
處理完成後在 memo 內容末尾加上 #triaged → obsidian 或 #triaged。
最後回報處理結果摘要。"
echo "✓ Memo Triage"

# 18. 早間 RSS 篩選
hermes cron create --name "早間 RSS 篩選" \
  --deliver "discord:1481652297376202883" \
  --skill freshrss-triage \
  "0 9 * * *" \
  "使用 freshrss-triage skill 從 FreshRSS 篩選重要文章。執行完整 triage flow：fetch → filter → present → execute。"
echo "✓ 早間 RSS 篩選"

# 19. 晚間 RSS 篩選
hermes cron create --name "晚間 RSS 篩選" \
  --deliver "discord:1481652297376202883" \
  --skill freshrss-triage \
  "0 21 * * *" \
  "使用 freshrss-triage skill 從 FreshRSS 篩選重要文章。執行完整 triage flow：fetch → filter → present → execute。"
echo "✓ 晚間 RSS 篩選"

echo ""
echo "Done! Created 18 cron jobs (skipped 1 OpenClaw-specific job)."
echo "Run 'hermes cron list' to verify."
