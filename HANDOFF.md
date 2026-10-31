# 交接：C 槽失控輸出檔已查因並加防線，gcloud 與拋棄式 GCP 專案備好；下一步是 3-5 真雲端驗收

> 寫於 2026-10-31 11:50（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 3-5 立即掃描的真雲端驗收（**要在 Mac 做**，Windows 版 gcloud 不支援立即掃描；需要使用者在場）：自動掃描那半已在 Windows 驗完（見「已完成」）。Mac 步驟：①裝 gcloud（先講來源與大小、等同意）並登入同一個帳號；②`gcloud config set project art-rec-verify-7k2m`（拋棄式專案保留中，`ondemandscanning` 已開，映像檔 `asia-east1-docker.pkg.dev/art-rec-verify-7k2m/verify-repo/old-alpine@sha256:25ef6b512276e407c80098e3e3489bbf847588529583581d082f3ad6af726814` 已在）；③**動手前問使用者**：立即掃描一次約 US$0.26；④`gcloud artifacts docker images scan <映像檔> --remote --location=asia --format=json`，再 `list-vulnerabilities <掃描名稱> --format=json`，核對輸出格式、`response.scan` 欄位與 location 對應，丟進 `collectOccurrences`／`imageFindings`（預期同樣 1 筆 CVE-2021-36159、高、已有修補）；⑤驗完 `gcloud projects delete art-rec-verify-7k2m`。細節在 `docs/todo-plan.md`「【細項 3-5】」。建議 Sonnet、high

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動跑完三階段檢查。第三階段 3-1～3-5 的程式、測試、文件、審閱都做完；3-5 缺的只剩真雲端驗收。交接包、錯誤回報還沒做。

## 已完成

- C 槽只剩 1.5 GB：查到前一個 session 留下的 `python.exe -` 把背景輸出檔寫到 13.5 GB，結束行程、永久刪除該檔，C 槽回到 14.87 GB；另 1,300 MB（VS 解壓資料夾 7 個、VS Code 擴充快取 5 項）在資源回收筒，等使用者清空
- 真因與防線：空的標準輸入（空 heredoc、`< /dev/null`）讓這台 Python 3.14 進互動模式無限印 `Traceback`；dotfiles `pretooluse-backslash.sh` 加檢查、測試 35 項全過、真 Bash 工具實測擋得到（dotfiles `3331be6`），pitfalls 補一條（ai-companion `e511c32`）
- 真雲端驗收前置：scoop 裝 `gcloud` 591.0.0（`C:\Users\87094024\scoop\apps\gcloud\`，374 MB）、`gcloud auth login` 已登入（使用者的 Google 帳號）、建拋棄式專案 `art-rec-verify-7k2m`、綁到使用者既有的帳單帳戶、預算警示 NT$150（帳戶幣別是新台幣，用美元會 INVALID_ARGUMENT；帳戶原本就有一個 NT$10 的預算，沒動）。**2026-10-31 下午已開掃描 API、用 Cloud Build 推 `alpine:3.10` 舊版、自動掃描 US$0.26（約 NT$8.5）**；自動掃描輸出核對完、解析程式不用改；立即掃描 Windows 不支援（沒花錢），專案保留給 Mac 驗
- 施工紀錄見 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md`「2026-10-31 C 槽清理…」；真名版 reflection 在 `D:\Dev\project-records\company\art-collector-recommender\reflections\2026-10-31_windows_disk-cleanup.md`，歷程已追加

## 還沒做完

- 上面「下一步」那一項
- 這次 reflection 與歷程的**去識別化版本還沒寫進 second-brain**（公司專案要先給使用者看過）：草稿在本機暫存，開工時重新產一份給使用者看；寫入前照 `reflect`、`project-log` Skill
- Mac 也要裝 `gcloud`（使用者要求雙平台都裝）：在 Mac 另開 session；要先講來源與大小、等同意
- 使用者自己清空資源回收筒（1,300 MB）才會釋放 C 槽空間
- Codex 當主線呼叫別家的驗證（Antigravity 另一台已做完）：`D:\Dev\personal\ai-companion\docs\todo-plan.md`「反方向派工」，等 Codex 訂閱
- findings.json 寫不進去只警告的測試、429／5xx 退避、真實推薦端點的格式（todo-plan「【小補強】」「【待確認】」）
- findings 欄位名稱與類別代號（`IMG-VULN`、`CWE-1395`）要請 vulnerability-scan-summary 寫進規格第 8 節（待辦「【交接包】」）
- 弱掃那邊照規格做 Skill 與懶人包（在那個專案另開 session）；Firebase 之後再談

## 這次定下的決策

- gcloud 用 scoop 裝在 C 槽（使用者選 B；放 D 槽要手動解壓官方 zip 並改 PATH，沒做）
- 真雲端驗收用拋棄式專案、帳單由使用者自己出、預算警示 NT$150；驗完刪整個專案
- 防線只擋「空輸入」兩種形狀，不擋一般的 `python - <<'EOF'`（實測非空正常）

## 相關檔案

- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：第三階段「【細項 3-5】」
- `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`：D13 第 8 點
- `C:\Users\87094024\dotfiles\claude\hooks\pretooluse-backslash.sh`：新增的 Python 空輸入檢查

## 踩過的坑

- Bash 工具裡讓 python 讀到**空的**標準輸入（空 heredoc，例如 `python3 - <<'EOF' … || python - <<'EOF2'` 第一個 `EOF` 緊接在宣告後面；或 `< /dev/null`），這台的 Python 3.14 會進互動模式、無限印 `Traceback`；超過 120 秒被移到背景後不會結束，曾 3 小時寫出 13.5 GB。非空的 heredoc、管線都正常；工具說「已移到背景」的任務要確認它真的會結束；C 槽剩不到 5 GB 時先查 `C:\Users\87094024\AppData\Local\Temp\claude\` 底下有沒有異常大的 `tasks\*.output`
- `gcloud billing budgets create` 的金額幣別要跟帳單帳戶一致（這個帳戶是 TWD）；`gcloud auth login` 不要加 `--update-adc=false`（沒有這個用法，指令直接報錯、瀏覽器不會開）
- `scoop install` 會先順便更新 scoop 與 bucket，裝到的版本可能比 `scoop info` 查到的新，耗時約 9 分鐘
- 不要直接在專案裡手動跑受測腳本（會蓋掉 `reports\.lazy-pack-state.env`）；手動情境複製到暫存區跑
- Bash 工具裡含反斜線的指令會被擋：改用 Write 寫 .py 再執行，或用 PowerShell 工具
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址、帳號 email、帳單帳戶編號
- 審閱材料只含某一個 commit 時，審閱者會把當時的待辦當現況；提示要註明待辦已更新，或審整個範圍
- 寫 reflection 到 vault 前先查檔名：10-30 的 `change-review` 已被別的專案用掉，要順延編號
- 改 dotfiles 規則檔前先 `git fetch`：另一台電腦同日可能改了同一行；push 被拒絕時兩邊檔案不重疊可 `pull --rebase`（要先問使用者）
