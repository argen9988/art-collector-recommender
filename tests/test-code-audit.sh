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

# 4. --eval-only 不需原始碼、不出選單
run --eval-only < /dev/null; rc_is t4 $? 0
nochk t4 "原始碼在哪裡"
chk t4 "完成 20 題自動化測試"

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

if [ -f "$S/state.bak" ]; then cp "$S/state.bak" "$ST"; else rm -f "$ST"; fi
rm -rf "${S:?}"
echo "PASS=$pass FAIL=$fail SKIP=$skip"
[ "$fail" -eq 0 ]
