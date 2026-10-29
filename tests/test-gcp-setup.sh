#!/usr/bin/env bash
# gcp-setup-and-check.sh 自動測試：PATH 前面放假 gcloud 走真實分支，另跑 dry-run；不連雲端、不花錢
# 用法：bash tests/test-gcp-setup.sh（結果暫存寫到系統暫存資料夾，跑完還原 reports/ 狀態檔、刪掉本次產生的報告）
T="$(cd -P "$(dirname "$0")" && pwd -P)"
S="$(mktemp -d)"; [ -n "$S" ] && [ -d "$S" ] || exit 2
cp -r "$T/fakebin" "$S/fakebin"
R="${R_UNDER_TEST:-$(cd -P "$T/.." && pwd -P)}"
SH="$R/lazy-pack/gcp-setup-and-check.sh"
ST="$R/reports/.lazy-pack-state.env"
mkdir -p "$R/reports"
[ -f "$ST" ] && { cp "$ST" "$S/state.bak" || exit 2; }
touch "$S/start.marker"
# 中途被中斷（Ctrl-C）也要還原使用者的狀態檔、刪掉本次產生的報告、清暫存
cleanup() {
  if [ -f "$S/state.bak" ]; then cp "$S/state.bak" "$ST"; else rm -f "$ST"; fi
  find "$R/reports" -maxdepth 1 -name 'stage-*-report-*.md' -newer "$S/start.marker" -delete 2>/dev/null
  rm -rf "${S:?}"
}
trap cleanup EXIT
trap 'exit 130' INT TERM
rm -f "$ST"   # 使用者狀態檔的舊值不能影響測試
chmod +x "$S/fakebin/gcloud"
export PATH="$S/fakebin:$PATH"
pass=0; fail=0
chk() { if grep -q -- "$2" "$S/out.txt"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] 找不到: $2"; fi; }
nochk() { if grep -q -- "$2" "$S/out.txt"; then fail=$((fail+1)); echo "FAIL [$1] 不該出現: $2"; else pass=$((pass+1)); fi; }
chkst() { if [ -f "$ST" ] && grep -q -- "$2" "$ST"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] 狀態檔找不到: $2"; fi; }
nochkst() { if [ -f "$ST" ] && grep -q -- "$2" "$ST"; then fail=$((fail+1)); echo "FAIL [$1] 狀態檔不該出現: $2"; else pass=$((pass+1)); fi; }
rc_is() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] rc=$2（預期 $3）"; fi; }

bash -n "$SH" && echo "bash -n OK" || { echo "bash -n FAIL"; exit 1; }

# 1. 三個專案、proj-a 有 2 個網站 → 預設選 1（proj-a），網站選 2
export FAKE_GCLOUD_LOG="$S/log1.txt"; : > "$FAKE_GCLOUD_LOG"
printf "\n2\n" | bash "$SH" --stage cost --check-only > "$S/out.txt" 2>&1; rc=$?
rc_is t1 "$rc" 0
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
printf "2\n" | bash "$SH" --stage cost --check-only > "$S/out.txt" 2>&1; rc=$?
rc_is t2 "$rc" 0
chk t2 "proj-b）  ⭐ 目前 gcloud 預設專案"
chk t2 "目標 GCP 專案：proj-b"
chk t2 "這個專案沒有探測到 Cloud Run 網站"
chkst t2 'SAVED_CLOUD_RUN_URL=""'

# 2b. gcloud 預設是 proj-b，但只有 proj-a 有網站 → 直接 Enter 選 proj-a
printf "\n\n" | bash "$SH" --stage cost --check-only > "$S/out.txt" 2>&1; rc=$?
rc_is t2b "$rc" 0
chk t2b "目標 GCP 專案：proj-a"

# 3. 亂輸入編號 → 退回預設
printf "9\n" | bash "$SH" --stage cost --check-only > "$S/out.txt" 2>&1; rc=$?
rc_is t3 "$rc" 0
chk t3 "編號 9 不在清單內，改用預設 \[1\]"
chk t3 "目標 GCP 專案：proj-a"
unset FAKE_DEFAULT_PROJECT

# 4. --project 直接指定，不出選單
bash "$SH" --stage cost --check-only --project proj-a < /dev/null > "$S/out.txt" 2>&1; rc=$?
rc_is t4 "$rc" 0
grep -q "專案清單" "$S/out.txt" && { fail=$((fail+1)); echo "FAIL [t4] 不該出專案選單"; } || pass=$((pass+1))
chk t4 "目標 GCP 專案：proj-a"
chk t4 "https://art-web-fake.a.run.app"

# 5. 沒有專案 → 結束碼 2
FAKE_NO_PROJECTS=1 bash "$SH" --stage cost --check-only < /dev/null > "$S/out.txt" 2>&1; rc=$?
rc_is t5 "$rc" 2
chk t5 "找不到任何 GCP 專案"

# 5b. 非互動且多個專案、沒給 --project → 印出自動選了哪個
bash "$SH" --stage cost --check-only < /dev/null > "$S/out.txt" 2>&1; rc=$?
rc_is t5b "$rc" 0
chk t5b "非互動模式且未指定 --project：自動選了"

# 6. dry-run（不碰 gcloud）；不寫狀態檔；封頂合計含 Cloud Run 上限 50（570～910）
rm -f "$ST"
export FAKE_GCLOUD_LOG="$S/log6.txt"; : > "$FAKE_GCLOUD_LOG"
bash "$SH" --dry-run --stage cost < /dev/null > "$S/out.txt" 2>&1; rc=$?
rc_is t6 "$rc" 0
chk t6 "demo-art-collector-proj）  🌐 有 1 個 Cloud Run 網站"
chk t6 "目標 GCP 專案：demo-art-collector-proj"
chk t6 "art-collector-web-demo-uc.a.run.app"
chk t6 'NT\$570 ～ NT\$910'
[ -s "$FAKE_GCLOUD_LOG" ] && { fail=$((fail+1)); echo "FAIL [t6] dry-run 呼叫了 gcloud"; } || pass=$((pass+1))
[ -f "$ST" ] && { fail=$((fail+1)); echo "FAIL [t6] dry-run 不該寫狀態檔"; } || pass=$((pass+1))
LATEST="$(find "$R/reports" -maxdepth 1 -name 'stage-cost-report-*.md' -newer "$S/start.marker" | sort | tail -1)"
[ -n "$LATEST" ] && grep -q "藏家推薦系統網址（Cloud Run）\*\*：https://art-collector-web-demo" "$LATEST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t6] 單次報告沒有網址"; }

# 7. 缺值與不認得的選項 → 結束碼 2
for args in "--stage" "--stage --check-only" "--project" "--item" "--item=" "--bogus" "--item 9" "--item=abc"; do
  bash "$SH" $args < /dev/null > "$S/out.txt" 2>&1; rc=$?
  rc_is "t7[$args]" "$rc" 2
done
bash "$SH" --bogus < /dev/null > "$S/out.txt" 2>&1
chk t7 "不認得的選項"

# 8. --check-only 不呼叫任何寫入類 gcloud
export FAKE_GCLOUD_LOG="$S/log8.txt"; : > "$FAKE_GCLOUD_LOG"
bash "$SH" --stage all --check-only --project proj-a < /dev/null > "$S/out.txt" 2>&1; rc=$?
rc_is t8 "$rc" 0
if grep -E "patch|add-iam-policy-binding|secrets create|services enable" "$FAKE_GCLOUD_LOG" > /dev/null; then fail=$((fail+1)); echo "FAIL [t8] --check-only 呼叫了寫入類 gcloud"; else pass=$((pass+1)); fi
chkst t8 'SAVED_PROJECT_ID="proj-a"'

# 9. 資料庫方案：patch 失敗不計入已完成、費用估算不變；成功才更新
export FAKE_GCLOUD_LOG="$S/log9.txt"; : > "$FAKE_GCLOUD_LOG"
rm -f "$ST"
printf "\n5\ny\n" | FAKE_GCLOUD_FAIL="sql instances patch" bash "$SH" --item 6 --project proj-a > "$S/out.txt" 2>&1; rc=$?
rc_is t9a "$rc" 0
chk t9a "方案 5 套用失敗"
chkst t9a "SAVED_PROJECT_ID="
nochkst t9a "SAVED_DB_MIN_NTD=780"
printf "\n5\ny\n" | bash "$SH" --item 6 --project proj-a > "$S/out.txt" 2>&1; rc=$?
rc_is t9b "$rc" 0
chk t9b "已套用方案 5"
chkst t9b "SAVED_DB_MIN_NTD=780"
printf "\n2\nn\n" | bash "$SH" --item 6 --project proj-a > "$S/out.txt" 2>&1
chk t9c "已取消方案 2"
chkst t9c "SAVED_DB_MIN_NTD=780"
# 方案 1 依現有規格（假 gcloud 回 db-f1-micro）對應月租
printf "\n1\n" | bash "$SH" --item 6 --project proj-a > "$S/out.txt" 2>&1; rc=$?
rc_is t9d "$rc" 0
chkst t9d "SAVED_DB_MIN_NTD=280"

# 10. Secret 建立失敗不計數
printf "\ny\nv1\ny\nv2\n" | FAKE_SECRETS_MISSING=1 FAKE_GCLOUD_FAIL="secrets create" bash "$SH" --item 4 --project proj-a > "$S/out.txt" 2>&1; rc=$?
rc_is t10 "$rc" 0
chk t10 "建立密鑰 GEMINI_API_KEY 失敗"
nochk t10 "已安全建立密鑰"
chkst t10 "SAVED_SECRET_COUNT=0"

# 11. 關公網 IP 前要有私有連線：沒有就不動
: > "$S/log11.txt"
printf "\ny\n" | FAKE_GCLOUD_LOG="$S/log11.txt" FAKE_SQL_IPV4=True bash "$SH" --item 5 --project proj-a > "$S/out.txt" 2>&1
chk t11a "沒有設定私有網路連線"
grep -q "no-assign-ip" "$S/log11.txt" && { fail=$((fail+1)); echo "FAIL [t11] 沒有私有連線卻關了公網 IP"; } || pass=$((pass+1))
# 有私有連線時回答 y 才會真的關；回答 n 不呼叫 patch
: > "$S/log11b.txt"
printf "\nn\nn\nn\n" | FAKE_GCLOUD_LOG="$S/log11b.txt" FAKE_SQL_IPV4=True FAKE_SQL_PRIVATE=projects/p/global/networks/n bash "$SH" --item 5 --project proj-a > "$S/out.txt" 2>&1
chk t11b "目前開啟了公網 IP"
grep -q "no-assign-ip" "$S/log11b.txt" && { fail=$((fail+1)); echo "FAIL [t11b] 回答 n 卻關了公網 IP"; } || pass=$((pass+1))
: > "$S/log11c.txt"
printf "\ny\nn\nn\n" | FAKE_GCLOUD_LOG="$S/log11c.txt" FAKE_SQL_IPV4=True FAKE_SQL_PRIVATE=projects/p/global/networks/n bash "$SH" --item 5 --project proj-a > "$S/out.txt" 2>&1
grep -q "no-assign-ip" "$S/log11c.txt" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11c] 有私有連線且回答 y 應該關公網 IP"; }
chk t11c "已關閉"

# 11d. 讀不到私有網路設定（describe 失敗）→ 不當成「沒有私有連線」，也不關公網 IP
: > "$S/log11d.txt"
printf "\ny\ny\ny\n" | FAKE_GCLOUD_LOG="$S/log11d.txt" FAKE_GCLOUD_FAIL="privateNetwork" FAKE_SQL_IPV4=True bash "$SH" --item 5 --project proj-a > "$S/out.txt" 2>&1
chk t11d "讀不到 .* 的私有網路連線設定"
grep -q "no-assign-ip" "$S/log11d.txt" && { fail=$((fail+1)); echo "FAIL [t11d] 讀不到私有連線設定卻關了公網 IP"; } || pass=$((pass+1))

# 12. 方案 3 遇到實例已經是 db-g1-small → 說已符合、不呼叫 patch
: > "$S/log12.txt"
printf "\n3\ny\n" | FAKE_GCLOUD_LOG="$S/log12.txt" FAKE_SQL_TIER=db-g1-small bash "$SH" --item 6 --project proj-a > "$S/out.txt" 2>&1; rc=$?
rc_is t12 "$rc" 0
chk t12 "已經是 db-g1-small，沒有變更"
nochk t12 "已選方案 3A"
grep -q "sql instances patch" "$S/log12.txt" && { fail=$((fail+1)); echo "FAIL [t12] 已是 db-g1-small 卻呼叫了 patch"; } || pass=$((pass+1))

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
