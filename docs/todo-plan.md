# art-collector-recommender — 待辦與階段規劃 (todo-plan.md)

> 遵循全域規則：待辦文件只留還沒做完的項目；做完的項目已移入 [`docs/worklog/2026-10.md`](./worklog/2026-10.md)。

---

## 零、 Lazy Pack 工具包補強與審閱待辦（下次開工優先執行）

- [ ] **【小補強】`--url` 線上測試遇到 429／5xx 的處理**（段 B2 審閱提出，2026-10-29 暫緩）：目前會連續打完剩下的題目，全部逾時最壞約 10 分鐘（20 題乘 30 秒）。真實端點格式確認後，再加「讀 `Retry-After` 退避」與「連續幾題逾時或 5xx 就中止」。另外 `tests/test-code-audit.sh` 用 `ls -t … | head -1` 取最新報告，兩次執行時間戳相同時可能抓到舊的，改成跑前記清單、跑後取差集。
- [ ] **【待確認】真實推薦端點的路徑與格式**：段 B2 的 `--url` 測試假設 `POST /api/recommend`、送 JSON（含虛構庫存 `inventory`）、回 `{ recommendations, cc_list, blocked, message }`。真實系統（AI Studio Build 產生的 Next.js）的推薦端點路徑、要不要登入、回傳格式都未知；拋棄式專案驗收或拿到原始碼時查清楚，不同就調 `askOnline` 或用 `--api-path`。
- [ ] **【真雲端驗收】用拋棄式 GCP 專案跑一輪（見 D7 第 ③ 層）**：上面三項與審閱都做完後，使用者用個人帳號建一個新 GCP 專案（不放公司資料）、部署 hello-world Cloud Run，照 `AGENT_SETUP` 從第一階段跑到第三階段，跑完關閉專案（估 NT$0～50）。
- [ ] **【審閱修改】段 C 第 2 件審閱（13 份、Sonnet）發現的待改項，使用者 2026-10-29 確認「照建議改」**（完整發現與材料：`C:\Users\87094024\.ai-companion\review\20261029-art-collector-reviewB\findings.md`，這台本機、不同步；下面是濃縮版）。改完要跑 `bash tests/test-gcp-setup.sh`、`bash tests/test-code-audit.sh`、`node lazy-pack/code-and-ai-audit.mjs --self-test`，並把 `AGENTS.md` 的項數（現 25／166）同步；改完最多再審一輪，只看會讓程式出錯的點。
  - **`lazy-pack/gcp-setup-and-check.sh`**（✅ 6 組已改完、測試 65 項全過；測試檔的部分在這組一併做完）
    1. 參數解析：`--stage`／`--item`／`--project` 缺值或後面接選項就 `exit 2`；加 `*)` 分支擋未知選項；`--item` 驗證 1～8。
    2. 狀態檔：讀寫補 `SAVED_SOURCE_DIR`（不然整檔覆蓋會丟掉）；`SAVED_SECRET_COUNT`／`SAVED_DB_MIN_NTD`／`SAVED_DB_MAX_NTD`／`SAVED_EDM_MAX_NTD` 讀入時驗 `^[0-9]+$`；`--dry-run` 不寫狀態檔（第 1022 行 `cat > "$STATE_FILE"` 前沒有 MODE 判斷，`--check-only` 照寫）。
    3. gcloud 結果如實回報：加 Owner、`secrets create`、`services enable`、`sql instances patch`（2-2a/b/c 與方案 2～6）、Vertex 授權，都改成 `if` 判斷，失敗不計數、不寫「已完成」；加 Owner 前驗信箱格式並回顯再按 y。
    4. 資料庫：關公網 IP 前 describe 確認有私有連線並告知重啟；describe 失敗（`Unknown`）單獨一種狀態、不當已關閉；方案 2～6 patch 前加 y/N 與「會重啟、儲存空間不可縮減」；方案 3A 排程沒建立，要標示「需自行設定，否則約 NT$780～880」、不計入已完成；方案 1 依 tier 對應月租、未知標「未知」；方案 2／5／6 的儲存與備份天數，改 README 與選單描述（不改雲端行為）；dry-run 的 `IPV4_ENABLED` 等給固定模擬值。
    5. 非互動且多個專案、未給 `--project`：印出自動選了哪個或 `exit 2` 請改用 `--project`；專案迴圈內的 gcloud 加 `</dev/null`。
    6. 費用：封頂合計加 Cloud Run 上限 50（570～910）；`--check-only` 且未啟用 EDM 時更新 `SAVED_EDM_STATUS`／`SAVED_EDM_MAX_NTD`。
  - **`lazy-pack/code-and-ai-audit.mjs`**（✅ 5 組已改完、`test-code-audit.sh` 166 項與 `--self-test` 全過；新增測試留在文件與測試那組）
    1. `runCmd` 在 Windows 用 `shell: true` 且參數只包雙引號：`--repo` 網址檢查改白名單，拒絕含 `" & | < > ^ %` 與空白；`extractZip` 的 PowerShell 命令改用環境變數傳路徑（或拒絕含 `'`、`"`、`%`）。
    2. `git clone` 網址含帳密就拒絕，印網址與 stderr 前遮蔽 `//…@`；`resolveEvalEndpoint` 的錯誤訊息只印 `?`、`#` 之前並遮帳密（第 305、310 行）。
    3. `--self-test` 不寫真實 `reports/.lazy-pack-state.env`（`writeReports` 約第 500～512 行）。
    4. `IGNORE_DIRS` 的 `reports` 改成只忽略專案自己的 `REPORTS_DIR` 完整路徑。
    5. 檔頭註解補結束碼：0 通過、1 檢查未過（或 self-test 失敗）、2 來源或參數有問題。
  - **文件**：`README.md` 第 84 行 570～860 改 570～910、補 `--item` 編號對照（1～8 對應哪個細項；第三階段用 `--scan-only`／`--eval-only`）；`AGENT_SETUP_雲端資安設定與驗收指南.md` 第 225 行「關卡 9」補「費用精算只能用 `--stage cost`」；`config/params.json` 說明的「500~600 甜區」改 480~560；`AGENTS.md` 補一句 `docs/email-draft-to-director.md` 只留本機、不入版控。
  - **測試**：`tests/test-gcp-setup.sh` 加 `cleanup`＋`trap`（照 `test-code-audit.sh` 第 24～31 行）、備份後立刻 `rm -f` 狀態檔、各 run 加結束碼斷言；兩支測試取最新報告改用 `touch` 標記＋`-newer`，並刪掉本次產生的 `reports/stage-*-report-*.md`；`test-code-audit.sh` 的 t8j2 補查報告檔、t8j5／t8i4 補驗訊息，t8j～t8j5 搬到「假伺服器起得來」的 `if` 外面且 skip>0 時結束碼非 0，`kill` 後加 `wait`。新增測試：`--dry-run` 不寫狀態檔、`--check-only` 不呼叫寫入類 gcloud、gcp 腳本缺值與未知選項 `rc=2`、audit 腳本未知選項與 `--repo`／`--source` 缺值。
  - **只記待辦、這次不改**：PITR 參數沒依 MySQL／Postgres 判斷；Vertex 檢查把 API 列出失敗當未啟用；假 gcloud 的 `services list` 不看 `--filter`，測不到 Vertex／Scheduler「已啟用」分支。

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
