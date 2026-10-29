# 交接：段 C 第 2 件審閱完成（13 份），接著照確認的清單修改（第 3 件真雲端驗收排在修改之後）

> 寫於 2026-10-29 15:58（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 依 `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「【審閱修改】」逐項修改（使用者 2026-10-29 已確認「照建議改」，細項、位置、確切改法都在該項底下）。分三組做、每組做完跑測試再接下一組：(a) `lazy-pack/gcp-setup-and-check.sh`（6 組改動，最大）；(b) `lazy-pack/code-and-ai-audit.mjs`（5 組）；(c) 文件與兩支測試（含新增測試與 `AGENTS.md` 項數）。量過：`gcp-setup-and-check.sh` 約 1,100+ 行、`code-and-ai-audit.mjs` 約 900 行、兩支測試各數百行，加上要新寫的測試，超過 800 行，所以切三組、每組一個對話（我只估要改的處與其依賴，實際常是 1.4～2.5 倍）。建議模型與努力程度：Sonnet、medium（有確切清單、跑測試就能驗）；做完請用主力模型抽查命令注入（`runCmd`、`extractZip`）與「gcloud 失敗不計數」兩處。不需要使用者在場。
2. 改完最多再審一輪（`review-changes`，只看會讓程式出錯的點，審閱者問使用者；公司專案只用 Claude Code 的 Sonnet 或 Opus）。
3. 段 C 第 3 件：使用者用個人帳號建拋棄式 GCP 專案、部署 hello-world Cloud Run，從第一階段跑到第三階段（D7 第 ③ 層，估 NT$0～50）。需要使用者在場；等第 1 項修好再做。

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動找到正確的 GCP 專案、網站與原始碼，跑完三階段檢查。段 A、B1、B2 完成並審過；段 C 第 1 件（同步 `AGENT_SETUP` 與 `README.md`，`91a7b83`）完成；第 2 件整段審閱完成（13 份、發現已確認），修改還沒開始。

## 已完成

- 段 A、B1、B2 與 B2 審閱修改（53f7987、cf51a76、1d0c04b、c47d814）
- 段 C 第 1 件：文件同步（91a7b83）；`AGENTS.md` 加「推送：自動」（5bfc691，已推送）
- 段 C 第 2 件：`2643155..HEAD` 審閱（排除紀錄與早期說明文件後 13 份、Sonnet、檢查碼全對）；批次授權停損做法已寫進 dotfiles 的 `review-changes` Skill
- 審閱材料與完整發現存在這台 `C:\Users\87094024\.ai-companion\review\20261029-art-collector-reviewB\`（含 `findings.md`，每台本機、不同步；全部改完後列給使用者、同意才移到資源回收筒）

## 還沒做完

- 上面「下一步」第 1～3 項
- 真實推薦端點的路徑與格式待確認（`D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「【待確認】」）
- 429／5xx 退避、報告取最新一份的時間戳風險（todo-plan「【小補強】」）；逾時分支沒有自動測試
- 這次審閱只記待辦不改的三項（PITR 參數、Vertex 檢查、假 gcloud 的 `--filter`），在 todo-plan「【審閱修改】」最後一條
- 本次審閱的 reflection 與專案紀錄還沒寫（公司專案：去識別化版本要先給使用者看；完整版寫到 `D:\Dev\project-records\company\art-collector-recommender\`）。使用者要求收工當下額度只剩約 6%，所以延到下個對話
- 第一至第三階段的實際 GCP 設定與整合驗收（todo-plan 各階段段落）

## 這次定下的決策

- 批次授權審閱：使用者可一次授權整批審完、最後才出結果，並給停損條件（這次是 5 小時額度剩 7%、每週額度剩 3%、上下文 35%）（寫進 dotfiles `claude/skills/review-changes/SKILL.md`）
- 審閱範圍排除紀錄與早期說明文件（`HANDOFF.md`、worklog、decisions、`docs/assessment-and-sop.md`），原因是沒有讓 AI 做錯事的風險
- 本專案推送改為自動（`AGENTS.md`「## 公私歸屬」`- 推送：自動`），因為只放腳本與文件、沒有部署流程
- 修改清單全部「照建議改」，其中方案 2／5／6 的儲存與備份天數是改 README 與選單描述、不改雲端行為

## 相關檔案

- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：「【審閱修改】」是下一步的完整清單
- `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md`：段 C 第 2 件的經過與用量
- `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh`、`D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`：要修改的兩支腳本
- `D:\Dev\company\art-collector-recommender\tests\test-gcp-setup.sh`、`D:\Dev\company\art-collector-recommender\tests\test-code-audit.sh`：要補清理、斷言與新增測試

## 踩過的坑

- Bash 工具會吞掉指令裡的雙反斜線：含 `\\` 的內容用 Write 寫成檔案再執行
- 公司專案的審閱，工具若被擋在「還沒查 second-brain playbook」，先列 `知識庫/playbooks/` 一次再改檔
- 整批審閱前先用 `get_usage` 看額度：這次每週額度已剩約 6%，審 13 份只增加約 1%，但改程式與跑測試會用更多，建議等額度重置（每週額度 2026-11-02）或確認額度再做
