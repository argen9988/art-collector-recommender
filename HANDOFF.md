# 交接：段 C 第 2 件改壞驗證全部完成；剩兩點小修；第 3 件真雲端驗收排在後面

> 寫於 2026-10-29 21:24（Windows，分支 master）。開工時說「開工」或打 /resume-work 讀這份。

## 下一步

1. 修 Opus 抽查新發現的兩點，位置在 `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「【審閱後續】」(2)：(a) `--item 8` 單獨重跑時 `SAVED_SECRET_COUNT` 越加越大（`D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh` 第 1106、1122 行附近，細項 4 沒跑時以狀態檔舊值為起點）；(b) Vertex 授權失敗後重跑被判成「已啟用」並蓋掉（第 964～973 行，API 已啟用時應再查 `roles/aiplatform.user`）。改完跑 `bash tests/test-gcp-setup.sh`（現在 74 項），並補對應測項、用 `python tests\mutate.py` 加新改壞項驗證抓得到。建議模型與努力程度：Sonnet、medium；Vertex 那段改完請主力模型看一眼。不需要使用者在場。
2. 補寫段 C 第 2 件的 reflection 與專案紀錄（公司專案：去識別化版本先給使用者看，看過才寫進 second-brain；完整版寫到 `D:\Dev\project-records\company\art-collector-recommender\`）。建議：Sonnet、medium；需要使用者看去識別化版本。
3. 段 C 第 3 件：使用者用個人帳號建拋棄式 GCP 專案、部署 hello-world Cloud Run，從第一階段跑到第三階段（D7 第 ③ 層，估 NT$0～50）。需要使用者在場；等第 1 項做完再做。

## 目標與做到哪

讓沒有資訊背景的執行者把 Lazy Pack 交給 AI Agent，就能自動找到正確的 GCP 專案、網站與原始碼，跑完三階段檢查。段 A、B1、B2、段 C 第 1 件、第 2 件（審閱＋(a)(b)(c) 修改＋Sonnet 一輪＋Opus 第二輪與抽查＋改壞驗證）都完成；測試 gcp 74 項、audit 190 項全過。

## 已完成

- 審閱修改 (a)`83a226c`、(b)`a162318`、(c)`405247d`、審閱一輪的 9 點 `1c09ec4`
- Opus 抽查：命令注入六處安全、十二處寫入類 gcloud 失敗都不計數
- 改壞驗證 M1～M12 全部跑完；M1、M5、M11、M12 補了測項（t8m、t1、t12、t11d），M2、M3 為等價改壞不補；假 gcloud 新增 `FAKE_SQL_TIER`（`db3727e`，已推送）

## 還沒做完

- 上面「下一步」第 1～3 項
- 真實推薦端點的路徑與格式待確認（`D:\Dev\company\art-collector-recommender\docs\todo-plan.md`「【待確認】」）
- 429／5xx 退避、報告取最新一份的時間戳風險（todo-plan「【小補強】」）；逾時分支沒有自動測試
- 只記待辦不改的三項（PITR 參數、Vertex 檢查、假 gcloud 的 `--filter`），在 todo-plan「【審閱修改】」最後一條
- 第 1 次審閱材料 `C:\Users\87094024\.ai-companion\review\20261029-art-collector-reviewB\` 可列給使用者、同意才移到資源回收筒
- 第一至第三階段的實際 GCP 設定與整合驗收（todo-plan 各階段段落）
- dotfiles（`C:\Users\87094024\dotfiles`）有兩個不是這個 session 改的未 commit 檔（`claude/CLAUDE.md`、`claude/skills/review-changes/SKILL.md`），沒動

## 這次定下的決策

- M2、M3 不補測資：M3 的網址一定以 https://、git@、file:// 開頭、不會以 `-` 開頭；M2 的守衛在可到達路徑上被 `fetchFromGithub` 的同類檢查先擋，皆等價（記在 `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md` 最後一段）
- 3A 的費用記目標值 480～560、不改（選單、提示、待辦三處已寫沒設排程是 780～880）

## 相關檔案

- `D:\Dev\company\art-collector-recommender\docs\todo-plan.md`：「【審閱後續】」是下一步的完整清單
- `D:\Dev\company\art-collector-recommender\docs\worklog\2026-10.md`：本次經過（最後一段）
- `D:\Dev\company\art-collector-recommender\tests\mutate.py`：改壞驗證腳本（複本上改、不動正式檔）；M1、M5、M11、M12 檔內「預期」文字仍是補測資前的舊說法，下次動它時順手更新
- `D:\Dev\company\art-collector-recommender\lazy-pack\gcp-setup-and-check.sh`、`D:\Dev\company\art-collector-recommender\lazy-pack\code-and-ai-audit.mjs`、兩支 `D:\Dev\company\art-collector-recommender\tests\test-*.sh`

## 踩過的坑

- Bash 工具會吞掉指令裡的雙反斜線：含 `\\` 的內容用 Write 寫成檔案再執行（hook 也會擋）
- 背景 `( … ) &` 在 Bash 工具裡一結束就被收掉，長測試用 PowerShell `run_in_background`
- `diff-reviewer` 抽查多時 12 輪會不夠、沒交報告：用 SendMessage 請它接著交
- 公司專案改檔前 hook 會擋一次，要先列 second-brain 的 `知識庫/playbooks/`；該 playbook（feature-testing）很長，讀進來吃 context，必要時只讀需要的段落
