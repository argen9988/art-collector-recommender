# art-collector-recommender — 待辦與階段規劃 (todo-plan.md)

> 遵循全域規則：待辦文件只留還沒做完的項目；做完的項目已移入 [`docs/worklog/2026-11.md`](./worklog/2026-11.md)。

---

## 零、 新沙盒專案實測驗收與交接（開工優先執行）

> 依據 2026-11-02 定案之「四步閉環」與「四合一透明動作卡」標準，在全新沙盒專案 `art-rec-test-432759` 重跑完整流程。

- [ ] **【真雲端驗收收尾】銷毀已完成閉環測試之拋棄式專案（art-rec-test-432759）**：
  - [ ] 執行 `gcloud projects delete art-rec-test-432759 --quiet`。
- [ ] **【待確認】真實推薦端點的路徑與格式**：真實系統（AI Studio Build 產生的 Next.js）的推薦端點路徑、要不要登入、回傳格式；拿到原始碼時查清楚。
- [ ] **【待討論】改用 Google／Firebase 服務時的檢測差異**：見 D14。
