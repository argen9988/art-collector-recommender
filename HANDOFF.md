# 交接：段 C 第 2 件修改全部完成並審過，剩改壞驗證與兩點小修；第 3 件真雲端驗收排在後面

> 寫於 2026-10-29 21:05（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 跑剩下的改壞驗證並補抓不到的測資：`python D:\Dev\company\art-collector-recommender\tests\mutate.py M1 M2 M3 M4 M5 M6 M9 M10 M11 M12`（背景跑，約 20～30 分鐘（估）；已跑 M7、M8 都符合預期）。細節與預測在 `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「【審閱後續】」。建議模型與努力程度：Sonnet、medium（照清單跑、補測資、跑測試即可驗）。不需要使用者在場。
2. 修 Opus 抽查新發現的兩點（`--item 8` 重跑時 `SAVED_SECRET_COUNT` 累加、Vertex 授權失敗重跑被蓋掉），位置同上；改完跑 `bash tests/test-gcp-setup.sh`，並補對應測試。建議：Sonnet、medium；改完請主力模型看一眼 Vertex 那段。
3. 段 C 第 3 件：使用者用個人帳號建拋棄式 GCP 專案、部署 hello-world Cloud Run，從第一階段跑到第三階段（D7 第 ③ 層，估 NT$0～50）。需要使用者在場；等第 1、2 項做完再做。

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動找到正確的 GCP 專案、網站與原始碼，跑完三階段檢查。段 A、B1、B2、段 C 第 1 件、第 2 件（審閱＋(a)(b)(c) 修改＋Sonnet 一輪＋Opus 第二輪與抽查）都完成；測試 gcp 68 項、audit 184 項全過。

## 已完成

- 審閱修改 (a)`83a226c`、(b)`a162318`、(c)`405247d`、審閱一輪的 9 點 `1c09ec4`
- Opus 抽查：命令注入六處安全、十二處寫入類 gcloud 失敗都不計數
- 改壞驗證 M7、M8 通過；`tests/mutate.py` 已寫好（本次收工 commit）

## 還沒做完

- 上面「下一步」第 1～3 項
- 真實推薦端點的路徑與格式待確認（`D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「【待確認】」）
- 429／5xx 退避、報告取最新一份的時間戳風險（todo-plan「【小補強】」）；逾時分支沒有自動測試
- 只記待辦不改的三項（PITR 參數、Vertex 檢查、假 gcloud 的 `--filter`），在 todo-plan「【審閱修改】」最後一條
- 段 C 第 2 件的 reflection 與專案紀錄還沒寫（公司專案：去識別化版本要先給使用者看；完整版寫到 `D:\Dev\project-records\company\art-collector-recommender\`）；收工當下因 context 大，延到下個對話
- 第 1 次審閱材料 `C:\Users\87094024\.ai-companion\review\20261029-art-collector-reviewB\` 可列給使用者、同意才移到資源回收筒
- 第一至第三階段的實際 GCP 設定與整合驗收（todo-plan 各階段段落）

## 這次定下的決策

- Opus 第二輪審閱只用一份、請它多做抽查；抽查發現的兩點不在這次修改範圍，記待辦（使用者要求補三件事後定的）
- 3A 的費用記目標值 480～560、不改（選單、提示、待辦三處已寫沒設排程是 780～880）

## 相關檔案

- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：「【審閱後續】」是下一步的完整清單
- `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md`：本次經過（最後一段）
- `D:\Dev\company\art-collector-recommender\tests\mutate.py`：改壞驗證腳本（複本上改、不動正式檔；SRC 取自檔案所在位置）
- `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh`、`D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`、兩支 `tests\test-*.sh`

## 踩過的坑

- Bash 工具會吞掉指令裡的雙反斜線：含 `\\` 的內容用 Write 寫成檔案再執行（hook 也會擋）
- `read -p` 的提示在 stdin 是管線時不顯示，測試別拿提示文字當正面檢查
- 背景 `( … ) &` 在 Bash 工具裡一結束就被收掉，長測試用 PowerShell `run_in_background` 或前景跑
- `diff-reviewer` 抽查多時 12 輪會不夠、沒交報告：用 SendMessage 請它接著交
- 公司專案查 second-brain playbook 前，改檔會被 hook 擋一次：先列 `知識庫/playbooks/`
