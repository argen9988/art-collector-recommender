# 交接：建立藏家推薦系統雲端資安評估報告、排程 EDM 開發指南與方案 C Lazy Pack

> 寫於 2026-10-28 17:15（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 將評估報告信件（見 `D:\Dev\company\art-collector-recommender\docs\assessment-and-sop.md`「## 附錄：給資訊部長的專案彙報信件草稿」）寄予資訊部長，並於 GCP Console 執行第一波止血設定（綁定計費切換 Paid Tier、設每月 NT$1,000 預算通知與 API 配額、設 OAuth 測試白名單）。建議模型與努力程度：Sonnet（中努力程度，協助核對設定結果即可）。
2. 於 GCP Cloud Shell 上傳 `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh` 與 `D:\Dev\company\art-collector-recommender\config\params.json`，執行 `bash gcp-setup-and-check.sh` 完成 Secret Manager 金鑰隔離、Cloud SQL 內網防護與資料庫規格選擇（含 NT$500–600/月 甜區方案）。建議模型與努力程度：Sonnet（中努力程度，例行腳本執行與結果判讀）。
3. 待開發者匯出藏家系統原始碼後，於本機執行 `node D:/Dev/company/art-collector-recommender/lazy-pack/code-and-ai-audit.mjs --target "<藏家系統原始碼路徑>" --run-ai-eval` 進行原始碼金鑰掃描與 20 題 AI 推薦紅隊驗收。建議模型與努力程度：主力模型（Opus / Gemini Pro 高努力程度，涉及原始碼漏洞修補與 AI 評測調校）。

## 目標與做到哪

建立 `art-collector-recommender` 公司專案，完成 Google AI Studio + Cloud Run + Cloud SQL 雲端資安評估 SOP、排程發送客製化 EDM 開發者實作指南與收費標準，並建置方案 C 自動化檢查與設定懶人包（Lazy Pack）；目前文件、腳本、自測與 `review-changes` 審閱皆已 100% 完成，待實際於 GCP 與系統原始碼執行。

## 已完成

- 建立專案結構、資安評估與六大設定 SOP 報告及方案 C Lazy Pack 腳本（`art-collector-recommender` `0e995ce`）
- 將第 8 關（排程發送客製化 EDM 之 Cloud Scheduler 檢查）加上條列說明，並與第 7 關（啟用 Vertex AI）並列為非必要選配項（`art-collector-recommender` `e4ffa2a`）
- 新增《排程以人推畫／以畫推人發送客製化 EDM 開發者實作指南與收費標準說明》（`art-collector-recommender` `25b55f1`）
- 完成 4 份 `review-changes` 子代理審閱與修正驗證（`art-collector-recommender` `1083b80`），並寫入本機專案紀錄與 `second-brain` 去識別化紀錄

## 還沒做完

- 本機 `second-brain` 新增之 4 篇筆記尚未推上 Google Drive（Windows Antigravity 依 `vault-sync` 規範跳過 PowerShell 同步，下次於 Claude Code 開 session 時會自動推送，或於 Claude Code 說「同步 second-brain」）
- 第一波至第六階段之實際雲端設定與系統整合驗收待辦（見 `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「## 第一波：立即止血與雲端保護」至「## 第六階段：正式導入與成果確認」）

## 這次定下的決策

- D1：維持 Google AI Studio（Paid Tier 付費層），不強制遷移至 Vertex AI（保留一鍵部署相容性且已享零資料訓練保障；完整的在 `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`）
- D2：採公務 Gmail 共管、每月預算通知＋API 配額硬上限雙重止損、OAuth Testing 白名單之輕量化治理（完整的在 `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`）
- D3：Cloud SQL 規格採 6 種方案互動選擇，增設兩個 NT$500–600/月 甜蜜點方案（完整的在 `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`）
- D4：採用方案 C 二合一 Lazy Pack，開場說明全流程且所有步驟遵循「先檢查現況、已存在自動跳過」（完整的在 `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`）
- D5：將「啟用 Vertex AI」與「排程發送客製化 EDM」並列為非必要選配項，並確立三級月租收費套餐（完整的在 `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`）

## 相關檔案

- `D:\Dev\company\art-collector-recommender\AGENTS.md`：專案開發規範、架構定義與公私歸屬標記
- `D:\Dev\company\art-collector-recommender\README.md`：Lazy Pack 快速啟動說明與月租套餐對照表
- `D:\Dev\company\art-collector-recommender\config\params.json`：預算、配額、EDM 單日上限與 20 題驗收門檻設定檔
- `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh`：GCP Cloud Shell 雲端資安檢查與互動設定腳本
- `D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`：本機原始碼金鑰掃描與 20 題 AI 推薦紅隊測試腳本
- `D:\Dev\company\art-collector-recommender\docs\assessment-and-sop.md`：專案概況、資安評估、六大 SOP 與給部長的信完整報告（同步存於 `D:\TTT\待處理\` 與本機紀錄）
- `D:\Dev\company\art-collector-recommender\docs\edm-feature-implementation-and-pricing.md`：排程發送客製化 EDM 開發者實作指南與收費標準說明（同步存於 `D:\TTT\待處理\` 與本機紀錄）
- `D:\Dev\project-records\company\art-collector-recommender\home.md`：本機真名完整專案紀錄首頁（僅 Windows 公司電腦）

## 踩過的坑

- Cloud SQL 若選用「方案 3A（`db-g1-small` 平日 08:00–22:00 自動開關機）」，未來若啟用排程發送 EDM，務必將 Cloud Scheduler 觸發時間設於平日白天資料庫開機時段內（見 `D:\Dev\company\art-collector-recommender\AGENTS.md`「## 開發時踩過的坑」）
