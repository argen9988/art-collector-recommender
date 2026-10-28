# 決策紀錄索引 (decisions)

每月一檔，記錄專案架構選型、資安治理取捨與設計決策。

## 2026-10

- **D1（2026-10-28）**：維持 Google AI Studio（Paid Tier 付費層）搭配後端環境變數隔離，不遷移至 Vertex AI。
- **D2（2026-10-28）**：關係企業獨立運作且無企業網域下，採「部門公務 Gmail 共管 ＋ 軟硬雙重止損 ＋ OAuth Testing 白名單」輕量化治理。
- **D3（2026-10-28）**：Cloud SQL 資料庫規格不強制降級為最低階，提供含 NT$500–600/月 甜區在內之 5 種方案由執行者互動決定。
- **D4（2026-10-28）**：採用方案 C 二合一 Lazy Pack，且所有檢查與設定步驟一律「先檢查現況，已存在自動跳過」。詳見 [`2026-10.md`](file:///D:/Dev/company/art-collector-recommender/docs/decisions/2026-10.md)。
