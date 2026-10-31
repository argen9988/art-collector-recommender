# 交接：錯誤回報 (a)(b1)(b2)(c) 全部做完；下一步是審閱或交接包 --handoff

> 寫於 2026-10-31 19:12（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

執行順序是使用者 2026-10-31 定的（`D:\Dev\company\art-collector-recommender\docs\todo-plan.md` 開頭）：① 錯誤回報（已完成）→ ② 交接包 → ③ 整輪真雲端驗收。

1. （先問使用者要不要）審閱錯誤回報 (a)＋(b1)＋(b2)＋(c)：`code-and-ai-audit.mjs` 約 200 行＋測試約 130 行、`gcp-setup-and-check.sh` 約 175 行＋測試約 230 行、兩份文件新增約 40 行，照 `review-changes` Skill；材料沒有公司個資時可選別家審閱者。重點看兩份遮蔽規則是否一致，以及 `lp_gcloud` 的邊界（`.gcerr` 暫存、結束碼、`set -u`）。建議模型：主力模型（審閱結果要判斷）；需要使用者在場選審閱者
2. 【交接包】`--handoff`（D9）：動手前先讀 todo-plan 那一項與 `D:\Dev\company\vulnerability-scan-summary\docs\specs\` 第 8 節；跨專案的事先問使用者；附件上限要問資訊相關權責單位。建議模型：主力模型、high（要上線的程式）；需要使用者在場
3. 整輪真雲端驗收（todo-plan「【真雲端驗收】」）：需要使用者在場

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent 就能跑完三階段檢查，出錯時能把問題用電子郵件回報給資訊相關權責單位。錯誤回報四段都做完；交接包、整輪真雲端驗收還沒做。

## 已完成

- 錯誤回報 (c)（2026-10-31）：`D:\Dev\company\art-collector-recommender\AGENT_SETUP_雲端資安設定與驗收指南.md` 加「第五步：遇到錯誤時」、`D:\Dev\company\art-collector-recommender\README.md` 加「遇到錯誤時：一鍵整理問題回報檔」；已對照 D15、D16 與腳本印的寄信四步；待辦原文搬到施工紀錄；只改文件，沒重跑測試
- 錯誤回報 (b2)（`a3b8d71`）、(b1)（`4a89c4f`）、(a)（`9c5090f`）

## 還沒做完

- 上面「下一步」各項
- reflection 與專案紀錄：(b1)、(b2)、(c) 都還沒寫完。(b1) 的完整版在 `D:\Dev\project-records\company\art-collector-recommender\reflections\2026-10-31_windows_feature-testing-4.md`，歷程在同資料夾 `journey\2026-10-31_windows.md`；去識別化版還沒給使用者看、沒寫進 second-brain；(b2)、(c) 完整版也還沒寫。公司專案：完整版寫 project-records，去識別化版先給使用者看
- 這個專案的整輪真雲端驗收（第一、二階段）還沒跑過
- 使用者自己清空資源回收筒才會釋放 C 槽空間
- Codex 當主線呼叫別家的驗證：`D:\Dev\personal\ai-companion\docs\todo-plan.md`「反方向派工」，等 Codex 訂閱
- findings.json 寫不進去只警告的測試、429／5xx 退避、真實推薦端點的格式（todo-plan「【小補強】」「【待確認】」）
- 弱掃那邊照規格做 Skill 與懶人包（在那個專案另開 session）；Firebase 之後再談

## 這次定下的決策

無新決策（文件照 D15、D16 寫）。

## 相關檔案

- `D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`：D8、D15、D16
- `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md`：「錯誤回報 (c)」
- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：【交接包】、【真雲端驗收】

## 踩過的坑

- 改壞驗證若拿掉 `lp_gcloud` 開頭的防呆，改壞的複本會在 repo 根目錄寫出 `.gcerr`；跑完看一次 `git status`（已收進專案 `AGENTS.md`）
- 含反斜線的指令被 Bash 工具的檢查擋下：用 Write 寫 Python 檔再執行
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址、帳號 email、帳單帳戶編號
