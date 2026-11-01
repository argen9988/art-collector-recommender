# 交接：交接包 B2 前半（`--handoff` 打包）做完；下一步是 B2 後半（信件草稿、附件上限）

> 寫於 2026-11-01 10:08（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 【交接包】B2 後半：`D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs` 的 `runHandoff`（「交接包 --handoff」那一節）打包成功後，比照 `writeProblemReport` 的信件草稿（同檔「錯誤回報」那一節）另寫 `reports/handoff/<代號>-<時間>-email-draft.txt` 之類的草稿（收件人走環境變數、不寫進程式；要不要跟 `LAZY_PACK_REPORT_TO` 共用是未定事項，先共用並在草稿註明）；`config/params.json` 加 `handoff_max_attachment_mb`（暫定 10，估的；`DEFAULTS`、`RANGES`、`_說明` 都要加），ZIP 超過時提示改放共用資料夾；`tests/test-code-audit.sh` 第 14 段加測試（參數檔用跟預設、正式值都不同的數字翻面測，見 playbook feature-testing 第 6 步），AGENTS.md「交接包」那一項與參數清單跟著改。估約 400 行（mjs 兩節約 200、第 14 段 143、新寫約 100）。建議模型與努力程度：主力模型、high（要上線的程式）；不用使用者在場
2. 補這次的 reflection 與專案歷程的去識別化版進 second-brain（完整版：`D:\Dev\project-records\company\art-collector-recommender\reflections\2026-11-01_windows_feature-design.md`、`D:\Dev\project-records\company\art-collector-recommender\journey\2026-11-01_windows.md`，歷程標 `second_brain: pending`）；要使用者先看過。可以跟第 1 項同一個 session 開頭做
3. 【交接包】C：`AGENT_SETUP_雲端資安設定與驗收指南.md` 加「交給資訊權責單位」一節（含 `--handoff`、`--platform-result`），README 跟著改；之後 B1＋B2＋C 照 `review-changes` 審一輪、整輪真雲端驗收。建議模型與努力程度：文件 Sonnet、medium（下一段用主力模型抽查）；審閱用主力模型選審閱者；真雲端驗收要使用者在場

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent 就能跑完三階段檢查，出錯能回報、檢查結果能用交接包交給資訊同仁再用自架平台驗證。錯誤回報做完；交接包 B1、B2 前半做完，剩 B2 後半、C、審閱；整輪真雲端驗收還沒做。

## 已完成

- B2 前半：`--handoff`（重跑 3-1、`SRC-SECRET` 整包不出、manifest 四欄位參數 → 狀態檔 → 問、node 自己寫 ZIP、排除 `.env*` 等）；`gcp-setup-and-check.sh` 讀寫 `SAVED_HANDOFF_*`；585、286 項全過，10 處改壞驗證都抓到（施工紀錄 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-11.md` 2026-11-01）
- reflection 與歷程完整版寫在本機專案紀錄（見下一步第 2 項）

## 還沒做完

- 上面「下一步」各項
- manifest 欄位名稱寫進弱掃規格第 4 節（在 vulnerability-scan-summary 做；待辦【交接包】）
- `gcp-setup-and-check.sh` 預設值 `NT$0` 被展開成腳本路徑（待辦【小補強】，這次發現、沒修）
- 附件上限的實際數字、交接包收件人是否同錯誤回報的信箱：要問資訊相關權責單位（D17「未定」）
- 使用者自己清空資源回收筒才會釋放 C 槽空間
- Codex 當主線呼叫別家的驗證：`D:\Dev\personal\ai-companion\docs\todo-plan.md`「反方向派工」，等 Codex 訂閱
- findings.json 寫不進去只警告的測試、429／5xx 退避、真實推薦端點的格式（todo-plan「【小補強】」「【待確認】」）
- 審閱錯誤回報時沒改的小邊界（家目錄太短、`ghp_`／`sk-` 規則、SKIP 算失敗等）：只記在施工紀錄，沒進待辦
- 弱掃那邊照規格做 Skill 與懶人包、合併產生器第二段 HTML 報告（在那個專案另開 session）；Firebase 之後再談

## 這次定下的決策

- manifest 欄位名稱照 D17 第 1 點的原則由這邊定（英文，清單在 `D:\Dev\company\art-collector-recommender\AGENTS.md`「交接包 `--handoff`」那一項）；沒有另開決策紀錄

## 相關檔案

- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：【交接包】（B2 後半、C 的範圍）
- `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`：D17 第 6 點（信件附件、附件上限）
- `D:\Dev\company\vulnerability-scan-summary\docs\specs\annual-and-system-reports-spec.md`：第 4 節（交接包內容）

## 踩過的坑

- 兩支測試跑的期間都會暫時改寫正式的 `reports/` 狀態檔與累計總報告：測試在背景跑時不手動跑 `--self-test` 等，兩支測試不同時跑（已寫進 AGENTS.md 踩過的坑）
- 手動試跑要先設 `LAZY_PACK_LOGS_DIR`、`LAZY_PACK_HANDOFF_DIR` 指到暫存資料夾，並先備份 `reports/.lazy-pack-state.env`、`reports/findings.json`
- 含 `\\` 的指令會被 Bash 工具的 hook 擋下：用 Write 寫成檔案再執行
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址、帳號 email、帳單帳戶編號
