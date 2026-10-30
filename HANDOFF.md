# 交接：段 D2a 完成（3-5 Artifact Analysis 主程式，D13）；下一步段 D2b（3-5 的測試與費用精算器）

> 寫於 2026-10-30 18:44（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 段 D2b：① `D:\Dev\company\art-collector-recommender\tests\test-code-audit.sh` 加第 11 段測 3-5（用假 gcloud 的 `FAKE_AUTO_SCAN`、`FAKE_ON_DEMAND`、`FAKE_IMAGE_REF`、`FAKE_IMAGE_DESCRIBE`、`FAKE_SCAN_VULNS`；要測的情境列在 `D:\Dev\company\art-collector-recommender\docs\todo-plan.md` 第三階段「【細項 3-5】」①）；② `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh` 的費用精算器（關卡 9，約第 1199 行起）加第 8 項，要另寫讀小數的函式（`read_json_int` 只讀整數），並改 `tests\test-gcp-setup.sh`。估約 800 行（test-code-audit 開頭與第 10 段約 240、sh 精算器與讀參數約 200、test-gcp-setup 約 240、新寫約 220）。建議模型與努力程度：Opus、medium（要上線的程式）。
2. 段 D2c：README、`AGENT_SETUP_雲端資安設定與驗收指南.md`、AGENTS.md（技術選型、資料模型的新參數、驗證方式的測試項數）照 D13 改成現況，再照 `review-changes` 審 D2a＋D2b 的 commit（公司專案只能用 Claude 的審閱者）。建議模型與努力程度：寫文件 Sonnet、medium；審閱結果要使用者決定改不改。
3. second-brain 的去識別化 reflection、歷程、首頁（D1 兩次、再審、這次 D2a）：給使用者看過才寫。建議模型與努力程度：Sonnet、medium，要使用者在場確認。

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動跑完三階段檢查。第三階段 3-1～3-4 做完並審過；3-5 主程式做好（D2a），自動測試、Bash 腳本的費用精算、文件與審閱還沒做；交接包、錯誤回報、真雲端驗收也還沒做。

## 已完成

- 3-5：`--image-scan`、`--enable-image-scan`、`--scan-now`；有修補版本的高、中風險才擋；findings.json 依類別代號開頭分段換掉；累計總報告費用精算第 8 項；`--self-test` 加 3-5 的判斷（commit 見 git log「收工：段 D2a」）
- `config\params.json` 加 `image_scan_usd_per_image`、`image_scan_deploys_per_month`、`usd_twd_rate`；假 gcloud 認得 3-5 的指令
- 測試：`--self-test` 通過、test-code-audit 318 項、test-gcp-setup 109 項全過；改壞 6 處都抓到（施工紀錄 2026-10-30「段 D2a」）
- reflection 本機版 `D:\Dev\project-records\company\art-collector-recommender\reflections\2026-10-30_windows_feature-design-3.md`，歷程本機版已記

## 還沒做完

- 上面「下一步」三項；3-5 的待辦在 todo-plan 第三階段「【細項 3-5】」
- second-brain 的去識別化版本：D1 的草稿在 `C:\Users\87094024\AppData\Roaming\Claude\side-session-notes\local_f40ff673-28f1-470d-8a1c-b9d4175e25d7\second-brain-去識別化草稿.md`（session 筆記資料夾，可能被清掉）；本機歷程 `second_brain: pending`
- findings.json 寫不進去只警告的測試、429／5xx 退避、真實推薦端點的格式（todo-plan「【小補強】」「【待確認】」）
- findings 欄位名稱與類別代號（現在多了 `IMG-VULN`、`CWE-1395`）要請 vulnerability-scan-summary 寫進規格第 8 節（待辦「【交接包】」）
- 弱掃那邊照規格做 Skill 與懶人包（在那個專案另開 session）；段 C 第 3 件真雲端驗收（需使用者在場，順便核對 3-5 的輸出格式）；Firebase 之後再談

## 這次定下的決策

- 3-5 自動掃描加「立即掃描」，開通與立即掃描只認旗標或終端機上的 y；有修補版本的高、中風險才讓第三階段不通過；`--image-scan` 沒結果時結束碼 2（D13，`D:\Dev\company\art-collector-recommender\docs\decisions\2026-10.md`）

## 相關檔案

- `D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`：3-5 在「3c.」那一節，`writeFindings` 在 3b 最後，self-test 的 3-5 判斷在 `imgOk`
- `D:\Dev\company\art-collector-recommender\tests\fakebin\gcloud`：開頭註解列了 3-5 用的環境變數

## 踩過的坑

- 不要直接在專案裡手動跑受測腳本（會蓋掉 `reports\.lazy-pack-state.env`）；手動情境複製到暫存區跑，PATH 要用 `cygpath -u` 轉出的 `/c/…`（`C:/…` 的冒號會被當成分隔）
- Bash 工具的 heredoc 裡放有反引號、`${}` 的 Python 會被截斷：用 Write 寫進暫存區再跑
- 改畫面訊息前先 `grep` 測試有沒有比對那句話（這次 t10j）
- 這個 repo 是公開的 GitHub：不寫內部主機名稱、內網位址
