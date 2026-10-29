#!/usr/bin/env bash
# gcp-setup-and-check.sh 自動測試：PATH 前面放假 gcloud 走真實分支，另跑 dry-run；不連雲端、不花錢
# 用法：bash tests/test-gcp-setup.sh（結果暫存寫到系統暫存資料夾，跑完還原 reports/ 狀態檔）
T="$(cd -P "$(dirname "$0")" && pwd -P)"
S="$(mktemp -d)"; [ -n "$S" ] && [ -d "$S" ] || exit 2
cp -r "$T/fakebin" "$S/fakebin"
R="${R_UNDER_TEST:-$(cd -P "$T/.." && pwd -P)}"
SH="$R/lazy-pack/gcp-setup-and-check.sh"
ST="$R/reports/.lazy-pack-state.env"
[ -f "$ST" ] && cp "$ST" "$S/state.bak"
chmod +x "$S/fakebin/gcloud"
export PATH="$S/fakebin:$PATH"
pass=0; fail=0
chk() { if grep -q -- "$2" "$S/out.txt"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] 找不到: $2"; fi; }
chkst() { if grep -q -- "$2" "$ST"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] 狀態檔找不到: $2"; fi; }

bash -n "$SH" && echo "bash -n OK" || { echo "bash -n FAIL"; exit 1; }

# 1. 三個專案、proj-a 有 2 個網站 → 預設選 1（proj-a），網站選 2
export FAKE_GCLOUD_LOG="$S/log1.txt"; : > "$FAKE_GCLOUD_LOG"
printf "\n2\n" | bash "$SH" --stage cost --check-only > "$S/out.txt" 2>&1
chk t1 "\[1\] 藏家推薦假專案（Project ID：proj-a）  🌐 有 2 個 Cloud Run 網站"
chk t1 "\[3\] （未命名）（Project ID：proj-c）"
chk t1 "目標 GCP 專案：proj-a"
chk t1 "https://admin-web-fake.a.run.app（Cloud Run 服務 admin-web"
chkst t1 'SAVED_CLOUD_RUN_URL="https://admin-web-fake.a.run.app"'
chkst t1 'SAVED_PROJECT_ID="proj-a"'
if grep -q "config set" "$FAKE_GCLOUD_LOG"; then fail=$((fail+1)); echo "FAIL [t1] 不該改 gcloud 預設專案"; else pass=$((pass+1)); fi
grep -q "run services list.*proj-b" "$FAKE_GCLOUD_LOG" && { fail=$((fail+1)); echo "FAIL [t1] proj-b 沒啟用 Run API 不該呼叫 run services list"; } || pass=$((pass+1))

# 2. 選 proj-b（gcloud 預設專案標星）→ 沒有網站
export FAKE_DEFAULT_PROJECT=proj-b
printf "2\n" | bash "$SH" --stage cost --check-only > "$S/out.txt" 2>&1
chk t2 "proj-b）  ⭐ 目前 gcloud 預設專案"
chk t2 "目標 GCP 專案：proj-b"
chk t2 "這個專案沒有探測到 Cloud Run 網站"
chkst t2 'SAVED_CLOUD_RUN_URL=""'

# 2b. gcloud 預設是 proj-b，但只有 proj-a 有網站 → 直接 Enter 選 proj-a
printf "\n\n" | bash "$SH" --stage cost --check-only > "$S/out.txt" 2>&1
chk t2b "目標 GCP 專案：proj-a"

# 3. 亂輸入編號 → 退回預設
printf "9\n" | bash "$SH" --stage cost --check-only > "$S/out.txt" 2>&1
chk t3 "編號 9 不在清單內，改用預設 \[1\]"
chk t3 "目標 GCP 專案：proj-a"
unset FAKE_DEFAULT_PROJECT

# 4. --project 直接指定，不出選單
bash "$SH" --stage cost --check-only --project proj-a < /dev/null > "$S/out.txt" 2>&1
grep -q "專案清單" "$S/out.txt" && { fail=$((fail+1)); echo "FAIL [t4] 不該出專案選單"; } || pass=$((pass+1))
chk t4 "目標 GCP 專案：proj-a"
chk t4 "https://art-web-fake.a.run.app"

# 5. 沒有專案 → 結束碼 2
FAKE_NO_PROJECTS=1 bash "$SH" --stage cost --check-only < /dev/null > "$S/out.txt" 2>&1; rc=$?
[ "$rc" = 2 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t5] rc=$rc"; }
chk t5 "找不到任何 GCP 專案"

# 6. dry-run（不碰 gcloud）
export FAKE_GCLOUD_LOG="$S/log6.txt"; : > "$FAKE_GCLOUD_LOG"
bash "$SH" --dry-run --stage cost < /dev/null > "$S/out.txt" 2>&1
chk t6 "demo-art-collector-proj）  🌐 有 1 個 Cloud Run 網站"
chk t6 "目標 GCP 專案：demo-art-collector-proj"
chk t6 "art-collector-web-demo-uc.a.run.app"
[ -s "$FAKE_GCLOUD_LOG" ] && { fail=$((fail+1)); echo "FAIL [t6] dry-run 呼叫了 gcloud"; } || pass=$((pass+1))
LATEST="$(ls -t "$R"/reports/stage-cost-report-*.md | head -1)"
grep -q "藏家推薦系統網址（Cloud Run）\*\*：https://art-collector-web-demo" "$LATEST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t6] 單次報告沒有網址"; }

[ -f "$S/state.bak" ] && cp "$S/state.bak" "$ST"
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
