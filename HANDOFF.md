# 交接：交接包 B2 做完（信件草稿、附件上限）；下一步是 C（指南、README）與審閱

> 寫於 2026-11-01 10:39（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 【交接包】C：`D:\Dev\company\art-collector-recommender\AGENT_SETUP_雲端資安設定與驗收指南.md` 加「交給資訊權責單位」一節（含 `--handoff`、信件草稿、附件上限超過時改放共用資料夾、`--platform-result`），`README.md` 跟著改；內容照 `AGENTS.md`「交接包 `--handoff`」那一項。建議模型與努力程度：Sonnet、medium（照現況改寫文件；下一段用主力模型抽查）；不用使用者在場
2. B1＋B2＋C 照 `review-changes` 審一輪：由使用者在 Antigravity 開這個專案、當主線用 Gemini 3.8 Flash（High）做（使用者 2026-11-01 定；Flash 當審閱者 2026-10-30 在 medium 實測有 2 點講錯，High 沒測過，每個問題先對照程式查證再改）；之後整輪真雲端驗收，要使用者在場

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent 就能跑完三階段檢查，出錯能回報、檢查結果能用交接包交給資訊同仁再用自架平台驗證。錯誤回報、交接包 B1、B2 做完，剩 C、審閱；整輪真雲端驗收還沒做。

## 已完成

- B2 後半：`--handoff` 打包後寫 `reports/handoff/<代號>-<時間>-email-draft.txt`（收件人共用 `LAZY_PACK_REPORT_TO`，草稿註明未定）；`config/params.json` 加 `handoff_max_attachment_mb`（10，估的），超過時提示改放共用資料夾；`tests/test-code-audit.sh` 615 項全過，9 處改壞驗證都抓到（施工紀錄 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-11.md` 2026-11-01 B2 段後半）
- B2 前半（`--handoff` 打包，`c358fd5`）

## 還沒做完

- 上面「下一步」各項
- manifest 欄位名稱寫進弱掃規格第 4 節（在 vulnerability-scan-summary 做；待辦【交接包】）
- `gcp-setup-and-check.sh` 預設值 `NT$0` 被展開成腳本路徑（待辦【小補強】；會把執行者的路徑帶進交接包，交出交接包之前要修）
- 附件上限的實際數字、交接包收件人是否同錯誤回報的信箱：要問資訊相關權責單位（D17「未定」）
- 使用者自己清空資源回收筒才會釋放 C 槽空間
- Codex 當主線呼叫別家的驗證：`D:\Dev\personal\ai-companion\docs\todo-plan.md`「反方向派工」，等 Codex 訂閱
- findings.json 寫不進去只警告的測試、429／5xx 退避、真實推薦端點的格式（todo-plan「【小補強】」「【待確認】」）
- 審閱錯誤回報時沒改的小邊界（家目錄太短、`ghp_`／`sk-` 規則、SKIP 算失敗等）：只記在施工紀錄，沒進待辦
- 弱掃那邊照規格做 Skill 與懶人包、合併產生器第二段 HTML 報告（在那個專案另開 session）；Firebase 之後再談

## 這次定下的決策

- 交接包的收件人先共用錯誤回報的 `LAZY_PACK_REPORT_TO`，草稿裡註明還沒確認（照上次交接檔的暫定做法；D17「未定」仍要問資訊單位）

## 相關檔案

- `D:\Dev\company\art-collector-recommender\AGENTS.md`：「交接包 `--handoff`」那一項（C 段文件照它寫）
- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：【交接包】（C 的範圍）
- `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`：D17

## 踩過的坑

- `tests/test-gcp-setup.sh` 第 16 段的 sed 假設 `usd_twd_rate` 是 `config/params.json` 最後一行（沒有逗號）：新參數要加在它前面
- 兩支測試跑的期間都會暫時改寫正式的 `reports/` 狀態檔與累計總報告：測試在背景跑時不手動跑 `--self-test` 等，兩支測試不同時跑
- 含 `\\` 的指令會被 Bash 工具的 hook 擋下：用 Write 寫成檔案再執行
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址、帳號 email、帳單帳戶編號
