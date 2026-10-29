# 交接：新增 `AGENT_SETUP` 跨 AI 代操指南、三階段分流、預算問答、每月費用精算器與雙軌報告輸出並發布 GitHub

> 寫於 2026-10-29 09:45（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 將本機專用之評估報告信件草稿（見 `D:\Dev\company\art-collector-recommender\docs\email-draft-to-director.md`，已列入 `.gitignore` 不上傳 GitHub）寄予資訊部長，說明關係企業獨立運作下之六大資安與成本控管規範。建議模型與努力程度：Sonnet（中努力程度，協助核對信件與設定即可）。
2. 將公開 GitHub 領航指南網址 `https://raw.githubusercontent.com/argen9988/art-collector-recommender/master/AGENT_SETUP_雲端資安設定與驗收指南.md` 交給執行者的 AI Agent，依序執行第一階段（`--stage 1`）、第二階段（`--stage 2`）與費用精算（`--stage cost`），產出單次報告與 `reports/full-execution-report.md`。建議模型與努力程度：Sonnet（中努力程度，例行腳本執行與結果判讀）。
3. 待開發者匯出藏家系統原始碼後，執行第三階段 `node D:/Dev/company/art-collector-recommender/lazy-pack/code-and-ai-audit.mjs --target "<藏家系統原始碼路徑>" --run-ai-eval` 進行原始碼金鑰掃描與 20 題 AI 推薦紅隊驗收，更新最終總報告。建議模型與努力程度：主力模型（Opus / Gemini Pro 高努力程度，涉及原始碼漏洞修補與 AI 評測調校）。

## 目標與做到哪

建立 `art-collector-recommender` 公司專案，完成雲端資安評估 SOP、排程發送客製化 EDM 開發者實作指南、跨 AI 自動代操指南（`AGENT_SETUP_雲端資安設定與驗收指南.md`）與方案 C 自動化檢查設定懶人包（Lazy Pack），並發布至公開 GitHub repo `argen9988/art-collector-recommender`。

## 已完成

- 建立專案結構、資安評估與六大設定 SOP 報告及方案 C Lazy Pack 腳本（`art-collector-recommender` `0e995ce`）
- 將第 8 關（排程發送客製化 EDM 之 Cloud Scheduler 檢查）與第 7 關（啟用 Vertex AI）並列為非必要選配項，並新增《排程發送客製化 EDM 開發者實作指南與收費標準說明》（`art-collector-recommender` `e4ffa2a`、`25b55f1`、`1083b80`）
- 新增 `AGENT_SETUP_雲端資安設定與驗收指南.md`、將三階段壓日期文字移除、支援 `--stage 1|2|cost|all` 與細項自由選做（含 6 點白話說明卡）、將預算與 AI 每日呼叫上限改為互動問答題（預設 1,000）、新增「💰 雲端服務開啟清單與每月費用精算器」與 `reports/` 單次及累計總報告雙軌輸出，並移除外部本機目錄關聯，發布至 GitHub `argen9988/art-collector-recommender`

## 還沒做完

- 本機 `second-brain` 新增之筆記尚未推上 Google Drive（Windows Antigravity 依 `vault-sync` 規範跳過 PowerShell 同步，下次於 Claude Code 開 session 時會自動推送，或於 Claude Code 說「同步 second-brain」）
- 第一階段至第三階段之實際 GCP 雲端設定與系統整合驗收待辦（見 `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`）

## 這次定下的決策

- D1～D5：維持 Google AI Studio Paid Tier、雙 Owner 共管與軟硬止損、Cloud SQL 6 方案選單、方案 C 二合一 Lazy Pack、Vertex AI 與排程 EDM 並列選配項（完整的在 `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`）
- D6：導入 `AGENT_SETUP` 跨 AI 代操領航指南、三階段不押日期與細項可選、預算配額互動問答、每月費用精算器與雙軌報告輸出（完整的在 `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`）

## 相關檔案

- `D:\Dev\company\art-collector-recommender\AGENT_SETUP_雲端資安設定與驗收指南.md`：給所有 AI Agent 讀的無腦代操領航指南
- `D:\Dev\company\art-collector-recommender\AGENTS.md`：專案開發規範、架構定義與公私歸屬標記
- `D:\Dev\company\art-collector-recommender\README.md`：Lazy Pack 快速啟動說明、白話口令、6 種 DB 方案與費用精算表
- `D:\Dev\company\art-collector-recommender\config\params.json`：預算、配額、EDM 單日上限與 20 題驗收門檻設定檔
- `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh`：雲端分階段資安檢查、互動設定與費用精算腳本
- `D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`：本機原始碼金鑰掃描與 20 題 AI 推薦紅隊測試腳本
- `D:\Dev\company\art-collector-recommender\docs\assessment-and-sop.md`：專案概況、資安評估與六大規範 SOP 完整報告
- `D:\Dev\company\art-collector-recommender\docs\email-draft-to-director.md`：給資訊部長的專案彙報信件草稿（僅留本機，已列入 `.gitignore`）
- `D:\Dev\company\art-collector-recommender\docs\edm-feature-implementation-and-pricing.md`：排程發送客製化 EDM 開發者實作指南與收費標準說明
- `D:\Dev\project-records\company\art-collector-recommender\home.md`：本機真名完整專案紀錄首頁（僅 Windows 公司電腦）

## 踩過的坑

- Cloud SQL 若選用「方案 3A（`db-g1-small` 平日 08:00–22:00 自動開關機）」，未來若啟用排程發送 EDM，務必將 Cloud Scheduler 觸發時間設於平日白天資料庫開機時段內（見 `D:\Dev\company\art-collector-recommender\AGENTS.md`「## 開發時踩過的坑」）
