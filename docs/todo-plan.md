# art-collector-recommender — 待辦與階段規劃 (todo-plan.md)

> 遵循全域規則：待辦文件只留還沒做完的項目；做完的項目已移入 [`docs/worklog/2026-10.md`](file:///D:/Dev/company/art-collector-recommender/docs/worklog/2026-10.md)。

---

## 第一波：立即止血與雲端保護（目標：2026-10-31 前完成）

- [ ] **寄發評估報告信件予資訊部長**：使用 [`docs/assessment-and-sop.md`](file:///D:/Dev/company/art-collector-recommender/docs/assessment-and-sop.md) 附錄草稿向部長彙報輕量化納管與雙重止損方案。
- [ ] **確認 GCP 專案綁定 Billing（切換 Paid Tier）**：確認專案處於 `Pay-as-you-go`，保障藏家資料 100% 不被用於模型訓練。
- [ ] **設定軟硬雙重成本止損**：於 GCP 設定每月 NT$1,000 預算通知，並鎖定 Gemini API 每日呼叫上限（1,000 次/日）。
- [ ] **設定無企業網域下之 OAuth 測試白名單**：於 OAuth consent screen (`Testing` 模式) 加入部門同仁 `@gmail.com` 白名單。

## 第二波：系統架構加固與第二階段 BUG 修正（2026-10-20 ～ 2026-10-31）

- [ ] **於 GCP Cloud Shell 執行 `lazy-pack/gcp-setup-and-check.sh`**：
  - 將 `GEMINI_API_KEY` 與 `DATABASE_URL` 移入 Secret Manager 並掛載至 Cloud Run。
  - 關閉 Cloud SQL 公網 IP（Public IP）、啟用強制 SSL 與每日自動備份。
  - 與執行者確認 Cloud SQL 規格方案（如 NT$500–600/月 之 `db-g1-small` 搭配上下班排程，或 `db-f1-micro` 加大備份方案）。
- [ ] **優化手動匯入與建檔介面**：簡化業務同仁批次匯入藏家與畫作資料之流程與防呆驗證。

## 第三階段：推薦邏輯與資料正確性驗證（2026-11-01 ～ 2026-11-15）

- [ ] **校驗藏家與畫作資料庫**：檢查資料缺漏、重複與異常價格區間。
- [ ] **調校 AI 推薦演算法條件**：確保「以畫薦人」與「以人薦畫」符合業務預算與媒材條件。

## 第四階段：整合測試與使用流程確認（2026-11-16 ～ 2026-11-30）

- [ ] **部門同仁完整操作流程測試**：蒐集內部回饋並調整 UI/UX。

## 第五階段：最終驗收與上線準備（2026-12-01 ～ 2026-12-15）

- [ ] **執行本機驗收腳本 `lazy-pack/code-and-ai-audit.mjs`**：完成原始碼金鑰 0 外洩掃描與 20 題 AI 推薦精準度／防注入紅隊測試。

## 第六階段：正式導入與成果確認（2026-12-16 ～ 2026-12-31）

- [ ] **部門正式導入上線**：彙整專案成果並規劃 2027 後續優化方向。
