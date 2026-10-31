# 交接：C 槽失控輸出檔已查因並加防線，gcloud 與拋棄式 GCP 專案備好；下一步是 3-5 真雲端驗收

> 寫於 2026-10-31 11:50（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 3-5 真雲端驗收（段 C 第 3 件，**需要使用者在場**）：前置都備好了（見「已完成」）。照順序：①開 Artifact Registry 與掃描用的 API（`artifactregistry`、`ondemandscanning`、`containeranalysis`，必要時 `containerscanning`），建一個 Artifact Registry 倉庫（地區用 `asia-east1`，立即掃描的資料處理地點只有 us、europe、asia）；②推一份很小的映像檔（例如 `alpine` 舊版，好讓有漏洞可看）；③**動手前再問使用者**：立即掃描一份約 US$0.26（實際收到 NT$ 帳單，專案已設 NT$150 預算警示）；④核對 `images describe --show-package-vulnerability`、`scan --remote`、`list-vulnerabilities` 的輸出格式、修補版本欄位與 location，把真輸出丟進 `lazy-pack/code-and-ai-audit.mjs` 的解析程式，看 `reports\findings.json` 對不對；⑤驗完整個專案 `gcloud projects delete art-rec-verify-7k2m`。要用拋棄式專案，`gcloud config` 的 `core/project` 已指到它（用 `gcloud config get project` 確認）。建議模型與努力程度：Sonnet、high（核心是比對真輸出與解析結果，可客觀檢查；動手前的花費確認照舊問使用者）

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動跑完三階段檢查。第三階段 3-1～3-5 的程式、測試、文件、審閱都做完；3-5 缺的只剩真雲端驗收。交接包、錯誤回報還沒做。

## 已完成

- C 槽只剩 1.5 GB：查到前一個 session 留下的 `python.exe -` 把背景輸出檔寫到 13.5 GB，結束行程、永久刪除該檔，C 槽回到 14.87 GB；另 1,300 MB（VS 解壓資料夾 7 個、VS Code 擴充快取 5 項）在資源回收筒，等使用者清空
- 真因與防線：空的標準輸入（空 heredoc、`< /dev/null`）讓這台 Python 3.14 進互動模式無限印 `Traceback`；dotfiles `pretooluse-backslash.sh` 加檢查、測試 35 項全過、真 Bash 工具實測擋得到（dotfiles `3331be6`），pitfalls 補一條（ai-companion `e511c32`）
- 真雲端驗收前置：scoop 裝 `gcloud` 591.0.0（`C:\Users\87094024\scoop\apps\gcloud\`，374 MB）、`gcloud auth login` 已登入（使用者的 Google 帳號）、建拋棄式專案 `art-rec-verify-7k2m`、綁到使用者既有的帳單帳戶、預算警示 NT$150（帳戶幣別是新台幣，用美元會 INVALID_ARGUMENT；帳戶原本就有一個 NT$10 的預算，沒動）。**還沒開掃描 API、沒推映像檔、沒掃描、沒有花費**
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
