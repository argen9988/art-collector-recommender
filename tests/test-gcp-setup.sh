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
export LAZY_PACK_LOGS_DIR="$S/logs"   # 執行紀錄寫到暫存資料夾，不留在使用者的 reports/logs/
unset LAZY_PACK_REPORT_TO LAZY_PACK_LOGGING
pass=0; fail=0; skip=0
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

# 13. 單獨重跑細項 8，Secret 密鑰數不能越加越大（EDM 兩組各只算一次）
rm -f "$ST"
FAKE_SCHEDULER_API=1 bash "$SH" --item 8 --project proj-a < /dev/null > "$S/out.txt" 2>&1; rc=$?
rc_is t13a "$rc" 0
chkst t13a "SAVED_SECRET_COUNT=4"
FAKE_SCHEDULER_API=1 bash "$SH" --item 8 --project proj-a < /dev/null > "$S/out.txt" 2>&1
chkst t13b "SAVED_SECRET_COUNT=4"
FAKE_SCHEDULER_API=1 bash "$SH" --item 8 --project proj-a < /dev/null > "$S/out.txt" 2>&1
nochkst t13c "SAVED_SECRET_COUNT=8"
chkst t13c "SAVED_SECRET_COUNT=4"

# 14. Vertex API 已啟用但服務帳戶沒有 roles/aiplatform.user → 不能判成已啟用
rm -f "$ST"
FAKE_VERTEX_API=1 bash "$SH" --item 7 --project proj-a < /dev/null > "$S/out.txt" 2>&1; rc=$?
rc_is t14a "$rc" 0
chk t14a "服務帳戶沒有 Vertex AI 使用者／管理員角色"
nochk t14a "專案已啟用 Vertex AI API"
chkst t14a "授權未完成"
# 14b. 有授權才判成已啟用
rm -f "$ST"
FAKE_VERTEX_API=1 FAKE_VERTEX_ROLE=1 bash "$SH" --item 7 --project proj-a < /dev/null > "$S/out.txt" 2>&1
chk t14b "專案已啟用 Vertex AI API"
nochk t14b "服務帳戶沒有 Vertex AI 使用者／管理員角色"
# 14c. Editor 涵蓋 Vertex 權限 → 算有授權
rm -f "$ST"
FAKE_VERTEX_API=1 FAKE_VERTEX_ROLE=roles/editor bash "$SH" --item 7 --project proj-a < /dev/null > "$S/out.txt" 2>&1
chk t14c "專案已啟用 Vertex AI API"
nochk t14c "服務帳戶沒有 Vertex AI 使用者／管理員角色"
chkst t14c "已啟用 Vertex AI API（依實際呼叫字數計費"
nochkst t14c "授權未完成"
# 14d. 缺角色時回答 y → 腳本補上授權（第一個 Enter 是 proj-a 有 2 個 Cloud Run 時的網站選擇）
rm -f "$ST"
export FAKE_GCLOUD_LOG="$S/log14d.txt"; : > "$FAKE_GCLOUD_LOG"
printf "\ny\n" | FAKE_VERTEX_API=1 bash "$SH" --item 7 --project proj-a > "$S/out.txt" 2>&1; rc=$?
rc_is t14d "$rc" 0
chk t14d "已替 Cloud Run 服務帳戶補上 Vertex AI 授權"
grep -q "add-iam-policy-binding proj-a --member=serviceAccount:123456-compute@developer.gserviceaccount.com --role=roles/aiplatform.user" "$FAKE_GCLOUD_LOG" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t14d] 沒有替預設服務帳戶加 roles/aiplatform.user"; }
nochkst t14d "授權未完成"
chkst t14d "已啟用 Vertex AI API（依實際呼叫字數計費"
# 14e. 回答 y 但加角色失敗 → 不算完成
rm -f "$ST"
printf "\ny\n" | FAKE_VERTEX_API=1 FAKE_GCLOUD_FAIL=add-iam-policy-binding bash "$SH" --item 7 --project proj-a > "$S/out.txt" 2>&1
chk t14e "補上授權失敗"
nochk t14e "已替 Cloud Run 服務帳戶補上"
chkst t14e "授權未完成"
# 14f. 讀不到 IAM（沒權限）→ 標「未確認」，不說缺角色
rm -f "$ST"
FAKE_VERTEX_API=1 FAKE_GCLOUD_FAIL=get-iam-policy bash "$SH" --item 7 --project proj-a < /dev/null > "$S/out.txt" 2>&1
chk t14f "查不到 Cloud Run 服務帳戶的授權"
nochk t14f "服務帳戶沒有 Vertex AI 使用者／管理員角色"
chkst t14f "授權未確認"
# 14g. 列 API 失敗 → 不當成未啟用、不出啟用選單
rm -f "$ST"
FAKE_GCLOUD_FAIL="config.name:aiplatform" bash "$SH" --item 7 --project proj-a < /dev/null > "$S/out.txt" 2>&1; rc=$?
rc_is t14g "$rc" 0
chk t14g "查不到這個專案有沒有啟用 Vertex AI API"
nochk t14g "選配啟用 Google Cloud Vertex AI"
chkst t14g "查不到 API 狀態"

# 15. 方案 3B 的 PITR 依資料庫種類：PostgreSQL 開 point-in-time-recovery，MySQL 開 binlog
rm -f "$ST"
export FAKE_GCLOUD_LOG="$S/log15a.txt"; : > "$FAKE_GCLOUD_LOG"
printf "\n4\ny\n" | bash "$SH" --item 6 --project proj-a > "$S/out.txt" 2>&1; rc=$?
rc_is t15a "$rc" 0
grep -q "sql instances patch db-1 .*--enable-point-in-time-recovery" "$FAKE_GCLOUD_LOG" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t15a] PostgreSQL 沒開 --enable-point-in-time-recovery"; }
grep -q "enable-bin-log" "$FAKE_GCLOUD_LOG" && { fail=$((fail+1)); echo "FAIL [t15a] PostgreSQL 不該開 --enable-bin-log"; } || pass=$((pass+1))
rm -f "$ST"
export FAKE_GCLOUD_LOG="$S/log15b.txt"; : > "$FAKE_GCLOUD_LOG"
printf "\n4\ny\n" | FAKE_SQL_VERSION=MYSQL_8_0 bash "$SH" --item 6 --project proj-a > "$S/out.txt" 2>&1
grep -q "sql instances patch db-1 .*--enable-bin-log" "$FAKE_GCLOUD_LOG" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t15b] MySQL 沒開 --enable-bin-log"; }
grep -q "enable-point-in-time-recovery" "$FAKE_GCLOUD_LOG" && { fail=$((fail+1)); echo "FAIL [t15b] MySQL 不該開 --enable-point-in-time-recovery"; } || pass=$((pass+1))

# 16. 費用精算第 8 項 Artifact Analysis：照狀態檔的 SAVED_IMAGE_SCAN_ENABLED（3-5 記下的）算，讀小數參數。
#     腳本複製到暫存的假 repo 跑，參數檔換成跟正式值、預設值都不同的數字（0.4×30×31.25＝375；一次 0.4×31.25＝12.5 → 四捨五入 13）
R16="$S/r16"; mkdir -p "$R16/lazy-pack" "$R16/config" "$R16/reports"
cp "$SH" "$R16/lazy-pack/"
ST16="$R16/reports/.lazy-pack-state.env"
p16() {   # p16 <每份美元> <每月部署次數> <匯率>：從正式參數檔換掉這三個值
  sed -E -e "s/^(  \"image_scan_usd_per_image\": ).*/\1$1,/" -e "s/^(  \"image_scan_deploys_per_month\": ).*/\1$2,/" \
    -e "s/^(  \"usd_twd_rate\": ).*/\1$3/" "$R/config/params.json" > "$R16/config/params.json"
}
run16() { bash "$R16/lazy-pack/gcp-setup-and-check.sh" --stage cost --check-only --project proj-a < /dev/null > "$S/out.txt" 2>&1; }
p16 0.4 30 31.25
grep -q '"usd_twd_rate": 31.25$' "$R16/config/params.json" && ! grep -q '"usd_twd_rate": 31.25' "$R/config/params.json" \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t16] 自訂參數檔沒換到，或跟正式值一樣"; }
printf 'SAVED_PROJECT_ID="proj-a"\nSAVED_IMAGE_SCAN_ENABLED=1\n' > "$ST16"
run16; rc_is t16a $? 0
chk t16a "8. \[選配映像檔掃描\] Artifact Analysis"
chk t16a "已開通自動掃描（每次部署 US\$0.4，以每月 30 次估"
chk t16a "預估月費：約 NT\$375 / 月"
chk t16a "日常營運預估總月費：約 NT\$870 ～ NT\$995 / 月"   # 480+15+375 ～ 560+60+375
nochk t16a "注意：參數檔"
grep -q "| \*\*8. \[選配\] Artifact Analysis 映像檔掃描\*\* | 已開通自動掃描.* | \*\*約 NT\$375\*\* |" "$R16/reports/full-execution-report.md" \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t16a] 累計總報告沒有第 8 項 NT\$375"; }
grep -q "約 NT\$870～995 / 月" "$R16/reports/full-execution-report.md" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t16a] 累計總報告的合計沒算進第 8 項"; }
L16="$(find "$R16/reports" -maxdepth 1 -name 'stage-cost-report-*.md' | sort | tail -1)"
[ -n "$L16" ] && grep -q "8. \[選配\] Artifact Analysis 映像檔掃描.*約 NT\$375" "$L16" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t16a] 單次報告沒有第 8 項"; }
grep -q "3-5 映像檔漏洞掃描" "$R16/reports/full-execution-report.md" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t16a] 總覽表第三階段沒列 3-5"; }
grep -qx 'SAVED_IMAGE_SCAN_ENABLED=1' "$ST16" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t16a] 狀態檔沒留下 SAVED_IMAGE_SCAN_ENABLED=1"; }
# 沒開通：第 8 項 NT$0，合計不加；立即掃描的單價四捨五入
printf 'SAVED_PROJECT_ID="proj-a"\nSAVED_IMAGE_SCAN_ENABLED=0\n' > "$ST16"
run16; rc_is t16b $? 0
chk t16b "未開通（立即掃描一次 US\$0.4，約 NT\$13，只在掃的時候收）"
chk t16b "預估月費：約 NT\$0 / 月"
chk t16b "日常營運預估總月費：約 NT\$495 ～ NT\$620 / 月"
# 狀態檔的值看不懂（mjs 寫的是 0／1）：當成沒開通，寫回 0
printf 'SAVED_PROJECT_ID="proj-a"\nSAVED_IMAGE_SCAN_ENABLED="yes"\n' > "$ST16"
run16; rc_is t16c $? 0
chk t16c "未開通（立即掃描一次"
grep -qx 'SAVED_IMAGE_SCAN_ENABLED=0' "$ST16" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t16c] 看不懂的值沒寫回 0"; }
# 參數不合法：負數、超出範圍、0 次、加了引號 → 各自警告並照預設（0.26×20×32.5＝169）
printf 'SAVED_PROJECT_ID="proj-a"\nSAVED_IMAGE_SCAN_ENABLED=1\n' > "$ST16"
p16 -1 0 60.5
run16; rc_is t16d $? 0
chk t16d "image_scan_usd_per_image 讀不到或格式不合法，這次照預設值 0.26 跑"
chk t16d "image_scan_deploys_per_month=0 超出合法範圍 (1~1000)，這次照預設值 20 跑"
chk t16d "usd_twd_rate=60.5 超出合法範圍 (20~50)，這次照預設值 32.5 跑"
chk t16d "預估月費：約 NT\$169 / 月"
p16 10 1000 '"50"'
run16; rc_is t16e $? 0
chk t16e "usd_twd_rate 讀不到或格式不合法，這次照預設值 32.5 跑"
nochk t16e "注意：參數檔.*image_scan"   # 範圍兩端（10、1000）要收
chk t16e "預估月費：約 NT\$325000 / 月"   # 10×1000×32.5

# 17. 錯誤回報（D8、D15）：全程記錄到 LAZY_PACK_LOGS_DIR、遮蔽規則、--report-problem 轉給 code-and-ai-audit.mjs；紀錄與回報檔都要遮掉金鑰、密碼、電子郵件與家目錄
logs_n() { find "$S/logs" -maxdepth 1 -name 'gcp-setup-and-check-*.log' 2>/dev/null | wc -l | tr -d ' '; }
latest_log() { find "$S/logs" -maxdepth 1 -name 'gcp-setup-and-check-*.log' 2>/dev/null | sort | tail -1; }
# fchk <代號> <檔案> <樣式>／fnochk：檢查檔案內容（chk 只看終端機輸出 out.txt）
fchk() { if [ -n "$2" ] && [ -f "$2" ] && grep -q -- "$3" "$2"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] 檔案「${2:-（沒有檔案）}」找不到: $3"; fi; }
fnochk() { if [ -n "$2" ] && [ -f "$2" ]; then if grep -q -- "$3" "$2"; then fail=$((fail+1)); echo "FAIL [$1] 不該出現: $3"; else pass=$((pass+1)); fi; else fail=$((fail+1)); echo "FAIL [$1] 沒有檔案可查「$3」"; fi; }
mp() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
QKEY="AIza$(head -c 35 < /dev/zero | tr '\0' 'Q')"   # 假金鑰，跑的時候才組出來
K_PASS="pass""word"; K_TOKEN="tok""en"; K_PW="hunter""2pw"; K_APIK="api_""key"; K_PRIVK="PRIVATE""-KEY"   # 像帳密的假字串也是跑的時候才組出來（不讓帳密掃描誤判）
KB="-----BEGIN ""PRIVATE KEY-----"; KE="-----END ""PRIVATE KEY-----"; KRB="-----BEGIN RSA ""PRIVATE KEY-----"; KRE="-----END RSA ""PRIVATE KEY-----"

# 17a. 一般執行：終端機印的都記進一個新的 gcp-setup-and-check-*.log，開頭有參數與版本、結尾有結束碼；終端機畫面照舊
rm -rf "$S/logs"
printf "\n2\n" | bash "$SH" --stage cost --check-only > "$S/out.txt" 2>&1; rc=$?
rc_is t17a $rc 0
rc_is t17a-n "$(logs_n)" 1
LG="$(latest_log)"
fchk t17a-head "$LG" "^# gcp-setup-and-check.sh 開始 .*參數：--stage cost --check-only"
fchk t17a-body "$LG" "目標 GCP 專案：proj-a"
fchk t17a-foot "$LG" "^# 結束，結束碼 0"
chk t17a "目標 GCP 專案：proj-a"
nochk t17a "^# 結束"   # 開頭與結尾只記在紀錄裡，不印在終端機上
# 紀錄的內容和終端機一致（只多開頭、空行、結尾三行）
n_out="$(wc -l < "$S/out.txt" | tr -d ' ')"; n_log="$(wc -l < "$LG" | tr -d ' ')"
rc_is t17a-lines "$n_log" "$((n_out + 3))"

# 17b. 結束碼要跟著實際結果：不認得的選項是 2、--item 超出範圍是 2；--help 不留紀錄
rm -rf "$S/logs"
bash "$SH" --bogus-flag > "$S/out.txt" 2>&1; rc_is t17b $? 2
chk t17b "不認得的選項：--bogus-flag"
fchk t17b-log "$(latest_log)" "不認得的選項：--bogus-flag"
fchk t17b-foot "$(latest_log)" "^# 結束，結束碼 2"
rm -rf "$S/logs"
bash "$SH" --item 9 > "$S/out.txt" 2>&1; rc_is t17b2 $? 2
fchk t17b2-foot "$(latest_log)" "^# 結束，結束碼 2"
rm -rf "$S/logs"
bash "$SH" --help > "$S/out.txt" 2>&1; rc_is t17b3 $? 0
chk t17b3 "用法"
chk t17b3 "--report-problem"
rc_is t17b3-n "$(logs_n)" 0

# 17c. 紀錄裡遮掉金鑰、帳密、Bearer 與電子郵件（參數與畫面上印出的都要遮）；終端機上原樣不動
rm -rf "$S/logs"
bash "$SH" --bogus "https://bob:${K_PW}@127.0.0.1:1/x?k=$QKEY&${K_TOKEN}=zzz98765" "Bearer abcdef1234567890" "bob@example.com" > "$S/out.txt" 2>&1; rc_is t17c $? 2
LG="$(latest_log)"
fchk t17c-pos "$LG" "參數：--bogus https://"
for pat in "$K_PW" "$QKEY" "zzz98765" "bob@example.com" "abcdef1234567890"; do fnochk t17c "$LG" "$pat"; done
fchk t17c-mask "$LG" "AIza\*\*\*"
fchk t17c-mask2 "$LG" "<email>"
# 畫面上印出來的（不只是參數）也要遮：--project 的值會印在「目標 GCP 專案」那一行
rm -rf "$S/logs"
printf "\n" | bash "$SH" --project "$QKEY" --stage cost --check-only > "$S/out.txt" 2>&1; rc_is t17c2 $? 0
chk t17c2 "目標 GCP 專案：$QKEY"
LG="$(latest_log)"
fchk t17c2-body "$LG" "目標 GCP 專案：AIza\*\*\*"
fnochk t17c2 "$LG" "$QKEY"

# 17d. 家目錄換成 <HOME>：假家目錄底下的路徑出現在參數與畫面上，紀錄裡要看不到家目錄名稱，終端機上照舊（Windows 的 C:/… 寫法也遮）
FH="$S/fakehome/alice-unique-9f3"; mkdir -p "$FH"
rm -rf "$S/logs"
env HOME="$FH" USERPROFILE="$(mp "$FH")" bash "$SH" --bogus "$FH/proj" "$(mp "$FH")/proj2" > "$S/out.txt" 2>&1; rc_is t17d $? 2
LG="$(latest_log)"
fchk t17d-pos "$LG" "參數：--bogus <HOME>/proj <HOME>/proj2"
fchk t17d-body "$LG" "不認得的選項：--bogus"
fnochk t17d "$LG" "alice-unique-9f3"
# 17d2. 環境裡帶進來的 LP_HOME_ERE（外層傳給內層用的）外層不採用：設成空的也照樣遮家目錄
rm -rf "$S/logs"
env HOME="$FH" USERPROFILE="$(mp "$FH")" LP_HOME_ERE="" LP_SED_U="" bash "$SH" --bogus "$FH/proj" > "$S/out.txt" 2>&1; rc_is t17d2 $? 2
LG="$(latest_log)"
fchk t17d2-pos "$LG" "參數：--bogus <HOME>/proj"
fnochk t17d2 "$LG" "alice-unique-9f3"

# 17e. 紀錄資料夾寫不進去（路徑被一個檔案擋住）不能擋住檢查本身，也不改寫到別處（reports/logs）
printf 'x' > "$S/afile"
touch "$S/run.marker"
printf "\n2\n" | LAZY_PACK_LOGS_DIR="$S/afile/logs" bash "$SH" --stage cost --check-only > "$S/out.txt" 2>&1; rc_is t17e $? 0
chk t17e "目標 GCP 專案：proj-a"
[ -z "$(find "$R/reports/logs" -name '*.log' -newer "$S/run.marker" 2>/dev/null)" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t17e] 紀錄寫不進去時不該改寫到別處（reports/logs）"; }

# 17f. 遮蔽規則逐條驗證：把腳本裡的遮蔽函式抽出來，直接餵一份樣本（私鑰跨好幾行、沒結尾的私鑰、各種金鑰與帳密、不該遮的行）
RD="$S/redact-fns.sh"
awk '/^# 家目錄的各種寫法/{f=1} /^# 照 \(a\) 的格式/{f=0} f' "$SH" > "$RD"
[ "$(grep -c '^lp_redact() {' "$RD")" = 1 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t17f] 抽不出遮蔽函式"; }
SAMPLE="$S/sample.txt"; EXPECT_DIR="$S/expect"
{
  echo "前面的行"
  echo "$KB"; echo "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC"; echo "$KE"
  echo "後面的行"
  echo "${KRB}MIIabc${KRE}"
  echo "https://user:${K_PW}@host.example/path"
  echo "key $QKEY end"
  echo "mail re_abcdefghijklmnopqrstuv end"
  echo "mail SG.abcdefghijklmnopqrstuvwx end"
  echo "oauth ya29.abcdefghijklmnopqrstuv end"
  echo "jwt eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.sig-nature end"
  echo "Authorization: Bearer abcDEF123456+/= end"
  echo "curl -H Bearer xyzXYZ987654+/= end"
  echo "${K_PASS}=abc12345 和 ${K_TOKEN}: tok98765 和 \"${K_APIK}\": \"kkk11111\" 和 ${K_PRIVK} = pk22222"
  echo "寄給 owner@corp.example 與 a.b+c@sub.example.co.uk"
  echo "一般的行：Secret Manager 已建 3 組密鑰，網址 https://example.com/a/b?x=1"
  echo "$KB"; echo "沒有結尾的私鑰內容ZZZ"
} > "$SAMPLE"
( . "$RD"; lp_redact_init; lp_redact < "$SAMPLE" > "$S/redacted.txt" )
RO="$S/redacted.txt"
for pat in "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC" "MIIabc" "$K_PW" "$QKEY" "abcdefghijklmnopqrstuv" "abcdefghijklmnopqrstuvwx" "sig-nature" "abcDEF123456" "xyzXYZ987654" "abc12345" "tok98765" "kkk11111" "pk22222" "owner@corp.example" "sub.example.co.uk" "沒有結尾的私鑰內容ZZZ"; do
  fnochk t17f "$RO" "$pat"
done
fchk t17f-keep1 "$RO" "^前面的行$"
fchk t17f-keep2 "$RO" "^後面的行$"
fchk t17f-key "$RO" "^<私鑰已遮蔽>$"
[ "$(grep -c '<私鑰已遮蔽>' "$RO")" = 3 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t17f] 私鑰應遮 3 處（多行、單行、沒結尾），實際 $(grep -c '<私鑰已遮蔽>' "$RO")"; }
fchk t17f-url "$RO" "https://\*\*\*@host.example/path"
fchk t17f-aiza "$RO" "key AIza\*\*\* end"
fchk t17f-re "$RO" "mail re_\*\*\* end"
fchk t17f-sg "$RO" "mail SG.\*\*\* end"
fchk t17f-ya "$RO" "oauth ya29.\*\*\* end"
fchk t17f-jwt "$RO" "jwt <JWT已遮蔽> end"
fchk t17f-bearer "$RO" "curl -H Bearer \*\*\* end"
fchk t17f-auth "$RO" "Authorization: \*\*\* \*\*\* end"
fchk t17f-pw "$RO" "${K_PASS}=\*\*\* 和 ${K_TOKEN}: \*\*\* 和 \"${K_APIK}\": \"\*\*\*\" 和 ${K_PRIVK} = \*\*\*"
fchk t17f-mail "$RO" "寄給 <email> 與 <email>"
fchk t17f-plain "$RO" "^一般的行：Secret Manager 已建 3 組密鑰，網址 https://example.com/a/b?x=1$"

# 17g. --report-problem：轉給 code-and-ai-audit.mjs；在複製的專案裡產生（不污染 reports/）。先用真的紀錄產生一次，再放一份比較新、含金鑰的假紀錄產生第二次
RP="$S/rp"; mkdir -p "$RP/lazy-pack" "$RP/config" "$RP/reports"
cp "$R/lazy-pack/"* "$RP/lazy-pack/"; cp "$R/config/params.json" "$RP/config/"
RPSH="$RP/lazy-pack/gcp-setup-and-check.sh"
rm -rf "$S/logs"
printf "\n2\n" | bash "$RPSH" --stage cost --check-only > "$S/out.txt" 2>&1; rc_is t17g-pre $? 0
rc_is t17g-n0 "$(logs_n)" 1
export LAZY_PACK_REPORT_TO="it-desk@corp.example"
bash "$RPSH" --report-problem --note "按 y 之後卡住 Bearer abcdef1234567890 我是 bob@example.com" > "$S/out.txt" 2>&1; rc=$?
unset LAZY_PACK_REPORT_TO
rc_is t17g $rc 0
rc_is t17g-nolog "$(logs_n)" 1   # --report-problem 自己不留紀錄
chk t17g "問題回報檔（要當附件）"
chk t17g "不會自動寄出"
PR="$(find "$RP/reports" -maxdepth 1 -name 'problem-report-*.md' | sort | tail -1)"
DR="$(find "$RP/reports" -maxdepth 1 -name 'problem-email-draft-*.txt' | sort | tail -1)"
fchk t17g-title "$PR" "^# Lazy Pack 問題回報檔"
fchk t17g-gcp "$PR" "^### gcp-setup-and-check（紀錄檔 gcp-setup-and-check-"
fchk t17g-head "$PR" "gcp-setup-and-check.sh 開始 .*參數：--stage cost --check-only"
fchk t17g-foot "$PR" "結束，結束碼 0"
fchk t17g-note "$PR" "按 y 之後卡住"
fchk t17g-to "$DR" "^收件人：it-desk@corp.example"
for f in "$PR" "$DR"; do
  for pat in abcdef1234567890 bob@example.com; do fnochk t17g "$f" "$pat"; done
done
# 第二次：放一份比較新、沒遮過、沒有結尾的紀錄（舊版或被中斷的紀錄），回報檔產生時要再遮一次
sleep 1
printf '# gcp-setup-and-check.sh 開始 2026-01-01 00:00:00\n❌ 新的失敗 %s=abc12345 %s owner@corp.example\n' "$K_PASS" "$QKEY" > "$S/logs/gcp-setup-and-check-29990101-000000.log"
bash "$RPSH" --report-problem > "$S/out.txt" 2>&1; rc_is t17g2 $? 0
PR="$(find "$RP/reports" -maxdepth 1 -name 'problem-report-*.md' -newer "$S/logs/gcp-setup-and-check-29990101-000000.log" | sort | tail -1)"
DR="$(find "$RP/reports" -maxdepth 1 -name 'problem-email-draft-*.txt' -newer "$S/logs/gcp-setup-and-check-29990101-000000.log" | sort | tail -1)"
fchk t17g2-file "$PR" "gcp-setup-and-check-29990101-000000.log"
fchk t17g2-nofoot "$PR" "沒有結束紀錄"
fchk t17g2-problem "$PR" "^- ❌ 新的失敗"
for f in "$PR" "$DR"; do
  for pat in abc12345 "$QKEY" owner@corp.example; do fnochk t17g2 "$f" "$pat"; done
done
fchk t17g2-mask "$PR" "AIza\*\*\*"
fchk t17g2-mask2 "$PR" "<email>"

# 17h. 找不到 node 時不能當掉：印白話說明與最近一次紀錄的位置，結束碼 1
if ( PATH=/usr/bin:/bin; command -v node >/dev/null 2>&1 ); then
  echo "SKIP [t17h] /usr/bin:/bin 底下有 node，沒辦法模擬找不到 node"; skip=$((skip+1))
else
  env PATH=/usr/bin:/bin "$BASH" "$RPSH" --report-problem > "$S/out.txt" 2>&1; rc_is t17h $? 1
  chk t17h "找不到 node"
  chk t17h "gcp-setup-and-check-29990101-000000.log"
  chk t17h "用電子郵件寄給資訊相關權責單位"
  rm -rf "$S/logs"
  env PATH=/usr/bin:/bin "$BASH" "$RPSH" --report-problem > "$S/out.txt" 2>&1; rc_is t17h2 $? 1
  chk t17h2 "也沒有找到執行紀錄"
fi

# 17i. --note 缺值、--report-problem 搭配不認得的選項：結束碼 2
bash "$SH" --report-problem --note > "$S/out.txt" 2>&1; rc_is t17i $? 2
chk t17i "選項 --note 需要接一個值"
bash "$SH" --report-problem --bogus-flag > "$S/out.txt" 2>&1; rc_is t17i2 $? 2
chk t17i2 "不認得的選項：--bogus-flag"
rm -rf "$S/logs"

# 17j. gcloud 查現況的錯誤訊息記進紀錄（D15 (b2)）：失敗時假 gcloud 在 stderr 印一行帶電子郵件與 token 的訊息。
#      終端機畫面不變（錯誤訊息不印）、紀錄裡有「（gcloud 錯誤）」且已遮蔽、檢查結果照舊（讀不到就標「未知」）
GERR="ERROR: (gcloud.sql.instances.describe) PERMISSION_DENIED for bob@example.com ${K_TOKEN}=zzz98765 end"
rm -rf "$S/logs"
FAKE_GCLOUD_FAIL="sql instances describe" FAKE_GCLOUD_FAIL_MSG="$GERR" bash "$SH" --item 5 --project proj-a --check-only < /dev/null > "$S/out.txt" 2>&1; rc_is t17j $? 0
LG="$(latest_log)"
nochk t17j-term "PERMISSION_DENIED"   # 終端機畫面不變
chk t17j-rc "目前規格: Unknown"   # 結束碼原樣交還：失敗時走原本的「|| echo Unknown」
chk t17j-rc2 "讀不到 Cloud SQL 的公網 IP 設定"
fchk t17j-hdr "$LG" "^（gcloud 錯誤）結束碼 1：gcloud sql instances describe db-1 --project=proj-a --format=value(settings.tier)"
fchk t17j-msg "$LG" "^（gcloud 錯誤）ERROR: (gcloud.sql.instances.describe) PERMISSION_DENIED for <email> ${K_TOKEN}=\*\*\* end"
fnochk t17j-mail "$LG" "bob@example.com"
fnochk t17j-tok "$LG" "zzz98765"
fchk t17j-foot "$LG" "^# 結束，結束碼 0"
[ "$(grep -c '^（gcloud 錯誤）結束碼' "$LG")" = 6 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t17j] 6 次 describe 都該各記一筆，實際 $(grep -c '^（gcloud 錯誤）結束碼' "$LG")"; }
# 17j-empty. 失敗但 stderr 沒字：只記結束碼那行，不多一行空的「（gcloud 錯誤）」
rm -rf "$S/logs"
FAKE_GCLOUD_FAIL="sql instances describe" bash "$SH" --item 5 --project proj-a --check-only < /dev/null > "$S/out.txt" 2>&1; rc_is t17j-empty $? 0
LG="$(latest_log)"
fchk t17j-empty-hdr "$LG" "^（gcloud 錯誤）結束碼 1：gcloud sql instances describe"
fnochk t17j-empty "$LG" "^（gcloud 錯誤）$"
[ -z "$(find "$S/logs" -name '*.gcerr' 2>/dev/null)" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t17j] 暫存的 .gcerr 檔跑完要刪掉"; }
# 17j2. 成功但 stderr 有警告：也記（結束碼 0），沒有警告的呼叫不記；多行訊息每行都加前綴
rm -rf "$S/logs"
FAKE_GCLOUD_WARN_ON="projects list" FAKE_GCLOUD_WARN="WARNING: update available" bash "$SH" --stage cost --check-only < /dev/null > "$S/out.txt" 2>&1; rc_is t17j2 $? 0
LG="$(latest_log)"
nochk t17j2-term "update available"
fchk t17j2-hdr "$LG" "^（gcloud 錯誤）結束碼 0：gcloud projects list"
fchk t17j2-msg "$LG" "^（gcloud 錯誤）WARNING: update available"
[ "$(grep -c '^（gcloud 錯誤）結束碼' "$LG")" = 1 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t17j2] 只有 projects list 有警告，該只記 1 筆，實際 $(grep -c '^（gcloud 錯誤）結束碼' "$LG")"; }
# 17j3. 沒有全程記錄（LAZY_PACK_LOGGING=1 直接跑內層）時照舊丟掉：不留紀錄、畫面不變、不留 .gcerr
rm -rf "$S/logs"
LAZY_PACK_LOGGING=1 FAKE_GCLOUD_FAIL="sql instances describe" FAKE_GCLOUD_FAIL_MSG="$GERR" bash "$SH" --item 5 --project proj-a --check-only < /dev/null > "$S/out.txt" 2>&1; rc_is t17j3 $? 0
nochk t17j3-term "PERMISSION_DENIED"
rc_is t17j3-n "$(logs_n)" 0
[ -z "$(find "$S" "$R" -maxdepth 3 -name '*.gcerr' 2>/dev/null)" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t17j3] 不該留下 .gcerr：$(find "$S" "$R" -maxdepth 3 -name '*.gcerr' 2>/dev/null | head -3)"; }
# 17j5. 暫存的 .gcerr 寫不進去（紀錄檔所在資料夾不存在）時，gcloud 仍照常執行、結果不變，只是不記
rm -rf "$S/logs"
LAZY_PACK_LOGGING=1 LAZY_PACK_LOG_FILE="$S/no-such-dir/x.log" bash "$SH" --stage cost --check-only < /dev/null > "$S/out.txt" 2>&1; rc_is t17j5 $? 0
chk t17j5 "目標 GCP 專案：proj-a"
# 17j4. --report-problem 的回報檔把 gcloud 錯誤列在「失敗與警告的行」，並已遮蔽
rm -rf "$S/logs"
cp "$R/lazy-pack/"* "$RP/lazy-pack/"
FAKE_GCLOUD_FAIL="sql instances describe" FAKE_GCLOUD_FAIL_MSG="$GERR" bash "$RPSH" --item 5 --project proj-a --check-only < /dev/null > "$S/out.txt" 2>&1
touch "$S/rp.marker"; sleep 1
bash "$RPSH" --report-problem > "$S/out.txt" 2>&1; rc_is t17j4 $? 0
PR="$(find "$RP/reports" -maxdepth 1 -name 'problem-report-*.md' -newer "$S/rp.marker" | sort | tail -1)"
fchk t17j4-hdr "$PR" "^- （gcloud 錯誤）結束碼 1：gcloud sql instances describe"
fchk t17j4-msg "$PR" "^- （gcloud 錯誤）ERROR: (gcloud.sql.instances.describe) PERMISSION_DENIED for <email>"
fnochk t17j4 "$PR" "bob@example.com"
rm -rf "$S/logs"

echo "PASS=$pass FAIL=$fail SKIP=$skip"
[ "$fail" -eq 0 ] && [ "$skip" -eq 0 ]
