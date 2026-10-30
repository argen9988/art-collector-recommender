# 交接：第三階段×自架平台討論完成（D9、弱掃規格）；下一步實作 3-3～3-5 與交接包

> 寫於 2026-10-30 14:57（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 實作段 D1：3-3 網址預檢＋3-4 MDN Observatory（`D:\Dev\company\art-collector-recommender\docs\todo-plan.md` 第三階段）。findings 欄位照 `D:\Dev\company\vulnerability-scan-summary\docs\specs\annual-and-system-reports-spec.md` 第 8 節（`schema_version` 從 1 開始）。量過：`lazy-pack/code-and-ai-audit.mjs` 948 行、`tests/test-code-audit.sh` 331 行、`tests/fake-recommend-api.mjs` 72 行，合計超過 800 行，所以切三段：D1 只讀 audit 腳本的網址取得與報告輸出段落＋測試＋假伺服器（估 600～800 行含新寫）；D2 做 3-5 Artifact Analysis（gcloud、假 gcloud、費用精算器）；D3 做 `--handoff` 與 AGENT_SETUP「交給資訊權責單位」一節。MDN API 要不要金鑰實作前先查證；測試一律用假伺服器。建議模型與努力程度：Opus、medium（要上線的程式），每段做完照 `review-changes` 審一輪。
2. 錯誤回報（D8）實作：動手前先問使用者資訊相關權責單位怎麼收回報檔（交接包走同一條管道）。建議 Opus、medium。
3. 段 C 第 3 件真雲端驗收（需使用者在場）；Firebase 之後再談。

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動跑完三階段檢查。段 A、B1、B2、段 C 第 1、2 件完成（gcp 109 項、audit 194 項）。這個 session 只討論與寫文件：D9 定案，弱掃那邊的規格寫好，沒改程式。

## 已完成

- D9：第三階段五項、自架平台為輔、交接包串接、合併在弱掃 Skill（`docs/decisions/2026-10.md`）
- 待辦新增 3-3、3-4、3-5、【交接包】；【討論】原文搬到施工紀錄 2026-10-30
- 弱掃規格 `D:\Dev\company\vulnerability-scan-summary\docs\specs\annual-and-system-reports-spec.md`（那個 repo 的新檔，未 commit）
- reflection 本機版 `D:\Dev\project-records\company\art-collector-recommender\reflections\2026-10-30_windows_feature-design-2.md`；歷程、大事記、首頁本機版已更新

## 還沒做完

- 上面「下一步」第 1～3 項
- 弱掃那邊照規格做 Skill、懶人包、程式修改、資料清理與 git 歷史清理（在那個專案另開 session）
- 429／5xx 退避、真實推薦端點的路徑與格式（todo-plan「【小補強】」「【待確認】」）
- `D:\Dev\company\art-collector-recommender\AGENTS.md`、`README.md` 的第三階段描述：功能做好才改（現在改會寫到還不存在的功能）

## 這次定下的決策

- 第三階段由系統負責人跑五項；不採 Web Security Scanner、OpenVAS（D9）
- 自架平台為輔，由使用者或資訊同仁用弱掃 Skill 操作，登入時人自己輸入密碼（D9）
- 交接包格式由弱掃專案定義，合併在弱掃 Skill 做（D9）
- 弱掃那邊的資料夾、年度報告、發布、舊結構轉換、git 歷史清理（使用者授權直接做）都寫在規格裡

## 相關檔案

- `D:\Dev\company\vulnerability-scan-summary\docs\specs\annual-and-system-reports-spec.md`：交接包與 findings 格式（第 4、8 節）
- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：第三階段與【交接包】
- `D:\Dev\project-records\company\vulnerability-scan-summary\data\資安檢測平台操作手冊.xlsx`：自架平台操作（這份可直接讀）

## 踩過的坑

- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網 IP、平台網址
- Bash 工具會吞掉指令裡的雙反斜線：含雙反斜線的內容用 Write 寫成檔案再執行，或改用 PowerShell
- 不要直接在專案裡手動跑受測腳本（會蓋掉 `reports\.lazy-pack-state.env`）
