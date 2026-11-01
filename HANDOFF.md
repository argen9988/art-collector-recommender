# 交接：交接包 B1＋B2＋C 審閱發現已照改、測試全過；下一步整輪真雲端驗收

> 寫於 2026-11-01 12:00（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 整輪真雲端驗收（第一、二、三階段一次驗完，含 `--handoff` 一輪）：使用者指定由 Antigravity（agy）用 Gemini Flash（High）做，要使用者在場；Flash 當審閱者曾有講錯的紀錄，每個結論先對照程式查證。驗收前先修 `gcp-setup-and-check.sh` 預設值 `NT$0` 被展開成腳本路徑（待辦【小補強】；會把執行者的路徑帶進交接包）。建議模型與努力程度：`NT$0` 那個小修用 Sonnet、medium（範圍清楚的 bug，要加測試）；真雲端驗收照使用者指定
2. 要問資訊相關權責單位：附件上限實際數字、交接包收件人是否同錯誤回報的信箱（D17「未定」，程式與文件都已註明暫定）
3. manifest 欄位名稱寫進弱掃規格第 4 節（在 vulnerability-scan-summary 另開 session 做）

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent 就能跑完三階段檢查，出錯能回報，檢查結果能用交接包交給資訊同仁再用自架平台驗證。錯誤回報、交接包 B1、B2、C 都做完，用 Sonnet 審過一輪（9 份）、發現已照改（D18）；`tests/test-code-audit.sh` 631 項、`tests/test-gcp-setup.sh` 293 項全過。剩整輪真雲端驗收。

## 已完成

- C：指南第六步、README 交接包一節（`e4b60c7`）
- 審閱發現照改：打包範圍、排除清單不分大小寫、報告遮蔽、失敗清半成品等，D18；測試加 14s～14v、16g、16h；改壞驗證 7 種都抓到（施工紀錄 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-11.md` 最後一段）
- 這次的 reflection 與專案紀錄：完整版在 `D:\Dev\project-records\company\art-collector-recommender\`，去識別化版已寫進 second-brain

## 還沒做完

- 上面「下一步」各項
- 沒測：打包中途失敗清半成品、`--platform-result` 寫總報告失敗的分支（未驗證，施工紀錄有記）
- 使用者自己清空資源回收筒才會釋放 C 槽空間
- Codex 當主線呼叫別家的驗證：`D:\Dev\personal\ai-companion\docs\todo-plan.md`「反方向派工」，等 Codex 訂閱
- findings.json 寫不進去只警告的測試、429／5xx 退避、真實推薦端點的格式（todo-plan「【小補強】」「【待確認】」）
- 審閱錯誤回報時沒改的小邊界（家目錄太短、`ghp_`／`sk-` 規則、SKIP 算失敗等）：只記在施工紀錄
- 弱掃那邊照規格做 Skill 與懶人包、合併產生器第二段 HTML 報告（在那個專案另開 session）；Firebase 之後再談

## 這次定下的決策

- 交接包「整包不出」看實際進包的檔，排除不分大小寫並加金鑰檔，報告先遮蔽（使用者 2026-11-01 說「改」；D18 在 `D:\Dev\company\art-collector-recommender\docs\decisions\2026-11.md`）
- 整輪真雲端驗收由 Antigravity 的 Gemini Flash（High）做（使用者 2026-11-01 指定）
- 公司專案、推送：自動

## 相關檔案

- `D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`：`runHandoff`、`packagedSecretFiles`、`ZIP_EXCLUDE`
- `D:\Dev\company\art-collector-recommender\AGENTS.md`：「交接包 `--handoff`」那一項（已更新）
- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：【交接包】、【小補強】

## 踩過的坑

- 跑測試要讓工具指令本身就是測試指令（背景工具會等它），不要在指令裡用 `&` 自己丟背景；兩支測試不同時跑，也不要重複開同一支：會互相改寫 `reports/`。被殺掉沒還原時，用最早那份 `%TEMP%\tmp.*\` 的 `state.bak`、`full.bak` 還原
- `tests/test-gcp-setup.sh` 第 16 段的 sed 假設 `usd_twd_rate` 是 `config/params.json` 最後一行（沒有逗號）：新參數加在它前面
- 指令裡有連續兩個反斜線會被 Bash 工具的 hook 擋下：用 Write 寫成檔案再執行；Bash 裡用多個 heredoc 串起來會卡住
- 改壞驗證：把測試第 14 段切成暫存的 `tests/_mut14.sh`，用環境變數 `R_UNDER_TEST` 指到改壞的複本（要有 `lazy-pack/`、`config/`、`reports/`），不碰正式的 `reports/`
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址、帳號 email、帳單帳戶編號
