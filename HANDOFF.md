# 交接：段 A 完成（GCP 專案選單、自動探測 Cloud Run 網址、假 gcloud 自動測試），接著做段 B

> 寫於 2026-10-29 11:48（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 段 B1：改 `D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`（501 行，參數解析與掃描目標約第 435–485 行），沒帶 `--target` 時不再掃 Lazy Pack 自己，改成三種原始碼來源（雲端下載／AI Studio 匯出引導、GitHub clone、搜尋本機 Downloads／Desktop）的選單；同時在 `tests/` 加埋了假 `AIza` 金鑰的假 Next.js 專案與一支測試，用故意改壞的複本確認抓得到。規格見 `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「## 零、 Lazy Pack 工具包補強與審閱待辦」第 1、3 點。估：讀 mjs 501＋新寫約 150＋測試約 150 ≈ 800 行，所以 `--url` 切到 B2。建議模型與努力程度：主力模型（Opus），中～高，要上線的程式。
2. 段 B2：`--url` 線上 20 題測試（沒帶時讀狀態檔 `SAVED_CLOUD_RUN_URL`）＋假推薦 API 小伺服器的測試（同一節第 2、3 點）。估約 500 行。建議模型與努力程度：主力模型，中。
3. 段 C：同步 `AGENT_SETUP_雲端資安設定與驗收指南.md`、`README.md`（同一節第 4 點，約 450 行），之後照 `review-changes` 審 `2643155..HEAD`，最後由使用者用拋棄式 GCP 專案跑一輪（D7 第 ③ 層）。建議模型與努力程度：文件同步用 Sonnet、medium；審閱用主力模型。

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動找到正確的 GCP 專案、網站與原始碼，跑完三階段檢查。段 A（雲端專案選單＋Cloud Run 網址）做完並有自動測試；段 B（第三階段原始碼定位與線上測試）、段 C（文件、審閱、真雲端驗收）還沒做。

## 已完成

- 段 A：`gcp-setup-and-check.sh` 專案選單、自動探測 Cloud Run 網址並寫入狀態檔與報告、`--project`、拿掉 `gcloud config set project`；`tests/test-gcp-setup.sh` 25 項全過、改壞複本測得出來（這次的 commit）
- 給資訊部長的信：使用者已自行寄出

## 還沒做完

- 段 B1、B2、C 與審閱、真雲端驗收（見 `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「## 零、 Lazy Pack 工具包補強與審閱待辦」）
- 第一至第三階段的實際 GCP 設定與整合驗收（見同一份 todo-plan 的各階段段落）

## 這次定下的決策

- D7：整套流程分三層驗證（dry-run 只驗選單與報告；假 gcloud／假專案／假 API 收進 `tests/` 每次跑；拋棄式真 GCP 專案在三段與審閱完成後跑一次）（完整的在 `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`）

## 相關檔案

- `D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`：段 B 要改的腳本
- `D:\Dev\company\art-collector-recommender\tests\test-gcp-setup.sh`、`D:\Dev\company\art-collector-recommender\tests\fakebin\gcloud`：段 A 的測試，段 B 的測試照這個寫法
- `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh`：狀態檔 `reports/.lazy-pack-state.env` 寫入 `SAVED_PROJECT_ID`、`SAVED_CLOUD_RUN_SERVICE`、`SAVED_CLOUD_RUN_URL` 的地方在檔尾 `cat > "$STATE_FILE"`
- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：段 B、C 的規格

## 踩過的坑

- `--dry-run` 碰到 gcloud 的地方都換成寫死的假值，真正呼叫 gcloud 的分支只能靠假 gcloud 測（已寫進 `AGENTS.md`「改動後的驗證方式」）
- `read -p` 在輸入不是終端機（管線、AI Agent 代跑）時不印提示文字，測試不要比對提示，改看實際結果
- 段 B 的假 `AIza` 金鑰要在測試執行時才組出來（例如字串相接），不要整串寫進檔案，否則會被 commit 前的帳密掃描擋下或誤報
- 測試會覆寫 `reports/.lazy-pack-state.env`，`tests/test-gcp-setup.sh` 跑前備份、跑完還原；段 B 的測試照做
