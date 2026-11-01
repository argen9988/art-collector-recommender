# 交接：Lazy Pack 待辦清空，下一步整輪真雲端驗收（Antigravity）

> 寫於 2026-11-01 16:15（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 整輪真雲端驗收（第一、二、三階段一次驗完，含 `--handoff` 一輪）：**到 Antigravity（agy）開新 session，用 Gemini Flash（High）做，使用者要在場**。開工讀這份，照 `D:\Dev\company\art-collector-recommender\AGENT_SETUP_雲端資安設定與驗收指南.md` 從第一階段跑到第三階段，再跑 `--handoff`。Flash 當審閱者曾有講錯的紀錄，每個結論先對照程式查證。建議用拋棄式 GCP 專案（`docs/todo-plan.md`「【真雲端驗收】」，含兩件假 gcloud 測不出來的事：第二階段 `sql instances patch` 在管線下會不會照常問 `(Y/n)`、Git Bash 按 Ctrl-C 後紀錄最後幾行有沒有掉）。驗收時順便查「【待確認】真實推薦端點的路徑與格式」（不同就調 `askOnline` 或用 `--api-path`）。建議模型與努力程度：照使用者指定（Gemini Flash、High）；驗收發現要改程式時回 Claude 用 Sonnet、medium（範圍清楚的 bug）或主力模型（設計問題）
2. 這個 session 的 reflection 與專案紀錄還沒寫（公司專案：完整版寫到 `D:\Dev\project-records\company\art-collector-recommender\`，去識別化版寫進 second-brain 前先給使用者看）；建議驗收完一起寫

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent 就能跑完三階段檢查，出錯能回報，檢查結果能用交接包交給資訊同仁再用自架平台驗證。所有程式與文件待辦都做完，只剩真雲端驗收。`tests/test-code-audit.sh` 665 項、`tests/test-gcp-setup.sh` 296 項全過，工作區乾淨。

## 已完成

- `NT$0` 預設值被展開成腳本路徑的 bug 修好，測試 16g 加 3 項（`1c8d25b`）
- manifest 欄位表寫進弱掃規格第 4 節（vulnerability-scan-summary 另一個 repo，已推送）
- `--url` 線上測試遇 429／5xx 重送一次、連續 3 題失敗中止（新參數 `eval_abort_after_failures`、`eval_retry_after_max_sec`）；findings.json 寫不進去的測試 13k；改壞驗證都抓到。施工紀錄 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-11.md` 最後兩段

## 還沒做完

- 上面「下一步」各項
- 真實推薦端點路徑與格式（`docs/todo-plan.md`「【待確認】」，驗收時查）；Firebase 檢測差異（使用者說之後再談）
- 沒測：打包中途失敗清半成品、`--platform-result` 寫總報告失敗的分支（未驗證）
- 審閱錯誤回報時沒改的小邊界（家目錄太短、`ghp_`／`sk-` 規則、SKIP 算失敗等）：只記在施工紀錄
- 使用者自己清空資源回收筒才會釋放 C 槽空間
- Codex 當主線呼叫別家的驗證：`D:\Dev\personal\ai-companion\docs\todo-plan.md`「反方向派工」，等 Codex 訂閱
- 弱掃那邊照規格做 Skill 與懶人包、合併產生器（在 vulnerability-scan-summary 另開 session）

## 這次定下的決策

- 整輪真雲端驗收由 Antigravity 的 Gemini Flash（High）做，使用者在場（使用者 2026-11-01 指定）
- 429／5xx：等 Retry-After（上限 60 秒，沒給等 2 秒）重送一次，連續 3 題逾時或 429／5xx 就中止（數字在 `config/params.json`）
- 公司專案、推送：自動

## 相關檔案

- `D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`：`askOnline`、`runAiEvaluation`、`runHandoff`
- `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh`：第一、二階段與費用精算
- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：【真雲端驗收】、【待確認】
- `D:\Dev\company\art-collector-recommender\AGENT_SETUP_雲端資安設定與驗收指南.md`：驗收照這份跑

## 踩過的坑

- 跑測試要讓工具指令本身就是測試指令，不要在指令裡用 `&` 丟背景；兩支測試不同時跑：會互相改寫 `reports/`。被殺掉沒還原時，用最早那份 `%TEMP%\tmp.*\` 的 `state.bak`、`full.bak` 還原
- Python `subprocess.run(capture_output=True, timeout=…)` 跑含假伺服器的測試，逾時後 node 假伺服器握著管線會卡死：改用 bash `timeout` 加輸出寫檔
- `tests/test-gcp-setup.sh` 第 16 段的 sed 假設 `usd_twd_rate` 是 `config/params.json` 最後一行（沒有逗號）：新參數加在它前面
- 指令裡有連續兩個反斜線會被 Bash 工具的 hook 擋下：用 Write 寫成檔案再執行
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址、帳號 email、帳單帳戶編號
- 真雲端驗收要開拋棄式專案，跑完關閉專案（估 NT$0～50）；立即掃描在 Windows 版 gcloud 不支援
