# 交接：錯誤回報第一段（code-and-ai-audit.mjs 的 --report-problem 與全程記錄）做完；下一步是第二段 gcp-setup-and-check.sh

> 寫於 2026-10-31 16:12（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

執行順序是使用者 2026-10-31 定的（也寫在 `D:\Dev\company\art-collector-recommender\docs\todo-plan.md` 第零節開頭）：① 錯誤回報 → ② 交接包 → ③ 整輪真雲端驗收。資訊相關權責單位用**電子郵件**收（D15，使用者 2026-10-31 回答），腳本不寄信。

1. 【錯誤回報】(b)：`lazy-pack/gcp-setup-and-check.sh` 的全程記錄與 `--report-problem`、19 處 `2>/dev/null` 改成記下來，連同 `tests/test-gcp-setup.sh` 新一段。照 (a) 的格式：紀錄檔 `reports/logs/gcp-setup-and-check-<時間>.log`，開頭 `# gcp-setup-and-check.sh 開始 …`、結尾 `# 結束，結束碼 N`，`LAZY_PACK_LOGS_DIR` 指到暫存資料夾；`--report-problem` 可轉呼叫 `node lazy-pack/code-and-ai-audit.mjs --report-problem`；bash 的遮蔽要和 `redactSecrets` 同一份規則（看 `D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs` 的 `redactSecrets`）。量過行數：腳本 1,419、測試 294，加上要比照的 (a) 約 200 行與新寫的，合計超過 800 行，要切兩段：(b1) 全程記錄＋`--report-problem`＋測試，(b2) 19 處 `2>/dev/null` 改記錄＋測試（估的，沒逐行量）。建議 Sonnet、high（規格明確、可用測試與改壞驗證檢查）
2. （使用者決定要不要）審閱 (a)：程式約 200 行加測試約 130 行，照 `review-changes` Skill；材料沒有公司個資時可選別家審閱者
3. 【錯誤回報】(c)：`AGENT_SETUP_雲端資安設定與驗收指南.md` 加「遇到錯誤時」一節、README 加說明。建議 Sonnet、medium
4. 【交接包】`--handoff`（D9）：動手前先讀 todo-plan 那一項與 `D:\Dev\company\vulnerability-scan-summary\docs\specs\` 第 8 節；欄位名稱與類別代號要請弱掃專案寫進規格，是跨專案的事先問使用者；交接包也走信件，ZIP 可能超過附件上限，要問資訊相關權責單位上限
5. 整輪真雲端驗收（todo-plan「【真雲端驗收】」）：需要使用者在場；Claude in Chrome 這台沒連上，瀏覽器操作由使用者做、貼回輸出

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動跑完三階段檢查，出錯時能把問題回報給資訊相關權責單位。第三階段 3-1～3-5 都做完；錯誤回報做完 (a)：`code-and-ai-audit.mjs` 有全程記錄、`--report-problem [--note]`、信件草稿與遮蔽，測試 479 項全過；(b)(c)、交接包、整輪真雲端驗收還沒做。

## 已完成

- 錯誤回報 (a)（2026-10-31）：程式、測試第 12 段 71 項、11 種改壞驗證、D15、AGENTS.md、待辦進度、施工紀錄 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md`「錯誤回報 (a)」；commit 見 git log
- 3-5 真雲端驗收（2026-10-31）、拋棄式專案已刪（見 D14）
- reflection 與歷程：真名版在 `D:\Dev\project-records\company\art-collector-recommender\`（reflections、journey、milestones）；去識別化版使用者看過後已寫進 second-brain 並推上 Drive

## 還沒做完

- 上面「下一步」各項
- 這個專案的整輪真雲端驗收（第一、二階段）還沒跑過
- 使用者自己清空資源回收筒（含這次移進去的，1,300 MB 以上）才會釋放 C 槽空間
- Codex 當主線呼叫別家的驗證：`D:\Dev\personal\ai-companion\docs\todo-plan.md`「反方向派工」，等 Codex 訂閱
- findings.json 寫不進去只警告的測試、429／5xx 退避、真實推薦端點的格式（todo-plan「【小補強】」「【待確認】」）
- 弱掃那邊照規格做 Skill 與懶人包（在那個專案另開 session）；Firebase 之後再談

## 這次定下的決策

- 錯誤回報用電子郵件寄：產生問題回報檔＋信件草稿，使用者自己寄；收件人信箱不寫進程式（repo 公開），用環境變數 `LAZY_PACK_REPORT_TO`（完整的在 D15）
- 紀錄內嵌進回報檔，不另打 ZIP；電子郵件與家目錄也遮（D15 第 3、4 點）

## 相關檔案

- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：「【錯誤回報】」（含 (a)(b)(c) 進度）、「【交接包】」
- `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`：D8、D15
- `D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`：`redactSecrets`、`startRunLog`、`writeProblemReport`
- `D:\Dev\company\art-collector-recommender\tests\test-code-audit.sh`：第 12 段（可單獨切出來跑改壞驗證）

## 踩過的坑

- 測試裡用 `cygpath -m` 轉「藏在檔案底下」的路徑會失敗並回空字串，變數空了就退回預設位置、寫到真的資料夾，測試還照樣通過；已收進 `D:\Dev\company\art-collector-recommender\AGENTS.md`「開發時踩過的坑」
- 手動跑 `--self-test` 會重寫 `reports/full-execution-report.md` 並新增單次報告；手動情境複製到暫存區跑
- 改壞驗證的錨點必須在檔案裡剛好出現一次（M8 第一次出現 3 次被跳過）
- Windows 版 gcloud 的立即掃描不支援；新專案沒有 docker 時用 `gcloud builds submit`（細節見 D13、D14）
- Bash 工具裡含反斜線的指令會被擋：改用 Write 寫檔再執行，或用 PowerShell；python 讀空的標準輸入會無限印 `Traceback`
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址、帳號 email、帳單帳戶編號
- 審閱材料只含某一個 commit 時，審閱者會把當時的待辦當現況；提示要註明或審整個範圍
- Claude in Chrome 擴充功能這台沒連上；需要瀏覽器操作時由使用者做、貼回輸出
