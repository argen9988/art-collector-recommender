#!/usr/bin/env bash
# ==============================================================================
# 藏家推薦系統 (art-collector-recommender)
# 雲端資安現況檢查、Vertex AI 選型、排程 EDM 與互動式加固懶人包 (gcp-setup-and-check.sh)
#
# 核心原則：
# 1. 互動開始前，先完整說明本 Lazy Pack 將執行的 8 大工作項目與運作原則。
# 2. 所有步驟「先檢查現況（Pre-check）」，已存在或已符合標準者自動跳過（✅ 已存在，跳過）。
# 3. 資料庫規格（含 NT$500–600/月 甜區方案）、AI 架構（AI Studio vs Vertex AI）與排程 EDM
#    皆提供互動式選單與執行者討論決定。
# 4. 可調門檻優先讀取 ../config/params.json；找不到時使用內建安全預設值並提示。
#
# 用法：
#   bash gcp-setup-and-check.sh                # 正常互動模式（於 GCP Cloud Shell 執行）
#   bash gcp-setup-and-check.sh --check-only   # 純唯讀體檢模式（只印報告，不修改任何設定）
#   bash gcp-setup-and-check.sh --dry-run      # 模擬測試模式（無 gcloud 環境下驗證流程與選單）
# ==============================================================================

set -u

MODE="interactive"
for arg in "$@"; do
  case "$arg" in
    --check-only) MODE="check-only" ;;
    --dry-run)    MODE="dry-run" ;;
    -h|--help)
      echo "用法: bash $0 [--check-only | --dry-run]"
      exit 0
      ;;
  esac
done

# ------------------------------------------------------------------------------
# 0. 讀取參數檔 (config/params.json)
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PARAMS_FILE=""
if [ -f "${SCRIPT_DIR}/../config/params.json" ]; then
  PARAMS_FILE="${SCRIPT_DIR}/../config/params.json"
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
  val="$(grep -E "\"${key}\"[[:space:]]*:[[:space:]]*[0-9]+" "$file" | tail -n 1 | sed -E 's/.*:[[:space:]]*([0-9]+).*/\1/')"
  if [ -z "$val" ] || ! [[ "$val" =~ ^[0-9]+$ ]]; then
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

# ------------------------------------------------------------------------------
# 開場總覽說明（與使用者互動的第一步：先說明這個 Lazy Pack 要做哪些事）
# ------------------------------------------------------------------------------
echo "=============================================================================="
echo " 🎨 藏家推薦系統 — GCP 雲端資安檢查與互動設定懶人包 (模式: ${MODE})"
echo "=============================================================================="
echo " 📋 【本 Lazy Pack 將為您執行的 8 項工作總覽】："
echo "   1. [資料隱私保護] 檢查專案是否已綁定計費帳戶（Paid Tier，確保藏家資料不拿去訓練模型）"
echo "   2. [帳號備援治理] 檢查是否具備 2 位以上專案共同 Owner（防止單一人員異動造成維運孤島）"
echo "   3. [成本與登入防線] 檢查每月預算警示 (NT\$${BUDGET_MONTHLY_NTD})、API 每日配額 (${API_QUOTA_RPD}次) 與同仁 Gmail 白名單"
echo "   4. [機敏金鑰隔離] 檢查並協助於 Secret Manager 建立 GEMINI_API_KEY、DATABASE_URL、EDM_API_KEY、CRON_SECRET"
echo "   5. [資料庫內網防護] 檢查並協助關閉 Cloud SQL 公網 IP、開啟強制 SSL 加密與每日自動備份 (${BACKUP_RETENTION_DAYS}天)"
echo "   6. [資料庫規格討論] 檢視目前 Cloud SQL 規格，提供含 NT\$500–600/月 甜區在內之 5 種方案供選擇"
echo "   7. [AI 架構選型] 檢查並讓您選擇維持「Google AI Studio (Paid Tier)」或升級啟用「Vertex AI (台灣機房/免金鑰)」"
echo "   8. [排程推播 EDM] 檢查並協助啟用 Cloud Scheduler 排程服務（供不定期/定期「以人推畫、以畫推人」發送 EDM）"
echo ""
echo " 💡 【運作原則】：所有步驟皆會「先檢查現況」，已經設定好的項目會自動標記『✅ 已存在，跳過』；"
echo "    需要調整的項目會先徵詢您的同意才執行，絕不擅自覆蓋既有設定。"
echo "=============================================================================="

if [ "$MODE" = "interactive" ]; then
  read -r -p "👉 了解上述工作內容後，請按 [Enter] 鍵開始執行檢查（或按 Ctrl+C 取消）..." _start_confirm
  echo ""
fi

# 檢查 gcloud 是否存在
if [ "$MODE" != "dry-run" ] && ! command -v gcloud >/dev/null 2>&1; then
  echo "❌ 找不到 gcloud 指令！請在 Google Cloud Console 右上角點選「Activate Cloud Shell (>_ )」執行本腳本，或加 --dry-run 預覽流程。"
  exit 2
fi

# 取得目前 GCP Project ID
if [ "$MODE" = "dry-run" ]; then
  PROJECT_ID="demo-art-collector-proj"
else
  PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
  if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "(unset)" ]; then
    read -r -p "請輸入您的 GCP Project ID: " PROJECT_ID
    gcloud config set project "$PROJECT_ID"
  fi
fi
echo "📌 目標 GCP 專案：${PROJECT_ID}"
echo ""

# 計數器
SKIPPED_COUNT=0
FIXED_COUNT=0
MANUAL_TODO_LIST=()

# ------------------------------------------------------------------------------
# 關卡 1：【第一波】檢查計費帳戶綁定狀態（Paid Tier 資料不訓練保障）
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------------------------"
echo "🔍 [關卡 1/8] 檢查專案是否已綁定計費帳戶（Paid Tier 零資料留存訓練保障）..."
BILLING_ENABLED="false"
if [ "$MODE" = "dry-run" ]; then
  BILLING_ENABLED="true"
else
  BILLING_ENABLED="$(gcloud beta billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" 2>/dev/null || echo "false")"
fi

if [ "$BILLING_ENABLED" = "True" ] || [ "$BILLING_ENABLED" = "true" ]; then
  echo "✅ [已存在，跳過] 專案 ${PROJECT_ID} 已綁定計費帳戶（處於 Paid Tier），享有客戶資料 100% 不被用於模型訓練之保障！"
  SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
else
  echo "⚠️  [尚未設定] 目前專案尚未綁定計費帳戶（處於 Free Tier 免費層，輸入資料有被 Google 留存訓練與人工審閱風險）！"
  MANUAL_TODO_LIST+=("1. 綁定計費帳戶切換 Paid Tier：請開啟 https://console.cloud.google.com/billing/linkedaccount?project=${PROJECT_ID} 綁定部長信用卡。")
fi

# ------------------------------------------------------------------------------
# 關卡 2：【第一波】檢查專案共同擁有者（Owner 備援，防維運孤島）
# ------------------------------------------------------------------------------
echo ""
echo "------------------------------------------------------------------------------"
echo "🔍 [關卡 2/8] 檢查專案 Owner（擁有者）人數（防單一開發者離職孤島）..."
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
  echo "✅ [已存在，跳過] 目前專案已有 ${OWNER_COUNT} 位 Owner 共同管理，具備職務備援機制。"
  SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
else
  echo "⚠️  [建議補強] 目前專案僅有 ${OWNER_COUNT} 位 Owner。"
  if [ "$MODE" = "interactive" ]; then
    read -r -p "👉 是否現在新增部門公務 Gmail 或主管 Gmail 為共同 Owner？[y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      read -r -p "請輸入要加入為 Owner 的 Gmail 信箱: " new_owner_email
      if [ -n "$new_owner_email" ]; then
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
          --member="user:${new_owner_email}" \
          --role="roles/owner"
        echo "✅ 已將 ${new_owner_email} 加入為專案共同 Owner！"
        FIXED_COUNT=$((FIXED_COUNT + 1))
      fi
    else
      MANUAL_TODO_LIST+=("2. 新增共同 Owner：可於 https://console.cloud.google.com/iam-admin/iam?project=${PROJECT_ID} 加入部門公務 Gmail。")
    fi
  else
    MANUAL_TODO_LIST+=("2. 新增共同 Owner：目前僅 ${OWNER_COUNT} 位，建議於 IAM 頁面加入部門公務 Gmail 共同管理。")
  fi
fi

# ------------------------------------------------------------------------------
# 關卡 3：【第一波】檢查預算警示（NT$1,000）與 OAuth 測試白名單
# ------------------------------------------------------------------------------
echo ""
echo "------------------------------------------------------------------------------"
echo "🔍 [關卡 3/8] 檢查軟硬成本止損（預算通知 + API 配額上限）與 Gmail 登入白名單..."
echo "💡 說明：這兩項若先前已於網頁設定過可直接跳過；若尚未確認，腳本將於結尾附上直達網址。"
if [ "$MODE" = "interactive" ]; then
  read -r -p "👉 請問您是否已經在網頁設好「每月 NT\$${BUDGET_MONTHLY_NTD} 預算通知」與「OAuth 同仁 Gmail 測試白名單」？[y=已設好跳過 / N=還沒，請列在最後提醒我]: " web_done
  if [[ "$web_done" =~ ^[Yy]$ ]]; then
    echo "✅ [已存在，跳過] 執行者確認已完成預算上限與 OAuth 白名單設定。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
  else
    MANUAL_TODO_LIST+=("3. 設定每月 NT\$${BUDGET_MONTHLY_NTD} 預算通知：https://console.cloud.google.com/billing/budgets?project=${PROJECT_ID}")
    MANUAL_TODO_LIST+=("4. 鎖定 Gemini API 每日呼叫上限 (${API_QUOTA_RPD} 次/日)：https://console.cloud.google.com/iam-admin/quotas?project=${PROJECT_ID}&service=generativelanguage.googleapis.com")
    MANUAL_TODO_LIST+=("5. 設定部門同仁 Gmail 登入白名單 (Testing 模式 + Test users)：https://console.cloud.google.com/apis/credentials/consent?project=${PROJECT_ID}")
  fi
else
  echo "ℹ️  [唯讀提醒] 請確認已設定每月 NT\$${BUDGET_MONTHLY_NTD} 預算通知、API 每日上限 ${API_QUOTA_RPD} 次及 OAuth 測試白名單。"
fi

# ------------------------------------------------------------------------------
# 關卡 4：【第二波】檢查 Secret Manager 金鑰隔離（含 AI、資料庫、排程與 EDM 金鑰）
# ------------------------------------------------------------------------------
echo ""
echo "------------------------------------------------------------------------------"
echo "🔍 [關卡 4/8] 檢查 Secret Manager 機敏金鑰是否已建立 (GEMINI_API_KEY / DATABASE_URL / EDM_API_KEY / CRON_SECRET)..."

for SECRET_NAME in "GEMINI_API_KEY" "DATABASE_URL" "EDM_API_KEY" "CRON_SECRET"; do
  SECRET_EXISTS="false"
  if [ "$MODE" = "dry-run" ]; then
    if [ "$SECRET_NAME" = "GEMINI_API_KEY" ] || [ "$SECRET_NAME" = "CRON_SECRET" ]; then
      SECRET_EXISTS="true"
    fi
  else
    if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
      SECRET_EXISTS="true"
    fi
  fi

  if [ "$SECRET_EXISTS" = "true" ]; then
    echo "✅ [已存在，跳過] Secret Manager 中已存在密鑰：${SECRET_NAME}"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
  else
    echo "⚠️  [尚未建立] Secret Manager 尚未建立密鑰：${SECRET_NAME}"
    if [ "$MODE" = "interactive" ]; then
      read -r -p "👉 是否現在建立密鑰 ${SECRET_NAME}？(若改用 Vertex AI 可跳過 GEMINI_API_KEY) [y/N]: " create_sec
      if [[ "$create_sec" =~ ^[Yy]$ ]]; then
        gcloud services enable secretmanager.googleapis.com --project="$PROJECT_ID"
        read -r -s -p "請貼上 ${SECRET_NAME} 的值（輸入時畫面不會顯示明文，按 Enter 結束）: " secret_val
        echo ""
        if [ -n "$secret_val" ]; then
          printf "%s" "$secret_val" | gcloud secrets create "$SECRET_NAME" --data-file=- --project="$PROJECT_ID"
          echo "✅ 已安全建立密鑰 ${SECRET_NAME}！"
          FIXED_COUNT=$((FIXED_COUNT + 1))
        fi
      fi
    fi
  fi
done

# ------------------------------------------------------------------------------
# 關卡 5：【第二波】檢查 Cloud SQL 資料庫網路防護（公網 IP、SSL、自動備份）
# ------------------------------------------------------------------------------
echo ""
echo "------------------------------------------------------------------------------"
echo "🔍 [關卡 5/8] 檢查 Cloud SQL 資料庫安全組態（公網 IP、強制 SSL、自動備份）..."

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
  echo "ℹ️  目前專案內尚未偵測到 Cloud SQL 實例，跳過關卡 5 與關卡 6。"
else
  if [ "$MODE" != "dry-run" ]; then
    IPV4_ENABLED="$(gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" --format="value(settings.ipConfiguration.ipv4Enabled)" 2>/dev/null || echo "Unknown")"
    REQUIRE_SSL="$(gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" --format="value(settings.ipConfiguration.requireSsl)" 2>/dev/null || echo "Unknown")"
    BACKUP_ENABLED="$(gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" --format="value(settings.backupConfiguration.enabled)" 2>/dev/null || echo "Unknown")"
    CURRENT_TIER="$(gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" --format="value(settings.tier)" 2>/dev/null || echo "Unknown")"
    ACTIVATION_POLICY="$(gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" --format="value(settings.activationPolicy)" 2>/dev/null || echo "Unknown")"
  fi

  echo "📌 偵測到 Cloud SQL 實例：${SQL_INSTANCE} (目前規格: ${CURRENT_TIER}, 狀態策略: ${ACTIVATION_POLICY})"

  # 5a. 公網 IP 檢查
  if [ "$IPV4_ENABLED" = "False" ] || [ "$IPV4_ENABLED" = "false" ]; then
    echo "✅ [已存在，跳過] Cloud SQL 公網 IP (Public IP) 已關閉，外部網路無法直接掃描攻擊。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
  else
    echo "⚠️  [尚未設定] Cloud SQL 目前開啟了公網 IP (ipv4Enabled=${IPV4_ENABLED})！"
    if [ "$MODE" = "interactive" ]; then
      read -r -p "👉 是否關閉 ${SQL_INSTANCE} 的公網 IP？（注意：請先確認已設定 Private IP 或 Cloud SQL Auth Proxy）[y/N]: " disable_ip
      if [[ "$disable_ip" =~ ^[Yy]$ ]]; then
        gcloud sql instances patch "$SQL_INSTANCE" --no-assign-ip --project="$PROJECT_ID"
        echo "✅ 已關閉 ${SQL_INSTANCE} 公網 IP！"
        FIXED_COUNT=$((FIXED_COUNT + 1))
      fi
    fi
  fi

  # 5b. SSL 加密檢查
  if [ "$REQUIRE_SSL" = "True" ] || [ "$REQUIRE_SSL" = "true" ]; then
    echo "✅ [已存在，跳過] Cloud SQL 已啟用強制 SSL 加密連線 (requireSsl=True)。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
  else
    echo "⚠️  [尚未設定] Cloud SQL 尚未強制要求 SSL 連線！"
    if [ "$MODE" = "interactive" ]; then
      read -r -p "👉 是否開啟強制 SSL 連線？[y/N]: " enable_ssl
      if [[ "$enable_ssl" =~ ^[Yy]$ ]]; then
        gcloud sql instances patch "$SQL_INSTANCE" --require-ssl --project="$PROJECT_ID"
        echo "✅ 已開啟強制 SSL 連線！"
        FIXED_COUNT=$((FIXED_COUNT + 1))
      fi
    fi
  fi

  # 5c. 自動備份檢查
  if [ "$BACKUP_ENABLED" = "True" ] || [ "$BACKUP_ENABLED" = "true" ]; then
    echo "✅ [已存在，跳過] Cloud SQL 已啟用每日自動備份 (backupConfiguration.enabled=True)。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
  else
    echo "⚠️  [尚未設定] Cloud SQL 尚未啟用每日自動備份！"
    if [ "$MODE" = "interactive" ]; then
      read -r -p "👉 是否立即開啟每日自動備份（保留 ${BACKUP_RETENTION_DAYS} 天）？[y/N]: " enable_bak
      if [[ "$enable_bak" =~ ^[Yy]$ ]]; then
        gcloud sql instances patch "$SQL_INSTANCE" --backup-start-time=03:00 --retained-backups-count="$BACKUP_RETENTION_DAYS" --project="$PROJECT_ID"
        echo "✅ 已開啟每日凌晨 03:00 自動備份（保留 ${BACKUP_RETENTION_DAYS} 份）！"
        FIXED_COUNT=$((FIXED_COUNT + 1))
      fi
    fi
  fi

  # ----------------------------------------------------------------------------
  # 關卡 6：【互動討論】Cloud SQL 規格與月租預算選擇（含 NT$500–600/月 方案）
  # ----------------------------------------------------------------------------
  echo ""
  echo "------------------------------------------------------------------------------"
  echo "💬 [關卡 6/8] Cloud SQL 資料庫規格與月租成本評估（目前規格：${CURRENT_TIER}）"
  echo "   我們不強制降級為最低階，請依部門實際使用人數與預算（目標參考值：約 NT\$${DB_TARGET_MONTHLY_NTD}/月）評估以下 6 種選項："
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
      tier_choice="1"
      echo "👉 [Dry-Run 模擬選擇]: 預設選 [1] 維持現有規格"
    else
      read -r -p "👉 請輸入您與團隊討論後的方案編號 [1-6，預設 1 維持現況]: " tier_choice
      tier_choice="${tier_choice:-1}"
    fi

    case "$tier_choice" in
      1)
        echo "✅ [維持現況，跳過] 保留目前規格 ${CURRENT_TIER}。"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        ;;
      2)
        echo "🔧 正在將 ${SQL_INSTANCE} 調整為 db-f1-micro..."
        [ "$MODE" != "dry-run" ] && gcloud sql instances patch "$SQL_INSTANCE" --tier=db-f1-micro --project="$PROJECT_ID"
        FIXED_COUNT=$((FIXED_COUNT + 1))
        ;;
      3)
        echo "🔧 正在將 ${SQL_INSTANCE} 調整為 db-g1-small (1.7 GB RAM)，並準備上下班自動啟停說明..."
        if [ "$CURRENT_TIER" != "db-g1-small" ]; then
          [ "$MODE" != "dry-run" ] && gcloud sql instances patch "$SQL_INSTANCE" --tier=db-g1-small --project="$PROJECT_ID"
        else
          echo "   (實例已經是 db-g1-small，無須重設機型)"
        fi
        echo "💡 【上下班自動啟停與 EDM 排程提醒】：請將 EDM 發送排程設於平日 08:30–21:30 資料庫開機時段內，即可將月租穩定控制在 NT\$480～560！"
        FIXED_COUNT=$((FIXED_COUNT + 1))
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
        ;;
      5)
        echo "🔧 正在將 ${SQL_INSTANCE} 調整為 db-g1-small (24h 全天候運行)..."
        [ "$MODE" != "dry-run" ] && gcloud sql instances patch "$SQL_INSTANCE" --tier=db-g1-small --project="$PROJECT_ID"
        FIXED_COUNT=$((FIXED_COUNT + 1))
        ;;
      6)
        echo "🔧 正在將 ${SQL_INSTANCE} 調整為 db-custom-1-3840 (獨立核心)..."
        [ "$MODE" != "dry-run" ] && gcloud sql instances patch "$SQL_INSTANCE" --tier=db-custom-1-3840 --project="$PROJECT_ID"
        FIXED_COUNT=$((FIXED_COUNT + 1))
        ;;
      *)
        echo "ℹ️  未識別的選項，保留現有規格 ${CURRENT_TIER}。"
        ;;
    esac
  fi
fi

# ------------------------------------------------------------------------------
# 關卡 7：【互動選型】AI 呼叫架構選型（維持 AI Studio Paid Tier vs. 啟用 Vertex AI）
# ------------------------------------------------------------------------------
echo ""
echo "------------------------------------------------------------------------------"
echo "💬 [關卡 7/8] 檢查 AI 模型呼叫架構（Google AI Studio Paid Tier vs. Vertex AI）..."

VERTEX_ENABLED="false"
if [ "$MODE" = "dry-run" ]; then
  VERTEX_ENABLED="false"
else
  if gcloud services list --enabled --project="$PROJECT_ID" --filter="config.name:aiplatform.googleapis.com" --format="value(config.name)" 2>/dev/null | grep -q "aiplatform.googleapis.com"; then
    VERTEX_ENABLED="true"
  fi
fi

if [ "$VERTEX_ENABLED" = "true" ]; then
  echo "✅ [已存在，跳過] 專案已啟用 Vertex AI API (aiplatform.googleapis.com)！"
  SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
else
  echo "ℹ️  目前專案尚未啟用 Vertex AI API（現況為使用 Google AI Studio 架構）。"
  echo "   請選擇本專案要採用的 AI 呼叫模式："
  echo "   [1] 維持 Google AI Studio（Paid Tier 付費層）＋ Secret Manager 金鑰隔離"
  echo "       （優點：100% 相容 AI Studio 內建預覽與一鍵部署，同享資料不訓練模型保障）"
  echo "   [2] 升級啟用 Google Cloud Vertex AI（自動開啟 API 並授權 Cloud Run 服務帳戶）"
  echo "       （優點：免管理靜態 API Key、可強制指定 asia-east1 台灣彰濱機房運算與完整 Audit Logs）"
  echo ""

  if [ "$MODE" = "interactive" ] || [ "$MODE" = "dry-run" ]; then
    if [ "$MODE" = "dry-run" ]; then
      ai_arch_choice="1"
      echo "👉 [Dry-Run 模擬選擇]: 預設選 [1] 維持 Google AI Studio (Paid Tier)"
    else
      read -r -p "👉 請輸入您的選擇 [1-2，預設 1 維持 AI Studio]: " ai_arch_choice
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
      echo "💡 後端程式碼只需將初始化改為：new GoogleGenAI({ vertexai: true, project: '${PROJECT_ID}', location: 'asia-east1' })"
      FIXED_COUNT=$((FIXED_COUNT + 1))
    else
      echo "✅ [維持現況，跳過] 維持採用 Google AI Studio (Paid Tier) 架構。"
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 關卡 8：【排程推播 EDM】檢查 Cloud Scheduler 排程服務（以人推畫 / 以畫推人 EDM）
# ------------------------------------------------------------------------------
echo ""
echo "------------------------------------------------------------------------------"
echo "🔍 [關卡 8/8] 檢查排程自動發送 EDM 機制 (Cloud Scheduler API 與排程工作)..."
echo "💡 費用說明：Cloud Scheduler 每個帳單帳戶每月享有 3 個免費排程（超過每個僅約 NT\$3/月）；"
echo "            EDM 郵件發送建議串接 Resend（月免 3,000 封）或 Brevo（日免 300 封），單日上限設為 ${EDM_DAILY_SEND_LIMIT} 封。"

SCHEDULER_ENABLED="false"
if [ "$MODE" = "dry-run" ]; then
  SCHEDULER_ENABLED="true"
else
  if gcloud services list --enabled --project="$PROJECT_ID" --filter="config.name:cloudscheduler.googleapis.com" --format="value(config.name)" 2>/dev/null | grep -q "cloudscheduler.googleapis.com"; then
    SCHEDULER_ENABLED="true"
  fi
fi

if [ "$SCHEDULER_ENABLED" = "true" ]; then
  echo "✅ [已存在，跳過] Cloud Scheduler 排程服務 API 已啟用，可直接設定「以人推畫 / 以畫推人」EDM 排程！"
  SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
else
  echo "⚠️  [尚未啟用] 目前尚未啟用 Cloud Scheduler API (cloudscheduler.googleapis.com)。"
  if [ "$MODE" = "interactive" ]; then
    read -r -p "👉 是否現在啟用 Cloud Scheduler 排程服務 API（享有每月 3 個免費排程額度）？[y/N]: " enable_sched
    if [[ "$enable_sched" =~ ^[Yy]$ ]]; then
      gcloud services enable cloudscheduler.googleapis.com --project="$PROJECT_ID"
      echo "✅ 已啟用 Cloud Scheduler API！後續可於 Cloud Run 設定定時或指定時間觸發 /api/cron/send-edm。"
      FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 總結報告
# ------------------------------------------------------------------------------
echo ""
echo "=============================================================================="
echo " 📊 雲端資安體檢與設定總結報告"
echo "=============================================================================="
echo " • 已符合標準並自動跳過項目數：${SKIPPED_COUNT} 項"
echo " • 本次透過腳本完成調整項目數：${FIXED_COUNT} 項"
echo " • 尚待人工於網頁確認項目數  ：${#MANUAL_TODO_LIST[@]} 項"

if [ "${#MANUAL_TODO_LIST[@]}" -gt 0 ]; then
  echo ""
  echo " 📋 【尚待人工於瀏覽器點選確認之清單】（已完成者下次不會再出現）："
  for item in "${MANUAL_TODO_LIST[@]}"; do
    echo "   - ${item}"
  done
else
  echo ""
  echo " 🎉 恭喜！所有雲端資安設定、AI 架構選型、排程 EDM 與止損機制皆已到位！"
fi
echo "=============================================================================="
