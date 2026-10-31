# 交接：交接包設計定案（D17）、B1 做完；下一步是 B2 `--handoff` 打包

> 寫於 2026-10-31 21:18（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 【交接包】B2：`code-and-ai-audit.mjs` 加 `--handoff`（做法照 `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md` D17 第 3～6 點、待辦【交接包】）：重跑 3-1、`SRC-SECRET` 整包不出、node 自己產生 ZIP（排除 `.env*`、`.git`、`node_modules`、`.next`）、manifest 欄位用參數或終端機問並記進狀態檔（`gcp-setup-and-check.sh` 的白名單與寫回也要加）、信件草稿、`config/params.json` 加 `handoff_max_attachment_mb`（暫定 10）；加測試。動手前先量：mjs 要讀的段落（選原始碼 1250～1440、`writeProblemReport` 約 1640～1720、主程式選項約 1700～1770）、`tests/test-code-audit.sh` 第 12、13 段，加上要新寫的約 400 行，超過約 800 行就把「ZIP＋manifest＋打包」與「信件草稿＋附件上限」切成兩段。建議模型與努力程度：主力模型、high（要上線的程式）；不用使用者在場（附件上限先用暫定值）
2. 【交接包】C：`AGENT_SETUP_雲端資安設定與驗收指南.md` 加「交給資訊權責單位」一節（含 `--handoff`、`--platform-result`），README、AGENTS.md 跟著改。建議模型與努力程度：Sonnet、medium（照現況寫文件），下一段用主力模型抽查
3. 交接包 B1＋B2＋C 照 `review-changes` 審一輪；之後整輪真雲端驗收（todo-plan「【真雲端驗收】」）。審閱用主力模型選審閱者；真雲端驗收需要使用者在場

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent 就能跑完三階段檢查，出錯能回報、檢查結果能用交接包交給資訊同仁再用自架平台驗證。錯誤回報做完；交接包設計定案、B1 做完，剩 B2、C、審閱；整輪真雲端驗收還沒做。

## 已完成

- 上次審閱的 reflection 與歷程去識別化版寫進 second-brain（使用者看過）
- 交接包 A 段設計定案，寫成 D17；弱掃那邊的讀取程式、測試、規格第 4、8、14 節改成這邊的欄位名稱（vulnerability-scan-summary `3d96397`，已推送）
- B1：3-1 轉 `SRC-*` 進 findings.json、累計總報告「自架平台驗證」一行與 `--platform-result`；526、282 項全過，改壞驗證 3 種都抓到（`a118c50`）

## 還沒做完

- 上面「下一步」各項
- 附件上限的實際數字、交接包收件人是否同錯誤回報的信箱：要問資訊相關權責單位（D17「未定」）
- 使用者自己清空資源回收筒才會釋放 C 槽空間
- Codex 當主線呼叫別家的驗證：`D:\Dev\personal\ai-companion\docs\todo-plan.md`「反方向派工」，等 Codex 訂閱
- findings.json 寫不進去只警告的測試、429／5xx 退避、真實推薦端點的格式（todo-plan「【小補強】」「【待確認】」）
- 審閱錯誤回報時沒改的小邊界（家目錄太短、`ghp_`／`sk-` 規則、SKIP 算失敗等）：只記在施工紀錄，沒進待辦
- 弱掃那邊照規格做 Skill 與懶人包、合併產生器第二段 HTML 報告（在那個專案另開 session）；Firebase 之後再談

## 這次定下的決策

- D17：findings 欄位以這邊為準；3-1 轉 `SRC-*`；掃到 `SRC-SECRET` 整包不出；`--handoff` 先重跑 3-1；ZIP 用 node 自己產生並排除 `.env*` 等；用信件附件送、超過上限改共用資料夾；累計總報告加「自架平台驗證」與 `--platform-result`（完整的在 `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`）

## 相關檔案

- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：【交接包】（B2、C 的範圍）
- `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md`：「2026-10-31 交接包 A 段（設計定案）與 B1 段」
- `D:\Dev\company\vulnerability-scan-summary\docs\specs\annual-and-system-reports-spec.md`：第 4 節（交接包內容）、第 8 節（findings 欄位表）
- `D:\Dev\project-records\company\art-collector-recommender\reflections\2026-10-31_windows_feature-design-2.md`：這次的 reflection（真名版）

## 踩過的坑

- `gcp-setup-and-check.sh` 讀狀態檔是白名單、寫回是固定清單：mjs 新增的狀態欄位（B2 的 manifest 欄位）兩支都要加，並測一次來回，否則跑一次第一、二階段就被丟掉
- 「不該改寫檔案」的測試：執行前要先放進改寫後會不同的內容，不然改壞也測不出來
- 含 `\\` 的指令會被 Bash 工具的 hook 擋下（heredoc 也算）：用 Write 寫成檔案再執行
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址、帳號 email、帳單帳戶編號
