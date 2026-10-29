# 交接：段 C 第 2 件全部完成（含 Opus 抽查兩點修改與 reflection／專案紀錄）；剩 Vertex 主力模型檢視與第 3 件真雲端驗收

> 寫於 2026-10-29 22:00（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 請主力模型看 `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh` 第 964～985 行附近的 Vertex 授權檢查（`get-iam-policy` 的 `--filter` 寫法、`no-role` 分支訊息、重跑指引 `--item 7`），再審一輪只看這兩點修改（(a) `SAVED_EDM_SECRET_COUNT`、(b) Vertex 角色檢查，commit `04075b8`）。範圍小（約 30 行＋測試 24 行）不需切段。建議模型與努力程度：Opus、medium（授權判斷屬主力範圍）；不需要使用者在場。
2. 段 C 第 3 件：使用者用個人帳號建拋棄式 GCP 專案、部署 hello-world Cloud Run，從第一階段跑到第三階段（D7 第 ③ 層，估 NT$0～50）。需要使用者在場；等第 1 項做完再做。

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動找到正確的 GCP 專案、網站與原始碼，跑完三階段檢查。段 A、B1、B2、段 C 第 1 件、第 2 件（審閱、修改、Opus 抽查、改壞驗證 M1～M14、抽查兩點修改、reflection 與專案紀錄）都完成；測試 gcp 85 項、audit 190 項全過。

## 已完成

- 審閱修改 (a)`83a226c`、(b)`a162318`、(c)`405247d`、審閱一輪 9 點 `1c09ec4`、補測項 `db3727e`
- 抽查兩點修改 `04075b8`：`--item 8` 重跑密鑰數不再越加；Vertex API 已啟用時再查 `roles/aiplatform.user`；假 gcloud 加 `FAKE_VERTEX_API`／`FAKE_VERTEX_ROLE`／`FAKE_SCHEDULER_API`；改壞驗證 M13、M14 只被預期測項抓到
- reflection：`D:\Dev\project-records\company\art-collector-recommender\reflections\2026-10-29_windows_change-review.md`；去識別化版已寫進 second-brain（`創作庫/reflections/2026-10-29_windows_change-review-3.md`）；歷程本機與 second-brain 都已加段

## 還沒做完

- 上面「下一步」第 1～2 項
- 真實推薦端點的路徑與格式待確認（`D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「【待確認】」）
- 429／5xx 退避、報告取最新一份的時間戳風險（todo-plan「【小補強】」）；逾時分支沒有自動測試
- 只記待辦不改的三項（PITR 參數、Vertex 檢查、假 gcloud 的 `--filter`），在 todo-plan「【審閱修改】」最後一條
- 第 1 次審閱材料 `C:\Users\87094024\.ai-companion\review\20261029-art-collector-reviewB\` 可列給使用者、同意才移到資源回收筒
- 第一至第三階段的實際 GCP 設定與整合驗收（todo-plan 各階段段落）

## 這次定下的決策

- EDM 密鑰數另存 `SAVED_EDM_SECRET_COUNT`（重算前先扣上次的）：單獨重跑細項不累加（記在 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md` 最後一段）
- second-brain 的專案首頁 `公司專案/art-collector-recommender/home.md` 沒有「下一步」欄位，不改

## 相關檔案

- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：「【審閱後續】」
- `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md`：本次經過（最後一段）
- `D:\Dev\company\art-collector-recommender\tests\mutate.py`：改壞驗證（M1～M14）；M1、M5、M11、M12 檔內「預期」文字仍是補測資前的舊說法，下次動它時順手更新
- `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh`、`D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`、兩支 `D:\Dev\company\art-collector-recommender\tests\test-*.sh`

## 踩過的坑

- Bash 工具會吞掉指令裡的雙反斜線：含雙反斜線的內容用 Write 寫成檔案再執行
- `python tests/mutate.py` 兩項就超過 120 秒，要放背景跑
- 公司專案改檔前 hook 會擋一次，要先列 second-brain 的 `知識庫/playbooks/`
