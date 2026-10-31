# art-collector-recommender — 待辦與階段規劃 (todo-plan.md)

> 遵循全域規則：待辦文件只留還沒做完的項目；做完的項目已移入 [`docs/worklog/2026-10.md`](./worklog/2026-10.md)。

---

## 零、 Lazy Pack 工具包補強與審閱待辦（下次開工優先執行）

> **執行順序（使用者 2026-10-31 定）**：① 【錯誤回報】→ ② 【交接包】→ ③ 【真雲端驗收】（整輪，第一、二、三階段一次驗完，放最後好用完整功能一次驗）。①②都依賴「資訊相關權責單位用什麼方式收」，開工第一件事先問使用者。其他【小補強】【待確認】【待討論】不排順序，有空檔再做。

- [ ] **【小補強】findings.json 寫不進去只警告的測試**（D12 再審提出，2026-10-30）：程式有 try/catch 只警告，但測試沒有這個情境；Windows 上把檔案設唯讀或換成資料夾才做得出來，之後補。
- [ ] **【小補強】`--url` 線上測試遇到 429／5xx 的處理**（段 B2 審閱提出，2026-10-29 暫緩）：目前會連續打完剩下的題目，全部逾時最壞約 10 分鐘（20 題乘 30 秒）。真實端點格式確認後，再加「讀 `Retry-After` 退避」與「連續幾題逾時或 5xx 就中止」。
- [ ] **【待確認】真實推薦端點的路徑與格式**：段 B2 的 `--url` 測試假設 `POST /api/recommend`、送 JSON（含虛構庫存 `inventory`）、回 `{ recommendations, cc_list, blocked, message }`。真實系統（AI Studio Build 產生的 Next.js）的推薦端點路徑、要不要登入、回傳格式都未知；拋棄式專案驗收或拿到原始碼時查清楚，不同就調 `askOnline` 或用 `--api-path`。
- [ ] **【真雲端驗收】用拋棄式 GCP 專案跑一輪（見 D7 第 ③ 層）**：使用者用個人帳號建一個新 GCP 專案（不放公司資料）、部署 hello-world Cloud Run，照 `AGENT_SETUP` 從第一階段跑到第三階段，跑完關閉專案（估 NT$0～50）。（2026-10-31 已用拋棄式專案驗完 3-5 映像檔掃描並刪除專案；第一、二階段還沒在真雲端跑過。）
- [ ] **【錯誤回報】讓不懂電腦的人出錯時能回報**（2026-10-30 使用者確認採方式 A＋D，見 D8）：現況沒有回報機制，gcloud 的錯誤訊息有 19 處被丟掉（`2>/dev/null`）、沒存完整執行紀錄。要做：① `lazy-pack/gcp-setup-and-check.sh`、`lazy-pack/code-and-ai-audit.mjs` 加 `--report-problem`，產出 `reports/problem-report-<時間>.md`（腳本版本、作業系統、gcloud 版本、各細項狀態、失敗項目與錯誤訊息，自動遮掉金鑰與密碼），由使用者傳給資訊相關權責單位；② 腳本全程記錄存 `reports/logs/`，出問題時一併打包；③ `AGENT_SETUP_雲端資安設定與驗收指南.md` 加「遇到錯誤時」一節，叫 AI 跑 ① 並用白話說明。方式 C（腳本自動寄出）不採。**2026-10-31 使用者定：資訊相關權責單位用電子郵件收**（D15，方式 B 信件草稿改為採用；交接包也走信件，附件大小上限要問資訊單位，見【交接包】）。**進度（分三段做）**：(a) `code-and-ai-audit.mjs` 的 `--report-problem`、`--note`、全程記錄 `reports/logs/`、信件草稿與遮蔽，連同 `tests/test-code-audit.sh` 第 12 段（71 項）**已做好（2026-10-31）**；(b) `gcp-setup-and-check.sh` 的 19 處 `2>/dev/null` 改成記下來、全程記錄（檔名 `reports/logs/gcp-setup-and-check-<時間>.log`，格式照 (a)：開頭 `# gcp-setup-and-check.sh 開始 …`、結尾 `# 結束，結束碼 N`，`LAZY_PACK_LOGS_DIR` 可指到暫存資料夾）、`--report-problem`（可轉呼叫 `node lazy-pack/code-and-ai-audit.mjs --report-problem`，bash 腳本也要遮蔽同樣的東西）與 `tests/test-gcp-setup.sh` 新一段，再切兩段做：(b1) 全程記錄、遮蔽（`lp_redact_init`，`redactSecrets` 的 sed 版）、`--report-problem`、`--note` 與測試第 17 段（109 項）**已做好（2026-10-31）**；(b2) 19 處 `2>/dev/null` 改成記下來（gcloud 的錯誤訊息要進紀錄，但不能把終端機畫面弄亂）與測試，**還沒做**；(c) `AGENT_SETUP_雲端資安設定與驗收指南.md` 加「遇到錯誤時」一節、README 加錯誤回報說明，**還沒做**。
- [ ] **【交接包】`--handoff` 產出給弱掃 Skill 的交接包**（D9）：`code-and-ai-audit.mjs` 加 `--handoff`，產出 `reports/handoff/<系統>-<時間>/`（`manifest.json`、`findings.json`、`full-execution-report.md`、`source.zip`、`README.md`）與它的 ZIP；格式照 `D:\Dev\company\vulnerability-scan-summary\docs\specs\annual-and-system-reports-spec.md` 第 4 節，`schema_version` 要對得上。不放密碼；3-1 掃到金鑰時不打包並說明原因。累計總報告加「自架平台驗證」一行（沒做寫「未執行（選做）」）。`reports/findings.json` 現在只有 3-3、3-4 的結果，3-1 掃到的金鑰問題也要轉成同一格式放進去；欄位名稱與類別代號（`category`、`WEB-*`、`OBS-GRADE`，見 D10）要請弱掃那邊寫進規格第 8 節、`schema_version` 對齊。`AGENT_SETUP_雲端資安設定與驗收指南.md` 加「交給資訊權責單位」一節。交接包怎麼送到對方手上，跟【錯誤回報】的收件方式一起決定。
- [ ] **【待討論】改用 Google／Firebase 服務時的檢測差異**（2026-10-30 使用者要求先列入待辦，之後再詳細討論）：Firebase 的資料靠 Security Rules、App Check 與 IAM 保護，Firebase 的 `apiKey` 官方說不是機密（所以現有 `AIza…` 規則會大量誤報），但 Gemini 的金鑰必須保密。要檢查的差異：`firestore.rules`／`storage.rules` 有沒有 `allow read, write: if true`、登入授權網域與 App Check、API 金鑰有沒有加使用限制、`firebase-adminsdk-*.json` 有沒有進 repo、`firebase.json` 的 hosting 標頭、費用精算（Firebase 方案的預算警示怎麼設**未查證**）；Cloud SQL 的 2-2、2-3 不適用。範圍分四層：A 只讀原始碼（建議先做，做成 `--profile firebase`）、B 唯讀查雲端設定、C 用 Firebase Emulator 在本機實測匿名讀寫（可行性未實測）、D 輸出成自架平台追蹤總表格式。

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
- [ ] **產出《全部階段執行累計總報告》並正式導入上線**：彙整 `reports/full-execution-report.md`（含三階段成果與每月雲端費用精算表）回報資訊相關權責單位留存。
