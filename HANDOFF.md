# 交接：second-brain 紀錄補齊、派工與審閱者規則調整完成；下一步是真雲端驗收

> 寫於 2026-10-31 10:40（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 真雲端驗收（段 C 第 3 件）：核對 3-5 的 `images describe --show-package-vulnerability`、`scan --remote`、`list-vulnerabilities` 輸出格式、修補版本欄位與 location 對應。**這台 Windows 沒有裝 `gcloud`**（PATH 和常見安裝位置都查過），開工先問使用者：要在哪台電腦做（公司網路連 Google 雲端是否可行沒驗證過）、拋棄式 GCP 專案與帳號是否準備好；要裝 `gcloud` 時照 `environment.md`先講來源與大小、等使用者同意；立即掃描一份映像檔約 US$0.26，要使用者同意。需要使用者在場。建議模型與努力程度：Sonnet、high（核心是把真輸出丟進 `lazy-pack/code-and-ai-audit.mjs` 的解析程式看 `findings.json` 對不對，可客觀檢查）

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動跑完三階段檢查。第三階段 3-1～3-5 的程式、測試、文件、審閱都做完；second-brain 的去識別化歷程、reflection、大事記、首頁也補到 D2d。交接包、錯誤回報、真雲端驗收還沒做。

## 已完成

- 本 session：second-brain 的去識別化歷程（10-30 追加 5 段、新增 10-31）、reflection 6 篇、大事記、首頁寫入；`journey/` 併入 `歷程/`，舊檔與草稿移到資源回收筒；本機真名版（`D:\Dev\project-records\company\art-collector-recommender\`）補到 D2d
- 派工與審閱者規則（使用者逐句確認）：不分公私專案、公司或個資原文先去識別化才派別家、審閱者列建議選項讓使用者挑、便宜的模型不審閱、額度用完換下一個可用工具；改 dotfiles `claude/CLAUDE.md` 第 57、59 行、`docs/how-to/delegation.md` 第 20、38 行、`claude/skills/review-changes/SKILL.md` 第 12、39、42 行（dotfiles `6561541`、`4397a04`、`c7a87e4`、`581deaf`，已推送）
- 段 D2a～D2d 與更早的見 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md`

## 還沒做完

- 上面「下一步」那一項
- Codex 當主線呼叫別家的驗證（Antigravity 另一台已做完）：`D:\Dev\personal\ai-companion\docs\todo-plan.md`「反方向派工」，等 Codex 訂閱
- findings.json 寫不進去只警告的測試、429／5xx 退避、真實推薦端點的格式（todo-plan「【小補強】」「【待確認】」）
- findings 欄位名稱與類別代號（`IMG-VULN`、`CWE-1395`）要請 vulnerability-scan-summary 寫進規格第 8 節（待辦「【交接包】」）
- 弱掃那邊照規格做 Skill 與懶人包（在那個專案另開 session）；Firebase 之後再談

## 這次定下的決策

- 派工不分公司或私人專案，資料用 `deidentify` 管（理由：減主流程 context、原文送出收不回；完整的在 `C:\Users\87094024\dotfiles\docs\decisions\2026-10.md` 最後一則）
- `delegation.md` 第 45 行維持另一台實測過的 Antigravity 做法，不寫「不限主線」

## 相關檔案

- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：第三階段「【細項 3-5】」
- `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`：D13 第 8 點

## 踩過的坑

- 不要直接在專案裡手動跑受測腳本（會蓋掉 `reports\.lazy-pack-state.env`）；手動情境複製到暫存區跑
- Bash 工具裡含反斜線的指令會被擋、heredoc 餵 python 會卡住：改用 Write 寫 .py 再執行，或用 PowerShell 工具
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址
- 審閱材料只含某一個 commit 時，審閱者會把當時的待辦當現況；提示要註明待辦已更新，或審整個範圍
- 寫 reflection 到 vault 前先查檔名：10-30 的 `change-review` 已被別的專案用掉，要順延編號
- 改 dotfiles 規則檔前先 `git fetch`：另一台電腦同日可能改了同一行（這次 `delegation.md` 第 45 行就是）
