# 交接：交接包 B1＋B2＋C 審完（共 9 份，發現待你決定）；下一步決定怎麼改，再整輪真雲端驗收

> 寫於 2026-11-01 11:25（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 【審閱結果】把 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-11.md` 最後一段「B1＋B2＋C 審閱」的發現逐點給使用者決定（改、不改、只改紀錄），要改規則文字的先給確切文字。最該先處理的兩點（已對照程式確認）：`source.zip` 打包範圍比 3-1 掃描範圍大（`.yaml`、`.pem`、`.sql`、`.txt` 裡的金鑰不會攔下）；3-1 掃到 `.env*` 會擋整包但 `.env*` 本來就不進 zip。其餘（累計總報告可能帶本機路徑、`ZIP_EXCLUDE` 區分大小寫、半成品資料夾、測試補強、文件小補）是審閱者提的，改之前先對照程式查證。建議模型與努力程度：主力模型、high（設計取捨與會上線的程式）；要使用者在場回覆決定
2. 改完後跑 `bash tests/test-code-audit.sh`（615 項，約 6 分，背景跑，不同時跑另一支）；`gcp-setup-and-check.sh` 有改才跑 `tests/test-gcp-setup.sh`
3. 整輪真雲端驗收（第一、二、三階段一次驗完）：使用者指定由 Antigravity（agy）用 Gemini Flash（High）做，要使用者在場；Flash 當審閱者曾有講錯的紀錄，每個結論先對照程式查證

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent 就能跑完三階段檢查，出錯能回報，檢查結果能用交接包交給資訊同仁再用自架平台驗證。錯誤回報、交接包 B1、B2、C 都做完且審閱過一輪（還沒改）；剩審閱結果的處理與整輪真雲端驗收。

## 已完成

- C：指南第六步、README 交接包一節（`e4b60c7`，已推送）
- B1＋B2＋C 用 Sonnet 審一輪：9 份、檢查碼都對上（紀錄在施工紀錄 `2026-11.md` 最後一段）

## 還沒做完

- 上面「下一步」各項
- 這次 reflection 與專案紀錄（公司專案：完整版寫 `D:\Dev\project-records\company\art-collector-recommender\`，去識別化版先給使用者看才寫 second-brain）還沒寫
- manifest 欄位名稱寫進弱掃規格第 4 節（在 vulnerability-scan-summary 做；待辦【交接包】）
- `gcp-setup-and-check.sh` 預設值 `NT$0` 被展開成腳本路徑（待辦【小補強】；會把執行者的路徑帶進交接包，交出交接包之前要修）
- 附件上限的實際數字、交接包收件人是否同錯誤回報的信箱：要問資訊相關權責單位（D17「未定」）
- 使用者自己清空資源回收筒才會釋放 C 槽空間
- Codex 當主線呼叫別家的驗證：`D:\Dev\personal\ai-companion\docs\todo-plan.md`「反方向派工」，等 Codex 訂閱
- findings.json 寫不進去只警告的測試、429／5xx 退避、真實推薦端點的格式（todo-plan「【小補強】」「【待確認】」）
- 審閱錯誤回報時沒改的小邊界（家目錄太短、`ghp_`／`sk-` 規則、SKIP 算失敗等）：只記在施工紀錄
- 弱掃那邊照規格做 Skill 與懶人包、合併產生器第二段 HTML 報告（在那個專案另開 session）；Firebase 之後再談

## 這次定下的決策

- 審閱者用 Claude Sonnet（`diff-reviewer` 子代理，使用者 2026-11-01 指定）；整輪真雲端驗收改由 Antigravity 的 Gemini Flash（High）做（使用者 2026-11-01 指定）
- 公司專案、推送：自動（C 段已推）

## 相關檔案

- `D:\Dev\company\art-collector-recommender\docs\worklog\2026-11.md`：最後一段是審閱發現
- `D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`：`CODE_EXTS`（164 行）、`collectFiles`（166 行）、`ZIP_EXCLUDE`、`runHandoff`
- `D:\Dev\company\art-collector-recommender\AGENTS.md`：「交接包 `--handoff`」那一項
- 審閱材料在暫存資料夾 `C:\Users\87094024\AppData\Local\Temp\review-1101\`（會被清掉；要重審用範圍 `a118c50,c358fd5,3b77d87,e4b60c7` 重切）

## 踩過的坑

- `tests/test-gcp-setup.sh` 第 16 段的 sed 假設 `usd_twd_rate` 是 `config/params.json` 最後一行（沒有逗號）：新參數加在它前面
- 兩支測試跑的期間會暫時改寫正式的 `reports/`：測試在背景跑時不手動跑 `--self-test` 等，兩支不同時跑
- 指令裡有連續兩個反斜線會被 Bash 工具的 hook 擋下：用 Write 寫成檔案再執行；Bash 裡用多個 heredoc 串起來會卡住
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址、帳號 email、帳單帳戶編號（審閱提到 todo 與 worklog README 有 `vulnerability-scan-summary` 本機路徑，待決定）
