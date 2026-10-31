# 交接：3-5 映像檔漏洞掃描真雲端驗收全部完成、拋棄式專案已刪；下一步是交接包 `--handoff`

> 寫於 2026-10-31 15:35（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

執行順序是使用者 2026-10-31 定的（也寫在 `D:\Dev\company\art-collector-recommender\docs\todo-plan.md` 第零節開頭）：① 錯誤回報 → ② 交接包 → ③ 整輪真雲端驗收。

1. 【錯誤回報】（D8，todo-plan「【錯誤回報】」）：兩支腳本加 `--report-problem`、全程記錄存 `reports/logs/`、`AGENT_SETUP` 加「遇到錯誤時」一節。**開工第一件事先問使用者**：資訊相關權責單位用什麼方式收（信件、共用資料夾或其他），交接包也走同一條管道。量過的行數：`lazy-pack/gcp-setup-and-check.sh` 1,419、`lazy-pack/code-and-ai-audit.mjs` 1,717、`tests/test-gcp-setup.sh` 294、`tests/test-code-audit.sh` 706，合計超過 800 行，要切段；建議切法：(a) `code-and-ai-audit.mjs` 的 `--report-problem` 與紀錄（連同它的測試），(b) `gcp-setup-and-check.sh` 的 19 處 `2>/dev/null` 與 `--report-problem`（連同它的測試），(c) `AGENT_SETUP` 與 README 文件；每段做完收工。建議 Sonnet、high（規格明確、可用測試檢查；收件方式與遮罩範圍的決定要問使用者）
2. 【交接包】`--handoff`（D9，todo-plan「【交接包】」）：把第三階段結果交給弱掃專案（`D:\Dev\company\vulnerability-scan-summary\docs\specs\`）串接年度彙整。動手前先讀 todo-plan 那一項與弱掃專案規格第 8 節；欄位名稱與類別代號（`IMG-VULN`、`CWE-1395`）要請 vulnerability-scan-summary 寫進規格第 8 節，是跨專案的事，先問使用者。建議 Sonnet、high
3. 整輪真雲端驗收（todo-plan「【真雲端驗收】」）：第一、二、三階段一次在拋棄式專案驗完（估 NT$0～50）；需要使用者在場（登入、同意花費），Claude in Chrome 這台沒連上，需要瀏覽器操作時由使用者做、貼回輸出

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動跑完三階段檢查。第三階段 3-1～3-5 的程式、測試（`test-code-audit.sh` 408 項、`test-gcp-setup.sh` 137 項）、文件、審閱、真雲端驗收都做完。交接包、錯誤回報還沒做。

## 已完成

- 3-5 真雲端驗收（2026-10-31）：自動掃描在 Windows、立即掃描在 Cloud Shell（使用者貼指令輸出，我核對）都驗完，解析程式不用改，共花 US$0.52（兩種掃描各一份 US$0.26）；立即掃描在 Windows 版 gcloud 不支援，腳本已補白話提示並加測試與真輸出 fixture（`D:\Dev\company\art-collector-recommender\tests\fixtures\real-scan\`）；拋棄式專案 `art-rec-verify-7k2m` 已刪（`DELETE_REQUESTED`，30 天內可 `gcloud projects undelete`）。細節見施工紀錄 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md` 最後三段、決策紀錄 D14
- reflection、歷程、大事記：C 槽清理、3-5 驗收（含 Cloud Shell 驗完這一段）的真名版與去識別化版都已寫進 `D:\Dev\project-records\company\art-collector-recommender\` 與 second-brain；歷程裡較早那一段寫的是「改在 Mac 驗」，之後改成 Cloud Shell，以決策紀錄 D14 為準（歷程只新增，沒改）
- C 槽失控輸出檔查因並加防線（dotfiles `3331be6`、ai-companion `e511c32`）；gcloud 591.0.0 以 scoop 裝在 Windows（`C:\Users\87094024\scoop\apps\gcloud\`），Mac 也已裝好 gcloud

## 還沒做完

- 上面「下一步」那一項
- 這個專案的整輪真雲端驗收（第一、二階段）還沒跑過（todo-plan「【真雲端驗收】」）
- 使用者自己清空資源回收筒（1,300 MB）才會釋放 C 槽空間
- Codex 當主線呼叫別家的驗證（Antigravity 另一台已做完）：`D:\Dev\personal\ai-companion\docs\todo-plan.md`「反方向派工」，等 Codex 訂閱
- findings.json 寫不進去只警告的測試、429／5xx 退避、真實推薦端點的格式（todo-plan「【小補強】」「【待確認】」）
- 弱掃那邊照規格做 Skill 與懶人包（在那個專案另開 session）；Firebase 之後再談

## 這次定下的決策

- 立即掃描改用 Cloud Shell 驗、公司專案只留在 Windows，不 clone 到 Mac；Mac 的 gcloud 等將來能在 Mac 驗的專案再用
- Windows 白話提示驗完後補（已補）；腳本仍會先開通 `ondemandscanning`（免費）再發現不支援，不先判斷作業系統（否則假 gcloud 的測試在 Windows 走不到）
- 驗完刪整個拋棄式專案

## 相關檔案

- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：「【交接包】」「【小補強】」「【待確認】」
- `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`：D9、D13、D14
- `D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`：3-5 在 `runImageScan` 一帶

## 踩過的坑

- Windows 版 gcloud 的立即掃描（`artifacts docker images scan`）不支援，回 "On-Demand Scanning is not supported on Windows"；要在 Mac、Linux 或 Cloud Shell。自動掃描 Windows 可用
- 新 GCP 專案沒有 docker／podman 時，用 `gcloud builds submit <資料夾> --tag <映像檔>` 推映像檔，要先給預設運算服務帳號 `roles/cloudbuild.builds.builder`；`--region=asia-east1` 會回 NOT_FOUND，用全域
- 自動掃描只掃開通之後新推的映像檔；`containerscanning` 要在推映像檔之前開
- Bash 工具裡讓 python 讀到**空的**標準輸入（空 heredoc，或 `< /dev/null`），這台的 Python 3.14 會進互動模式無限印 `Traceback`；非空 heredoc、管線正常；工具說「已移到背景」的任務要確認它真的會結束；C 槽剩不到 5 GB 時先查 `C:\Users\87094024\AppData\Local\Temp\claude\` 底下有沒有異常大的 `tasks\*.output`
- `gcloud billing budgets create` 的金額幣別要跟帳單帳戶一致（這個帳戶是 TWD）
- 不要直接在專案裡手動跑受測腳本（會蓋掉 `reports\.lazy-pack-state.env`）；手動情境複製到暫存區跑。`tests/test-code-audit.sh` 整支約 4 分鐘（之前量到約 1 分鐘，看負載）
- Bash 工具裡含反斜線的指令會被擋：改用 Write 寫 .py 再執行，或用 PowerShell 工具
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址、帳號 email、帳單帳戶編號
- 審閱材料只含某一個 commit 時，審閱者會把當時的待辦當現況；提示要註明待辦已更新，或審整個範圍
- 寫 reflection 到 vault 前先查檔名；改 dotfiles 規則檔前先 `git fetch`
- Claude in Chrome 擴充功能這台沒連上，無法代操作瀏覽器；需要瀏覽器操作時由使用者做、貼回輸出
