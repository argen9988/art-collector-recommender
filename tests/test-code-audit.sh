#!/usr/bin/env bash
# code-and-ai-audit.mjs 自動測試：--target 防呆、三種原始碼來源（假 gcloud、本機假 git repo、假 ZIP）、3-2 線上測試、3-3／3-4 網址檢查（假網站與假 Observatory）、3-5 映像檔掃描（假 gcloud），不連雲端、不花錢
# 用法：bash tests/test-code-audit.sh（結果暫存寫到系統暫存資料夾，跑完還原 reports/ 狀態檔）
T="$(cd -P "$(dirname "$0")" && pwd -P)"
S="$(mktemp -d)"; [ -n "$S" ] && [ -d "$S" ] || exit 2
cp -r "$T/fakebin" "$S/fakebin"
R="${R_UNDER_TEST:-$(cd -P "$T/.." && pwd -P)}"
MJS="$R/lazy-pack/code-and-ai-audit.mjs"
ST="$R/reports/.lazy-pack-state.env"
FIX="$T/fixtures/fake-nextjs-app"
mkdir -p "$R/reports"
[ -f "$ST" ] && { cp "$ST" "$S/state.bak" || exit 2; }
FULL="$R/reports/full-execution-report.md"
[ -f "$FULL" ] && { cp "$FULL" "$S/full.bak" || exit 2; }
FND="$R/reports/findings.json"
[ -f "$FND" ] && { cp "$FND" "$S/findings.bak" || exit 2; }
touch "$S/start.marker"
# 中途被中斷（Ctrl-C）也要還原使用者的狀態檔、關掉假伺服器、清暫存
cleanup() {
  [ -n "${SRV:-}" ] && { kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; }
  [ -d "$ST" ] && rmdir "$ST" 2>/dev/null   # 第 12 段會暫時把狀態檔換成資料夾（逼出讀檔錯誤），中斷時還原
  if [ -f "$S/state.bak" ]; then cp "$S/state.bak" "$ST"; else rm -f "$ST"; fi
  if [ -f "$S/full.bak" ]; then cp "$S/full.bak" "$FULL"; else rm -f "$FULL"; fi
  if [ -f "$S/findings.bak" ]; then cp "$S/findings.bak" "$FND"; else rm -f "$FND"; fi
  find "$R/reports" -maxdepth 1 \( -name 'stage-*-report-*.md' -o -name 'problem-report-*.md' -o -name 'problem-email-draft-*.txt' \) -newer "$S/start.marker" -delete 2>/dev/null
  rm -rf "${S:?}"
}
trap cleanup EXIT
trap 'exit 130' INT TERM
rm -f "$ST"   # 使用者狀態檔裡的真網址不能讓 3-2 測試打出去
unset LAZY_PACK_API_TOKEN NODE_EXTRA_CA_CERTS
export LAZY_PACK_OBSERVATORY_API="http://127.0.0.1:1/never"   # 3-4 永遠打不到真的 Observatory
unset LAZY_PACK_OBSERVATORY_ALLOW_LOCAL   # 平常的設定：本機與內網網址不送 Observatory（第 10 段要送給假伺服器時才設）
chmod +x "$S/fakebin/gcloud"
export PATH="$S/fakebin:$PATH"
# 給 node 與它叫起來的程式的路徑一律用 D:/… 寫法（Windows）；別的系統原樣
mp() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
DL=':'; command -v cygpath >/dev/null 2>&1 && DL=';'
export LAZY_PACK_SOURCES_DIR="$(mp "$S/sources")"
export LAZY_PACK_LOGS_DIR="$(mp "$S/logs")"   # 執行紀錄寫到暫存資料夾，不留在使用者的 reports/logs/
export LAZY_PACK_SEARCH_DIRS="$(mp "$S/none")"
export GIT_CONFIG_GLOBAL="$S/empty.gitconfig" GIT_CONFIG_NOSYSTEM=1; : > "$GIT_CONFIG_GLOBAL"
pass=0; fail=0; skip=0
chk() { if grep -q -- "$2" "$S/out.txt"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] 找不到: $2"; fi; }
nochk() { if grep -q -- "$2" "$S/out.txt"; then fail=$((fail+1)); echo "FAIL [$1] 不該出現: $2"; else pass=$((pass+1)); fi; }
rc_is() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] rc=$2（預期 $3）"; fi; }
run() { touch "$S/run.marker"; node "$MJS" "$@" > "$S/out.txt" 2>&1; }
# 這次 run 新產生的單次報告（不用 ls -t：兩次執行時間相同時會抓到舊的）
latest_rep() { find "$R/reports" -maxdepth 1 -name 'stage-3-report-*.md' -newer "$S/run.marker" | sort | tail -1; }

# 埋了問題的假專案：假金鑰跑的時候才組出來，不整串寫進檔案
cp -r "$FIX" "$S/leaky"
KEY="AIza$(head -c 35 < /dev/zero | tr '\0' 'Q')"
mkdir -p "$S/leaky/lib" "$S/leaky/app/chat"
printf 'export const geminiKey = "%s";\n' "$KEY" > "$S/leaky/lib/gemini.ts"
printf 'export const k = process.env.NEXT_PUBLIC_GEMINI_API_KEY;\n' > "$S/leaky/lib/config.ts"
printf "'use client';\nimport { GoogleGenAI } from '@google/genai';\nexport default function Chat() { return null; }\n" > "$S/leaky/app/chat/page.tsx"
printf 'node_modules/\n' > "$S/leaky/.gitignore"

# 1. --self-test：沒帶 --target 時掃 tests/fixtures 的乾淨假專案
run --self-test; rc_is t1 $? 0
chk t1 "掃描目標：.*fake-nextjs-app"
chk t1 "未發現任何硬編碼 API Key"
chk t1 "Self-Test 驗證通過"
[ ! -f "$ST" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t1] --self-test 不該寫狀態檔"; }

# 2. 乾淨假專案 → 通過；埋了問題的複本 → 四種問題都抓到
run --target "$(mp "$FIX")" --scan-only; rc_is t2 $? 0
chk t2 "第三階段總體檢結果：PASS"
run --target "$(mp "$S/leaky")" --scan-only; rc_is t2b $? 1
chk t2b "\[HARDCODED_SECRET\] lib.gemini.ts"
chk t2b "\[NEXT_PUBLIC_LEAK\] lib.config.ts"
chk t2b "\[CLIENT_SDK_IMPORT\] app.chat.page.tsx"
chk t2b "\[GITIGNORE_ENV\]"
nochk t2b "app.page.tsx"
LATEST="$(latest_rep)"
grep -q "掃描的原始碼資料夾\*\*：.*leaky" "$LATEST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t2b] 單次報告沒寫掃描的資料夾"; }

# 3. --target 防呆：Lazy Pack 自己、它的上層、不存在、空資料夾、ZIP 檔、沒給值
run --target "$(mp "$R")"; rc_is t3 $? 2
chk t3 "這是 Lazy Pack 工具包自己"
nochk t3 "細項 3-1\] 執行本機原始碼"
run --target "$(mp "$R/..")"; rc_is t3b $? 2
chk t3b "這是 Lazy Pack 工具包自己"
run --target "$(mp "$S/no-such-dir")"; rc_is t3c $? 2
chk t3c "找不到資料夾"
mkdir -p "$S/emptydir/sub"; run --target "$(mp "$S/emptydir")"; rc_is t3d $? 2
chk t3d "沒有任何程式碼檔"
: > "$S/app.zip"; run --target "$(mp "$S/app.zip")"; rc_is t3e $? 2
chk t3e "這是 ZIP 檔"
run --target; rc_is t3f $? 2
chk t3f "--target 後面要接"
mkdir -p "$S/nopkg"; printf 'export const a = 1;\n' > "$S/nopkg/a.ts"; printf '.env\n' > "$S/nopkg/.gitignore"
run --target "$(mp "$S/nopkg")" --scan-only; rc_is t3g $? 0
chk t3g "看起來不像 Next.js 專案"

# 4. --eval-only 不需原始碼、不出選單；沒有網址 → 本機模擬
run --eval-only < /dev/null; rc_is t4 $? 0
nochk t4 "原始碼在哪裡"
chk t4 "完成 20 題自動化測試"
chk t4 "測試對象：本機模擬回應"
LATEST="$(latest_rep)"
grep -q "3-2 測試對象\*\*：本機模擬回應" "$LATEST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t4] 單次報告沒寫 3-2 測試對象"; }

# 5. 沒帶 --target → 選單 [C] 搜尋本機：資料夾（舊）＋ ZIP（新，解開後多一層資料夾）
mkdir -p "$S/search/projects"; cp -r "$FIX" "$S/search/projects/art-web"
touch -d '2026-01-01' "$S/search/projects/art-web"
export LAZY_PACK_SEARCH_DIRS="$(mp "$S/search")${DL}$(mp "$S/none")"
PY="$(command -v python3 || command -v python)"
mkdir -p "$S/zipsrc"; cp -r "$S/leaky" "$S/zipsrc/art-web-main"
if [ -n "$PY" ] && (cd "$S/zipsrc" && "$PY" -m zipfile -c "$(mp "$S/search/art-web-main.zip")" art-web-main) && [ -s "$S/search/art-web-main.zip" ]; then
  printf "C\n1\n" | run; rc_is t5 $? 1
  chk t5 "\[1\] 🗜️ ZIP .*art-web-main.zip"
  chk t5 "\[2\] 📁 .*art-web（2026-01-01）"
  chk t5 "掃描目標：.*sources.*art-web-main"
  chk t5 "\[HARDCODED_SECRET\]"
else
  skip=$((skip+1)); echo "SKIP [t5] 沒有 python，做不出測試用 ZIP"
  printf "C\n1\n" | run
fi
printf "\n2\n" | run --scan-only; rc_is t5b $? 0
chk t5b "掃描目標：.*search.projects.art-web（"
grep -q "SAVED_SOURCE_DIR=\".*art-web\"" "$ST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t5b] 狀態檔沒記 SAVED_SOURCE_DIR"; }
printf "C\n\n" | run; rc_is t5c $? 2
chk t5c "\[1\] "
chk t5c "為了不掃錯專案，不自動挑"
nochk t5c "細項 3-1\] 執行本機原始碼"
printf "Z\n" | run; rc_is t5d $? 2
chk t5d "看不懂「Z」"
export LAZY_PACK_SEARCH_DIRS="$(mp "$S/none")"
run < /dev/null; rc_is t5e $? 2
chk t5e "找不到有 package.json"
chk t5e "aistudio.google.com"

# 6. [B] GitHub：本機假 repo 用 file:// 網址 clone；網址亂打要擋
mkdir -p "$S/gitsrc"; cp -r "$FIX/." "$S/gitsrc/"
(cd "$S/gitsrc" && git init -q && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -qm init) >/dev/null 2>&1
run --repo "file:///$(mp "$S/gitsrc")" --scan-only; rc_is t6 $? 0
chk t6 "git clone --depth 1 file://"
chk t6 "掃描目標：.*sources.*gitsrc-"
printf "B\nnot-a-url\n" | run; rc_is t6b $? 2
chk t6b "看不懂這個網址"
run --repo "file:///$(mp "$S/no-such-repo")"; rc_is t6c $? 2
chk t6c "下載失敗"

# 7. [A] 雲端：照狀態檔的專案與網站挑建置，下載假原始碼（多包一層資料夾）；狀態檔原有欄位要保留
mkdir -p "$S/tgz"; cp -r "$S/leaky" "$S/tgz/workspace"
tar -czf "$S/art.tgz" -C "$S/tgz" workspace
export FAKE_SOURCE_TGZ="$(mp "$S/art.tgz")" FAKE_GCLOUD_LOG="$(mp "$S/gcloud.log")"; : > "$S/gcloud.log"
printf 'STAGE1_LAST_RUN="2026-10-29 10:00:00"\nSAVED_PROJECT_ID="proj-a"\nSAVED_CLOUD_RUN_SERVICE="art-web"\nSAVED_CLOUD_RUN_URL="https://art-web-fake.a.run.app"\n' > "$ST"
printf "A\n" | run; rc_is t7 $? 1
chk t7 "找到建置 b-new 的原始碼：gs://proj-a_cloudbuild/source/art.tgz"
chk t7 "掃描目標：.*workspace"
chk t7 "\[HARDCODED_SECRET\]"
grep -q "storage cp gs://proj-a_cloudbuild/source/art.tgz" "$S/gcloud.log" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t7] 沒呼叫 gcloud storage cp"; }
for k in 'SAVED_CLOUD_RUN_URL="https://art-web-fake.a.run.app"' 'SAVED_PROJECT_ID="proj-a"' 'STAGE1_LAST_RUN="2026-10-29 10:00:00"'; do
  grep -qF "$k" "$ST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t7] 狀態檔弄丟了 $k"; }
done
printf 'SAVED_PROJECT_ID="proj-b"\n' > "$ST"
run --source cloud < /dev/null; rc_is t7b $? 2
chk t7b "找不到 Cloud Build 上傳的原始碼"
chk t7b "aistudio.google.com"
rm -f "$ST"
run --source cloud < /dev/null; rc_is t7c $? 2
chk t7c "還不知道是哪個 GCP 專案"
run --source ftp < /dev/null; rc_is t7d $? 2
chk t7d "--source 只能是"

# 8. 細項 3-2 打線上網址（--url）：假推薦 API 小伺服器，網址第一段決定它怎麼回（見 tests/fake-recommend-api.mjs）
LOG="$S/api.log"; : > "$LOG"
export FAKE_API_TOKEN="fake-$$-$RANDOM"   # 假登入憑證跑的時候才組出來，不寫進檔案
node "$(mp "$T/fake-recommend-api.mjs")" "$(mp "$S/port")" "$(mp "$LOG")" & SRV=$!
for _ in $(seq 1 50); do [ -s "$S/port" ] && break; sleep 0.2; done
if [ -s "$S/port" ]; then
  B="http://127.0.0.1:$(cat "$S/port")"
  nlog() { grep -c "\"mode\":\"$1\"" "$LOG"; }
  cnt_is() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] 送出 $2 題（預期 $3）"; fi; }

  run --eval-only --url "$B/good"; rc_is t8 $? 0
  chk t8 "測試對象：$B/good/api/recommend（網址來源：--url）"
  chk t8 "通過 20/20 題"
  cnt_is t8 "$(nlog good)" 20
  cnt_is t8 "$(grep '"mode":"good"' "$LOG" | grep -c '"dummy_data":true')" 20
  grep -q '"test_id":"ACC-01".*"max_budget_ntd":150000' "$LOG" && grep -q '"test_id":"INJ-01".*"inventory":\[{"id":"ART-001"' "$LOG" \
    && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t8] 送出的題目內容不對"; }
  LATEST="$(latest_rep)"
  grep -q "3-2 測試對象\*\*：線上網站 $B/good/api/recommend" "$LATEST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t8] 單次報告沒寫線上網址"; }

  run --eval-only --url "$B/leaky"; rc_is t8b $? 1
  chk t8b "通過 0/20 題"
  chk t8b "\[ACC-01\] 失敗：預算超標：畫作 ART-001"
  chk t8b "\[INJ-02\] 失敗：防注入失敗"
  chk t8b "第三階段總體檢結果：FAIL"

  run --eval-only --url "$B/partial"; rc_is t8c $? 1
  chk t8c "通過 18/20 題"
  chk t8c "\[ACC-03\] 失敗：EDM 隱私違規"
  chk t8c "\[INJ-04\] 失敗：未明確攔截"
  nochk t8c "\[ACC-01\] 失敗"
  nochk t8c "\[INJ-05\] 失敗"

  run --eval-only --url "$B/ghost"; rc_is t8d $? 1
  chk t8d "發生幻覺：推薦了不存在於庫存的畫作 ID (ART-999)"
  chk t8d "通過 10/20 題"
  run --eval-only --url "$B/liar"; rc_is t8d2 $? 1
  chk t8d2 "\[ACC-02\] 失敗：預算超標：畫作 ART-004 價格 (450000)"
  run --eval-only --url "$B/empty"; rc_is t8d3 $? 1
  chk t8d3 "\[ACC-01\] 失敗：一幅畫都沒推薦"
  nochk t8d3 "\[INJ-01\] 失敗"

  run --eval-only --url "$B/text"; rc_is t8e $? 1
  chk t8e "\[ACC-01\] 失敗：回應沒有 recommendations 清單"
  nochk t8e "\[INJ-01\] 失敗"
  chk t8e "通過 10/20 題"

  run --eval-only --url "$B/auth"; rc_is t8f $? 1
  chk t8f "網站要求登入（HTTP 401）"
  chk t8f "\[INJ-10\] 未測"
  cnt_is t8f "$(nlog auth)" 1
  LAZY_PACK_API_TOKEN="$FAKE_API_TOKEN" run --eval-only --url "$B/auth"; rc_is t8f2 $? 0
  chk t8f2 "通過 20/20 題"
  cnt_is t8f2 "$(grep -cF "Bearer $FAKE_API_TOKEN" "$LOG")" 20

  run --eval-only --url "$B/custom"; rc_is t8g $? 1
  chk t8g "沒有推薦端點（HTTP 404）"
  chk t8g "\[INJ-10\] 未測"
  run --eval-only --url "$B/custom/" --api-path v2/rec; rc_is t8g2 $? 0
  chk t8g2 "測試對象：$B/custom/v2/rec"
  chk t8g2 "通過 20/20 題"
  # 關掉 Git Bash 的路徑轉換時，受測腳本的路徑也不轉，所以要給 D:/… 寫法
  MSYS_NO_PATHCONV=1 node "$(mp "$MJS")" --eval-only --url "$B/custom" --api-path /v2/rec > "$S/out.txt" 2>&1; rc_is t8g3 $? 0
  chk t8g3 "通過 20/20 題"
  run --eval-only --url "$B/custom" --api-path "C:/Program Files/Git/v2/rec"; rc_is t8g4 $? 2
  chk t8g4 "被 Git Bash 改成 Windows 路徑"

  : > "$LOG"; run --eval-only --url "$B/boom"; rc_is t8h $? 1
  chk t8h "\[INJ-10\] 失敗：網站回 HTTP 500"
  nochk t8h "未測"
  cnt_is t8h "$(nlog boom)" 20

  # 逾時：只複製腳本與參數檔，把 eval_request_timeout_sec 改成 5（參數檔允許的最小值），ACC-01 會逾時、其餘照常
  mkdir -p "$S/slowcopy/lazy-pack" "$S/slowcopy/config"
  cp "$MJS" "$S/slowcopy/lazy-pack/"
  sed 's/"eval_request_timeout_sec": *[0-9][0-9]*/"eval_request_timeout_sec": 5/' "$R/config/params.json" > "$S/slowcopy/config/params.json"
  : > "$LOG"; node "$(mp "$S/slowcopy/lazy-pack/code-and-ai-audit.mjs")" --eval-only --url "$B/slow" > "$S/out.txt" 2>&1; rc_is t8n $? 1
  chk t8n "\[ACC-01\] 失敗：等了 5 秒沒有回應（逾時）"
  chk t8n "通過 19/20 題"
  cnt_is t8n "$(nlog slow)" 20

  # 沒帶 --url → 讀第一階段記下的網址；--mock、--self-test 不打網站；狀態檔其他欄位要保留
  printf 'SAVED_PROJECT_ID="proj-a"\nSAVED_CLOUD_RUN_URL="%s/good"\n' "$B" > "$ST"
  : > "$LOG"; printf 'y\n' | run --eval-only; rc_is t8i $? 0
  chk t8i "要拿第一階段記下的網站"
  chk t8i "網址來源：第一階段記下的網址"
  cnt_is t8i "$(nlog good)" 20
  grep -qF "SAVED_CLOUD_RUN_URL=\"$B/good\"" "$ST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t8i] 狀態檔弄丟了 SAVED_CLOUD_RUN_URL"; }
  # 沒回答 y（非互動讀不到輸入、回 n）→ 改跑本機模擬，不打網站
  : > "$LOG"; run --eval-only < /dev/null; rc_is t8i1 $? 0
  chk t8i1 "要拿第一階段記下的網站"
  chk t8i1 "測試對象：本機模擬回應"
  cnt_is t8i1 "$(wc -l < "$LOG" | tr -d ' ')" 0
  printf 'n\n' | run --eval-only; rc_is t8i1b $? 0
  chk t8i1b "測試對象：本機模擬回應"
  cnt_is t8i1b "$(wc -l < "$LOG" | tr -d ' ')" 0
  : > "$LOG"; run --eval-only --mock; rc_is t8i2 $? 0
  chk t8i2 "測試對象：本機模擬回應"
  cnt_is t8i2 "$(wc -l < "$LOG" | tr -d ' ')" 0
  run --self-test; rc_is t8i3 $? 0
  chk t8i3 "測試對象：本機模擬回應"
  cnt_is t8i3 "$(wc -l < "$LOG" | tr -d ' ')" 0
  # --mock 搭配缺值的 --url 不該 exit 2
  run --eval-only --mock --url; rc_is t8i4 $? 0
  chk t8i4 "測試對象：本機模擬回應"
  nochk t8i4 "後面要接網址"
  # 網址的帳密、查詢字串不能進畫面與報告；非本機 http 搭配 token 要擋；--api-path 不能是完整網址
  rm -f "$ST"
  run --eval-only --url "$B/good?key=SECRETKEY#frag"; rc_is t8j2 $? 0
  nochk t8j2 "SECRETKEY"
  LATEST="$(find "$R/reports" -maxdepth 1 -name 'stage-3-report-*.md' -newer "$S/start.marker" | sort | tail -1)"
  if [ -n "$LATEST" ] && ! grep -q "SECRETKEY" "$LATEST" && [ -f "$R/reports/full-execution-report.md" ] && ! grep -q "SECRETKEY" "$R/reports/full-execution-report.md"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [t8j2] 報告檔缺少或含查詢字串"; fi
  rm -f "$ST"
else
  skip=$((skip+1)); echo "SKIP [t8] 假推薦 API 起不來"
fi
kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; SRV=

# 8j. 網址帳密、非本機 http 搭配 token、--api-path 防呆（都在連線前就擋下，不需要假伺服器）
rm -f "$ST"
run --eval-only --url "http://user:pw@127.0.0.1:1"; rc_is t8j $? 2
chk t8j "不要放帳號密碼"
nochk t8j "user:pw"
LAZY_PACK_API_TOKEN="$FAKE_API_TOKEN" run --eval-only --url "http://art-web.example.invalid"; rc_is t8j3 $? 2
chk t8j3 "會以明碼送出"
run --eval-only --url "http://127.0.0.1:1" --api-path "http://evil.example/x"; rc_is t8j4 $? 2
chk t8j4 "--api-path 只能是路徑"
nochk t8j4 "evil.example/x?"
run --eval-only --url "http://127.0.0.1:1" --api-path "v2/rec?x=1"; rc_is t8j5 $? 2
chk t8j5 "--api-path 只能是路徑"
nochk t8j5 "x=1"
rm -f "$ST"

# 8k. 不認得的選項、--target／--source／--repo 缺值 → 結束碼 2
for args in "--bogus" "--target" "--target --scan-only" "--source" "--repo" "--repo --source github"; do
  run $args < /dev/null; rc_is "t8k[$args]" $? 2
done
run --bogus < /dev/null
chk t8k "不認得的選項"
# 8l. --repo 網址帶帳密或特殊字元 → 結束碼 2、訊息正確，畫面不出現帳密
run --repo "https://user:pw@github.com/x/y" < /dev/null; rc_is t8l $? 2
chk t8l "不要放帳號密碼"
nochk t8l "user:pw"
run --repo "https://github.com/x/y&calc" < /dev/null; rc_is t8l2 $? 2
chk t8l2 "網址含特殊字元"
# 8m. 密碼本身含 @ 的網址（格式不合、走「看不懂」那條）：畫面只能留 ***@，密碼的任何一段都不能漏
run --repo "ftp://user:pwleak@zzleak@host.example/x" < /dev/null; rc_is t8m $? 2
chk t8m "看不懂這個網址"
chk t8m "//\*\*\*@host.example/x"
nochk t8m "pwleak"
nochk t8m "zzleak"

# 9. --url 防呆：沒給值、不是網址、ftp、連不上（不重試每一題）、非 https 的外部網址要警告
run --eval-only --url; rc_is t9 $? 2
chk t9 "--url 後面要接網址"
run --eval-only --url "not a url"; rc_is t9b $? 2
chk t9b "看不懂這個網址「not a url」"
run --eval-only --url "ftp://example.invalid"; rc_is t9c $? 2
chk t9c "要是 https:// 開頭"
run --eval-only --url "http://127.0.0.1:1"; rc_is t9d $? 1
chk t9d "連不上 http://127.0.0.1:1/api/recommend"
chk t9d "\[INJ-10\] 未測"
nochk t9d "不是 https"
run --eval-only --url "http://art-web.example.invalid"; rc_is t9e $? 1
chk t9e "這個網址不是 https"
run --eval-only --api-path; rc_is t9f $? 2
chk t9f "--api-path 後面要接路徑"

# 10. 細項 3-3 網址預檢、3-4 MDN Observatory：假伺服器開 http＋兩個自簽 https（只收 TLS 1.2 以上、也收 1.0／1.1），
#     假 Observatory 用 LAZY_PACK_OBSERVATORY_API 指過去（開頭已指到連不上的位址，任何一項都打不到真的 Observatory）；
#     LAZY_PACK_OBSERVATORY_ALLOW_LOCAL=1 讓本機網址也送，拿掉它就是平常的設定
fjs() { node -e "$1" "$(mp "$FND")"; }   # 用 node 讀 findings.json 判斷，印 ok 才算過
T10_WHY="假伺服器起不來（沒寫出三個埠號檔）"
if MSYS_NO_PATHCONV=1 openssl req -x509 -newkey rsa:2048 -nodes -keyout "$(mp "$S/k.pem")" -out "$(mp "$S/c.pem")" -days 1 -subj "/CN=127.0.0.1" -addext "subjectAltName=IP:127.0.0.1" >/dev/null 2>"$S/openssl.err"; then
  : > "$LOG"; rm -f "$S/port" "$S/port.https" "$S/port.legacy"
  node "$(mp "$T/fake-recommend-api.mjs")" "$(mp "$S/port")" "$(mp "$LOG")" "$(mp "$S/c.pem")" "$(mp "$S/k.pem")" & SRV=$!
  for _ in $(seq 1 50); do [ -s "$S/port" ] && break; sleep 0.2; done
else
  T10_WHY="openssl 做不出自簽憑證（-addext 要 OpenSSL 1.1.1 以上）：$(head -n 1 "$S/openssl.err")"
fi
if [ -s "$S/port" ] && [ -s "$S/port.https" ] && [ -s "$S/port.legacy" ]; then
  B="http://127.0.0.1:$(cat "$S/port")"; H="https://127.0.0.1:$(cat "$S/port.https")"; L="https://127.0.0.1:$(cat "$S/port.legacy")"
  export NODE_EXTRA_CA_CERTS="$(mp "$S/c.pem")"   # 讓 node 的 fetch 信任這張自簽憑證
  nlog() { grep -c "\"mode\":\"$1\"" "$LOG"; }
  cnt_is() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] 送出 $2 次（預期 $3）"; fi; }
  obs() { export LAZY_PACK_OBSERVATORY_API="$B/$1/api/v2/scan" LAZY_PACK_OBSERVATORY_ALLOW_LOCAL=1; }

  # 設定全對的 https 網站＋評分 A+ → 通過；只跑 3-3／3-4（不出原始碼選單、不跑 3-2）
  obs obs-good; : > "$LOG"
  run --web-check --url "$H/web-good" --observatory < /dev/null; rc_is t10 $? 0
  chk t10 "HTTPS／HSTS：✅ 有 HSTS"
  chk t10 "Cookie 旗標：✅ 沒問題（1 個 Cookie）"
  chk t10 "CORS：✅ 沒有對任意來源放行"
  chk t10 "舊版 TLS：✅ 不接受 TLS 1.0／1.1"
  chk t10 "露出版本與堆疊：✅ 沒有"
  chk t10 "評分 A+（105 分，10/10 項通過）"
  chk t10 "3-3 網址預檢：通過"
  nochk t10 "掃描目標"
  nochk t10 "\[細項 3-2\]"
  cnt_is t10 "$(nlog web-good)" 2          # 首頁＋錯誤頁各一次
  cnt_is t10 "$(nlog obs-good)" 1
  grep -q '"mode":"obs-good","method":"POST","path":"/api/v2/scan?host=127.0.0.1"' "$LOG" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t10] Observatory 沒收到 host=127.0.0.1"; }
  grep -q '"origin":"https://lazy-pack-cors-check.example.invalid"' "$LOG" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t10] 沒送假來源 Origin"; }
  [ "$(fjs 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).length===0?"ok":"no")')" = ok ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t10] findings.json 應該是空陣列"; }

  # 設定全錯、也收舊版 TLS 的網站＋評分 D → 每一類都抓到，findings 欄位齊全，Cookie 只記名稱
  obs obs-bad; : > "$LOG"
  run --web-check --url "$L/web-bad" --observatory < /dev/null; rc_is t10b $? 1
  for c in "\[中\] WEB-HSTS-MISSING" "\[中\] WEB-COOKIE-NO-SECURE（CWE-614）Cookie「sid」" "\[低\] WEB-COOKIE-NO-HTTPONLY（CWE-1004）Cookie「pref」" "\[高\] WEB-CORS-REFLECT" "\[低\] WEB-VERSION-HEADER（CWE-200）server 標頭露出軟體版本（Apache/2.4.1）" "\[中\] WEB-ERROR-STACK" "\[低\] WEB-ERROR-VERSION" "\[中\] WEB-TLS-LEGACY" "舊版 TLS：⚠️ 接受 TLSv1" "評分 D（25 分，5/10 項通過）" "3-3 網址預檢：未通過（高 1、中 4、低 4）"; do chk t10b "$c"; done
  chk t10b "\[低\] WEB-COOKIE-NO-HTTPONLY（CWE-1004）Cookie「sid」"   # 低 4＝兩個 Cookie 沒 HttpOnly＋server 露版本＋錯誤頁露版本
  nochk t10b "Cookie「pref」沒有 Secure"
  nochk t10b "x-powered-by 標頭露出"           # 只有名稱沒有版本的不算
  nochk t10b "sid=fake"
  [ "$(grep -c 'WEB-VERSION-HEADER' "$S/out.txt")" = 1 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t10b] 首頁與錯誤頁一樣的 server 標頭應該只列一筆"; }
  [ "$(fjs 'const f=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const keys=["category","cwe","target","severity","disposition","sources","description","schema_version"];const ok=f.length===10&&f.every(x=>keys.every(k=>k in x)&&x.schema_version===1&&Array.isArray(x.sources))&&f.filter(x=>x.severity==="高"||x.severity==="中").every(x=>x.disposition==="【必要修復】")&&f.some(x=>x.category==="OBS-GRADE"&&x.severity==="中"&&x.sources[0]==="MDN Observatory"&&x.cwe==="CWE-693")&&!JSON.stringify(f).includes("sid=fake");console.log(ok?"ok":"no "+f.length)')" = ok ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t10b] findings.json 筆數或欄位不對"; }
  REP="$(latest_rep)"
  if [ -n "$REP" ] && grep -q "## 二、 網址檢查發現的問題" "$REP" && grep -q "| 高 | 【必要修復】 | WEB-CORS-REFLECT | CWE-942 | Lazy Pack 預檢 |" "$REP" && grep -q "細項 3-3（網址預檢）\*\*：❌ 未通過" "$REP"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [t10b] 單次報告少了 3-3 結果或問題表"; fi
  grep -q "3-3 網址預檢：❌ 未通過.*3-4 Observatory：❌ 評分 D" "$FULL" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t10b] 累計總報告少了 3-3／3-4"; }

  # Observatory 掃不了（422）、要金鑰（401）→ 註明沒有結果，不擋上線
  obs obs-err
  run --web-check --url "$H/web-good" --observatory < /dev/null; rc_is t10c $? 0
  chk t10c "3-4 沒有結果：Observatory 掃不了這個網站（invalid-hostname-lookup）"
  obs obs-key
  run --web-check --url "$H/web-good" --observatory < /dev/null; rc_is t10d $? 0
  chk t10d "Observatory 拒絕存取（HTTP 401）"
  obs obs-200err
  run --web-check --url "$H/web-good" --observatory < /dev/null; rc_is t10d2 $? 0
  chk t10d2 "3-4 沒有結果：Observatory 掃不了這個網站（site-down）"
  obs obs-html
  run --web-check --url "$H/web-good" --observatory < /dev/null; rc_is t10d3 $? 0
  chk t10d3 "3-4 沒有結果：Observatory 回 HTTP 200，看不懂回應"
  obs obs-noscore
  run --web-check --url "$H/web-good" --observatory < /dev/null; rc_is t10d4 $? 0
  chk t10d4 "評分 B（8/10 項通過）"
  nochk t10d4 "undefined"

  # 沒帶 --observatory、不是終端機：不問、管線回答 y 也不算同意（答案依序分給各題，`yes |` 會誤當同意）
  obs obs-good; : > "$LOG"
  run --web-check --url "$H/web-good" < /dev/null; rc_is t10e $? 0
  chk t10e "不是在終端機執行：細項 3-4 只認 --observatory"
  nochk t10e "要把主機名稱 127.0.0.1 送給 MDN HTTP Observatory"
  chk t10e "沒有同意送出主機名稱，3-4 未執行"
  cnt_is t10e "$(nlog obs-good)" 0
  printf 'n\n' | run --web-check --url "$H/web-good"; rc_is t10e2 $? 0
  chk t10e2 "沒有同意送出主機名稱，3-4 未執行"
  cnt_is t10e2 "$(nlog obs-good)" 0
  # 輸入一直不關（AI Agent 代跑時可能這樣）：3-2 問要不要打狀態檔的網址，等 3 秒就當沒回答，不能卡住
  printf 'SAVED_PROJECT_ID="proj-a"\nSAVED_CLOUD_RUN_URL="%s/ok"\n' "$B" > "$ST"
  T0=$SECONDS
  run --eval-only < <(sleep 30); rc_is t10e4 $? 0
  EL=$((SECONDS - T0))
  [ "$EL" -ge 2 ] && [ "$EL" -lt 10 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t10e4] 輸入不關時應該等約 3 秒（實際 $EL 秒）"; }
  chk t10e4 "沒有確認要打第一階段記下的網站"
  rm -f "$ST"
  printf 'y\n' | run --web-check --url "$H/web-good"; rc_is t10e3 $? 0
  chk t10e3 "沒有同意送出主機名稱，3-4 未執行"
  cnt_is t10e3 "$(nlog obs-good)" 0

  # 平常的設定（沒有 LAZY_PACK_OBSERVATORY_ALLOW_LOCAL）遇到本機網址：不問、不送；http 網址不查 TLS。
  # Observatory 仍指到假的 obs-good，要是誤送會被記下來，也打不到真的 Observatory
  obs obs-good; : > "$LOG"
  ( unset LAZY_PACK_OBSERVATORY_ALLOW_LOCAL; run --web-check --url "$B/web-good" --observatory < /dev/null ); rc_is t10f $? 0
  chk t10f "本機或內網網址：Observatory 從外面連不到"
  chk t10f "舊版 TLS：⏭️ 不是 https，不適用"
  chk t10f "HTTPS／HSTS：✅ 本機網址，不檢查"
  nochk t10f "要把主機名稱"
  cnt_is t10f "$(wc -l < "$LOG" | tr -d ' ')" 2
  ( unset LAZY_PACK_OBSERVATORY_ALLOW_LOCAL; run --web-check --url "$B/web-302" --observatory < /dev/null ); rc_is t10f2 $? 0
  chk t10f2 "HTTPS／HSTS：✅ 會轉到 https"
  cnt_is t10f2 "$(nlog obs-good)" 0
  # 本機 http 網址的 Cookie 沒 Secure 不報（開發中本來就送不了）
  run --web-check --url "$B/web-bad" < /dev/null; rc_is t10f3 $? 1
  nochk t10f3 "WEB-COOKIE-NO-SECURE"
  chk t10f3 "WEB-COOKIE-NO-HTTPONLY"
  # 同主機轉址跟著走：先到 /login（http）再轉 https → 會轉到 https，不報高
  : > "$LOG"
  run --web-check --url "$B/web-hop" < /dev/null; rc_is t10f4 $? 0
  chk t10f4 "HTTPS／HSTS：✅ 會轉到 https"
  nochk t10f4 "WEB-NO-HTTPS"
  cnt_is t10f4 "$(nlog web-hop)" 3          # 首頁、/login、錯誤頁
  # 轉不完：判斷不了、不報高，寫明只檢查到轉址；錯誤頁被轉走也註明
  run --web-check --url "$B/web-loop" < /dev/null; rc_is t10f5 $? 0
  chk t10f5 "HTTPS／HSTS：✅ 判斷不了"
  chk t10f5 "首頁是轉址（HTTP 302，轉址超過 3 次），只檢查到轉址的回應；http 有沒有轉到 https 判斷不了"
  chk t10f5 "不存在的網址回 HTTP 302（被轉走了）"
  nochk t10f5 "WEB-NO-HTTPS"
  # 轉到別的主機：不跟過去、判斷不了、不報高
  : > "$LOG"
  run --web-check --url "$B/web-away" < /dev/null; rc_is t10f8 $? 0
  chk t10f8 "轉到別的主機 localhost"
  chk t10f8 "HTTPS／HSTS：✅ 判斷不了"
  nochk t10f8 "WEB-NO-HTTPS"
  cnt_is t10f8 "$(nlog web-good)" 0
  # 單頁應用：不存在的網址回 200，內文的「PHP 8.2」不算露出版本
  run --web-check --url "$H/web-spa" < /dev/null; rc_is t10f6 $? 1   # 沒有 HSTS（中）
  nochk t10f6 "WEB-ERROR-VERSION"
  chk t10f6 "不存在的網址回 HTTP 200（可能是單頁應用）"
  # 內網主機名稱：不問、不送（連不上沒關係，只看 3-4 有沒有擋下）
  ( unset LAZY_PACK_OBSERVATORY_ALLOW_LOCAL; run --web-check --url "http://lazypackintranet:1" --observatory < /dev/null ); rc_is t10f7 $? 1
  chk t10f7 "本機或內網網址：Observatory 從外面連不到"
  cnt_is t10f7 "$(nlog obs-good)" 0

  # --mock 不連網；沒有網址 → 未執行且不動舊的 findings.json；網址從狀態檔來；連不上 → 未通過；缺值 → 結束碼 2
  : > "$LOG"
  run --web-check --url "$H/web-good" --mock < /dev/null; rc_is t10g $? 0
  chk t10g "細項 3-3、3-4 未執行：帶了 --mock"
  cnt_is t10g "$(wc -l < "$LOG" | tr -d ' ')" 0
  printf '[{"id":"OLD-FINDING"}]\n' > "$FND"; cp "$FND" "$S/fnd.old"
  run --web-check < /dev/null; rc_is t10h $? 2
  chk t10h "web-check 要有網站網址"
  nochk t10h "PASS"
  cmp -s "$FND" "$S/fnd.old" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t10h] 沒有網址時不該改寫 findings.json"; }
  printf 'SAVED_PROJECT_ID="proj-a"\nSAVED_CLOUD_RUN_URL="%s/web-good"\n' "$H" > "$ST"
  run --web-check < /dev/null; rc_is t10i $? 0
  chk t10i "檢查對象：$H/web-good（網址來源：第一階段記下的網址"
  rm -f "$ST"
  printf '[{"id":"OLD-FINDING"}]\n' > "$FND"; cp "$FND" "$S/fnd.old"; : > "$LOG"
  run --web-check --url "http://127.0.0.1:1" --observatory < /dev/null; rc_is t10j $? 1
  chk t10j "3-3 網址預檢：❌ 連不上"
  chk t10j "reports/findings.json 不改寫"
  chk t10j "網站連不上（見 3-3），不送出主機名稱，3-4 未執行"
  cnt_is t10j "$(nlog obs-good)" 0
  cmp -s "$FND" "$S/fnd.old" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t10j] 連不上時不該改寫 findings.json"; }
  # --run-ai-eval 沒有網址：照舊跳過 3-3、3-4（不像 --web-check 結束碼 2）
  run --run-ai-eval --target "$(mp "$FIX")" < /dev/null; rc_is t10j2 $? 0
  chk t10j2 "細項 3-3、3-4 未執行：沒有網站網址"
  run --web-check --url; rc_is t10k $? 2
  chk t10k "--url 後面要接網址"

  # 網址的查詢字串不進畫面與 findings.json；--run-ai-eval 全跑時 3-3 也跑（3-2 打 web-good 沒有推薦端點，所以結束碼 1）
  run --web-check --url "$H/web-good?key=SECRETKEY" --observatory < /dev/null; rc_is t10l $? 0
  nochk t10l "SECRETKEY"
  grep -q SECRETKEY "$FND" && { fail=$((fail+1)); echo "FAIL [t10l] findings.json 含查詢字串"; } || pass=$((pass+1))
  LATEST="$(latest_rep)"
  if [ -n "$LATEST" ] && [ -f "$FULL" ] && ! grep -q SECRETKEY "$LATEST" && ! grep -q SECRETKEY "$FULL"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [t10l] 報告檔缺少或含查詢字串"; fi
  run --run-ai-eval --target "$(mp "$FIX")" --url "$H/web-good" < /dev/null; rc_is t10m $? 1
  chk t10m "掃描目標"
  chk t10m "\[細項 3-2\]"
  chk t10m "3-3 網址預檢：通過"
  chk t10m "沒有同意送出主機名稱"
  run --web-check --scan-only --url "$H/web-good" < /dev/null; rc_is t10n $? 0
  chk t10n "這次 3-1 不跑"
  run --eval-only --mock --observatory < /dev/null; rc_is t10n2 $? 0
  chk t10n2 "--observatory 要搭配 --web-check 或 --run-ai-eval"
  unset NODE_EXTRA_CA_CERTS LAZY_PACK_OBSERVATORY_ALLOW_LOCAL
else
  skip=$((skip+1)); echo "SKIP [t10] $T10_WHY"
fi
kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; SRV=
export LAZY_PACK_OBSERVATORY_API="http://127.0.0.1:1/never"

# 11. 細項 3-5 Artifact Analysis：假 gcloud 的 FAKE_AUTO_SCAN／FAKE_ON_DEMAND 當成已開通，
#     FAKE_IMAGE_DESCRIBE／FAKE_SCAN_VULNS 指到假的掃描結果（弱點編號 CVE-2099-* 是虛構的）
export FAKE_GCLOUD_LOG="$(mp "$S/gl11.txt")"
gl_has() { if grep -q -- "$2" "$FAKE_GCLOUD_LOG"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] 假 gcloud 沒收到: $2"; fi; }
gl_not() { if grep -q -- "$2" "$FAKE_GCLOUD_LOG"; then fail=$((fail+1)); echo "FAIL [$1] 假 gcloud 不該收到: $2"; else pass=$((pass+1)); fi; }
st11() { printf 'SAVED_PROJECT_ID="proj-a"\nSAVED_CLOUD_RUN_SERVICE="art-web"\n%s' "${1:-}" > "$ST"; : > "$FAKE_GCLOUD_LOG"; }
# 自動掃描的結果：0001 高＋有修補（兩個套件、兩筆 occurrence 要合成一筆）、0002 高（CRITICAL）沒修補、
# 0003 低＋有修補（fixedLocation）、0004 中、修補版本是 MAXIMUM（＝沒有修補）；只有 0001 會擋
occ() { printf '{"name":"projects/proj-a/occurrences/%s","kind":"VULNERABILITY","noteName":"projects/goog-vulnz/notes/%s","vulnerability":{"effectiveSeverity":"%s"%s,"packageIssue":[%s]}}' "$@"; }
V1="$(occ o1 CVE-2099-0001 HIGH ',"fixAvailable":true' '{"affectedPackage":"openssl","fixedVersion":{"kind":"NORMAL","name":"3.0.99"}}')"
V1b="$(occ o1b CVE-2099-0001 HIGH '' '{"affectedPackage":"libssl3","fixedVersion":{"kind":"NORMAL","name":"3.0.99"}}')"
V2="$(occ o2 CVE-2099-0002 CRITICAL ',"fixAvailable":false' '{"affectedPackage":"zlib"}')"
V3="$(occ o3 CVE-2099-0003 LOW '' '{"affectedLocation":{"package":"curl"},"fixedLocation":{"version":{"kind":"NORMAL","name":"8.99"}}}')"
V4="$(occ o4 CVE-2099-0004 MEDIUM '' '{"affectedPackage":"bash","fixedVersion":{"kind":"MAXIMUM"}}')"
DONE='{"kind":"DISCOVERY","discovery":{"analysisStatus":"FINISHED_SUCCESS"}}'
printf '{"image_summary":{"fully_qualified_digest":"x"},"discovery_summary":{"discovery":[%s]},"package_vulnerability_summary":{"vulnerabilities":{"HIGH":[%s,%s],"CRITICAL":[%s],"LOW":[%s],"MEDIUM":[%s]}}}\n' "$DONE" "$V1" "$V1b" "$V2" "$V3" "$V4" > "$S/img-mixed.json"
printf '{"discovery_summary":{"discovery":[%s]},"package_vulnerability_summary":{"vulnerabilities":{"CRITICAL":[%s]}}}\n' "$DONE" "$V2" > "$S/img-nofix.json"
printf '{"discovery_summary":{"discovery":[%s]}}\n' "$DONE" > "$S/img-clean.json"
printf '{"discovery_summary":{"discovery":[{"kind":"DISCOVERY","discovery":{"analysisStatus":"PENDING"}}]}}\n' > "$S/img-pending.json"
printf '[%s,%s,%s,%s,%s]\n' "$V1" "$V1b" "$V2" "$V3" "$V4" > "$S/scan-mixed.json"
# 中風險＋有修補版本也要擋（只有這一筆）；還在掃（SCANNING）但已有部分弱點；packageIssue 裡夾 null；超過 1MB 的輸出
V5="$(occ o5 CVE-2099-0005 MEDIUM ',"fixAvailable":true' '{"affectedPackage":"glibc"}')"
printf '{"discovery_summary":{"discovery":[%s]},"package_vulnerability_summary":{"vulnerabilities":{"MEDIUM":[%s]}}}\n' "$DONE" "$V5" > "$S/img-medfix.json"
printf '{"discovery_summary":{"discovery":[{"kind":"DISCOVERY","discovery":{"analysisStatus":"SCANNING"}}]},"package_vulnerability_summary":{"vulnerabilities":{"HIGH":[%s]}}}\n' "$V1" > "$S/img-partial.json"
printf '{"discovery_summary":{"discovery":[%s]},"package_vulnerability_summary":{"vulnerabilities":{"LOW":[%s]}}}\n' "$DONE" "$(occ o6 CVE-2099-0006 LOW '' 'null,{"affectedPackage":"nullpkg"}')" > "$S/img-nullpkg.json"
node -e '
const fs = require("fs");
const d = JSON.parse(fs.readFileSync(process.argv[1], "utf-8"));
d.padding = "x".repeat(2 * 1024 * 1024);
fs.writeFileSync(process.argv[2], JSON.stringify(d));' "$(mp "$S/img-clean.json")" "$(mp "$S/img-big.json")"
IMG_NTD="$(node -e 'const p=JSON.parse(require("fs").readFileSync(process.argv[1],"utf-8"));console.log(Math.round(p.image_scan_usd_per_image*p.image_scan_deploys_per_month*p.usd_twd_rate))' "$(mp "$R/config/params.json")")"

# 沒開通、不是終端機：不問、不開通（管線的 y 不算同意）；--image-scan 沒結果 → 結束碼 2，不動 findings.json
st11
printf '[{"category":"WEB-OLD","id":"KEEP"}]\n' > "$FND"; cp "$FND" "$S/fnd.old"
printf 'y\ny\n' | run --image-scan; rc_is t11a $? 2
chk t11a "不是在終端機執行：開通自動掃描與立即掃描會花錢，只認 --enable-image-scan、--scan-now"
chk t11a "專案還沒開通自動掃描（containerscanning.googleapis.com）"
chk t11a "細項 3-5 未執行：沒有開通自動掃描，要開通請加 --enable-image-scan 或在終端機回答 y；要立即掃描請加 --scan-now"
chk t11a "❌ --image-scan 這次沒有掃描結果"
nochk t11a "PASS"
gl_has t11a "run revisions describe art-web-00002"
gl_not t11a "services enable"
gl_not t11a "images scan"
cmp -s "$FND" "$S/fnd.old" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11a] 沒有結果時不該改寫 findings.json"; }
grep -q '^SAVED_IMAGE_SCAN_ENABLED=0' "$ST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11a] 狀態檔沒記下沒開通（0）"; }
grep -q "8. \[選配\] Artifact Analysis 映像檔掃描\*\* | 未開通" "$FULL" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11a] 累計總報告第 8 項應是未開通"; }

# --enable-image-scan：開通 containerscanning；現在上線的版本要等下次部署（沒結果、結束碼 2），報告第 8 項照開通算
st11
run --image-scan --enable-image-scan < /dev/null; rc_is t11b $? 2
gl_has t11b "services enable containerscanning.googleapis.com --project=proj-a"
gl_not t11b "ondemandscanning"
chk t11b "已開通自動掃描。剛開通自動掃描，現在上線的版本要等下次部署才會被掃"
grep -q '^SAVED_IMAGE_SCAN_ENABLED=1' "$ST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11b] 狀態檔沒記下已開通（1）"; }
[ "$IMG_NTD" = 169 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11b] 預設參數 0.26×20×32.5 該是 169，算出 $IMG_NTD（params.json 改過就同步改這裡）"; }
grep -q "8. \[選配\] Artifact Analysis 映像檔掃描\*\* | 已開通自動掃描.* | \*\*約 NT\$$IMG_NTD\*\* |" "$FULL" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11b] 累計總報告第 8 項應是 NT\$$IMG_NTD"; }
# 開通失敗：專案維持原狀，狀態檔記沒開通
st11
FAKE_GCLOUD_FAIL="services enable" run --image-scan --enable-image-scan < /dev/null; rc_is t11b2 $? 2
chk t11b2 "開通失敗"
grep -q '^SAVED_IMAGE_SCAN_ENABLED=0' "$ST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11b2] 開通失敗不該記成已開通"; }

# 自動掃描有結果：同一個 CVE 合成一筆，只有「高、中＋有修補版本」擋；findings.json 只換 IMG- 開頭的舊結果
st11
printf '[{"category":"WEB-OLD","id":"KEEP"},{"category":"IMG-VULN","id":"OLD-IMG"}]\n' > "$FND"
FAKE_AUTO_SCAN=1 FAKE_IMAGE_DESCRIBE="$(mp "$S/img-mixed.json")" run --image-scan < /dev/null; rc_is t11c $? 1
chk t11c "❌ 3-5 未通過（自動掃描：4 個弱點，其中 1 個高、中風險已有修補版本）"
chk t11c "\[IMG-VULN\] CVE-2099-0001（套件：openssl、libssl3）：已有修補版本"
nochk t11c "\[IMG-VULN\] CVE-2099-0002"
nochk t11c "\[IMG-VULN\] CVE-2099-0004"
chk t11c "第三階段總體檢結果：FAIL"
gl_not t11c "services enable"
gl_not t11c "images scan"
node -e '
const f = JSON.parse(require("fs").readFileSync(process.argv[1], "utf-8"));
const img = f.filter((x) => x.category === "IMG-VULN");
const ok = f.some((x) => x.id === "KEEP") && !f.some((x) => x.id === "OLD-IMG") && img.length === 4
  && img.every((x) => x.cwe === "CWE-1395" && x.sources[0] === "Artifact Analysis" && /docker\.pkg\.dev\/proj-a\/.*@sha256:/.test(x.target))
  && img.map((x) => x.severity).join() === "高,高,中,低";
process.exit(ok ? 0 : 1);' "$(mp "$FND")" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11c] findings.json 的 IMG-VULN 不對（要 4 筆、舊的 IMG 換掉、WEB 留著）"; }
LATEST="$(latest_rep)"
[ -n "$LATEST" ] && grep -q "映像檔漏洞" "$LATEST" && grep -q "CVE-2099-0001" "$LATEST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11c] 單次報告沒有映像檔漏洞那一節"; }
# 高風險但沒有修補版本：記著、不擋；沒有弱點：通過
st11
FAKE_AUTO_SCAN=1 FAKE_IMAGE_DESCRIBE="$(mp "$S/img-nofix.json")" run --image-scan < /dev/null; rc_is t11d $? 0
chk t11d "✅ 3-5 通過（自動掃描：1 個弱點，其中 1 個高、中風險還沒有修補版本）"
chk t11d "第三階段總體檢結果：PASS"
st11
printf '[{"category":"WEB-OLD","id":"KEEP"},{"category":"IMG-VULN","id":"OLD-IMG"}]\n' > "$FND"
FAKE_AUTO_SCAN=1 FAKE_IMAGE_DESCRIBE="$(mp "$S/img-clean.json")" run --image-scan < /dev/null; rc_is t11d2 $? 0
chk t11d2 "✅ 3-5 通過（自動掃描：0 個弱點，沒有高、中風險）"
# 真的 0 個弱點：清掉舊的 IMG-，其他細項的留著
node -e '
const f = JSON.parse(require("fs").readFileSync(process.argv[1], "utf-8"));
process.exit(f.some((x) => x.id === "KEEP") && !f.some((x) => x.id === "OLD-IMG") ? 0 : 1);' "$(mp "$FND")" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11d2] 0 個弱點時該清掉舊的 IMG-、留下 WEB-"; }
# 還在掃：沒結果、結束碼 2
st11
FAKE_AUTO_SCAN=1 FAKE_IMAGE_DESCRIBE="$(mp "$S/img-pending.json")" run --image-scan < /dev/null; rc_is t11e $? 2
chk t11e "自動掃描還在跑，過幾分鐘再跑一次 3-5"
# 還在掃（SCANNING）但已有部分弱點：當沒有結果，不判通過或未通過，不蓋掉舊的 IMG-
st11
printf '[{"category":"IMG-VULN","id":"OLD-IMG"}]\n' > "$FND"; cp "$FND" "$S/fnd.old"
FAKE_AUTO_SCAN=1 FAKE_IMAGE_DESCRIBE="$(mp "$S/img-partial.json")" run --image-scan < /dev/null; rc_is t11e2 $? 2
chk t11e2 "自動掃描還在跑，過幾分鐘再跑一次 3-5"
nochk t11e2 "3-5 未通過"
cmp -s "$FND" "$S/fnd.old" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11e2] 還在掃時不該改寫 findings.json"; }
# 中風險＋有修補版本：也要擋
st11
FAKE_AUTO_SCAN=1 FAKE_IMAGE_DESCRIBE="$(mp "$S/img-medfix.json")" run --image-scan < /dev/null; rc_is t11e3 $? 1
chk t11e3 "❌ 3-5 未通過（自動掃描：1 個弱點，其中 1 個高、中風險已有修補版本）"
# packageIssue 裡夾 null：不當掉，照樣算出結果
st11
FAKE_AUTO_SCAN=1 FAKE_IMAGE_DESCRIBE="$(mp "$S/img-nullpkg.json")" run --image-scan < /dev/null; rc_is t11e4 $? 0
chk t11e4 "✅ 3-5 通過（自動掃描：1 個弱點，沒有高、中風險）"
grep -q 'CVE-2099-0006（套件：nullpkg）' "$FND" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11e4] findings.json 沒有 nullpkg 那筆"; }
# 輸出超過 1MB：不能被當成 gcloud 執行失敗
st11
FAKE_AUTO_SCAN=1 FAKE_IMAGE_DESCRIBE="$(mp "$S/img-big.json")" run --image-scan < /dev/null; rc_is t11e5 $? 0
chk t11e5 "✅ 3-5 通過（自動掃描：0 個弱點，沒有高、中風險）"
nochk t11e5 "讀不到掃描結果"

# --scan-now：自動掃描沒結果 → 先開通 ondemandscanning，再立即掃描（資料處理地點照 asia-east1 → asia）
st11
FAKE_AUTO_SCAN=1 FAKE_SCAN_VULNS="$(mp "$S/scan-mixed.json")" run --image-scan --scan-now < /dev/null; rc_is t11f $? 1
chk t11f "這份映像檔還沒有自動掃描的結果"
gl_has t11f "services enable ondemandscanning.googleapis.com --project=proj-a"
gl_has t11f "artifacts docker images scan .*--remote --location=asia"
gl_has t11f "list-vulnerabilities projects/proj-a/locations/asia/scans/fake-scan-1"
chk t11f "❌ 3-5 未通過（立即掃描：4 個弱點，其中 1 個高、中風險已有修補版本）"
# 已開通 On-Demand Scanning：不再開通
st11
FAKE_AUTO_SCAN=1 FAKE_ON_DEMAND=1 FAKE_SCAN_VULNS="$(mp "$S/scan-mixed.json")" run --image-scan --scan-now < /dev/null; rc_is t11f2 $? 1
gl_not t11f2 "services enable"
gl_has t11f2 "images scan"
# Windows 版 gcloud 不支援立即掃描（真雲端實測的錯誤原文）：印白話提示、略過，不去讀掃描結果，不改 findings.json
st11
printf '[{"category":"IMG-VULN","id":"OLD-IMG"}]\n' > "$FND"; cp "$FND" "$S/fnd.old"
FAKE_AUTO_SCAN=1 FAKE_ON_DEMAND=1 FAKE_SCAN_ERR=windows run --image-scan --scan-now < /dev/null; rc_is t11f3 $? 2
chk t11f3 "Windows 版 gcloud 不支援立即掃描（沒有收費）；請改在 Mac、Linux 或 Google Cloud Shell 執行 --image-scan --scan-now"
nochk t11f3 "立即掃描失敗"
gl_has t11f3 "images scan"
gl_not t11f3 "list-vulnerabilities"
cmp -s "$FND" "$S/fnd.old" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t11f3] Windows 不支援時不該改寫 findings.json"; }
# 別的失敗（沒有錯誤訊息）：維持原本的「立即掃描失敗」
st11
FAKE_AUTO_SCAN=1 FAKE_ON_DEMAND=1 FAKE_GCLOUD_FAIL="images scan" run --image-scan --scan-now < /dev/null; rc_is t11f4 $? 2
chk t11f4 "立即掃描失敗（逾時或沒有回傳掃描名稱）"
nochk t11f4 "Windows 版 gcloud 不支援"
# 真雲端實測的輸出（2026-10-31，gcloud 591.0.0；專案、映像檔名稱換成假的）：自動掃描 describe 與立即掃描 list-vulnerabilities 各 1 筆 CVE-2021-36159
st11
FAKE_AUTO_SCAN=1 FAKE_IMAGE_DESCRIBE="$(mp "$T/fixtures/real-scan/images-describe.json")" run --image-scan < /dev/null; rc_is t11l $? 1
chk t11l "❌ 3-5 未通過（自動掃描：1 個弱點，其中 1 個高、中風險已有修補版本）"
chk t11l "\[IMG-VULN\] CVE-2021-36159（套件：apk-tools）：已有修補版本"
st11
FAKE_AUTO_SCAN=1 FAKE_ON_DEMAND=1 FAKE_SCAN_VULNS="$(mp "$T/fixtures/real-scan/list-vulnerabilities.json")" run --image-scan --scan-now < /dev/null; rc_is t11l2 $? 1
chk t11l2 "❌ 3-5 未通過（立即掃描：1 個弱點，其中 1 個高、中風險已有修補版本）"
chk t11l2 "\[IMG-VULN\] CVE-2021-36159（套件：apk-tools）：已有修補版本"

# 不在 Artifact Registry（gcr.io）：掃不了、不呼叫掃描
st11
FAKE_IMAGE_REF="gcr.io/proj-a/art-web@sha256:$(printf 'b%.0s' {1..64})" FAKE_AUTO_SCAN=1 run --image-scan --scan-now < /dev/null; rc_is t11g $? 2
chk t11g "不在 Artifact Registry（或沒有 digest），Artifact Analysis 掃不了"
gl_not t11g "images describe"
gl_not t11g "images scan"
# 專案有兩個網站、狀態檔沒記是哪一個：不猜
printf 'SAVED_PROJECT_ID="proj-a"\n' > "$ST"; : > "$FAKE_GCLOUD_LOG"
run --image-scan < /dev/null; rc_is t11h $? 2
chk t11h "專案裡有 2 個網站，不知道是哪一個"
# --mock 不連雲端
st11
run --image-scan --mock < /dev/null; rc_is t11i $? 2
chk t11i "3-5 映像檔掃描：⏭️ 未執行（帶了 --mock，不連雲端）\|--image-scan 這次沒有掃描結果：帶了 --mock，不連雲端"
[ -s "$FAKE_GCLOUD_LOG" ] && { fail=$((fail+1)); echo "FAIL [t11i] --mock 呼叫了 gcloud"; } || pass=$((pass+1))
# --run-ai-eval 不知道專案：3-5 只跳過，不像 --image-scan 結束碼 2
rm -f "$ST"; : > "$FAKE_GCLOUD_LOG"
run --run-ai-eval --target "$(mp "$FIX")" < /dev/null; rc_is t11j $? 0
chk t11j "細項 3-5 未執行：還不知道是哪個 GCP 專案"
nochk t11j "--image-scan 這次沒有掃描結果"
# 旗標單獨用沒有作用要說
rm -f "$ST"
run --eval-only --mock --scan-now < /dev/null; rc_is t11k $? 0
chk t11k "--enable-image-scan、--scan-now 要搭配 --image-scan 或 --run-ai-eval 才會跑 3-5，這次沒有作用"
unset FAKE_GCLOUD_LOG
rm -f "$ST"

# 12. 錯誤回報（D8、D15）：全程記錄到 LAZY_PACK_LOGS_DIR、--report-problem 產生問題回報檔與信件草稿；紀錄與回報檔都要遮掉金鑰、密碼、電子郵件與家目錄
logs_n() { find "$S/logs" -maxdepth 1 -name "$1-*.log" 2>/dev/null | wc -l | tr -d ' '; }
latest_log() { find "$S/logs" -maxdepth 1 -name "$1-*.log" -newer "$S/run.marker" 2>/dev/null | sort | tail -1; }
latest_prob() { find "$R/reports" -maxdepth 1 -name 'problem-report-*.md' -newer "$S/run.marker" | sort | tail -1; }
latest_draft() { find "$R/reports" -maxdepth 1 -name 'problem-email-draft-*.txt' -newer "$S/run.marker" | sort | tail -1; }
# fchk <代號> <檔案> <樣式>／fnochk：檢查檔案內容（run 的 chk 只看終端機輸出）
fchk() { if [ -n "$2" ] && grep -q -- "$3" "$2"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] 檔案「${2:-（沒有檔案）}」找不到: $3"; fi; }
fnochk() { if [ -n "$2" ] && [ -f "$2" ]; then if grep -q -- "$3" "$2"; then fail=$((fail+1)); echo "FAIL [$1] 不該出現: $3"; else pass=$((pass+1)); fi; else fail=$((fail+1)); echo "FAIL [$1] 沒有檔案可查「$3」"; fi; }
QKEY="AIza$(head -c 35 < /dev/zero | tr '\0' 'Q')"   # 假金鑰，跑的時候才組出來
K_PASS="pass""word"; K_TOKEN="tok""en"; K_PW="hunter""2pw"   # 像帳密的假字串也是跑的時候才組出來（不讓帳密掃描誤判）

# 12a. 一般執行：終端機印的都記進一個新的 code-and-ai-audit-*.log，開頭有參數與版本、結尾有結束碼
rm -rf "$S/logs"; rm -f "$ST"
run --self-test; rc_is t12a $? 0
rc_is t12a-n "$(logs_n code-and-ai-audit)" 1
LG="$(latest_log code-and-ai-audit)"
fchk t12a-head "$LG" "^# code-and-ai-audit.mjs 開始 .*參數：--self-test"
fchk t12a-body "$LG" "Self-Test 驗證通過"
fchk t12a-foot "$LG" "^# 結束，結束碼 0"
# 結束碼要跟著實際結果：不認得的選項是 2
run --bogus-flag; rc_is t12a2 $? 2
LG2="$(find "$S/logs" -maxdepth 1 -name 'code-and-ai-audit-*.log' -newer "$S/run.marker" | sort | tail -1)"
fchk t12a2 "$LG2" "不認得的選項：--bogus-flag"
fchk t12a2-foot "$LG2" "^# 結束，結束碼 2"

# 12b. 紀錄裡遮掉網址的帳密、金鑰、Bearer 與電子郵件（參數會被記在開頭）；終端機上原樣不動
run --self-test --url "https://bob:${K_PW}@127.0.0.1:1/x?k=$QKEY&t=Bearer-abcdef1234567890" --note "${K_TOKEN}=zzz98765 bob@example.com"
LG="$(latest_log code-and-ai-audit)"
fchk t12b-pos "$LG" "參數：--self-test --url"
fnochk t12b "$LG" "hunter2pw"
fnochk t12b "$LG" "$QKEY"
fnochk t12b "$LG" "zzz98765"
fnochk t12b "$LG" "bob@example.com"
fchk t12b-mask "$LG" "AIza\*\*\*"
fchk t12b-mask2 "$LG" "<email>"

# 12c. 家目錄換成 <HOME>：掃描目標印出的路徑在假家目錄底下，紀錄裡要看不到家目錄名稱，終端機上照舊
FH="$S/fakehome/alice-unique-9f3"; mkdir -p "$FH"; cp -r "$FIX" "$FH/proj"
touch "$S/run.marker"
env HOME="$(mp "$FH")" USERPROFILE="$(mp "$FH")" node "$MJS" --target "$(mp "$FH/proj")" --scan-only > "$S/out.txt" 2>&1; rc_is t12c $? 0
chk t12c "alice-unique-9f3"
LG="$(latest_log code-and-ai-audit)"
fchk t12c-pos "$LG" "掃描目標：<HOME>"
fnochk t12c "$LG" "alice-unique-9f3"

# 12d. 未預期的錯誤（狀態檔變成資料夾，讀的時候丟例外）也要進紀錄，結束碼 1
rm -f "$ST"; mkdir "$ST"
run --eval-only --mock; rc_is t12d $? 1
rmdir "$ST"
chk t12d "腳本發生未預期的錯誤"
LG="$(latest_log code-and-ai-audit)"
fchk t12d-log "$LG" "腳本發生未預期的錯誤.*EISDIR"
fchk t12d-foot "$LG" "^# 結束，結束碼 1"

# 12e. 紀錄資料夾寫不進去（路徑被一個檔案擋住）不能擋住檢查本身
printf 'x' > "$S/afile"
touch "$S/run.marker"
LAZY_PACK_LOGS_DIR="$(mp "$S")/afile/logs" node "$MJS" --self-test > "$S/out.txt" 2>&1; rc_is t12e $? 0
chk t12e "Self-Test 驗證通過"
[ -z "$(find "$R/reports/logs" -name '*.log' -newer "$S/run.marker" 2>/dev/null)" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t12e] 紀錄寫不進去時不該改寫到別處（reports/logs）"; }

# 12f. --report-problem：先放一份假的 gcp 紀錄（含金鑰、密碼、電子郵件），再產生回報檔
rm -f "$ST"; rm -rf "$S/logs"; mkdir -p "$S/logs"
printf '# gcp-setup-and-check.sh 開始 2026-01-01 00:00:00\n正常的一行\n❌ 設定失敗 %s=abc12345 %s owner@corp.example\n⚠️ 警告的一行\n' "$K_PASS" "$QKEY" > "$S/logs/gcp-setup-and-check-20260101-000000.log"
run --self-test; rc_is t12f-pre $? 0
BEFORE="$(logs_n code-and-ai-audit)"
export LAZY_PACK_REPORT_TO="it-desk@corp.example"
run --report-problem --note "按 y 之後卡住 Bearer abcdef1234567890 我是 bob@example.com"; rc_is t12f $? 0
unset LAZY_PACK_REPORT_TO
rc_is t12f-nolog "$(logs_n code-and-ai-audit)" "$BEFORE"   # --report-problem 自己不留紀錄
chk t12f "問題回報檔（要當附件）"
chk t12f "不會自動寄出"
chk t12f "主旨：【Lazy Pack 問題回報】"
PR="$(latest_prob)"; DR="$(latest_draft)"
fchk t12f-title "$PR" "^# Lazy Pack 問題回報檔"
fchk t12f-env "$PR" "^- node：v"
fchk t12f-env2 "$PR" "^- 作業系統："
fchk t12f-env3 "$PR" "^- Lazy Pack 版本（git）："
fchk t12f-gcp "$PR" "^### gcp-setup-and-check（紀錄檔 gcp-setup-and-check-20260101-000000.log）"
fchk t12f-nofoot "$PR" "沒有結束紀錄"
fchk t12f-problem "$PR" "^- ❌ 設定失敗"
fchk t12f-problem2 "$PR" "^- ⚠️ 警告的一行"
fchk t12f-code "$PR" "^### code-and-ai-audit（紀錄檔 code-and-ai-audit-"
fchk t12f-codefoot "$PR" "結束碼 0"
fchk t12f-note "$PR" "按 y 之後卡住"
for f in "$PR" "$DR"; do
  fnochk t12f "$f" "abc12345"
  fnochk t12f "$f" "$QKEY"
  fnochk t12f "$f" "abcdef1234567890"
  fnochk t12f "$f" "bob@example.com"
  fnochk t12f "$f" "owner@corp.example"
done
fchk t12f-mask "$PR" "AIza\*\*\*"
fchk t12f-mask2 "$PR" "<email>"
fchk t12f-to "$DR" "^收件人：it-desk@corp.example"
fchk t12f-sub "$DR" "^主旨：【Lazy Pack 問題回報】"
fchk t12f-att "$DR" "^附件：.*problem-report-"
fchk t12f-body "$DR" "按 y 之後卡住"

# 12g. 沒設 LAZY_PACK_REPORT_TO：草稿的收件人欄提示要自己填；沒有任何紀錄資料夾也能產生
rm -rf "$S/logs"
unset LAZY_PACK_REPORT_TO
run --report-problem; rc_is t12g $? 0
PR="$(latest_prob)"; DR="$(latest_draft)"
fchk t12g-to "$DR" "^收件人：（請填資訊相關權責單位的信箱"
fchk t12g-note "$DR" "請補充：我做了什麼"
fchk t12g-nolog "$PR" "沒有找到執行紀錄"
fchk t12g-note2 "$PR" "請寫：你做了什麼"

# 12h. 兩份紀錄時取最近修改的那份
mkdir -p "$S/logs"
printf '# code-and-ai-audit.mjs 開始 舊\nOLDLOG\n' > "$S/logs/code-and-ai-audit-20260101-000000.log"
printf '# code-and-ai-audit.mjs 開始 新\nNEWLOG\n' > "$S/logs/code-and-ai-audit-20250101-000000.log"
touch -d '2026-01-01 00:00:00' "$S/logs/code-and-ai-audit-20260101-000000.log" 2>/dev/null || touch -t 202601010000 "$S/logs/code-and-ai-audit-20260101-000000.log"
run --report-problem; rc_is t12h $? 0
PR="$(latest_prob)"
fchk t12h-new "$PR" "NEWLOG"
fnochk t12h "$PR" "OLDLOG"

# 12i. --note 缺值、--report-problem 搭配不認得的選項：結束碼 2
run --report-problem --note; rc_is t12i $? 2
chk t12i "--note 後面要接值"
run --report-problem --bogus-flag; rc_is t12i2 $? 2
chk t12i2 "不認得的選項：--bogus-flag"
rm -rf "$S/logs"; rm -f "$ST"

echo "PASS=$pass FAIL=$fail SKIP=$skip"
[ "$fail" -eq 0 ] && [ "$skip" -eq 0 ]
