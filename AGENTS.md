# art-collector-recommender — AGENTS.md

藏家推薦系統之雲端 AI 開發資安治理、架構評估、每月費用精算與自動化檢查懶人包（Lazy Pack）專案；使用者操作說明見同目錄的 `README.md`，跨 AI 工具自動代操領航指南見 `AGENT_SETUP_雲端資安設定與驗收指南.md`。

## 公私歸屬

- 歸屬：公司
- 完整紀錄位置：`D:\Dev\project-records\company\art-collector-recommender\`
- 推送：自動

## 技術選型與理由

- **雲端架構**：Google AI Studio（Build 模式，維持 **Paid Tier 付費層**以保障客戶資料 100% 不用於模型訓練；亦於 Lazy Pack 內建 **Vertex AI** 互動式啟用選項）＋ Google Cloud Run（Next.js 全端容器）＋ Google Cloud SQL（PostgreSQL / MySQL）＋ Cloud Scheduler（選配排程觸發以人推畫／以畫推人客製化 EDM）＋ 外部發信 API（Resend / Brevo）（決策見 `docs/decisions/2026-10.md` D1、D5）。
- **身分驗證**：無企業網域，採用 GCP OAuth Consent Screen `Testing` 模式白名單（Test Users Allowlist）搭配後端 `ALLOWED_EMAILS` 核驗，阻絕外部 Gmail 登入；排程路由 `/api/cron/send-edm` 另以 Secret Manager 之 `CRON_SECRET` 驗證（見 D2、D5）。
- **自動化懶人包（Lazy Pack）與跨 AI 領航指南**：
  - 跨 AI 自動代操指南（`AGENT_SETUP_雲端資安設定與驗收指南.md`）：仿照 `ai-agent-ep04` 領航格式，供無資訊背景使用者將檔案或 GitHub 網址直接交給任何 AI Agent（Claude Code／ChatGPT App & Codex／Antigravity 2／Cursor／OpenCode）全程代操電腦完成三階段檢查、設定、費用精算與報告產出（見 D6）。
  - 雲端分階段設定、體檢與費用精算（`lazy-pack/gcp-setup-and-check.sh`）：Bash 腳本，支援 `--stage 1|2|cost|all` 與 `--item 1..8` 分階段或挑單一細項執行（不押特定日期）；不帶 `--project` 時列出帳號下所有 GCP 專案供選擇，並探測、記下藏家推薦系統的 Cloud Run 網址（`reports/.lazy-pack-state.env` 的 `SAVED_CLOUD_RUN_URL`）；每個細項執行前先展示「6 點白話說明卡」並允許自由選做或跳過；細項 1-3 將「每月預算金額」與「AI 每日呼叫上限」設計為帶數值影響說明之互動問答題（預設原值 1,000）；內建「💰 雲端服務開啟清單與每月費用精算器」；每次執行自動輸出「單次階段執行報告」並更新「全部執行累計總報告（`reports/full-execution-report.md`）」（見 D3、D4、D5、D6）。出問題時的回報（D8、D15）：每次執行（`--report-problem`、`--help` 除外）腳本把自己再跑一次、經 `tee` 把終端機印的全部內容遮蔽後記到 `reports/logs/gcp-setup-and-check-<時間>.log`（格式同 `code-and-ai-audit.mjs`：開頭記參數與環境、結尾記結束碼；記不下來就照常跑、不記），遮蔽規則是 `redactSecrets` 的 sed 版（`lp_redact_init`，改一邊要改另一邊）；`--report-problem [--note]` 轉給 `code-and-ai-audit.mjs --report-problem`（兩支腳本的紀錄都收），找不到 node 時印白話說明與最近一次紀錄的位置、結束碼 1。gcloud 錯誤訊息被 `2>/dev/null` 丟掉的 19 處還沒改成記下來（待辦【錯誤回報】(b2)）。
  - 本機程式碼掃描與 AI 紅隊測試（`lazy-pack/code-and-ai-audit.mjs`）：Node.js ESM 腳本，讀取 `config/params.json`；不帶 `--target` 時不掃自己，出「原始碼在哪裡」選單（[A] 雲端 Cloud Build 原始碼／AI Studio 下載引導、[B] GitHub clone、[C] 搜尋本機下載與桌面的資料夾與 ZIP，`--source`、`--repo` 可跳過選單，抓下來的放 `reports/sources/`），`--target` 指到 Lazy Pack 自己、不存在或沒有程式碼檔時結束碼 2；支援細項自由選擇（`--scan-only`、`--eval-only`、`--run-ai-eval`），執行靜態金鑰掃描與 20 題 LLM-as-a-Judge 推薦品質/防注入/EDM 收件人隱私驗收；20 題的測試對象依序為 `--url`、狀態檔的 `SAVED_CLOUD_RUN_URL`、本機模擬回應（`--mock`、`--self-test` 一律模擬），線上端點的路徑與格式是假設的約定（預設 `POST /api/recommend`，`--api-path` 可改，要登入時用環境變數 `LAZY_PACK_API_TOKEN`，約定寫在腳本開頭註解），有網址時（`--web-check` 只跑這兩項、`--run-ai-eval` 全跑）再做 3-3 網址預檢（node 內建 fetch 與 tls 看 HSTS、Cookie 旗標、CORS、TLS 1.0／1.1、錯誤頁露出版本）與 3-4 MDN HTTP Observatory（只送主機名稱、掃描紀錄公開，要 `--observatory` 或在終端機回答 y 才送，管線的回答不算同意），結果照弱掃專案的共同格式寫進 `reports/findings.json`（D10、D11、D12；連不上網站時不改寫、也不送 Observatory，本機與內網網址不送 Observatory）；並自動輸出第三階段單次報告與更新全部執行累計總報告（見 D4、D6）。出問題時的回報（D8、D15）：每次執行把終端機印的全部內容記到 `reports/logs/code-and-ai-audit-<時間>.log`；`--report-problem [--note "<狀況>"]` 把兩支腳本最近一次的紀錄、環境與各階段最後狀態整理成 `reports/problem-report-<時間>.md`，另寫信件草稿 `reports/problem-email-draft-<時間>.txt`（資訊相關權責單位用電子郵件收；腳本不寄信，收件人信箱不寫進程式，設環境變數 `LAZY_PACK_REPORT_TO` 帶入草稿）；紀錄與回報檔先遮掉金鑰、密碼、電子郵件與電腦使用者名稱；測試時用 `LAZY_PACK_LOGS_DIR` 指到暫存資料夾。
  - 3-5 Artifact Analysis 容器映像檔漏洞掃描（同一支 `code-and-ai-audit.mjs`，D9、D13）：`--image-scan` 只跑 3-5，`--run-ai-eval` 也跑；專案與網站取自狀態檔的 `SAVED_PROJECT_ID`、`SAVED_CLOUD_RUN_SERVICE`，從網站最新版本取映像檔 digest，要在 Artifact Registry 才掃；自動掃描（`containerscanning`）與立即掃描（`ondemandscanning`，`--scan-now`）兩種都做，開通（`--enable-image-scan`）與立即掃描都會花錢（一份映像檔 US$0.26），要帶旗標或在終端機回答 y，管線的回答不算同意；高、中風險而且已有修補版本的才讓第三階段不通過（類別代號 `IMG-VULN`、CWE-1395）；`--image-scan` 沒有結果時結束碼 2；立即掃描在 Windows 版 gcloud 不支援（真雲端實測），腳本印白話提示（改在 Mac、Linux 或 Cloud Shell 執行）後略過，自動掃描與立即掃描的輸出格式都已用真輸出核對（D14）；`reports/findings.json` 依類別代號開頭分段換掉（`WEB-`、`OBS-`、`IMG-`）；開通狀態記在狀態檔 `SAVED_IMAGE_SCAN_ENABLED`，`gcp-setup-and-check.sh` 只讀、照原樣寫回，並把開通後的月費算進費用精算器第 8 項。

## 資料夾結構

```text
art-collector-recommender/
├── AGENT_SETUP_雲端資安設定與驗收指南.md  # 給所有 AI Agent 讀的無腦代操領航指南
├── AGENTS.md                            # 本檔（開發視角與專案規則）
├── README.md                            # 操作指南（使用者視角，含白話口令、6 種 DB 方案與費用精算表）
├── config/
│   └── params.json                      # 可調參數檔（預算、配額、驗收門檻與 _說明）
├── lazy-pack/
│   ├── gcp-setup-and-check.sh           # 雲端 GCP 分階段資安檢查、互動設定與費用精算腳本
│   └── code-and-ai-audit.mjs            # 本機原始碼金鑰掃描、AI 推薦品質驗收、網址預檢與 Observatory 腳本
├── tests/
│   ├── test-gcp-setup.sh                # gcp-setup-and-check.sh 自動測試（假 gcloud 走真實分支＋dry-run；第 17 段是全程記錄、遮蔽與 --report-problem）
│   ├── test-code-audit.sh               # code-and-ai-audit.mjs 自動測試（--target 防呆、三種原始碼來源、埋假金鑰的複本、--url 線上測試、3-3／3-4 網址檢查、3-5 映像檔掃描）
│   ├── fake-recommend-api.mjs           # 假推薦 API、假網站與假 Observatory 小伺服器（網址第一段決定回對或回錯；給憑證時另開兩個 https）
│   ├── fakebin/gcloud(.cmd)             # 假 gcloud：依參數回固定輸出並記下呼叫（.cmd 給 Windows 的 node 經 cmd.exe 叫）
│   └── fixtures/                        # fake-nextjs-app/：乾淨的假 Next.js 專案（--self-test 掃它；測試執行時才複製一份埋問題）；real-scan/：3-5 真雲端實測輸出（專案、映像檔名稱換成假的）
├── reports/                             # 自動輸出之單次階段報告、全部階段執行累計總報告、findings.json、logs/（每次執行的全程記錄）與 problem-report-*.md／problem-email-draft-*.txt（--report-problem 產生，不入版控）
│   （另：`docs/email-draft-to-director.md` 只留本機、不入版控，見 `.gitignore`）
└── docs/
    ├── assessment-and-sop.md                     # 專案概況與六大資安規範 SOP 完整報告
    ├── edm-feature-implementation-and-pricing.md # 排程發送客製化 EDM 開發者實作指南與收費標準說明
    ├── todo-plan.md                              # 待辦清單（只留未完成項目）
    ├── worklog/                                  # 施工紀錄（分月存）
    └── decisions/                                # 決策紀錄（分月存）
```

## 資料模型與參數定義

- 所有可調門檻集中於 `config/params.json`（含 `"_說明"`），包含每月預算警示 `budget_monthly_ntd`（現在是 1000）、資料庫目標月租 `db_target_monthly_ntd`（現在是 550）、API 每日上限 `api_quota_rpd`（現在是 1000）、每分鐘上限 `api_quota_rpm`（現在是 30）、備份天數 `backup_retention_days`（現在是 14）、每日 EDM 發送上限 `edm_daily_send_limit`（現在是 100）、驗收題數 `eval_question_count`（現在是 20）、測試藏家預算上限 `eval_max_budget_ntd`（現在是 200000）、驗收合格門檻百分比 `eval_pass_threshold_pct`（現在是 100）、`--url` 線上測試每題等待秒數 `eval_request_timeout_sec`（現在是 30）、3-5 每份映像檔掃描費用美元 `image_scan_usd_per_image`（現在是 0.26）、費用精算用的每月部署次數 `image_scan_deploys_per_month`（現在是 20）、美元兌新台幣匯率 `usd_twd_rate`（現在是 32.5，估的）。

## 業務規則精確定義

1. **所有自動化檢查與設定皆須具備冪等性（Idempotency）與細項可選性**：執行任何變更前，先查詢現況；若該項設定已存在且符合安全標準，印出 `✅ 已存在，自動跳過`；尚未設定之細項先展示「6 點白話說明卡」，允許執行者逐項決定現在做或暫緩跳過。
2. **Cloud SQL 規格採互動式選擇**：腳本不強制降級為最低規格，而是列出 6 種方案（含維持現況、NT$500–600/月 之 `db-g1-small` 搭配上下班自動啟停排程，或 `db-f1-micro` 加大儲存與 30 天 PITR 備份）供執行者討論決定。
3. **雙軌報告與每月費用精算自動輸出**：每次執行任一階段，皆自動輸出單次報告 `reports/stage-<階段>-report-<時間>.md` 並更新累計總報告 `reports/full-execution-report.md`（內含 8 大雲端服務開啟狀態與每月費用精算表）。
4. **前端零機密原則**：任何含 `AIza`、`postgres://` 或未加白名單之敏感變數，不得出現於前端 bundle 或 `NEXT_PUBLIC_` 變數中。

## 核心流程（分三階段推進，不押特定日期）

1. **第一階段（立即止血與基礎防護）**：執行 `bash lazy-pack/gcp-setup-and-check.sh --stage 1` 檢查並導引完成 Paid Tier 綁定、雙 Owner 共管、互動問答設定每月預算與 API 每日上限、設定 OAuth 同仁 Gmail 白名單。
2. **第二階段（系統架構加固與規格選型）**：執行 `bash lazy-pack/gcp-setup-and-check.sh --stage 2` 隔離金鑰至 Secret Manager、關閉 Cloud SQL 公網 IP／開啟 SSL 與每日備份、選定資料庫月租方案（含選配 Vertex AI 與排程 EDM），並自動產出每月費用精算表。
3. **第三階段（上線前原始碼與 AI 總體檢）**：於本機執行 `node lazy-pack/code-and-ai-audit.mjs --run-ai-eval` 掃描程式碼並完成 AI 推薦精準度與防注入測試（有網站網址時打線上網站；現在是 20 題，見 `config/params.json` 的 `eval_question_count`），有網址時再做 3-3 網址預檢與 3-4 MDN Observatory，並做 3-5 容器映像檔漏洞掃描（開通與立即掃描會花錢，要使用者同意），產出最終《全部階段執行累計總報告》。

## 開發時踩過的坑

- Windows PowerShell 傳雙引號字串給 `python -c` 時，反ticks（`` ` ``）會被 PowerShell 當作跳脫字元吃掉；跨工具批量替換文字應寫成獨立 `.py` 腳本執行。
- Google Cloud SQL 官方 24 小時機型直接從 `db-f1-micro`（約 NT$300/月）跳至 `db-g1-small`（約 NT$800/月），若預算落在 NT$500–600/月，需透過「`db-g1-small` ＋ Cloud Scheduler 平日上下班自動開關機」或「`db-f1-micro` ＋ 50GB SSD ＋ 30 天 PITR 備份」達成。

- Git Bash 會把 `/v2/rec` 這類以斜線開頭的參數改成 `C:/Program Files/Git/v2/rec`：`--api-path` 寫成 `v2/rec`（腳本會擋下被改過的值），測試要原樣傳時前面加 `MSYS_NO_PATHCONV=1`（加了之後受測腳本自己的路徑也不轉，要給 `cygpath -m` 轉出的 `D:/…` 寫法）。
- Git Bash 的 openssl 要加 `MSYS_NO_PATHCONV=1`（不然 `-subj "/CN=…"` 會被改成 Windows 路徑），加了之後檔案路徑也要給 `cygpath -m` 轉出的 `D:/…` 寫法，不然開不了 `/tmp/…`。
- Windows 上 node 叫 `gcloud`、`git` 要經 cmd.exe（真的是 `.cmd`），所以 `code-and-ai-audit.mjs` 的 `runCmd` 在 Windows 用 `shell: true`、參數加雙引號；假 gcloud 因此另放 `tests/fakebin/gcloud.cmd` 轉給 bash。給 node 的路徑在測試裡一律用 `cygpath -m` 轉成 `D:/…`。

- 測試裡用 `cygpath -m` 轉「藏在檔案底下」的路徑會失敗並回空字串（`LAZY_PACK_LOGS_DIR` 變空就退回預設的 `reports/logs/`，寫到真的資料夾、測試還照樣通過）：先轉共同前綴再接後半段（`$(mp "$S")/afile/logs`），並對「不該發生」的情況加正面檢查。手動跑 `--self-test` 等也會重寫 `reports/full-execution-report.md` 並新增單次報告，只把紀錄指到暫存區不夠。
- 改壞驗證用的精簡測試與改壞腳本放在暫存區：`tests/test-code-audit.sh` 第 12 段、`tests/test-gcp-setup.sh` 第 17 段（錯誤回報）可單獨切出來跑，錨點要先確認在檔案裡剛好出現一次。
- Git Bash 每開一個外部程式要 0.1～0.3 秒：`gcp-setup-and-check.sh` 開頭的全程記錄第一版叫了三十幾次（cygpath、awk、mktemp、sed 探測），每次執行多 5 秒；改成家目錄一次 awk 算完、sed 規則放陣列、日期只叫一次後只多約 0.4 秒。腳本開頭每次都會跑的地方不要逐項叫外部程式。

## 安全與備份

- 腳本只讀取環境變數與 Secret Manager 名稱，不在 repo 內儲存任何真實 API Key、資料庫密碼或藏家真實個資。
- 測試 AI 推薦與防注入時，一律使用腳本內建之虛構藏家與畫作假資料（Dummy Data）。

## 改動後的驗證方式

1. 修改 `lazy-pack/gcp-setup-and-check.sh` 後，用 Git Bash 的 `C:\Program Files\Git\bin\bash.exe -n lazy-pack/gcp-setup-and-check.sh` 驗證語法無誤，跑 `bash tests/test-gcp-setup.sh`（PATH 前面放假 gcloud，走真實分支、不連雲端；現在 246 項，這台實測約 2～15 分鐘（看當時負載），第 17 段可單獨切出來跑），並用 `--dry-run` 模式測試 `--stage 1`、`--stage 2`、`--stage cost` 與報告輸出。`--dry-run` 碰到 gcloud 的地方都換成寫死的假值，只驗得到選單與報告，不能取代前者。
2. 修改 `lazy-pack/code-and-ai-audit.mjs` 或 `config/params.json` 後，執行 `node lazy-pack/code-and-ai-audit.mjs --self-test` 確認參數讀取、靜態掃描（掃 `tests/fixtures/fake-nextjs-app`）、模擬閱卷、3-3、3-5 的判斷規則與報告輸出皆通過，再跑 `bash tests/test-code-audit.sh`（假 gcloud、本機假 git repo、假 ZIP、假推薦 API 與假網站、假 Observatory 小伺服器，不連雲端、不打真的 Observatory；現在 479 項，這台實測約 1～4 分鐘（看當時負載））。手動跑 `--eval-only`、`--run-ai-eval` 前，先把 `reports/.lazy-pack-state.env` 備份並移開（裡面第一階段記下的真網址會被當成測試對象），或加 `--mock`；`tests/test-code-audit.sh` 自己會備份、移開（連同 `reports/findings.json`），結束或被中斷時還原。
