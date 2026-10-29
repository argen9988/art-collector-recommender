# 交接：段 C 第 2 件收尾完成（Vertex 授權檢查修正、只記待辦清掉、審閱一輪）；剩第 3 件真雲端驗收

> 寫於 2026-10-29 22:52（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 段 C 第 3 件：使用者用個人帳號建拋棄式 GCP 專案（不放公司資料）、部署 hello-world Cloud Run，照 `D:\Dev\company\art-collector-recommender\AGENT_SETUP_雲端資安設定與驗收指南.md` 從第一階段跑到第三階段，跑完關閉專案（D7 第 ③ 層，估 NT$0～50）。順便查真實推薦端點的路徑與格式（todo-plan「【待確認】」）。需要使用者在場（使用者說明天進公司做）。建議模型與努力程度：主力模型（Opus）、medium（要判斷真雲端的輸出與權限結果，可能要改上線程式）。

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動找到正確的 GCP 專案、網站與原始碼，跑完三階段檢查。段 A、B1、B2、段 C 第 1、2 件全部完成；剩段 C 第 3 件真雲端驗收。測試 gcp 109 項、audit 194 項全過。

## 已完成

- 主力模型看 `04075b8`：Vertex 授權檢查改三點（缺角色時直接問要不要補、Editor／Owner／Vertex 管理員也算、讀不到 IAM 標「授權未確認」）`4ed556d`
- 只記待辦三項（PITR 依資料庫種類、列 API 失敗另標、假 gcloud `--filter`）與小補強的兩項測試（逾時 t8n、取最新報告用標記檔）`4ed556d`
- Sonnet 審 `4ed556d`（2 份、逐份），7 點改 6 點 `10b02c7`；改壞驗證 M14～M20 都只被預期測項抓到
- 第 1 次審閱材料經同意移到資源回收筒
- reflection：`D:\Dev\project-records\company\art-collector-recommender\reflections\2026-10-29_windows_change-review-2.md`；去識別化版寫進 second-brain `創作庫/reflections/2026-10-29_windows_change-review-5.md`；歷程本機與 second-brain 都已加段

## 還沒做完

- 上面「下一步」第 1 項
- 429／5xx 退避（`D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「【小補強】」，等真實端點格式）
- 真實推薦端點的路徑與格式（todo-plan「【待確認】」）
- 第一至第三階段的實際 GCP 設定與整合驗收（todo-plan 各階段段落）

## 這次定下的決策

- Vertex 授權：Compute Engine 預設服務帳戶有 `aiplatform.user`／`aiplatform.admin`／`editor`／`owner` 任一個都算有授權（沒有組織的專案預設帳戶通常有 Editor；記在 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md` 最後一段）
- 查詢失敗做成獨立狀態（「授權未確認」「查不到 API 狀態」），不併進有或沒有

## 相關檔案

- `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh`：細項 7（Vertex）、方案 3B（PITR）
- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：剩下的待辦
- `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md`：本次經過（最後一段）
- `D:\Dev\company\art-collector-recommender\tests\mutate.py`：改壞驗證 M1～M20

## 踩過的坑

- Bash 工具會吞掉指令裡的雙反斜線：含雙反斜線的內容用 Write 寫成檔案再執行
- 不要直接在專案裡手動跑受測腳本（會蓋掉 `reports\.lazy-pack-state.env`），在暫存複本跑
- 互動測試：proj-a 有 2 個 Cloud Run，腳本先問選哪個網站，stdin 第一行要先給 Enter
- `python tests/mutate.py` 兩項就超過 120 秒，要放背景跑；跑的期間不要改受測腳本
- 真雲端驗收會花錢、動到真的 GCP：每個寫入類動作照腳本的 y/N 確認，跑完記得關閉拋棄式專案
