# 交接：新增 `AGENT_SETUP` 跨 AI 代操指南、三階段分流、預算問答、每月費用精算器與雙軌報告輸出並發布 GitHub

> 寫於 2026-10-29 10:18（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 實作「自動定位藏家推薦系統目標」3 項機制（詳見 `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「## 零、 Lazy Pack 工具包補強與審閱待辦」）：(A) 在 `lazy-pack/gcp-setup-and-check.sh`（目前 1,021 行，讀改約第 225–250 行）新增 `gcloud projects list` 專案編號選單與自動探測 Cloud Run 服務網址；(B) 在 `lazy-pack/code-and-ai-audit.mjs`（目前 501 行，讀改約第 435–485 行）與 `AGENT_SETUP_雲端資安設定與驗收指南.md`、`README.md` 移除未帶 `--target` 預設掃自身目錄之盲點，新增三種原始碼來源自動定位（從 Cloud Run/Cloud Build 或 AI Studio 匯出下載、GitHub clone、本機搜尋）與 `--url` 線上網址 20 題紅隊測試。建議模型與努力程度：主力模型（Claude Sonnet 4.6 / Opus 4.6 或 Gemini Pro，中～高努力程度，涉及跨雲端與本機腳本互動設計）。
2. 照 `review-changes` Skill 對 commit `2643155..HEAD`（含今日改動與上述自動定位機制，共 11 個檔案、約 1,650 行，依 400 行上限約切成 6 份材料）執行完整收尾審閱。建議模型與努力程度：主力模型（Sonnet 4.6 / Opus 4.6 或 Gemini Pro，中～高努力程度，審閱不可用 Flash 等小模型）。
3. 將本機專用信件草稿（`D:\Dev\company\art-collector-recommender\docs\email-draft-to-director.md`）寄予資訊部長，並將公開 GitHub 領航指南網址交給執行者的 AI Agent 依序執行第一至第三階段與費用精算。建議模型與努力程度：Sonnet（中努力程度，協助核對信件與判讀腳本輸出）。

## 目標與做到哪

建立 `art-collector-recommender` 公司專案，完成雲端資安評估 SOP、排程發送客製化 EDM 開發者實作指南、跨 AI 自動代操指南（`AGENT_SETUP_雲端資安設定與驗收指南.md`）與方案 C 自動化檢查設定懶人包（Lazy Pack），並發布至公開 GitHub repo `argen9988/art-collector-recommender`。目前待補強「自動定位藏家推薦系統目標（雲端專案選單＋原始碼三來源抓取）」後一併執行 `review-changes` 審閱。

## 已完成

- 建立專案結構、資安評估與六大設定 SOP 報告及方案 C Lazy Pack 腳本（`art-collector-recommender` `0e995ce`）
- 將第 8 關（排程發送客製化 EDM 之 Cloud Scheduler 檢查）與第 7 關（啟用 Vertex AI）並列為非必要選配項，並新增《排程發送客製化 EDM 開發者實作指南與收費標準說明》（`art-collector-recommender` `e4ffa2a`、`25b55f1`、`1083b80`）
- 新增 `AGENT_SETUP_雲端資安設定與驗收指南.md`（含建議模型與努力程度表）、支援 `--stage 1|2|cost|all` 與細項自由選做（含 6 點白話說明卡）、預算與 AI 每日呼叫上限互動問答題、每月費用精算器與 `reports/` 雙軌報告輸出，並將部長信件草稿拆出至 `.gitignore`，發布至公開 GitHub `argen9988/art-collector-recommender`（`art-collector-recommender` `09bfd7e`、`0523d90`、`0dac5b3`）

## 還沒做完

- 實作「自動定位藏家推薦系統目標（GCP 專案選單＋Cloud Run/AI Studio 原始碼自動抓取與 `--target` 防呆＋`--url` 線上端點測試）」（見 `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「## 零、 Lazy Pack 工具包補強與審閱待辦」）
- 對 commit `2643155..HEAD` 執行 `review-changes` 審閱（待自動定位機制完成後一併審閱）
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
- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：待辦清單（含下次開工優先實作之「自動定位藏家推薦系統目標」規格）
- `D:\Dev\company\art-collector-recommender\docs\email-draft-to-director.md`：給資訊部長的專案彙報信件草稿（僅留本機，已列入 `.gitignore`）

## 踩過的坑

- `code-and-ai-audit.mjs` 未傳 `--target` 時原本預設掃描 `REPO_ROOT`（即 Lazy Pack 自身目錄），且 `gcp-setup-and-check.sh` 原本只讀 `gcloud config get-value project`，對無資訊背景且程式碼在 AI Studio 雲端的使用者不夠自動；已列入 `docs/todo-plan.md` 下次開工第 1 步修正
- Bash 腳本在 `set -u` 模式下讀取含 `NT$1000` 字串的 `.env` 狀態檔時，若用 `source` 會將 `$1000` 當成 `$1` 展開而報 `$1: unbound variable`；已改為 `IFS='=' read -r` 安全解析
