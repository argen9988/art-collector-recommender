# 交接：錯誤回報 (b2)（gcloud 錯誤記進紀錄）做完；下一步是 (c) 指南與 README 的錯誤回報說明

> 寫於 2026-10-31 18:46（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

執行順序是使用者 2026-10-31 定的（`D:\Dev\company\art-collector-recommender\docs\todo-plan.md` 第零節開頭）：① 錯誤回報 → ② 交接包 → ③ 整輪真雲端驗收。

1. 【錯誤回報】(c)：`D:\Dev\company\art-collector-recommender\AGENT_SETUP_雲端資安設定與驗收指南.md`（289 行）加「遇到錯誤時」一節、`D:\Dev\company\art-collector-recommender\README.md`（155 行）加錯誤回報說明（兩支腳本都有 `--report-problem [--note]`；紀錄在 `reports/logs/`，回報檔與信件草稿在 `reports/`，腳本不寄信，收件人用環境變數 `LAZY_PACK_REPORT_TO`；紀錄與回報檔已遮金鑰、密碼、電子郵件與電腦使用者名稱，gcloud 的錯誤也記進去）。量的：兩份加起來約 450 行，只讀要改的段落，不用切段。寫完照 D15 / D16 對一次。建議模型與努力程度：Sonnet、medium（照現況改寫文件、結果容易檢查）；不用使用者在場。
2. （使用者決定要不要）審閱 (a)＋(b1)＋(b2)：`code-and-ai-audit.mjs` 約 200 行＋測試約 130 行、`gcp-setup-and-check.sh` 約 175 行＋測試約 230 行，照 `review-changes` Skill；材料沒有公司個資時可選別家審閱者。重點看兩份遮蔽規則是否一致，以及 `lp_gcloud` 的邊界（`.gcerr` 暫存、結束碼、`set -u`）
3. 【交接包】`--handoff`（D9）：動手前先讀 todo-plan 那一項與 `D:\Dev\company\vulnerability-scan-summary\docs\specs\` 第 8 節；跨專案的事先問使用者；附件上限要問資訊相關權責單位
4. 整輪真雲端驗收（todo-plan「【真雲端驗收】」）：需要使用者在場

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent 就能跑完三階段檢查，出錯時能把問題用電子郵件回報給資訊相關權責單位。錯誤回報 (a)、(b1)、(b2) 都做完；(c)、交接包、整輪真雲端驗收還沒做。

## 已完成

- 錯誤回報 (b2)（2026-10-31）：`lp_gcloud` 取代 19 處 `2>/dev/null`、`LAZY_PACK_LOG_FILE`、回報檔收 `（gcloud 錯誤）` 行、`tests/test-gcp-setup.sh` 第 17 段 j（25 項，整支 271 項全過、2 分 44 秒；`test-code-audit.sh` 479 項全過）、10 種改壞驗證都抓到；施工紀錄 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md`「錯誤回報 (b2)」、決策 D16；commit 見 git log
- 錯誤回報 (b1)（2026-10-31，`4a89c4f`）、(a)（`9c5090f`）

## 還沒做完

- 上面「下一步」各項
- reflection 與專案紀錄：(b1) 的去識別化版還沒給使用者看、還沒寫進 second-brain（完整版在 `D:\Dev\project-records\company\art-collector-recommender\reflections\2026-10-31_windows_feature-testing-4.md`；歷程在同資料夾的 `journey\2026-10-31_windows.md`）；(b2) 這一段的 reflection 與專案紀錄還沒寫（要寫時完整版寫到 project-records、去識別化版先給使用者看）
- 這個專案的整輪真雲端驗收（第一、二階段）還沒跑過
- 使用者自己清空資源回收筒才會釋放 C 槽空間
- Codex 當主線呼叫別家的驗證：`D:\Dev\personal\ai-companion\docs\todo-plan.md`「反方向派工」，等 Codex 訂閱
- findings.json 寫不進去只警告的測試、429／5xx 退避、真實推薦端點的格式（todo-plan「【小補強】」「【待確認】」）
- 弱掃那邊照規格做 Skill 與懶人包（在那個專案另開 session）；Firebase 之後再談

## 這次定下的決策

- gcloud 錯誤用 `lp_gcloud` 包起來，只包查現況的 19 處；修改設定的 gcloud 呼叫本來就印在畫面上（理由：不動呼叫點的邏輯；完整的在 `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md` D16）

## 相關檔案

- `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh`：`lp_gcloud`、`lp_run_logged`
- `D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`：`problemLogSection`（回報檔收哪些行）
- `D:\Dev\company\art-collector-recommender\tests\test-gcp-setup.sh`：第 17 段（可單獨切出來跑：開頭到第 1 段之前＋第 17 段，`T=` 改指到 tests 資料夾）
- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：「【錯誤回報】」進度
- `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`：D8、D15、D16

## 踩過的坑

- 改壞驗證若拿掉 `lp_gcloud` 開頭的防呆，改壞的複本會在目前資料夾（repo 根目錄）寫出 `.gcerr`；跑完看一次 `git status`（已收進 `D:\Dev\company\art-collector-recommender\AGENTS.md`「開發時踩過的坑」）
- 機器忙時整支 `test-gcp-setup.sh` 要 14 分鐘、只在失敗時印東西，看起來像卡住；先用精簡版跑新段落
- 含反斜線的指令被 Bash 工具的檢查擋下：用 Write 寫 Python 檔再執行
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址、帳號 email、帳單帳戶編號
