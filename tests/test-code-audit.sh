#!/usr/bin/env bash
# code-and-ai-audit.mjs 自動測試：--target 防呆與三種原始碼來源（假 gcloud、本機假 git repo、假 ZIP），不連雲端、不花錢
# 用法：bash tests/test-code-audit.sh（結果暫存寫到系統暫存資料夾，跑完還原 reports/ 狀態檔）
T="$(cd -P "$(dirname "$0")" && pwd -P)"
S="$(mktemp -d)"; [ -n "$S" ] && [ -d "$S" ] || exit 2
cp -r "$T/fakebin" "$S/fakebin"
R="${R_UNDER_TEST:-$(cd -P "$T/.." && pwd -P)}"
MJS="$R/lazy-pack/code-and-ai-audit.mjs"
ST="$R/reports/.lazy-pack-state.env"
FIX="$T/fixtures/fake-nextjs-app"
mkdir -p "$R/reports"
[ -f "$ST" ] && cp "$ST" "$S/state.bak"
rm -f "$ST"   # 使用者狀態檔裡的真網址不能讓 3-2 測試打出去
unset LAZY_PACK_API_TOKEN
chmod +x "$S/fakebin/gcloud"
export PATH="$S/fakebin:$PATH"
# 給 node 與它叫起來的程式的路徑一律用 D:/… 寫法（Windows）；別的系統原樣
mp() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
DL=':'; command -v cygpath >/dev/null 2>&1 && DL=';'
export LAZY_PACK_SOURCES_DIR="$(mp "$S/sources")"
export LAZY_PACK_SEARCH_DIRS="$(mp "$S/none")"
export GIT_CONFIG_GLOBAL="$S/empty.gitconfig" GIT_CONFIG_NOSYSTEM=1; : > "$GIT_CONFIG_GLOBAL"
pass=0; fail=0; skip=0
chk() { if grep -q -- "$2" "$S/out.txt"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] 找不到: $2"; fi; }
nochk() { if grep -q -- "$2" "$S/out.txt"; then fail=$((fail+1)); echo "FAIL [$1] 不該出現: $2"; else pass=$((pass+1)); fi; }
rc_is() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL [$1] rc=$2（預期 $3）"; fi; }
run() { node "$MJS" "$@" > "$S/out.txt" 2>&1; }

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

# 2. 乾淨假專案 → 通過；埋了問題的複本 → 四種問題都抓到
run --target "$(mp "$FIX")" --scan-only; rc_is t2 $? 0
chk t2 "第三階段總體檢結果：PASS"
run --target "$(mp "$S/leaky")" --scan-only; rc_is t2b $? 1
chk t2b "\[HARDCODED_SECRET\] lib.gemini.ts"
chk t2b "\[NEXT_PUBLIC_LEAK\] lib.config.ts"
chk t2b "\[CLIENT_SDK_IMPORT\] app.chat.page.tsx"
chk t2b "\[GITIGNORE_ENV\]"
nochk t2b "app.page.tsx"
LATEST="$(ls -t "$R"/reports/stage-3-report-*.md | head -1)"
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
LATEST="$(ls -t "$R"/reports/stage-3-report-*.md | head -1)"
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
  LATEST="$(ls -t "$R"/reports/stage-3-report-*.md | head -1)"
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

  # 沒帶 --url → 讀第一階段記下的網址；--mock、--self-test 不打網站；狀態檔其他欄位要保留
  printf 'SAVED_PROJECT_ID="proj-a"\nSAVED_CLOUD_RUN_URL="%s/good"\n' "$B" > "$ST"
  : > "$LOG"; run --eval-only; rc_is t8i $? 0
  chk t8i "網址來源：第一階段記下的網址"
  cnt_is t8i "$(nlog good)" 20
  grep -qF "SAVED_CLOUD_RUN_URL=\"$B/good\"" "$ST" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL [t8i] 狀態檔弄丟了 SAVED_CLOUD_RUN_URL"; }
  : > "$LOG"; run --eval-only --mock; rc_is t8i2 $? 0
  chk t8i2 "測試對象：本機模擬回應"
  run --self-test; rc_is t8i3 $? 0
  chk t8i3 "測試對象：本機模擬回應"
  cnt_is t8i2 "$(wc -l < "$LOG" | tr -d ' ')" 0
  rm -f "$ST"
else
  skip=$((skip+1)); echo "SKIP [t8] 假推薦 API 起不來"
fi
kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null

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

if [ -f "$S/state.bak" ]; then cp "$S/state.bak" "$ST"; else rm -f "$ST"; fi
rm -rf "${S:?}"
echo "PASS=$pass FAIL=$fail SKIP=$skip"
[ "$fail" -eq 0 ]
