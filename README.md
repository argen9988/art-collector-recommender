# 藏家推薦系統（art-collector-recommender）：雲端資安治理與 AI 自動化驗收懶人包

提供「藏家推薦系統」在 Google AI Studio ＋ Cloud Run ＋ Cloud SQL 架構下的完整資安評估報告、六大設定 SOP，以及一鍵檢查與設定的 **Lazy Pack（懶人包）**。

---

## 一、 快速開始 / 啟動方式

### 1. 首次設定（第一波止血 ＋ 雲端加固，只做一次，約 15 分鐘）

#### 步驟 A：網頁人工確認（3 項涉及信用卡與 Google 網頁限制的操作）
> 💡 **提示**：若您不確定這 3 項是否已經設過，可直接跳到「步驟 B」先跑雲端腳本，腳本會自動幫您檢查哪些已經存在、哪些還沒設！

1. **確認 Paid Tier（防資料被拿去訓練模型）**：於 [Google AI Studio](https://aistudio.google.com/) ➔ `Get API key` 確認專案 Plan 為 **`Pay-as-you-go`（Paid Tier）**。
2. **設定預算通知與每日呼叫硬上限**：於 GCP Console `Billing` ➔ `Budgets & alerts` 設定每月預算（預設 NT$1,000），並於 `IAM & Admin` ➔ `Quotas` 將 `Generative Language API` 每日上限鎖在 1,000 次。
3. **設定同仁 Gmail 登入白名單**：於 `APIs & Services` ➔ `OAuth consent screen` 維持 `Testing` 模式，在 `Test users` 加入部門同仁的 `@gmail.com` 信箱。

#### 步驟 B：執行雲端一鍵檢查與加固腳本（在瀏覽器 GCP Cloud Shell 跑）
1. 打開 Google Cloud Console 右上角的終端機圖示 **「Activate Cloud Shell (`>_`)」**。
2. 上傳本專案的 `lazy-pack/gcp-setup-and-check.sh` 與 `config/params.json`，執行：
   ```bash
   bash gcp-setup-and-check.sh
   ```
3. 腳本一啟動會**先向執行者說明整個 Lazy Pack 要做的 8 大關卡總覽（1～6 為核心必備防線，7～8 為非必要選配項）**，接著自動**先檢查現況（已設好的項目自動跳過）**，針對未完成的項目（Secret Manager 金鑰隔離、關閉資料庫公網 IP、開啟每日備份）詢問您是否一鍵套用，並提供：
   - **Cloud SQL 規格選單（含 NT$300 / NT$500–600 / NT$800+ 等方案）**
   - **Stage 7【🟢 非必要選配 1】：AI 呼叫端點選擇（預設維持 AI Studio Paid Tier 跳過，或選配啟用 Vertex AI `aiplatform.googleapis.com` ＋ 綁定 IAM 權限）**
   - **Stage 8【🟢 非必要選配 2】：排程發送客製化 EDM 之 `Cloud Scheduler API` 與專屬密鑰檢查與啟用（預設暫不啟用跳過，需要自動背景排程發信時才選配開啟）**

---

### 2. 之後每次更新或上線前驗收（本機一鍵執行，約 3 分鐘）

當系統前端或 Prompt 修改完成、準備於 12/1–12/15 進行驗收時，在 Windows PowerShell 或命令提示字元執行：

```powershell
# 1. 僅跑「原始碼金鑰外洩掃描」與「參數檢查」（不消耗 API Token）
node D:/Dev/company/art-collector-recommender/lazy-pack/code-and-ai-audit.mjs --target "<藏家系統原始碼路徑>"

# 2. 連同「20 題 AI 推薦精準度與防套話紅隊測試」一起跑（需設定測試用 API Endpoint 或 GEMINI_API_KEY）
node D:/Dev/company/art-collector-recommender/lazy-pack/code-and-ai-audit.mjs --target "<藏家系統原始碼路徑>" --run-ai-eval
```

---

## 二、 核心概念：Cloud SQL 資料庫預算與規格選單（含 NT$500–600/月 方案）

Google Cloud SQL 官方 24 小時連續開機的牌價，在 `db-f1-micro`（約 NT$300/月）與 `db-g1-small`（約 NT$800/月）之間原本有一個價格斷層。為了讓部門能彈性選擇最適合的規格（特別是 **NT$500–600/月** 的甜蜜點），本懶人包提供以下 5 種方案供執行者評估：

| 方案代號 | 機器規格与記憶體 | 運作與備份配置 | 預估月租 (NTD) | 適用情境與優缺點 |
| :--- | :--- | :--- | :---: | :--- |
| **方案 1** | **維持現有規格** | 不變更目前設定 | 依現況 | 已由資訊處調校完畢時直接跳過。 |
| **方案 2**<br>*(最省錢)* | `db-f1-micro`<br>(共享 vCPU / 0.6 GB RAM) | 24 小時開機 ＋ 10GB SSD ＋ 7 天備份 | **約 NT$280～350** | 適合初期少人測試；多同仁同時複雜查詢時記憶體較緊繃。 |
| **方案 3A**<br>*(推薦 500–600 甜區)* | **`db-g1-small`**<br>(共享 vCPU / **1.7 GB RAM**) | **搭配上下班自動開關機排程**<br>(平日 08:00–22:00 開機，夜間與假日休眠) | **約 NT$480～560** | **部門內部系統首選**：記憶體翻近 3 倍、操作順暢，利用非上班時段停機省下 58% 運算費！ |
| **方案 3B**<br>*(24h 500–600 甜區)* | `db-f1-micro`<br>(共享 vCPU / 0.6 GB RAM) | 24 小時開機 ＋ **50GB SSD** ＋ **30 天 PITR 時間點還原備份** | **約 NT$500～580** | 需要半夜與週末 24 小時隨時連入，且重視長期備份與大圖片/資料容量。 |
| **方案 4**<br>*(全天候順暢)* | `db-g1-small`<br>(共享 vCPU / 1.7 GB RAM) | 24 小時全天候開機 ＋ 20GB SSD ＋ 14 天備份 | **約 NT$780～880** | 不想設上下班開關機排程，且需要 1.7 GB 記憶體穩定運作。 |
| **方案 5**<br>*(正式高併發)* | `db-custom-1-3840`<br>(1 獨立 vCPU / 3.75 GB RAM) | 24 小時全天候開機 ＋ 14 天備份 | **約 NT$1,700～1,950** | 未來跨部門大量同仁同時使用、資料量龐大時升級。 |

### 加上「排程以人推畫／以畫推人發送自製 EDM」後的整套月租收費套餐

納入 `Cloud Scheduler`（每月前 3 個排程免費，NT$0）、外部發信 API（**Resend** 免費 3,000 封/月 或 **Brevo** 免費 9,000 封/月）與 Gemini 2.5 Flash 客製化文案生成（每 100 封約 NT$1.5）後，整套系統每月總費用調整如下：

| 總費用套餐 | AI 端點選擇 | 資料庫規格 (Cloud SQL) | 排程器 + EDM 發信服務 | **預估每月總費用** | 建議預算警示 (`budget_monthly_ntd`) |
| :--- | :--- | :--- | :--- | :---: | :---: |
| **套餐 A：極簡省錢版**<br>*(初期測試、< 100 位藏家)* | AI Studio Paid Tier | **方案 2 (`db-f1-micro` 24h)**<br>約 NT$300/月 | Cloud Scheduler (免費)<br>+ Resend / Brevo (免費版) | **約 NT$300～380 / 月** | 設 **NT$600** |
| **套餐 B：部門推薦甜區版**<br>*(最推薦！100～300 位藏家)* | AI Studio Paid Tier<br>*(或選配 Vertex AI)* | **方案 3A (`db-g1-small` 平日排程)**<br>約 NT$480～560/月 | Cloud Scheduler (免費)<br>+ Resend / Brevo (免費版) | **約 NT$500～600 / 月** | 設 **NT$1,000**<br>*(目前 `params.json` 預設值)* |
| **套餐 C：全天候專業行銷版**<br>*(> 300 位藏家、半夜發信與開信追蹤)* | AI Studio Paid Tier<br>或 **Vertex AI** | **方案 4 (`db-g1-small` 24h)**<br>約 NT$830/月 | Cloud Scheduler (免費)<br>+ Resend Pro / Brevo 付費版 (約 NT$650/月) | **約 NT$1,500～1,650 / 月** | 設 **NT$2,000** |

---

## 三、 操作指南與調整參數

- **調整預算與驗收數字**：打開 `D:\Dev\company\art-collector-recommender\config\params.json`，可直接修改 `budget_monthly_ntd`（每月預算）、`eval_question_count`（測試題數）等欄位，改完存檔立即生效，不需改程式碼。
- **閱讀完整評估報告與給部長的信**：見 `D:\Dev\company\art-collector-recommender\docs\assessment-and-sop.md`。

---

## 四、 安全機制與注意事項

1. **先檢查、已存在就跳過**：雲端腳本與本機腳本皆設計為「唯讀檢查優先」，已經設好的項目絕不重複覆蓋；任何會改變雲端組態的動作都會先印出將執行的 `gcloud` 指令並詢問 `[y/N]` 確認。
2. **機密不落本機**：驗收腳本只檢查金鑰是否外洩，不會把您的金鑰存進報表；紅隊測試全數使用虛構藏家資料。

---

## 五、 疑難排解

- **Cloud Shell 提示 `PERMISSION_DENIED`**：代表目前登入 GCP 的帳號權限不足，請切換為具備專案 `Owner` 或 `Editor` 的部門公務帳號再跑。
- **採用「方案 3A（上下班自動開關機）」遇到假日加班怎麼辦？**：同仁或管理員只需在 GCP Console `SQL` 點一下「Start（啟動）」，3 分鐘內即可隨時開機使用，晚上排程時間到仍會自動關機。

---

## 六、 更多細節

開發規範、技術選型理由、決策紀錄與施工歷程，請見同目錄之 [`AGENTS.md`](file:///D:/Dev/company/art-collector-recommender/AGENTS.md) 與 [`docs/`](file:///D:/Dev/company/art-collector-recommender/docs/)。
