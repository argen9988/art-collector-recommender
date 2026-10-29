#!/usr/bin/env bash
# ==============================================================================
# 藏家推薦系統 (art-collector-recommender)
# 雲端資安分階段檢查、互動設定、每月費用精算與雙軌報告懶人包 (gcp-setup-and-check.sh)
#
# 核心原則：
# 1. 開場先提供「白話互動口令參考」與「分階段選單（不押日期，每個細項皆可選做或跳過）」。
# 2. 每個細項執行前皆印出「6 點白話詳盡說明卡」（做什麼、為什麼做、好處、費用與影響、安全性、誰來做）。
# 3. 所有步驟「先檢查現況（Pre-check）」，已符合標準者自動標記『✅ 已存在，自動跳過』。
# 4. 每月預算與 AI 每日呼叫上限採「互動問答題」（預設原值 1000，並說明數值影響）。
# 5. 內建「💰 雲端服務開啟清單與每月費用精算器」，詳細列出已開服務與預估月費總和。
# 6. 每次執行自動輸出「單次階段執行報告」並同步更新「全部執行累計總報告 (reports/full-execution-report.md)」。
#
# 用法：
#   bash gcp-setup-and-check.sh                       # 互動選單模式（可選第 1 階段、第 2 階段、費用精算或全部）
#   bash gcp-setup-and-check.sh --stage 1             # 只跑第一階段（立即止血與基礎防護：細項 1-1 ~ 1-3）
#   bash gcp-setup-and-check.sh --stage 2             # 只跑第二階段（系統架構加固與規格選型：細項 2-1 ~ 2-5）
#   bash gcp-setup-and-check.sh --stage cost          # 只跑雲端服務開啟清單與每月費用精算
#   bash gcp-setup-and-check.sh --stage all           # 一次跑完第一、二階段與費用精算
#   bash gcp-setup-and-check.sh --item <1-8>          # 只挑單一細項（關卡 1~8）執行
#   bash gcp-setup-and-check.sh --check-only          # 純唯讀體檢模式（只檢查與出報告，不修改任何設定）
#   bash gcp-setup-and-check.sh --project <ID>        # 直接指定 GCP 專案（不帶時自動列出帳號下所有專案供選擇）
#   bash gcp-setup-and-check.sh --dry-run             # 模擬測試模式（無 gcloud 環境下驗證流程、選單與報告輸出）
# ==============================================================================

set -u

MODE="interactive"
TARGET_STAGE="menu"
TARGET_ITEM=""
PROJECT_ID=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check-only) MODE="check-only" ;;
    --dry-run)    MODE="dry-run" ;;
    --stage|--wave)
      shift
      TARGET_STAGE="${1:-all}"
      ;;
    --stage=*|--wave=*)
      TARGET_STAGE="${1#*=}"
      ;;
    --item)
      shift
      TARGET_ITEM="${1:-}"
      TARGET_STAGE="item-${TARGET_ITEM}"
      ;;
    --item=*)
      TARGET_ITEM="${1#*=}"
      TARGET_STAGE="item-${TARGET_ITEM}"
      ;;
    --project)
      shift
      PROJECT_ID="${1:-}"
      ;;
    --project=*)
      PROJECT_ID="${1#*=}"
      ;;
    -h|--help)
      echo "用法: bash $0 [--stage 1|2|cost|all] [--item 1..8] [--project <Project ID>] [--check-only] [--dry-run]"
      exit 0
      ;;
  esac
  shift
done

# ------------------------------------------------------------------------------
# 0. 讀取參數檔 (config/params.json) 與報告目錄準備
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -P "${SCRIPT_DIR}/.." && pwd -P)"
REPORTS_DIR="${REPO_ROOT}/reports"
STATE_FILE="${REPORTS_DIR}/.lazy-pack-state.env"
mkdir -p "$REPORTS_DIR"

PARAMS_FILE=""
if [ -f "${REPO_ROOT}/config/params.json" ]; then
  PARAMS_FILE="${REPO_ROOT}/config/params.json"
elif [ -f "./params.json" ]; then
  PARAMS_FILE="./params.json"
fi

# 預設值（當參數檔不在或欄位缺漏時使用）
BUDGET_MONTHLY_NTD=1000
DB_TARGET_MONTHLY_NTD=550
API_QUOTA_RPD=1000
API_QUOTA_RPM=30
BACKUP_RETENTION_DAYS=14
EDM_DAILY_SEND_LIMIT=100

read_json_int() {
  local file="$1"
  local key="$2"
  local default_val="$3"
  local min_val="$4"
  local max_val="$5"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    echo "$default_val"
    return 0
  fi
  local val
  val="$(grep -E "^  \"${key}\"[[:space:]]*:[[:space:]]*-?[0-9]+" "$file" | tail -n 1 | sed -E 's/.*:[[:space:]]*(-?[0-9]+).*/\1/')"
  if [ -z "$val" ] || ! [[ "$val" =~ ^-?[0-9]+$ ]]; then
    echo "注意：參數檔 ${file} 的 ${key} 讀不到或格式不合法，這次照預設值 ${default_val} 跑。" >&2
    echo "$default_val"
    return 0
  fi
  if [ "$val" -lt "$min_val" ] || [ "$val" -gt "$max_val" ]; then
    echo "注意：參數檔 ${file} 的 ${key}=${val} 超出合法範圍 (${min_val}~${max_val})，這次照預設值 ${default_val} 跑。" >&2
    echo "$default_val"
    return 0
  fi
  echo "$val"
}

if [ -n "$PARAMS_FILE" ]; then
  BUDGET_MONTHLY_NTD="$(read_json_int "$PARAMS_FILE" "budget_monthly_ntd" 1000 300 50000)"
  DB_TARGET_MONTHLY_NTD="$(read_json_int "$PARAMS_FILE" "db_target_monthly_ntd" 550 250 10000)"
  API_QUOTA_RPD="$(read_json_int "$PARAMS_FILE" "api_quota_rpd" 1000 50 50000)"
  API_QUOTA_RPM="$(read_json_int "$PARAMS_FILE" "api_quota_rpm" 30 5 1000)"
  BACKUP_RETENTION_DAYS="$(read_json_int "$PARAMS_FILE" "backup_retention_days" 14 7 365)"
  EDM_DAILY_SEND_LIMIT="$(read_json_int "$PARAMS_FILE" "edm_daily_send_limit" 100 10 10000)"
else
  echo "注意：找不到 config/params.json，這次照程式內建預設值跑（每月預算 NT\$${BUDGET_MONTHLY_NTD}、資料庫參考月租 NT\$${DB_TARGET_MONTHLY_NTD}）。"
fi

# 載入先前階段累積狀態（供產生全部執行累計總報告）
STAGE1_LAST_RUN="尚未執行"
STAGE1_SUMMARY="⏳ 尚未執行"
STAGE2_LAST_RUN="尚未執行"
STAGE2_SUMMARY="⏳ 尚未執行"
STAGE3_LAST_RUN="尚未執行"
STAGE3_SUMMARY="⏳ 尚未執行（請於本機執行 node lazy-pack/code-and-ai-audit.mjs）"
SAVED_DB_CHOICE_LABEL="方案 3A：db-g1-small (1.7GB RAM) + 平日上班開機排程"
SAVED_DB_MIN_NTD=480
SAVED_DB_MAX_NTD=560
SAVED_VERTEX_STATUS="未啟用（維持 AI Studio Paid Tier，NT$0 底租）"
SAVED_EDM_STATUS="未啟用（維持人工操作或免費額度內 NT$0）"
SAVED_EDM_MAX_NTD=0
SAVED_SECRET_COUNT=2

if [ -f "$STATE_FILE" ]; then
  while IFS='=' read -r s_key s_val; do
    s_val="${s_val%$'\r'}"
    s_val="${s_val#\"}"
    s_val="${s_val%\"}"
    case "$s_key" in
      STAGE1_LAST_RUN)       STAGE1_LAST_RUN="$s_val" ;;
      STAGE1_SUMMARY)        STAGE1_SUMMARY="$s_val" ;;
      STAGE2_LAST_RUN)       STAGE2_LAST_RUN="$s_val" ;;
      STAGE2_SUMMARY)        STAGE2_SUMMARY="$s_val" ;;
      STAGE3_LAST_RUN)       STAGE3_LAST_RUN="$s_val" ;;
      STAGE3_SUMMARY)        STAGE3_SUMMARY="$s_val" ;;
      SAVED_DB_CHOICE_LABEL) SAVED_DB_CHOICE_LABEL="$s_val" ;;
      SAVED_DB_MIN_NTD)      SAVED_DB_MIN_NTD="$s_val" ;;
      SAVED_DB_MAX_NTD)      SAVED_DB_MAX_NTD="$s_val" ;;
      SAVED_VERTEX_STATUS)   SAVED_VERTEX_STATUS="$s_val" ;;
      SAVED_EDM_STATUS)      SAVED_EDM_STATUS="$s_val" ;;
      SAVED_EDM_MAX_NTD)     SAVED_EDM_MAX_NTD="$s_val" ;;
      SAVED_SECRET_COUNT)    SAVED_SECRET_COUNT="$s_val" ;;
    esac
  done < "$STATE_FILE"
fi

# ------------------------------------------------------------------------------
# 開場總覽與白話互動參考說明
# ------------------------------------------------------------------------------
echo "=============================================================================="
echo " 🎨 藏家推薦系統 — 雲端資安分階段檢查、設定與費用精算懶人包 (模式: ${MODE})"
echo "=============================================================================="
echo " 💬 【您可以怎麼跟這個 Lazy Pack / AI 小幫手互動？（白話口令參考）】："
echo "   • 分階段執行：可自由選擇跑「第一階段」、「第二階段」、「第三階段」或「全部檢查」"
echo "   • 細項自由選：每個階段底下的細項都會先印出【白話說明卡】，您可逐項決定要做或先跳過"
echo "   • 挑單一細項：隨時可跟 AI 說「我今天只想改每月預算與 AI 次數」或「只想換資料庫方案」"
echo "   • 費用精算器：隨時可說「幫我精算目前開了哪些雲端服務、一個月總共要花多少錢？」"
echo "   • 雙報告輸出：每次跑完自動輸出「單次階段執行報告」與更新「全部執行總報告」"
echo "------------------------------------------------------------------------------"
echo " 📋 【三階段與費用精算工作總覽（不押日期，依團隊節奏隨時執行）】： "
echo "   🔹 第一階段：立即止血與基礎防護（細項 1-1 ~ 1-3）"
echo "      1. [細項 1-1] 切換 Google 付費層（Paid Tier，確保藏家個資 100% 不被拿去訓練模型）"
echo "      2. [細項 1-2] 設定雙管理員（Owner）帳號共管（防單一開發者異動造成維運孤島）"
echo "      3. [細項 1-3] 互動問答設定「每月預算提醒鈴 (預設 NT\$${BUDGET_MONTHLY_NTD})」、「AI 每日呼叫保險絲 (預設 ${API_QUOTA_RPD}次)」與「同仁 Gmail 白名單」"
echo "   🔹 第二階段：系統架構加固與規格選型（細項 2-1 ~ 2-5）"
echo "      4. [細項 2-1] 把 API 金鑰與資料庫密碼收進雲端保險箱 (Secret Manager)"
echo "      5. [細項 2-2] 關閉資料庫 (Cloud SQL) 對外公網 IP、開啟 SSL 加密與每日自動備份 (${BACKUP_RETENTION_DAYS}天)"
echo "      6. [細項 2-3] 互動選擇資料庫月租方案（含 NT\$500–600/月 甜區在內之 6 種方案）"
echo "      7. [細項 2-4] 🟢 非必要選配：是否啟用 Vertex AI（預設維持 AI Studio Paid Tier 跳過）"
echo "      8. [細項 2-5] 🟢 非必要選配：是否啟用排程自動發送客製化 EDM 之 Cloud Scheduler（預設跳過）"
echo "   🔹 第三階段：上線前原始碼與 AI 總體檢（於本機執行 code-and-ai-audit.mjs）"
echo "   💰 獨立項目：雲端服務開啟清單與每月費用精算表（自動盤點已開服務並試算每月總花費）"
echo "=============================================================================="

if [ "$TARGET_STAGE" = "menu" ]; then
  if [ "$MODE" = "interactive" ]; then
    echo ""
    echo "👉 請選擇本次要執行的階段："
    echo "   [1] 只執行「第一階段：立即止血與基礎防護」（細項 1-1 ~ 1-3 + 費用精算）"
    echo "   [2] 只執行「第二階段：系統架構加固與規格選型」（細項 2-1 ~ 2-5 + 費用精算）"
    echo "   [3] 只執行「💰 雲端服務開啟清單與每月費用精算表」"
    echo "   [4] 一次執行「全部階段（第一階段 + 第二階段 + 費用精算）」 [預設]"
    read -r -p "請輸入選項編號 [1-4，直接按 Enter 預設選 4]: " stage_choice
    case "${stage_choice:-4}" in
      1) TARGET_STAGE="1" ;;
      2) TARGET_STAGE="2" ;;
      3) TARGET_STAGE="cost" ;;
      *) TARGET_STAGE="all" ;;
    esac
    echo ""
  else
    TARGET_STAGE="all"
  fi
fi

should_run_item() {
  local item_num="$1"
  if [ -n "$TARGET_ITEM" ]; then
    [ "$TARGET_ITEM" = "$item_num" ] && return 0 || return 1
  fi
  case "$TARGET_STAGE" in
    1|stage1|wave1)
      [[ "$item_num" =~ ^[123]$ ]] && return 0 || return 1
      ;;
    2|stage2|wave2)
      [[ "$item_num" =~ ^[45678]$ ]] && return 0 || return 1
      ;;
    cost)
      return 1
      ;;
    all|*)
      return 0
      ;;
  esac
}

# 檢查 gcloud 是否存在
if [ "$MODE" != "dry-run" ] && ! command -v gcloud >/dev/null 2>&1; then
  echo "❌ 找不到 gcloud 指令！請交由 AI Agent 操作，或在 Google Cloud Console 右上角點選「Activate Cloud Shell (>_ )」執行本腳本，或加 --dry-run 預覽流程。"
  exit 2
fi

# ------------------------------------------------------------------------------
# 自動定位目標 GCP 專案與 Cloud Run 網址（列出帳號下所有專案供選擇，不需手輸 Project ID）
# ------------------------------------------------------------------------------
# 列出某專案下的 Cloud Run 服務（每行「服務名稱<TAB>網址」）；未啟用 Cloud Run API 時回傳空白，不觸發啟用提示
list_cloud_run_services() {
  local pid="$1"
  if [ "$MODE" = "dry-run" ]; then
    [ "$pid" = "demo-art-collector-proj" ] && printf "art-collector-web\thttps://art-collector-web-demo-uc.a.run.app\n"
    return 0
  fi
  if gcloud services list --enabled --project="$pid" --filter="config.name:run.googleapis.com" --format="value(config.name)" 2>/dev/null | grep -q "run.googleapis.com"; then
    gcloud run services list --project="$pid" --platform=managed --format="value(metadata.name,status.url)" --quiet 2>/dev/null || true
  fi
}

DEFAULT_GCLOUD_PROJECT=""
if [ "$MODE" != "dry-run" ]; then
  DEFAULT_GCLOUD_PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
  [ "$DEFAULT_GCLOUD_PROJECT" = "(unset)" ] && DEFAULT_GCLOUD_PROJECT=""
fi

if [ -z "$PROJECT_ID" ]; then
  if [ "$MODE" = "dry-run" ]; then
    PROJECT_LINES="$(printf "demo-art-collector-proj\t藏家推薦系統（模擬）\ndemo-sandbox-proj\t個人練習專案（模擬）\n")"
  else
    echo "🔎 正在列出您帳號下的所有 GCP 專案，並探測哪個專案有運行中的 Cloud Run 網站..."
    PROJECT_LINES="$(gcloud projects list --format="value(projectId,name)" --sort-by=projectId 2>/dev/null || true)"
  fi
  if [ -z "$PROJECT_LINES" ]; then
    echo "❌ 這個帳號下找不到任何 GCP 專案！請確認已用正確的 Google 帳號登入（gcloud auth login），或改用 --project <Project ID> 指定。"
    exit 2
  fi

  PROJECT_IDS=()
  DEFAULT_PICK=""
  RUN_PROJECT_TOTAL=0
  RUN_PROJECT_PICK=""
  idx=0
  echo ""
  echo "📋 您帳號下的 GCP 專案清單："
  while IFS=$'\t' read -r p_id p_name; do
    p_name="${p_name%$'\r'}"
    [ -z "$p_id" ] && continue
    idx=$((idx + 1))
    PROJECT_IDS+=("$p_id")
    run_lines="$(list_cloud_run_services "$p_id")"
    run_count=0
    [ -n "$run_lines" ] && run_count="$(printf "%s\n" "$run_lines" | grep -c .)"
    tags=""
    if [ "$run_count" -gt 0 ]; then
      tags="  🌐 有 ${run_count} 個 Cloud Run 網站"
      RUN_PROJECT_TOTAL=$((RUN_PROJECT_TOTAL + 1))
      RUN_PROJECT_PICK="$idx"
    fi
    if [ -n "$DEFAULT_GCLOUD_PROJECT" ] && [ "$p_id" = "$DEFAULT_GCLOUD_PROJECT" ]; then
      tags="${tags}  ⭐ 目前 gcloud 預設專案"
      DEFAULT_PICK="$idx"
    fi
    echo "   [${idx}] ${p_name:-（未命名）}（Project ID：${p_id}）${tags}"
  done <<< "$PROJECT_LINES"

  # 預設選擇：只有一個專案有 Cloud Run 網站時選它；否則選 gcloud 預設專案；再不然選第 1 個
  if [ "$RUN_PROJECT_TOTAL" -eq 1 ]; then
    DEFAULT_PICK="$RUN_PROJECT_PICK"
  fi
  [ -z "$DEFAULT_PICK" ] && DEFAULT_PICK=1

  project_choice=1
  if [ "$idx" -gt 1 ]; then
    project_choice=""
    read -r -p "👉 請輸入要檢查的專案編號 [1-${idx}，直接按 Enter 預設選 ${DEFAULT_PICK}]: " project_choice || true
    project_choice="${project_choice:-$DEFAULT_PICK}"
    if ! [[ "$project_choice" =~ ^[0-9]+$ ]] || [ "$project_choice" -lt 1 ] || [ "$project_choice" -gt "$idx" ]; then
      echo "⚠️ 編號 ${project_choice} 不在清單內，改用預設 [${DEFAULT_PICK}]。"
      project_choice="$DEFAULT_PICK"
    fi
  fi
  PROJECT_ID="${PROJECT_IDS[$((project_choice - 1))]}"
  if [ "$RUN_PROJECT_TOTAL" -eq 0 ]; then
    echo "⚠️ 所有專案都沒有探測到 Cloud Run 網站：可能網站還在 Google AI Studio 尚未部署，或 Cloud Run API 未啟用。腳本照常檢查所選專案。"
  fi
fi

# 探測所選專案的 Cloud Run 網址（存進狀態檔，供第三階段 --url 線上實測讀取）
CLOUD_RUN_SERVICE=""
CLOUD_RUN_URL=""
RUN_LINES="$(list_cloud_run_services "$PROJECT_ID")"
if [ -n "$RUN_LINES" ]; then
  RUN_TOTAL="$(printf "%s\n" "$RUN_LINES" | grep -c .)"
  run_choice=1
  if [ "$RUN_TOTAL" -gt 1 ]; then
    echo "🌐 專案 ${PROJECT_ID} 下有 ${RUN_TOTAL} 個 Cloud Run 網站："
    printf "%s\n" "$RUN_LINES" | awk -F'\t' '{ printf "   [%d] %s → %s\n", NR, $1, $2 }'
    run_choice=""
    read -r -p "👉 哪一個是藏家推薦系統？[1-${RUN_TOTAL}，直接按 Enter 預設選 1]: " run_choice || true
    run_choice="${run_choice:-1}"
    if ! [[ "$run_choice" =~ ^[0-9]+$ ]] || [ "$run_choice" -lt 1 ] || [ "$run_choice" -gt "$RUN_TOTAL" ]; then
      run_choice=1
    fi
  fi
  CLOUD_RUN_SERVICE="$(printf "%s\n" "$RUN_LINES" | sed -n "${run_choice}p" | cut -f1)"
  CLOUD_RUN_URL="$(printf "%s\n" "$RUN_LINES" | sed -n "${run_choice}p" | cut -f2 | tr -d '\r')"
fi

echo "📌 目標 GCP 專案：${PROJECT_ID} | 本次執行範圍：${TARGET_STAGE}"
if [ -n "$CLOUD_RUN_URL" ]; then
  echo "🌐 藏家推薦系統網址：${CLOUD_RUN_URL}（Cloud Run 服務 ${CLOUD_RUN_SERVICE}，已記下供第三階段 --url 線上實測使用）"
else
  echo "🌐 這個專案沒有探測到 Cloud Run 網站（第三階段可改用本機原始碼檢查）。"
fi
echo ""

# 計數器與單次報告明細陣列
SKIPPED_COUNT=0
FIXED_COUNT=0
DEFERRED_COUNT=0
MANUAL_TODO_LIST=()
STAGE_LOG_LINES=()

add_stage_log() {
  STAGE_LOG_LINES+=("$1")
}

# ==============================================================================
# 🔹 第一階段：立即止血與基礎防護（細項 1-1 ~ 1-3）
# ==============================================================================

# ------------------------------------------------------------------------------
# 關卡 1 (細項 1-1)：檢查計費帳戶綁定狀態（Paid Tier 資料不訓練保障）
# ------------------------------------------------------------------------------
if should_run_item 1; then
  echo "------------------------------------------------------------------------------"
  echo "🔍 [細項 1-1] 檢查專案是否已綁定計費帳戶（切換 Paid Tier 零資料訓練保障）"
  echo "   📖 【白話說明卡】："
  echo "   • 🎯 這是做什麼：把 Google AI 從「免費試用版」切換為「正式綁卡版 (Paid Tier)」。"
  echo "   • ⚠️ 為什麼要做：Google 條款規定【免費版輸入的藏家個資與畫作底價會被拿去訓練 AI 且供人工審閱】！"
  echo "   • ✨ 有什麼好處：綁卡切為 Paid Tier 後，Google 正式承諾 100% 絕不拿資料訓練模型、禁止人工審閱。"
  echo "   • 💰 費用與影響：綁定本身 NT\$0；日常查詢推薦每月 AI 費用僅約 NT\$15～60，且完全不影響現有網站。"
  echo "------------------------------------------------------------------------------"

  BILLING_ENABLED="false"
  if [ "$MODE" = "dry-run" ]; then
    BILLING_ENABLED="true"
  else
    BILLING_ENABLED="$(gcloud beta billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" 2>/dev/null || echo "false")"
  fi

  if [ "$BILLING_ENABLED" = "True" ] || [ "$BILLING_ENABLED" = "true" ]; then
    echo "✅ [已存在，自動跳過] 專案 ${PROJECT_ID} 已綁定計費帳戶（處於 Paid Tier），享有客戶資料 100% 不訓練模型保障！"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    add_stage_log "| 細項 1-1 | 切換 Paid Tier（零資料訓練保障） | ✅ 已符合（Paid Tier 已啟用） |"
  else
    echo "⚠️  [尚未設定] 目前專案尚未綁定計費帳戶（處於 Free Tier 免費層，輸入資料有被 Google 留存訓練風險）！"
    if [ "$MODE" = "interactive" ]; then
      read -r -p "👉 [可選細項] 是否將「綁定計費帳戶切換 Paid Tier」加入待辦提醒並印出直達網址？[Y/n]: " do_item1
      if [[ "${do_item1:-Y}" =~ ^[Nn]$ ]]; then
        echo "⏭️  [本次暫緩跳過] 您選擇暫緩設定細項 1-1。"
        DEFERRED_COUNT=$((DEFERRED_COUNT + 1))
        add_stage_log "| 細項 1-1 | 切換 Paid Tier（零資料訓練保障） | ⏭️ 本次暫緩跳過 |"
      else
        MANUAL_TODO_LIST+=("細項 1-1 [切換 Paid Tier]：請開啟 https://console.cloud.google.com/billing/linkedaccount?project=${PROJECT_ID} 綁定計費帳戶。")
        add_stage_log "| 細項 1-1 | 切換 Paid Tier（零資料訓練保障） | ⚠️ 待於網頁綁定計費帳戶 |"
      fi
    else
      MANUAL_TODO_LIST+=("細項 1-1 [切換 Paid Tier]：請開啟 https://console.cloud.google.com/billing/linkedaccount?project=${PROJECT_ID} 綁定計費帳戶。")
      add_stage_log "| 細項 1-1 | 切換 Paid Tier（零資料訓練保障） | ⚠️ 待於網頁綁定計費帳戶 |"
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 關卡 2 (細項 1-2)：檢查專案共同擁有者（Owner 備援，防維運孤島）
# ------------------------------------------------------------------------------
if should_run_item 2; then
  echo ""
  echo "------------------------------------------------------------------------------"
  echo "🔍 [細項 1-2] 檢查專案雙管理員（Owner）帳號共管（防單一開發者異動變孤島）"
  echo "   📖 【白話說明卡】："
  echo "   • 🎯 這是做什麼：在雲端後台多加一個「部門公務 Gmail」或「主管 Gmail」當共同最高管理員。"
  echo "   • ⚠️ 為什麼要做：若只有單一開發者一個帳號有權限，人員休假或離職時整個資料庫與網站將無人能接管。"
  echo "   • ✨ 有什麼好處：至少 2 人互為備援，隨時可管理與備份；完全免費 (NT\$0) 且不影響現有系統。"
  echo "------------------------------------------------------------------------------"

  OWNER_COUNT=0
  if [ "$MODE" = "dry-run" ]; then
    OWNER_COUNT=2
  else
    OWNER_LIST="$(gcloud projects get-iam-policy "$PROJECT_ID" --flatten="bindings[].members" --filter="bindings.role:roles/owner" --format="value(bindings.members)" 2>/dev/null || true)"
    if [ -n "$OWNER_LIST" ]; then
      OWNER_COUNT="$(echo "$OWNER_LIST" | wc -l | tr -d ' ')"
    fi
  fi

  if [ "$OWNER_COUNT" -ge 2 ]; then
    echo "✅ [已存在，自動跳過] 目前專案已有 ${OWNER_COUNT} 位 Owner 共同管理，具備職務備援機制。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    add_stage_log "| 細項 1-2 | 雙管理員（Owner）帳號共管 | ✅ 已符合（共 ${OWNER_COUNT} 位 Owner） |"
  else
    echo "⚠️  [尚未設定] 目前專案僅有 ${OWNER_COUNT} 位 Owner。"
    if [ "$MODE" = "interactive" ]; then
      read -r -p "👉 [可選細項] 是否現在輸入「部門公務 Gmail 或主管 Gmail」由腳本自動加入為共同 Owner？[y=現在加 / n=先跳過]: " ans
      if [[ "$ans" =~ ^[Yy]$ ]]; then
        read -r -p "請輸入要加入為共同 Owner 的 Gmail 信箱: " new_owner_email
        if [ -n "$new_owner_email" ]; then
          gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="user:${new_owner_email}" \
            --role="roles/owner"
          echo "✅ 已將 ${new_owner_email} 加入為專案共同 Owner！"
          FIXED_COUNT=$((FIXED_COUNT + 1))
          add_stage_log "| 細項 1-2 | 雙管理員（Owner）帳號共管 | 🔧 本次已新增共同 Owner (${new_owner_email}) |"
        fi
      else
        echo "⏭️  [本次暫緩跳過] 保留稍後設定，將於報告附上 IAM 設定網址。"
        DEFERRED_COUNT=$((DEFERRED_COUNT + 1))
        MANUAL_TODO_LIST+=("細項 1-2 [新增共同 Owner]：可於 https://console.cloud.google.com/iam-admin/iam?project=${PROJECT_ID} 加入部門公務 Gmail。")
        add_stage_log "| 細項 1-2 | 雙管理員（Owner）帳號共管 | ⏭️ 本次暫緩（目前 ${OWNER_COUNT} 位 Owner） |"
      fi
    else
      MANUAL_TODO_LIST+=("細項 1-2 [新增共同 Owner]：目前僅 ${OWNER_COUNT} 位，建議於 https://console.cloud.google.com/iam-admin/iam?project=${PROJECT_ID} 加入部門公務 Gmail。")
      add_stage_log "| 細項 1-2 | 雙管理員（Owner）帳號共管 | ⚠️ 待補強（目前僅 ${OWNER_COUNT} 位 Owner） |"
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 關卡 3 (細項 1-3)：互動問答設定「每月預算」、「AI 每日呼叫上限」與「Gmail 白名單」
# ------------------------------------------------------------------------------
if should_run_item 3; then
  echo ""
  echo "------------------------------------------------------------------------------"
  echo "🔍 [細項 1-3] 設定「每月預算提醒鈴」＋「AI 每日呼叫保險絲」＋「同仁 Gmail 登入白名單」"
  echo "   📖 【白話說明卡與數值影響解釋】："
  echo "   • 🎯 這是做什麼：設定三道保護鎖——(A) 帳單超標寄信提醒、(B) 限制每日呼叫 AI 次數、(C) 限定同仁 Gmail 登入。"
  echo "   • ⚠️ 為什麼要做：防止程式寫錯無窮迴圈把信用卡刷爆，並阻擋外部陌生 Gmail 登入偷看藏家名單。"
  echo "   • 💰 【問答題 A：每月預算警示金額（目前預設原值：NT\$${BUDGET_MONTHLY_NTD} / 月）會影響什麼？】"
  echo "     - 作用（軟止損提醒鈴）：當本月累積總花費達此金額的 50%、80%、100% 時自動寄信通知，【不會把網站斷電關機】。"
  echo "     - 調高／調低影響：若設得比資料庫月租（約 NT\$500）還低，每個月中就會一直收到警告信；設太高則太晚預警。"
  echo "   • 💰 【問答題 B：Gemini AI 每日呼叫次數上限（目前預設原值：${API_QUOTA_RPD} 次/日）會影響什麼？】"
  echo "     - 作用（硬止損保險絲）：當天全系統呼叫 AI 達此次數時，Google 當天會【強制擋下新的 AI 請求】（隔天自動恢復）。"
  echo "     - 費用與影響：呼叫 1,000 次 Gemini Flash 一天僅花約 NT\$3～10 元（絕對刷不爆卡！）。設太低（如 50 次）業務查幾次"
  echo "       推薦就會滿額卡住；部門日常使用＋每日 100 封內 EDM，維持預設 1,000 次/日最安全充裕。"
  echo "------------------------------------------------------------------------------"

  if [ "$MODE" = "interactive" ]; then
    read -r -p "💬 [問答題 1/2] 請輸入您希望設定的「每月預算警示金額 (台幣 NTD)」[直接按 Enter 套用預設原值 ${BUDGET_MONTHLY_NTD}]: " input_budget
    if [ -n "$input_budget" ] && [[ "$input_budget" =~ ^[0-9]+$ ]]; then
      BUDGET_MONTHLY_NTD="$input_budget"
      echo "   ✅ 已將每月預算警示金額設為：NT\$${BUDGET_MONTHLY_NTD} / 月"
    else
      echo "   ✅ 維持預設原值：NT\$${BUDGET_MONTHLY_NTD} / 月"
    fi

    read -r -p "💬 [問答題 2/2] 請輸入您希望鎖定的「AI 每日呼叫次數上限 (次/日)」[直接按 Enter 套用預設原值 ${API_QUOTA_RPD}]: " input_rpd
    if [ -n "$input_rpd" ] && [[ "$input_rpd" =~ ^[0-9]+$ ]]; then
      API_QUOTA_RPD="$input_rpd"
      echo "   ✅ 已將 AI 每日呼叫上限設為：${API_QUOTA_RPD} 次 / 日"
    else
      echo "   ✅ 維持預設原值：${API_QUOTA_RPD} 次 / 日"
    fi

    read -r -p "👉 請問您是否已經在 GCP 網頁完成上述「NT\$${BUDGET_MONTHLY_NTD} 預算通知」、「每日 ${API_QUOTA_RPD} 次配額」與「OAuth 同仁 Gmail 白名單」設定？[y=已設好跳過 / N=還沒，請產生直達網址提醒我]: " web_done
    if [[ "$web_done" =~ ^[Yy]$ ]]; then
      echo "✅ [已存在，自動跳過] 執行者確認已完成每月 NT\$${BUDGET_MONTHLY_NTD} 預算、每日 ${API_QUOTA_RPD} 次上限與 OAuth 白名單設定。"
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      add_stage_log "| 細項 1-3 | 預算提醒 (NT\$${BUDGET_MONTHLY_NTD}) + AI 日上限 (${API_QUOTA_RPD}次) + Gmail 白名單 | ✅ 已符合（執行者確認已完成） |"
    else
      MANUAL_TODO_LIST+=("細項 1-3A [設定每月 NT\$${BUDGET_MONTHLY_NTD} 預算提醒鈴]：https://console.cloud.google.com/billing/budgets?project=${PROJECT_ID}")
      MANUAL_TODO_LIST+=("細項 1-3B [鎖定 AI 每日呼叫保險絲 (${API_QUOTA_RPD} 次/日)]：https://console.cloud.google.com/iam-admin/quotas?project=${PROJECT_ID}&service=generativelanguage.googleapis.com")
      MANUAL_TODO_LIST+=("細項 1-3C [設定同仁 Gmail 登入白名單 (Testing 模式 + Test users)]：https://console.cloud.google.com/apis/credentials/consent?project=${PROJECT_ID}")
      add_stage_log "| 細項 1-3 | 預算提醒 (NT\$${BUDGET_MONTHLY_NTD}) + AI 日上限 (${API_QUOTA_RPD}次) + Gmail 白名單 | ⚠️ 已設定目標值，待於網頁點選確認 |"
    fi
  else
    echo "ℹ️  [唯讀/模擬模式] 採用參數值：每月預算警示 NT\$${BUDGET_MONTHLY_NTD}、AI 每日呼叫上限 ${API_QUOTA_RPD} 次/日（每分鐘 ${API_QUOTA_RPM} 次）。"
    add_stage_log "| 細項 1-3 | 預算提醒 (NT\$${BUDGET_MONTHLY_NTD}) + AI 日上限 (${API_QUOTA_RPD}次) + Gmail 白名單 | ℹ️ 目標值已載入（NT\$${BUDGET_MONTHLY_NTD} / ${API_QUOTA_RPD}次） |"
  fi

  if [ -z "$TARGET_ITEM" ]; then
    STAGE1_LAST_RUN="$(date '+%Y-%m-%d %H:%M:%S')"
    if [ "${#MANUAL_TODO_LIST[@]}" -eq 0 ]; then
      STAGE1_SUMMARY="✅ 已完成（Paid Tier 已啟用、${OWNER_COUNT} 位共同 Owner、預算 NT\$${BUDGET_MONTHLY_NTD}/月、AI 日上限 ${API_QUOTA_RPD} 次）"
    else
      STAGE1_SUMMARY="🔄 進行中（預算設為 NT\$${BUDGET_MONTHLY_NTD}/月、AI 日上限 ${API_QUOTA_RPD} 次；尚有網頁確認項待點選）"
    fi
  fi
fi

# ==============================================================================
# 🔹 第二階段：系統架構加固與規格選型（細項 2-1 ~ 2-5）
# ==============================================================================

# ------------------------------------------------------------------------------
# 關卡 4 (細項 2-1)：檢查 Secret Manager 核心金鑰隔離（AI 與資料庫金鑰）
# ------------------------------------------------------------------------------
if should_run_item 4; then
  echo ""
  echo "------------------------------------------------------------------------------"
  echo "🔍 [細項 2-1] 檢查雲端保險箱 Secret Manager 機敏金鑰隔離 (GEMINI_API_KEY / DATABASE_URL)"
  echo "   📖 【白話說明卡】："
  echo "   • 🎯 這是做什麼：把 AI 金鑰與資料庫密碼從程式碼抽出來，鎖進 Google 雲端保險箱 (Secret Manager)。"
  echo "   • ⚠️ 為什麼要做：若直接寫在前端程式碼，外人打開網站按鍵盤 F12 就能偷走金鑰盜刷或偷連資料庫。"
  echo "   • ✨ 有什麼好處：金鑰 100% 鎖在後端；每月前 6 組密鑰完全免費 (NT\$0)，且不影響網站運作。"
  echo "------------------------------------------------------------------------------"

  FOUND_SECRETS=0
  for SECRET_NAME in "GEMINI_API_KEY" "DATABASE_URL"; do
    SECRET_EXISTS="false"
    if [ "$MODE" = "dry-run" ]; then
      if [ "$SECRET_NAME" = "GEMINI_API_KEY" ]; then
        SECRET_EXISTS="true"
      fi
    else
      if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
        SECRET_EXISTS="true"
      fi
    fi

    if [ "$SECRET_EXISTS" = "true" ]; then
      echo "✅ [已存在，自動跳過] Secret Manager 中已存在密鑰：${SECRET_NAME}"
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      FOUND_SECRETS=$((FOUND_SECRETS + 1))
      add_stage_log "| 細項 2-1 | Secret Manager 金鑰隔離 (${SECRET_NAME}) | ✅ 已存在，自動跳過 |"
    else
      echo "⚠️  [尚未建立] Secret Manager 尚未建立密鑰：${SECRET_NAME}"
      if [ "$MODE" = "interactive" ]; then
        read -r -p "👉 [可選細項] 是否現在於雲端保險箱建立 ${SECRET_NAME}？(若暫不建立可按 N 跳過) [y/N]: " create_sec
        if [[ "$create_sec" =~ ^[Yy]$ ]]; then
          gcloud services enable secretmanager.googleapis.com --project="$PROJECT_ID"
          read -r -s -p "請貼上 ${SECRET_NAME} 的值（輸入時畫面不會顯示明文，按 Enter 結束）: " secret_val
          echo ""
          if [ -n "$secret_val" ]; then
            printf "%s" "$secret_val" | gcloud secrets create "$SECRET_NAME" --data-file=- --project="$PROJECT_ID"
            echo "✅ 已安全建立密鑰 ${SECRET_NAME}！"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            FOUND_SECRETS=$((FOUND_SECRETS + 1))
            add_stage_log "| 細項 2-1 | Secret Manager 金鑰隔離 (${SECRET_NAME}) | 🔧 本次已建立完成 |"
          fi
        else
          echo "⏭️  [本次暫緩跳過] 暫不建立 ${SECRET_NAME}。"
          DEFERRED_COUNT=$((DEFERRED_COUNT + 1))
          add_stage_log "| 細項 2-1 | Secret Manager 金鑰隔離 (${SECRET_NAME}) | ⏭️ 本次暫緩跳過 |"
        fi
      else
        add_stage_log "| 細項 2-1 | Secret Manager 金鑰隔離 (${SECRET_NAME}) | ⚠️ 尚未建立 |"
      fi
    fi
  done
  SAVED_SECRET_COUNT="$FOUND_SECRETS"
fi

# ------------------------------------------------------------------------------
# 關卡 5 (細項 2-2) & 關卡 6 (細項 2-3)：Cloud SQL 網路防護與規格月租選單
# ------------------------------------------------------------------------------
if should_run_item 5 || should_run_item 6; then
  SQL_INSTANCE=""
  if [ "$MODE" = "dry-run" ]; then
    SQL_INSTANCE="art-collector-db"
    IPV4_ENABLED="True"
    REQUIRE_SSL="True"
    BACKUP_ENABLED="True"
    CURRENT_TIER="db-g1-small"
    ACTIVATION_POLICY="ALWAYS"
  else
    SQL_INSTANCE="$(gcloud sql instances list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null | head -n 1 || true)"
  fi

  if [ -z "$SQL_INSTANCE" ]; then
    echo "ℹ️  目前專案內尚未偵測到 Cloud SQL 實例，跳過細項 2-2 與細項 2-3。"
    add_stage_log "| 細項 2-2 & 2-3 | Cloud SQL 資料庫防護與規格選型 | ℹ️ 尚未建立 Cloud SQL 實例，跳過 |"
  else
    if [ "$MODE" != "dry-run" ]; then
      IPV4_ENABLED="$(gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" --format="value(settings.ipConfiguration.ipv4Enabled)" 2>/dev/null || echo "Unknown")"
      REQUIRE_SSL="$(gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" --format="value(settings.ipConfiguration.requireSsl)" 2>/dev/null || echo "Unknown")"
      BACKUP_ENABLED="$(gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" --format="value(settings.backupConfiguration.enabled)" 2>/dev/null || echo "Unknown")"
      CURRENT_TIER="$(gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" --format="value(settings.tier)" 2>/dev/null || echo "Unknown")"
      ACTIVATION_POLICY="$(gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" --format="value(settings.activationPolicy)" 2>/dev/null || echo "Unknown")"
    fi

    if should_run_item 5; then
      echo ""
      echo "------------------------------------------------------------------------------"
      echo "🔍 [細項 2-2] 檢查 Cloud SQL 資料庫安全防護（關閉公網 IP、強制 SSL 加密、每日自動備份）"
      echo "   📖 【白話說明卡】："
      echo "   • 🎯 這是做什麼：把資料庫對外公開大門 (Public IP) 關掉、強制連線加密 (SSL)，並設每天凌晨 3 點自動備份。"
      echo "   • ⚠️ 為什麼要做：開公網 IP 會被全世界駭客機器人暴力猜密碼；沒開自動備份萬一誤刪藏家資料就救不回來。"
      echo "   • ✨ 有什麼好處：外人連資料庫大門都摸不到，誤刪也能隨時還原；設定本身完全免費 (NT\$0)。"
      echo "------------------------------------------------------------------------------"
      echo "📌 偵測到 Cloud SQL 實例：${SQL_INSTANCE} (目前規格: ${CURRENT_TIER}, 狀態策略: ${ACTIVATION_POLICY})"

      # 5a. 公網 IP 檢查
      if [ "$IPV4_ENABLED" = "False" ] || [ "$IPV4_ENABLED" = "false" ] || [ -z "$IPV4_ENABLED" ]; then
        echo "✅ [已存在，自動跳過] Cloud SQL 公網 IP (Public IP) 已關閉，外部網路無法直接掃描攻擊。"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        add_stage_log "| 細項 2-2a | Cloud SQL 關閉對外公網 IP | ✅ 已符合（公網 IP 已關閉） |"
      else
        echo "⚠️  [尚未設定] Cloud SQL 目前開啟了公網 IP (ipv4Enabled=${IPV4_ENABLED})！"
        if [ "$MODE" = "interactive" ]; then
          read -r -p "👉 [可選細項] 是否現在關閉 ${SQL_INSTANCE} 的公網 IP？（請先確認已設好內網連線，或按 N 先跳過）[y/N]: " disable_ip
          if [[ "$disable_ip" =~ ^[Yy]$ ]]; then
            gcloud sql instances patch "$SQL_INSTANCE" --no-assign-ip --project="$PROJECT_ID"
            echo "✅ 已關閉 ${SQL_INSTANCE} 公網 IP！"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            add_stage_log "| 細項 2-2a | Cloud SQL 關閉對外公網 IP | 🔧 本次已關閉公網 IP |"
          else
            echo "⏭️  [本次暫緩跳過] 保留公網 IP 現況。"
            DEFERRED_COUNT=$((DEFERRED_COUNT + 1))
            add_stage_log "| 細項 2-2a | Cloud SQL 關閉對外公網 IP | ⏭️ 本次暫緩跳過 |"
          fi
        else
          add_stage_log "| 細項 2-2a | Cloud SQL 關閉對外公網 IP | ⚠️ 尚未關閉 (ipv4Enabled=${IPV4_ENABLED}) |"
        fi
      fi

      # 5b. SSL 加密檢查
      if [ "$REQUIRE_SSL" = "True" ] || [ "$REQUIRE_SSL" = "true" ]; then
        echo "✅ [已存在，自動跳過] Cloud SQL 已啟用強制 SSL 加密連線 (requireSsl=True)。"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        add_stage_log "| 細項 2-2b | Cloud SQL 強制 SSL 加密連線 | ✅ 已符合（已啟用） |"
      else
        echo "⚠️  [尚未設定] Cloud SQL 尚未強制要求 SSL 連線！"
        if [ "$MODE" = "interactive" ]; then
          read -r -p "👉 [可選細項] 是否開啟強制 SSL 加密連線？[y/N]: " enable_ssl
          if [[ "$enable_ssl" =~ ^[Yy]$ ]]; then
            gcloud sql instances patch "$SQL_INSTANCE" --require-ssl --project="$PROJECT_ID"
            echo "✅ 已開啟強制 SSL 連線！"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            add_stage_log "| 細項 2-2b | Cloud SQL 強制 SSL 加密連線 | 🔧 本次已開啟 |"
          else
            DEFERRED_COUNT=$((DEFERRED_COUNT + 1))
            add_stage_log "| 細項 2-2b | Cloud SQL 強制 SSL 加密連線 | ⏭️ 本次暫緩跳過 |"
          fi
        else
          add_stage_log "| 細項 2-2b | Cloud SQL 強制 SSL 加密連線 | ⚠️ 尚未啟用 |"
        fi
      fi

      # 5c. 自動備份檢查
      if [ "$BACKUP_ENABLED" = "True" ] || [ "$BACKUP_ENABLED" = "true" ]; then
        echo "✅ [已存在，自動跳過] Cloud SQL 已啟用每日自動備份 (backupConfiguration.enabled=True)。"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        add_stage_log "| 細項 2-2c | Cloud SQL 每日自動備份 (${BACKUP_RETENTION_DAYS}天) | ✅ 已符合（已啟用） |"
      else
        echo "⚠️  [尚未設定] Cloud SQL 尚未啟用每日自動備份！"
        if [ "$MODE" = "interactive" ]; then
          read -r -p "👉 [可選細項] 是否立即開啟每日自動備份（保留 ${BACKUP_RETENTION_DAYS} 天）？[y/N]: " enable_bak
          if [[ "$enable_bak" =~ ^[Yy]$ ]]; then
            gcloud sql instances patch "$SQL_INSTANCE" --backup-start-time=03:00 --retained-backups-count="$BACKUP_RETENTION_DAYS" --project="$PROJECT_ID"
            echo "✅ 已開啟每日凌晨 03:00 自動備份（保留 ${BACKUP_RETENTION_DAYS} 份）！"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            add_stage_log "| 細項 2-2c | Cloud SQL 每日自動備份 (${BACKUP_RETENTION_DAYS}天) | 🔧 本次已開啟 |"
          else
            DEFERRED_COUNT=$((DEFERRED_COUNT + 1))
            add_stage_log "| 細項 2-2c | Cloud SQL 每日自動備份 (${BACKUP_RETENTION_DAYS}天) | ⏭️ 本次暫緩跳過 |"
          fi
        else
          add_stage_log "| 細項 2-2c | Cloud SQL 每日自動備份 (${BACKUP_RETENTION_DAYS}天) | ⚠️ 尚未啟用 |"
        fi
      fi
    fi

    if should_run_item 6; then
      echo ""
      echo "------------------------------------------------------------------------------"
      echo "💬 [細項 2-3] 互動選擇 Cloud SQL 資料庫規格與月租方案（目前規格：${CURRENT_TIER}）"
      echo "   📖 【白話說明卡】："
      echo "   • 🎯 這是做什麼：決定存放藏家資料的雲端資料庫主機大小與開機時段（系統最主要的固定月租來源）。"
      echo "   • ⚠️ 為什麼要做：選太小多人用會卡，選太大一個月白花一兩千元；透過選單可精準鎖定在預算甜蜜點。"
      echo "   • 🛡️ 安全性保障：換規格只會重啟約 2～3 分鐘，裡面的藏家與畫作資料 100% 完好無損，隨時可再改。"
      echo "------------------------------------------------------------------------------"
      echo "   請依部門實際使用人數與預算（參考目標：約 NT\$${DB_TARGET_MONTHLY_NTD}/月）評估以下 6 種選項："
      echo ""
      echo "   [1] 維持現有規格 (${CURRENT_TIER}) — 不做任何變更（直接跳過）"
      echo "   [2] 最省錢方案：db-f1-micro (0.6 GB RAM，24h 開機)          ➔ 預估月租：約 NT\$280～350 / 月"
      echo "   [3] 🌟 推薦 500–600 甜區 A：db-g1-small (1.7 GB RAM 順暢版) ＋ 平日上下班自動啟停排程"
      echo "       (平日 08:00–22:00 開機，夜間與週末休眠省 58% 運算費；EDM 排程請設於上班時段) ➔ 預估月租：約 NT\$480～560 / 月"
      echo "   [4] 🌟 24h 500–600 甜區 B：db-f1-micro (0.6 GB RAM，24h 開機) ＋ 50GB SSD ＋ 30天 PITR 時間點還原"
      echo "       (適合半夜週末也要排程寄送 EDM、且重視大容量與長天數完整備份) ➔ 預估月租：約 NT\$500～580 / 月"
      echo "   [5] 全天候順暢方案：db-g1-small (1.7 GB RAM，24h 不關機)    ➔ 預估月租：約 NT\$780～880 / 月"
      echo "   [6] 正式高併發方案：db-custom-1-3840 (1 獨立 vCPU / 3.75GB) ➔ 預估月租：約 NT\$1,700～1,950 / 月"
      echo ""

      if [ "$MODE" = "interactive" ] || [ "$MODE" = "dry-run" ]; then
        if [ "$MODE" = "dry-run" ]; then
          tier_choice="3"
          echo "👉 [Dry-Run 模擬選擇]: 模擬選 [3] 推薦 500–600 甜區方案 A (db-g1-small 平日排程，約 NT\$480～560/月)"
        else
          read -r -p "👉 [可選細項] 請輸入方案編號 [1-6，直接按 Enter 預設選 1 維持現況跳過]: " tier_choice
          tier_choice="${tier_choice:-1}"
        fi

        case "$tier_choice" in
          1)
            echo "✅ [維持現況，自動跳過] 保留目前規格 ${CURRENT_TIER}。"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            if [ "$CURRENT_TIER" = "db-f1-micro" ]; then
              SAVED_DB_CHOICE_LABEL="維持現況：db-f1-micro (24h 開機)"
              SAVED_DB_MIN_NTD=280
              SAVED_DB_MAX_NTD=350
            else
              SAVED_DB_CHOICE_LABEL="維持現況：${CURRENT_TIER}"
              SAVED_DB_MIN_NTD=480
              SAVED_DB_MAX_NTD=880
            fi
            add_stage_log "| 細項 2-3 | Cloud SQL 資料庫月租規格選型 | ✅ 維持現有規格 (${CURRENT_TIER}) |"
            ;;
          2)
            echo "🔧 正在將 ${SQL_INSTANCE} 調整為 db-f1-micro..."
            [ "$MODE" != "dry-run" ] && gcloud sql instances patch "$SQL_INSTANCE" --tier=db-f1-micro --project="$PROJECT_ID"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            SAVED_DB_CHOICE_LABEL="方案 2：db-f1-micro (0.6GB RAM，24h 開機)"
            SAVED_DB_MIN_NTD=280
            SAVED_DB_MAX_NTD=350
            add_stage_log "| 細項 2-3 | Cloud SQL 資料庫月租規格選型 | 🔧 已選方案 2：db-f1-micro (約 NT\$280～350/月) |"
            ;;
          3)
            echo "🔧 正在將 ${SQL_INSTANCE} 調整為 db-g1-small (1.7 GB RAM)，並套用上下班排程說明..."
            if [ "$CURRENT_TIER" != "db-g1-small" ]; then
              [ "$MODE" != "dry-run" ] && gcloud sql instances patch "$SQL_INSTANCE" --tier=db-g1-small --project="$PROJECT_ID"
            else
              echo "   (實例已經是 db-g1-small，無須重設機型)"
            fi
            echo "💡 【上下班自動啟停與 EDM 排程提醒】：請將 EDM 發送排程設於平日 08:30–21:30 資料庫開機時段內，即可將月租穩定控制在 NT\$480～560！"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            SAVED_DB_CHOICE_LABEL="方案 3A：db-g1-small (1.7GB RAM) + 平日 08:00-22:00 開機排程"
            SAVED_DB_MIN_NTD=480
            SAVED_DB_MAX_NTD=560
            add_stage_log "| 細項 2-3 | Cloud SQL 資料庫月租規格選型 | 🔧 已選方案 3A：db-g1-small 平日排程 (約 NT\$480～560/月) |"
            ;;
          4)
            echo "🔧 正在將 ${SQL_INSTANCE} 設定為 db-f1-micro + 50GB SSD + 30 天備份與 PITR..."
            [ "$MODE" != "dry-run" ] && gcloud sql instances patch "$SQL_INSTANCE" \
              --tier=db-f1-micro \
              --storage-size=50GB \
              --retained-backups-count=30 \
              --enable-point-in-time-recovery \
              --project="$PROJECT_ID"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            SAVED_DB_CHOICE_LABEL="方案 3B：db-f1-micro (24h) + 50GB SSD + 30天 PITR 備份"
            SAVED_DB_MIN_NTD=500
            SAVED_DB_MAX_NTD=580
            add_stage_log "| 細項 2-3 | Cloud SQL 資料庫月租規格選型 | 🔧 已選方案 3B：db-f1-micro + 50GB + 30天PITR (約 NT\$500～580/月) |"
            ;;
          5)
            echo "🔧 正在將 ${SQL_INSTANCE} 調整為 db-g1-small (24h 全天候運行)..."
            [ "$MODE" != "dry-run" ] && gcloud sql instances patch "$SQL_INSTANCE" --tier=db-g1-small --project="$PROJECT_ID"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            SAVED_DB_CHOICE_LABEL="方案 5：db-g1-small (1.7GB RAM，24h 不關機)"
            SAVED_DB_MIN_NTD=780
            SAVED_DB_MAX_NTD=880
            add_stage_log "| 細項 2-3 | Cloud SQL 資料庫月租規格選型 | 🔧 已選方案 5：db-g1-small 24h (約 NT\$780～880/月) |"
            ;;
          6)
            echo "🔧 正在將 ${SQL_INSTANCE} 調整為 db-custom-1-3840 (獨立核心)..."
            [ "$MODE" != "dry-run" ] && gcloud sql instances patch "$SQL_INSTANCE" --tier=db-custom-1-3840 --project="$PROJECT_ID"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            SAVED_DB_CHOICE_LABEL="方案 6：db-custom-1-3840 (1 vCPU / 3.75GB RAM，24h)"
            SAVED_DB_MIN_NTD=1700
            SAVED_DB_MAX_NTD=1950
            add_stage_log "| 細項 2-3 | Cloud SQL 資料庫月租規格選型 | 🔧 已選方案 6：db-custom-1-3840 (約 NT\$1,700～1,950/月) |"
            ;;
          *)
            echo "ℹ️  未識別的選項，保留現有規格 ${CURRENT_TIER}。"
            add_stage_log "| 細項 2-3 | Cloud SQL 資料庫月租規格選型 | ℹ️ 保留現有規格 (${CURRENT_TIER}) |"
            ;;
        esac
      fi
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 關卡 7 (細項 2-4)：【🟢 非必要選配 1】AI 呼叫架構選型（AI Studio Paid Tier vs. Vertex AI）
# ------------------------------------------------------------------------------
if should_run_item 7; then
  echo ""
  echo "------------------------------------------------------------------------------"
  echo "💬 [細項 2-4] 【🟢 非必要選配項】是否啟用企業級 Vertex AI？（預設維持 AI Studio Paid Tier 跳過）"
  echo "   📖 【白話說明卡】："
  echo "   • 🎯 這是做什麼：選擇維持「Google AI Studio (Paid Tier)」或改接大型企業用的「Vertex AI」。"
  echo "   • ⚠️ 為什麼列為非必要：只要在細項 1-1 綁好計費切為 Paid Tier，目前的 AI Studio 就已經享有【100% 不拿資料"
  echo "     訓練模型】的保障，而且還能保留 AI Studio 一鍵部署更新功能！因此現階段完全不需要換。"
  echo "   • ✨ 什麼時候才需要開：未來若跨部門擴編、要求鎖定台灣彰濱機房 (asia-east1) 且免除 API Key 時再選開啟。"
  echo "------------------------------------------------------------------------------"

  VERTEX_ENABLED="false"
  if [ "$MODE" = "dry-run" ]; then
    VERTEX_ENABLED="false"
  else
    if gcloud services list --enabled --project="$PROJECT_ID" --filter="config.name:aiplatform.googleapis.com" --format="value(config.name)" 2>/dev/null | grep -q "aiplatform.googleapis.com"; then
      VERTEX_ENABLED="true"
    fi
  fi

  if [ "$VERTEX_ENABLED" = "true" ]; then
    echo "✅ [已存在，自動跳過] 專案已啟用 Vertex AI API (aiplatform.googleapis.com)！"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    SAVED_VERTEX_STATUS="已啟用 Vertex AI API（依實際呼叫字數計費，無底租）"
    add_stage_log "| 細項 2-4 | [選配] 啟用 Vertex AI API | ✅ 已啟用 |"
  else
    if [ "$MODE" = "interactive" ] || [ "$MODE" = "dry-run" ]; then
      echo "   [1] 維持 Google AI Studio（Paid Tier 付費層）＋ Secret Manager 金鑰隔離（預設推薦，直接跳過）"
      echo "   [2] 選配啟用 Google Cloud Vertex AI（自動開啟 API 並授權 Cloud Run 服務帳戶）"
      if [ "$MODE" = "dry-run" ]; then
        ai_arch_choice="1"
        echo "👉 [Dry-Run 模擬選擇]: 預設選 [1] 維持 Google AI Studio (Paid Tier，跳過)"
      else
        read -r -p "👉 [可選細項] 請輸入您的選擇 [1-2，直接按 Enter 預設選 1 跳過]: " ai_arch_choice
        ai_arch_choice="${ai_arch_choice:-1}"
      fi

      if [ "$ai_arch_choice" = "2" ]; then
        echo "🔧 正在啟用 Vertex AI API (aiplatform.googleapis.com) 並配置 IAM 權限..."
        if [ "$MODE" != "dry-run" ]; then
          gcloud services enable aiplatform.googleapis.com --project="$PROJECT_ID"
          PROJECT_NUM="$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)" 2>/dev/null || true)"
          if [ -n "$PROJECT_NUM" ]; then
            gcloud projects add-iam-policy-binding "$PROJECT_ID" \
              --member="serviceAccount:${PROJECT_NUM}-compute@developer.gserviceaccount.com" \
              --role="roles/aiplatform.user" >/dev/null
          fi
        fi
        echo "✅ 已啟用 Vertex AI API 並完成服務帳戶授權（roles/aiplatform.user）！"
        FIXED_COUNT=$((FIXED_COUNT + 1))
        SAVED_VERTEX_STATUS="已啟用 Vertex AI API（依實際呼叫字數計費，無底租）"
        add_stage_log "| 細項 2-4 | [選配] 啟用 Vertex AI API | 🔧 本次已選配啟用 |"
      else
        echo "✅ [非必要選配，跳過] 維持採用 Google AI Studio (Paid Tier) 架構。"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        SAVED_VERTEX_STATUS="未啟用（維持 AI Studio Paid Tier，NT\$0 額外底租）"
        add_stage_log "| 細項 2-4 | [選配] 啟用 Vertex AI API | ⏭️ 非必要選配，維持 AI Studio Paid Tier |"
      fi
    else
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      add_stage_log "| 細項 2-4 | [選配] 啟用 Vertex AI API | ⏭️ 未啟用（維持 AI Studio Paid Tier） |"
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 關卡 8 (細項 2-5)：【🟢 非必要選配 2】排程自動發送客製化 EDM 之 Cloud Scheduler 檢查與啟用
# ------------------------------------------------------------------------------
if should_run_item 8; then
  echo ""
  echo "------------------------------------------------------------------------------"
  echo "💬 [細項 2-5] 【🟢 非必要選配項】排程自動發送客製化 EDM（以人推畫／以畫推人）之定時器檢查與啟用"
  echo "   📖 【白話說明卡】："
  echo "   • 🎯 這是做什麼：開啟 Google 雲端定時鬧鐘 (Cloud Scheduler) 與發信密鑰槽位，供系統定時自動寄出推薦信。"
  echo "   • ⚠️ 為什麼列為非必要：若目前僅由業務同仁在網頁查詢推薦、或手動按按鈕寄信，完全不需要開背景定時器。"
  echo "   • 💰 費用與影響：Cloud Scheduler 每月前 3 個排程免費 (NT\$0)；搭配 Resend/Brevo 免費層（月免 3,000～9,000 封）亦為 NT\$0。"
  echo "------------------------------------------------------------------------------"

  SCHEDULER_ENABLED="false"
  if [ "$MODE" = "dry-run" ]; then
    SCHEDULER_ENABLED="false"
  else
    if gcloud services list --enabled --project="$PROJECT_ID" --filter="config.name:cloudscheduler.googleapis.com" --format="value(config.name)" 2>/dev/null | grep -q "cloudscheduler.googleapis.com"; then
      SCHEDULER_ENABLED="true"
    fi
  fi

  CHECK_EDM_SECRETS="false"

  if [ "$SCHEDULER_ENABLED" = "true" ]; then
    echo "✅ [已存在，自動跳過] Cloud Scheduler 排程服務 API (cloudscheduler.googleapis.com) 已啟用！"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    CHECK_EDM_SECRETS="true"
    SAVED_EDM_STATUS="已啟用 Cloud Scheduler（前 3 個排程 NT\$0 + Resend/Brevo 免費額度內 NT\$0）"
    SAVED_EDM_MAX_NTD=0
    add_stage_log "| 細項 2-5 | [選配] 排程自動發送 EDM (Cloud Scheduler) | ✅ 已啟用 |"
  else
    if [ "$MODE" = "interactive" ] || [ "$MODE" = "dry-run" ]; then
      echo "   [1] 暫不啟用（非必要選項：維持人工手動操作或留待後續擴充，直接跳過）"
      echo "   [2] 選配啟用 Cloud Scheduler API 並檢查/建立 EDM 專屬密鑰 (EDM_API_KEY / CRON_SECRET)"
      if [ "$MODE" = "dry-run" ]; then
        edm_sched_choice="1"
        echo "👉 [Dry-Run 模擬選擇]: 預設選 [1] 暫不啟用排程自動發送 EDM (跳過)"
      else
        read -r -p "👉 [可選細項] 請輸入您的選擇 [1-2，直接按 Enter 預設選 1 跳過]: " edm_sched_choice
        edm_sched_choice="${edm_sched_choice:-1}"
      fi

      if [ "$edm_sched_choice" = "2" ]; then
        echo "🔧 正在啟用 Cloud Scheduler API (cloudscheduler.googleapis.com)..."
        if [ "$MODE" != "dry-run" ]; then
          gcloud services enable cloudscheduler.googleapis.com --project="$PROJECT_ID"
        fi
        echo "✅ 已啟用 Cloud Scheduler API！單日發送上限建議鎖定 ${EDM_DAILY_SEND_LIMIT} 封。"
        FIXED_COUNT=$((FIXED_COUNT + 1))
        CHECK_EDM_SECRETS="true"
        SAVED_EDM_STATUS="已啟用 Cloud Scheduler（前 3 個排程 NT\$0 + Resend/Brevo 免費層 NT\$0）"
        SAVED_EDM_MAX_NTD=0
        add_stage_log "| 細項 2-5 | [選配] 排程自動發送 EDM (Cloud Scheduler) | 🔧 本次已選配啟用 |"
      else
        echo "✅ [非必要選配，跳過] 暫不啟用 Cloud Scheduler 自動排程發信。"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        SAVED_EDM_STATUS="未啟用（維持人工操作，NT\$0）"
        SAVED_EDM_MAX_NTD=0
        add_stage_log "| 細項 2-5 | [選配] 排程自動發送 EDM (Cloud Scheduler) | ⏭️ 非必要選配，暫不啟用 |"
      fi
    else
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      add_stage_log "| 細項 2-5 | [選配] 排程自動發送 EDM (Cloud Scheduler) | ⏭️ 未啟用 |"
    fi
  fi

  if [ "$CHECK_EDM_SECRETS" = "true" ]; then
    for EDM_SEC in "EDM_API_KEY" "CRON_SECRET"; do
      if [ "$MODE" != "dry-run" ] && gcloud secrets describe "$EDM_SEC" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo "✅ [已存在，自動跳過] Secret Manager 中已存在 EDM 密鑰：${EDM_SEC}"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        SAVED_SECRET_COUNT=$((SAVED_SECRET_COUNT + 1))
      elif [ "$MODE" = "interactive" ]; then
        read -r -p "👉 [可選細項] 是否順便於 Secret Manager 建立選配之 ${EDM_SEC}？[y/N]: " create_edm_sec
        if [[ "$create_edm_sec" =~ ^[Yy]$ ]]; then
          gcloud services enable secretmanager.googleapis.com --project="$PROJECT_ID"
          read -r -s -p "請貼上 ${EDM_SEC} 的值（輸入時不顯示明文，按 Enter 結束）: " edm_sec_val
          echo ""
          if [ -n "$edm_sec_val" ]; then
            printf "%s" "$edm_sec_val" | gcloud secrets create "$EDM_SEC" --data-file=- --project="$PROJECT_ID"
            echo "✅ 已建立 EDM 密鑰 ${EDM_SEC}！"
            FIXED_COUNT=$((FIXED_COUNT + 1))
            SAVED_SECRET_COUNT=$((SAVED_SECRET_COUNT + 1))
          fi
        fi
      fi
    done
  fi

  if [ -z "$TARGET_ITEM" ]; then
    STAGE2_LAST_RUN="$(date '+%Y-%m-%d %H:%M:%S')"
    STAGE2_SUMMARY="✅ 已執行（資料庫方案：${SAVED_DB_CHOICE_LABEL}；Secret 密鑰數：${SAVED_SECRET_COUNT} 組）"
  fi
fi

# ==============================================================================
# 💰 關卡 9 (獨立精算項目)：雲端服務開啟清單與每月費用精算表 (Cost Estimator)
# ==============================================================================
# 根據 API_QUOTA_RPD 精算 AI 費用：
# 日常使用 (約每日 50~200 次 Gemini Flash 呼叫) 約 NT$15~60/月
# 極端滿載封頂 (天天打滿 API_QUOTA_RPD 次，以每 1,000 次約 NT$6~10 估算)：
AI_DAILY_NORMAL_MIN_NTD=15
AI_DAILY_NORMAL_MAX_NTD=60
AI_CAP_MONTHLY_MIN_NTD=$(( (API_QUOTA_RPD * 30 * 3) / 1000 ))
AI_CAP_MONTHLY_MAX_NTD=$(( (API_QUOTA_RPD * 30 * 10) / 1000 ))
[ "$AI_CAP_MONTHLY_MIN_NTD" -lt 30 ] && AI_CAP_MONTHLY_MIN_NTD=30
[ "$AI_CAP_MONTHLY_MAX_NTD" -lt 90 ] && AI_CAP_MONTHLY_MAX_NTD=90

TOTAL_NORMAL_MIN_NTD=$(( SAVED_DB_MIN_NTD + AI_DAILY_NORMAL_MIN_NTD ))
TOTAL_NORMAL_MAX_NTD=$(( SAVED_DB_MAX_NTD + AI_DAILY_NORMAL_MAX_NTD ))
TOTAL_CAP_MIN_NTD=$(( SAVED_DB_MIN_NTD + AI_CAP_MONTHLY_MIN_NTD + SAVED_EDM_MAX_NTD ))
TOTAL_CAP_MAX_NTD=$(( SAVED_DB_MAX_NTD + AI_CAP_MONTHLY_MAX_NTD + SAVED_EDM_MAX_NTD ))

if [ "$TOTAL_NORMAL_MAX_NTD" -le "$BUDGET_MONTHLY_NTD" ]; then
  BUDGET_VERDICT="✅ 安全合規（日常預估總月費 NT\$${TOTAL_NORMAL_MIN_NTD}～${TOTAL_NORMAL_MAX_NTD} 低於您設定的每月預算警示上限 NT\$${BUDGET_MONTHLY_NTD}）"
else
  BUDGET_VERDICT="⚠️ 注意：您選擇的資料庫方案日常預估總月費 (NT\$${TOTAL_NORMAL_MIN_NTD}～${TOTAL_NORMAL_MAX_NTD}) 高於目前設定的預算警示值 (NT\$${BUDGET_MONTHLY_NTD})，建議將每月預算警示調高至 NT\$$(( TOTAL_NORMAL_MAX_NTD + 300 ))。"
fi

echo ""
echo "=============================================================================="
echo " 💰 【雲端服務開啟清單與每月費用精算表 (Cost Estimator)】"
echo "=============================================================================="
echo " 1. [網站容器主機] Google Cloud Run          ：已啟用 | 免費額度內 (月免 200 萬次請求) ➔ 預估月費：NT\$0"
echo " 2. [關聯式資料庫] Google Cloud SQL          ：${SAVED_DB_CHOICE_LABEL}"
echo "                                              ➔ 預估固定月租：約 NT\$${SAVED_DB_MIN_NTD} ～ NT\$${SAVED_DB_MAX_NTD} / 月"
echo " 3. [AI 推薦引擎]  Gemini API (Paid Tier)    ：每日上限鎖定 ${API_QUOTA_RPD} 次/日"
echo "                                              ➔ 日常預估月費：約 NT\$${AI_DAILY_NORMAL_MIN_NTD} ～ NT\$${AI_DAILY_NORMAL_MAX_NTD} / 月（天天滿載封頂約 NT\$${AI_CAP_MONTHLY_MIN_NTD}～${AI_CAP_MONTHLY_MAX_NTD}/月）"
echo " 4. [雲端保險箱]   Secret Manager            ：目前已建 ${SAVED_SECRET_COUNT} 組密鑰 (前 6 組免費) ➔ 預估月費：NT\$0"
echo " 5. [門禁白名單]   Google OAuth 2.0 Testing  ：已啟用 (基礎驗證永久免費)        ➔ 預估月費：NT\$0"
echo " 6. [選配 AI 平台] Google Cloud Vertex AI    ：${SAVED_VERTEX_STATUS}"
echo " 7. [選配排程發信] Cloud Scheduler + EDM API ：${SAVED_EDM_STATUS}"
echo "------------------------------------------------------------------------------"
echo " 📊 【每月預估總花費合計】："
echo "    • 日常營運預估總月費：約 NT\$${TOTAL_NORMAL_MIN_NTD} ～ NT\$${TOTAL_NORMAL_MAX_NTD} / 月"
echo "    • 極端滿載封頂總月費：約 NT\$${TOTAL_CAP_MIN_NTD} ～ NT\$${TOTAL_CAP_MAX_NTD} / 月（受每日 ${API_QUOTA_RPD} 次硬上限保護）"
echo "    • 對照每月預算警示值 (NT\$${BUDGET_MONTHLY_NTD})：${BUDGET_VERDICT}"
echo "=============================================================================="

# ------------------------------------------------------------------------------
# 儲存狀態並自動輸出「單次階段執行報告」與「全部執行累計總報告」
# ------------------------------------------------------------------------------
cat > "$STATE_FILE" <<EOF
STAGE1_LAST_RUN="${STAGE1_LAST_RUN}"
STAGE1_SUMMARY="${STAGE1_SUMMARY}"
STAGE2_LAST_RUN="${STAGE2_LAST_RUN}"
STAGE2_SUMMARY="${STAGE2_SUMMARY}"
STAGE3_LAST_RUN="${STAGE3_LAST_RUN}"
STAGE3_SUMMARY="${STAGE3_SUMMARY}"
SAVED_DB_CHOICE_LABEL="${SAVED_DB_CHOICE_LABEL}"
SAVED_DB_MIN_NTD=${SAVED_DB_MIN_NTD}
SAVED_DB_MAX_NTD=${SAVED_DB_MAX_NTD}
SAVED_VERTEX_STATUS="${SAVED_VERTEX_STATUS}"
SAVED_EDM_STATUS="${SAVED_EDM_STATUS}"
SAVED_EDM_MAX_NTD=${SAVED_EDM_MAX_NTD}
SAVED_SECRET_COUNT=${SAVED_SECRET_COUNT}
SAVED_BUDGET_MONTHLY_NTD=${BUDGET_MONTHLY_NTD}
SAVED_API_QUOTA_RPD=${API_QUOTA_RPD}
SAVED_PROJECT_ID="${PROJECT_ID}"
SAVED_CLOUD_RUN_SERVICE="${CLOUD_RUN_SERVICE}"
SAVED_CLOUD_RUN_URL="${CLOUD_RUN_URL}"
EOF

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
HUMAN_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
SINGLE_REPORT_FILE="${REPORTS_DIR}/stage-${TARGET_STAGE}-report-${TIMESTAMP}.md"
FULL_REPORT_FILE="${REPORTS_DIR}/full-execution-report.md"

{
  echo "# 藏家推薦系統 — 單次執行成果紀錄回報（執行階段：${TARGET_STAGE}）"
  echo ""
  echo "- **執行時間**：${HUMAN_TIME}"
  echo "- **目標 GCP 專案**：\`${PROJECT_ID}\`"
  echo "- **藏家推薦系統網址（Cloud Run）**：${CLOUD_RUN_URL:-未探測到（第三階段改用本機原始碼檢查）}"
  echo "- **執行模式**：\`${MODE}\`（階段參數：\`${TARGET_STAGE}\`）"
  echo "- **統計摘要**：已符合跳過 **${SKIPPED_COUNT}** 項 ｜ 本次完成調整 **${FIXED_COUNT}** 項 ｜ 本次暫緩跳過 **${DEFERRED_COUNT}** 項 ｜ 待網頁確認 **${#MANUAL_TODO_LIST[@]}** 項"
  echo ""
  echo "## 一、 本次執行細項成果清單"
  echo ""
  echo "| 細項編號 | 檢查與設定項目 | 執行結果 |"
  echo "| :--- | :--- | :--- |"
  if [ "${#STAGE_LOG_LINES[@]}" -gt 0 ]; then
    for line in "${STAGE_LOG_LINES[@]}"; do
      echo "$line"
    done
  else
    echo "| 費用精算 | 雲端服務開啟清單與每月費用精算 | ✅ 已完成精算（詳見下方精算表） |"
  fi
  echo ""
  if [ "${#MANUAL_TODO_LIST[@]}" -gt 0 ]; then
    echo "## 二、 尚待於瀏覽器點選確認之項目（點擊直達網址即可完成）"
    echo ""
    for item in "${MANUAL_TODO_LIST[@]}"; do
      echo "- [ ] ${item}"
    done
    echo ""
  fi
  echo "## 三、 💰 雲端服務開啟清單與每月費用精算表"
  echo ""
  echo "| 雲端服務項目 | 目前開啟與設定狀態 | 預估日常月費 (NTD) | 極端滿載封頂月費 (NTD) |"
  echo "| :--- | :--- | :---: | :---: |"
  echo "| **1. Cloud Run（網站容器主機）** | 已啟用（每月前 200 萬次請求免費） | **NT\$0** | 約 NT\$0～50 |"
  echo "| **2. Cloud SQL（關聯式資料庫）** | ${SAVED_DB_CHOICE_LABEL} | **約 NT\$${SAVED_DB_MIN_NTD}～${SAVED_DB_MAX_NTD}** | **約 NT\$${SAVED_DB_MIN_NTD}～${SAVED_DB_MAX_NTD}** |"
  echo "| **3. Gemini AI API（Paid Tier）** | 每日呼叫硬上限鎖定 **${API_QUOTA_RPD} 次/日** | **約 NT\$${AI_DAILY_NORMAL_MIN_NTD}～${AI_DAILY_NORMAL_MAX_NTD}** | **約 NT\$${AI_CAP_MONTHLY_MIN_NTD}～${AI_CAP_MONTHLY_MAX_NTD}** |"
  echo "| **4. Secret Manager（雲端保險箱）** | 已建立 **${SAVED_SECRET_COUNT} 組**密鑰（前 6 組免費） | **NT\$0** | **NT\$0** |"
  echo "| **5. Google OAuth 2.0（白名單登入）** | Testing 模式白名單（永久免費） | **NT\$0** | **NT\$0** |"
  echo "| **6. [選配] Vertex AI API** | ${SAVED_VERTEX_STATUS} | **NT\$0** | 依實際呼叫量 |"
  echo "| **7. [選配] 排程自動發送 EDM** | ${SAVED_EDM_STATUS} | **NT\$0** | **NT\$0**（免費層內） |"
  echo "| **📊 每月預估總花費合計** | **對照每月預算警示上限：NT\$${BUDGET_MONTHLY_NTD} / 月** | **約 NT\$${TOTAL_NORMAL_MIN_NTD}～${TOTAL_NORMAL_MAX_NTD} / 月** | **約 NT\$${TOTAL_CAP_MIN_NTD}～${TOTAL_CAP_MAX_NTD} / 月** |"
  echo ""
  echo "> **預算合規判定**：${BUDGET_VERDICT}"
} > "$SINGLE_REPORT_FILE"

{
  echo "# 藏家推薦系統 — 全部階段執行累計總報告 (Full Execution Report)"
  echo ""
  echo "> 本報告由 Lazy Pack 自動彙整更新，完整記錄第一階段、第二階段、第三階段之最新執行成果與每月雲端費用精算，可直接提供予資訊部與部門主管審閱。"
  echo ""
  echo "- **最後更新時間**：${HUMAN_TIME}"
  echo "- **目標 GCP 專案**：\`${PROJECT_ID}\`"
  echo "- **藏家推薦系統網址（Cloud Run）**：${CLOUD_RUN_URL:-未探測到（第三階段改用本機原始碼檢查）}"
  echo "- **目前設定之每月預算警示上限**：**NT\$${BUDGET_MONTHLY_NTD} / 月**（軟止損提醒鈴）"
  echo "- **目前鎖定之 AI 每日呼叫硬上限**：**${API_QUOTA_RPD} 次 / 日**（硬止損保險絲，每分鐘上限 ${API_QUOTA_RPM} 次）"
  echo ""
  echo "## 一、 三階段執行總覽表（不押特定日期，依實際完成狀態更新）"
  echo ""
  echo "| 階段名稱 | 涵蓋規範項目 | 最新執行時間 | 最新狀態與成果摘要 |"
  echo "| :--- | :--- | :---: | :--- |"
  echo "| **第一階段：立即止血與基礎防護** | 1-1 切換 Paid Tier 零訓練保障<br>1-2 雙 Owner 帳號共管<br>1-3 預算提醒、API 硬上限與 Gmail 白名單 | ${STAGE1_LAST_RUN} | ${STAGE1_SUMMARY} |"
  echo "| **第二階段：系統架構加固與規格選型** | 2-1 Secret Manager 金鑰隔離<br>2-2 Cloud SQL 關公網 IP / SSL / 每日備份<br>2-3 資料庫月租規格選單<br>2-4 & 2-5 選配 Vertex AI / 排程 EDM | ${STAGE2_LAST_RUN} | ${STAGE2_SUMMARY} |"
  echo "| **第三階段：上線前原始碼與 AI 總體檢** | 3-1 原始碼金鑰 0 外洩靜態掃描<br>3-2 20 題 AI 推薦準確度與防套話紅隊測試 | ${STAGE3_LAST_RUN} | ${STAGE3_SUMMARY} |"
  echo ""
  echo "## 二、 💰 雲端服務開啟清單與每月費用精算總表"
  echo ""
  echo "| 雲端服務項目 | 目前開啟與設定狀態 | 預估日常月費 (NTD) | 極端滿載封頂月費 (NTD) |"
  echo "| :--- | :--- | :---: | :---: |"
  echo "| **1. Cloud Run（網站容器主機）** | 已啟用（每月前 200 萬次請求免費） | **NT\$0** | 約 NT\$0～50 |"
  echo "| **2. Cloud SQL（關聯式資料庫）** | ${SAVED_DB_CHOICE_LABEL} | **約 NT\$${SAVED_DB_MIN_NTD}～${SAVED_DB_MAX_NTD}** | **約 NT\$${SAVED_DB_MIN_NTD}～${SAVED_DB_MAX_NTD}** |"
  echo "| **3. Gemini AI API（Paid Tier）** | 每日呼叫硬上限鎖定 **${API_QUOTA_RPD} 次/日** | **約 NT\$${AI_DAILY_NORMAL_MIN_NTD}～${AI_DAILY_NORMAL_MAX_NTD}** | **約 NT\$${AI_CAP_MONTHLY_MIN_NTD}～${AI_CAP_MONTHLY_MAX_NTD}** |"
  echo "| **4. Secret Manager（雲端保險箱）** | 已建立 **${SAVED_SECRET_COUNT} 組**密鑰（前 6 組免費） | **NT\$0** | **NT\$0** |"
  echo "| **5. Google OAuth 2.0（白名單登入）** | Testing 模式白名單（永久免費） | **NT\$0** | **NT\$0** |"
  echo "| **6. [選配] Vertex AI API** | ${SAVED_VERTEX_STATUS} | **NT\$0** | 依實際呼叫量 |"
  echo "| **7. [選配] 排程自動發送 EDM** | ${SAVED_EDM_STATUS} | **NT\$0** | **NT\$0**（免費層內） |"
  echo "| **📊 每月預估總花費合計** | **對照每月預算警示上限：NT\$${BUDGET_MONTHLY_NTD} / 月** | **約 NT\$${TOTAL_NORMAL_MIN_NTD}～${TOTAL_NORMAL_MAX_NTD} / 月** | **約 NT\$${TOTAL_CAP_MIN_NTD}～${TOTAL_CAP_MAX_NTD} / 月** |"
  echo ""
  echo "> **預算合規判定**：${BUDGET_VERDICT}"
} > "$FULL_REPORT_FILE"

echo ""
echo "=============================================================================="
echo " 📄 報告已自動輸出（單次報告 ＋ 全部執行累計總報告）"
echo "=============================================================================="
echo " • 單次執行成果報告：${SINGLE_REPORT_FILE}"
echo " • 全部執行累計總表：${FULL_REPORT_FILE}"
echo "=============================================================================="
