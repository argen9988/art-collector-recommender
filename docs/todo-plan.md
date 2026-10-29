# art-collector-recommender — 待辦與階段規劃 (todo-plan.md)

> 遵循全域規則：待辦文件只留還沒做完的項目；做完的項目已移入 [`docs/worklog/2026-10.md`](./worklog/2026-10.md)。

---

## 第一階段：立即止血與基礎防護（對應 `gcp-setup-and-check.sh --stage 1`）

- [ ] **【細項 1-1】確認 GCP 專案綁定 Billing（切換 Paid Tier）**：確認專案處於 `Pay-as-you-go`，保障藏家資料 100% 不被用於模型訓練。
- [ ] **【細項 1-2】設定雙管理員（Owner）帳號共管**：將部門公務專用 Gmail 與主管 Gmail 共同設為專案 `Owner`（至少 2 人互為備援）。
- [ ] **【細項 1-3】設定軟硬雙重成本止損與同仁 Gmail 白名單**：透過互動問答決定並於 GCP 設定每月預算提醒鈴（預設 NT$1,000）、鎖定 Gemini API 每日呼叫硬上限（預設 1,000 次/日），並於 OAuth consent screen (`Testing` 模式) 加入部門同仁 `@gmail.com` 白名單。

## 第二階段：系統架構加固與規格選型（對應 `gcp-setup-and-check.sh --stage 2`）

- [ ] **【細項 2-1】Secret Manager 金鑰隔離**：將 `GEMINI_API_KEY` 與 `DATABASE_URL` 移入雲端保險箱 Secret Manager 並掛載至 Cloud Run。
- [ ] **【細項 2-2】Cloud SQL 資料庫內網防護與每日自動備份**：關閉 Cloud SQL 公網 IP（Public IP）、啟用強制 SSL 與每日自動備份（保留 14 天）。
- [ ] **【細項 2-3】選定 Cloud SQL 資料庫月租方案**：從 6 種規格選單中選定方案（推薦方案 3A：NT$480–560/月 之 `db-g1-small` 搭配平日上下班開機排程，或方案 3B：`db-f1-micro` 加大備份方案）。
- [ ] **優化系統手動匯入與建檔介面**：簡化業務同仁批次匯入藏家與畫作資料之流程與防呆驗證，並校驗推薦演算法邊界條件。

## 第三階段：上線前原始碼與 AI 紅隊總體檢（對應 `code-and-ai-audit.mjs`）

- [ ] **【細項 3-1】執行本機原始碼金鑰 0 外洩掃描**：確認前端無硬編碼 API Key、資料庫密碼或 `NEXT_PUBLIC_` 機密變數外洩。
- [ ] **【細項 3-2】執行 20 題 AI 推薦準確度與防惡意套話壓力測試**：以虛構假資料驗證推薦畫作 100% 符合預算與庫存、EDM 無 CC 外洩名單，並成功攔截 Prompt Injection 套話指令。
- [ ] **產出《全部階段執行累計總報告》並正式導入上線**：彙整 `reports/full-execution-report.md`（含三階段成果與每月雲端費用精算表）回報資訊部留存。
