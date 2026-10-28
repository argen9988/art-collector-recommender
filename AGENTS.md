# art-collector-recommender — AGENTS.md

藏家推薦系統之雲端 AI 開發資安治理、架構評估與自動化檢查懶人包（Lazy Pack）專案；使用者操作說明見同目錄的 `README.md`。

## 公私歸屬

- 歸屬：公司
- 完整紀錄位置：`D:\Dev\project-records\company\art-collector-recommender\`

## 技術選型與理由

- **雲端架構**：Google AI Studio（Build 模式，維持 **Paid Tier 付費層**以保障客戶資料 100% 不用於模型訓練；亦於 Lazy Pack 內建 **Vertex AI** 互動式啟用選項）＋ Google Cloud Run（Next.js 全端容器）＋ Google Cloud SQL（PostgreSQL / MySQL）＋ Cloud Scheduler（排程觸發以人推畫／以畫推人客製化 EDM）＋ 外部發信 API（Resend / Brevo）（決策見 `docs/decisions/2026-10.md` D1、D5）。
- **身分驗證**：無企業網域，採用 GCP OAuth Consent Screen `Testing` 模式白名單（Test Users Allowlist）搭配後端 `ALLOWED_EMAILS` 核驗，阻絕外部 Gmail 登入；排程路由 `/api/cron/send-edm` 另以 Secret Manager 之 `CRON_SECRET` 驗證（見 D2、D5）。
- **自動化懶人包（Lazy Pack）**：
  - 雲端設定與體檢（`lazy-pack/gcp-setup-and-check.sh`）：Bash 腳本，於 GCP Cloud Shell 執行，遵循「開場先向執行者說明全流程（區分第 1～6 關核心必備與第 7～8 關非必要選配）」、「先檢查現況、已存在自動跳過」、「Cloud SQL 規格互動討論（含 NT$500–600/月 方案）」以及兩項並列之非必要選配項：「Stage 7 啟用 Vertex AI」與「Stage 8 排程發送客製化 EDM（Cloud Scheduler API ＋ EDM 密鑰）」（見 D3、D4、D5）。
  - 本機程式碼掃描與 AI 紅隊測試（`lazy-pack/code-and-ai-audit.mjs`）：Node.js ESM 腳本，讀取 `config/params.json`，開場先說明檢查項目，執行靜態金鑰掃描（含 `GEMINI_API_KEY`、`EDM_API_KEY`、`CRON_SECRET`）與 LLM-as-a-Judge 推薦品質/防注入/EDM 收件人隱私驗收。

## 資料夾結構

```text
D:\Dev\company\art-collector-recommender\
├── AGENTS.md                        # 本檔（開發視角與專案規則）
├── README.md                        # 操作指南（使用者視角）
├── config/
│   └── params.json                  # 可調參數檔（預算、配額、驗收門檻與 _說明）
├── lazy-pack/
│   ├── gcp-setup-and-check.sh       # 雲端 GCP 資安檢查與互動設定腳本
│   └── code-and-ai-audit.mjs        # 本機原始碼金鑰掃描與 AI 推薦品質驗收腳本
└── docs/
    ├── assessment-and-sop.md                     # 專案概況、時程、六大資安 SOP 與部長信件完整報告
    ├── edm-feature-implementation-and-pricing.md # 排程發送客製化 EDM 開發者實作指南與收費標準說明
    ├── todo-plan.md                              # 待辦清單（只留未完成項目）
    ├── worklog/                                  # 施工紀錄（分月存）
    └── decisions/                                # 決策紀錄（分月存）
```

## 資料模型與參數定義

- 所有可調門檻集中於 `config/params.json`（含 `"_說明"`），包含每月預算警示 `budget_monthly_ntd`（現在是 1000）、資料庫目標月租 `db_target_monthly_ntd`（現在是 550）、API 每日上限 `api_quota_rpd`（現在是 1000）、每分鐘上限 `api_quota_rpm`（現在是 30）、備份天數 `backup_retention_days`（現在是 14）、每日 EDM 發送上限 `edm_daily_send_limit`（現在是 100）、驗收題數 `eval_question_count`（現在是 20）。

## 業務規則精確定義

1. **所有自動化檢查與設定皆須具備冪等性（Idempotency）**：執行任何變更前，先查詢現況；若該項設定已存在且符合安全標準，印出 `✅ 已存在，跳過`，不重複覆寫。
2. **Cloud SQL 規格採互動式選擇**：腳本不強制降級為最低規格，而是列出 5 種方案（含 NT$500–600/月 之 `db-g1-small` 搭配上下班自動啟停排程，或 `db-f1-micro` 加大儲存與 30 天 PITR 備份）供執行者討論決定。
3. **前端零機密原則**：任何含 `AIza`、`postgres://` 或未加白名單之敏感變數，不得出現於前端 bundle 或 `NEXT_PUBLIC_` 變數中。

## 核心流程

1. **第一波（立即止血）**：綁定 Billing 切換 Paid Tier ➔ 設定預算警示與 API Quota ➔ 設定 OAuth 測試白名單。
2. **第二波（架構加固）**：於 GCP Cloud Shell 執行 `lazy-pack/gcp-setup-and-check.sh` 隔離金鑰至 Secret Manager、關閉 Cloud SQL 公網 IP 並選定資料庫規格。
3. **第三波（上線體檢）**：於本機執行 `lazy-pack/code-and-ai-audit.mjs` 掃描程式碼並完成 20 題 AI 推薦精準度與防注入測試。

## 開發時踩過的坑

- Windows PowerShell 傳雙引號字串給 `python -c` 時，反ticks（`` ` ``）會被 PowerShell 當作跳脫字元吃掉；跨工具批量替換文字應寫成獨立 `.py` 腳本執行。
- Google Cloud SQL 官方 24 小時機型直接從 `db-f1-micro`（約 NT$300/月）跳至 `db-g1-small`（約 NT$800/月），若預算落在 NT$500–600/月，需透過「`db-g1-small` ＋ Cloud Scheduler 平日上下班自動開關機」或「`db-f1-micro` ＋ 50GB SSD ＋ 30 天 PITR 備份」達成。

## 安全與備份

- 腳本只讀取環境變數與 Secret Manager 名稱，不在 repo 內儲存任何真實 API Key、資料庫密碼或藏家真實個資。
- 測試 AI 推薦與防注入時，一律使用腳本內建之虛構藏家與畫作假資料（Dummy Data）。

## 改動後的驗證方式

1. 修改 `lazy-pack/gcp-setup-and-check.sh` 後，用 Git Bash 的 `C:\Program Files\Git\bin\bash.exe -n lazy-pack/gcp-setup-and-check.sh` 驗證語法無誤，並用 `--dry-run` 模式測試無 `gcloud` 環境下的現況檢查與選單互動。
2. 修改 `lazy-pack/code-and-ai-audit.mjs` 或 `config/params.json` 後，執行 `node lazy-pack/code-and-ai-audit.mjs --self-test` 確認參數讀取、靜態掃描與模擬閱卷皆通過。
