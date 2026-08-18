#!/usr/bin/env bash
# Claude Code Statusline — J.A.R.V.I.S. (Iron Man) カラー版
# 元版: statusline-command.sh（ロジック同一・配色のみ変更）
# 5-line display: session info, 5h usage+尽きる予測, 7d usage+尽きる予測, daily cost, bg agents

set -euo pipefail

input=$(cat)

# ── Colors (Iron Man HUD — red/gold dominant) ──
ACCENT="\033[38;2;255;68;54m"   # ホットロッドレッド (ラベル・アクセント)
GREEN="\033[38;2;255;193;7m"    # ゴールドチタニウム (正常)
YELLOW="\033[38;2;255;145;0m"   # 警告オレンジ
RED="\033[38;2;255;68;54m"      # ホットロッドレッド (危険)
GRAY="\033[38;2;80;105;125m"    # スチールグレー
RESET="\033[0m"

color_for_pct() {
  local pct=$1
  if (( pct >= 80 )); then
    printf '%s' "$RED"
  elif (( pct >= 50 )); then
    printf '%s' "$YELLOW"
  else
    printf '%s' "$GREEN"
  fi
}

# ── Progress bar (10 segments) ──
progress_bar() {
  local pct=$1
  local filled=$(( pct / 10 ))
  local empty=$(( 10 - filled ))
  local color
  color=$(color_for_pct "$pct")
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="▰"; done
  for ((i=0; i<empty; i++)); do bar+="▱"; done
  printf '%b%s%b' "$color" "$bar" "$RESET"
}

# ── Token count formatter (9526776 -> 9.5M, 896487 -> 896k) ──
fmt_tok() {
  awk -v n="$1" 'BEGIN{
    if (n >= 1000000) printf "%.1fM", n/1000000;
    else if (n >= 1000) printf "%.0fk", n/1000;
    else printf "%d", n
  }'
}

# ── Duration formatter (seconds -> "3d 4h" / "2h 5m" / "8m") ──
fmt_dur() {
  local s=$1 d h m out=""
  (( s < 60 )) && { echo "<1m"; return; }
  d=$(( s / 86400 )); h=$(( (s % 86400) / 3600 )); m=$(( (s % 3600) / 60 ))
  (( d > 0 )) && out+="${d}d "
  (( h > 0 )) && out+="${h}h "
  (( d == 0 )) && out+="${m}m"
  echo "${out% }"
}

# ── Arc reactor (常時稼働アニメーション) ──
# refreshInterval=1 で毎秒再実行される前提で、エポック秒から16フレームを決める。
# 1文字セルで表せる回転の最細は点字リングの8方位（切り欠きが回る）なので、
# 各方位×2色相で16分割: グリフは2秒ごとに回転、色は毎秒グラデーションが流れ、
# 16秒で1回転＋グロウが呼吸する。全グリフ半角幅でレイアウトは揺れない。
reactor() {
  local t
  t=$(date +%s)

  # ── 中央の丸ひとつだけ: 12秒周期でゆっくり「ぼわっ」と呼吸する ──
  # グリフの大きさ (◌→○→◎→◉) と色の明るさ (深い青→白) を連動させ、
  # 膨らみながら明るくなり、沈みながら暗くなる。回転要素はなし。
  local glyphs=("◌" "○" "○" "◎" "◉" "◉" "◉" "◉" "◉" "◎" "○" "○")
  local colors=(
    "38;2;21;101;192"   # 最暗 (deep blue)
    "38;2;0;145;234"
    "38;2;0;176;255"
    "38;2;64;196;255"
    "38;2;100;215;255"
    "38;2;160;230;255"
    "38;2;224;247;250"  # ピーク (soft white)
    "38;2;160;230;255"
    "38;2;100;215;255"
    "38;2;64;196;255"
    "38;2;0;176;255"
    "38;2;0;145;234"
  )
  local i=$(( t % 12 ))
  printf '\033[%sm%s\033[0m' "${colors[$i]}" "${glyphs[$i]}"
}

# ── Line 1: Session info ──
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // ""')

# Abbreviate home directory with ~ (mirrors zsh %~)
short_cwd="$cwd"
home="$HOME"
if [ -n "$home" ] && [ "${cwd#"$home"}" != "$cwd" ]; then
  short_cwd="~${cwd#"$home"}"
fi

# Context percentage (integer)
ctx_int=0
if [ -n "$used_pct" ]; then
  printf -v ctx_int "%.0f" "$used_pct" 2>/dev/null || ctx_int="${used_pct%%.*}"
fi
ctx_color=$(color_for_pct "$ctx_int")

# Git branch
git_branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

sep="${GRAY} │ ${RESET}"

line1="$(reactor) ${model}${sep}${GREEN}${short_cwd}${RESET}${sep}${ctx_color}📊 ${ctx_int}%${RESET}${sep}✏️ +${lines_added}/-${lines_removed}"
if [ -n "$git_branch" ]; then
  line1+="${sep}${RED}⎇ ${git_branch}${RESET}"
fi

# ── Line 2/3: 5h / 7d rate limits + 尽きる予測 ──
# Claude Code が statusline 入力 JSON で渡す .rate_limits を使用
# (used_percentage + resets_at[epoch秒])。OAuth/Keychain 不要。
# 尽きる予測 = 経過時間と消費率から現ペースで100%到達までの残り時間を線形外挿。
line2=""
line3=""

build_limit_line() {  # $1=表示ラベル $2=jqキー $3=ウィンドウ秒 -> $REPLY に行をセット
  local label=$1 key=$2 window=$3
  local pct reset_epoch pct_int color bar now
  REPLY=""
  pct=$(echo "$input" | jq -r ".rate_limits.${key}.used_percentage // empty" 2>/dev/null)
  reset_epoch=$(echo "$input" | jq -r ".rate_limits.${key}.resets_at // empty" 2>/dev/null)
  [ -z "$pct" ] && return 0
  printf -v pct_int "%.0f" "$pct" 2>/dev/null || pct_int="${pct%%.*}"
  color=$(color_for_pct "$pct_int")
  bar=$(progress_bar "$pct_int")
  printf -v pct_str "%2d" "$pct_int" 2>/dev/null || pct_str="$pct_int"
  REPLY="${ACCENT}${label}${RESET}  ${bar}  ${color}${pct_str}%${RESET}"

  now=$(date +%s)
  if [ -n "$reset_epoch" ] && (( reset_epoch > now )); then
    local remain=$(( reset_epoch - now ))
    local elapsed=$(( window - remain ))
    if (( pct_int > 0 && elapsed > 60 )); then
      local eta=$(( elapsed * (100 - pct_int) / pct_int ))
      if (( eta < remain )); then
        # リセット前に尽きるペース → 赤で警告
        REPLY+="  ${RED}⌛ ~$(fmt_dur "$eta")${RESET}"
      else
        # このペースならリセットまで持つ → 灰色+✓
        REPLY+="  ${GRAY}⌛ ~$(fmt_dur "$eta") ✓${RESET}"
      fi
    fi
    REPLY+="  ${GRAY}rst $(fmt_dur "$remain")${RESET}"
  fi
  return 0
}

build_limit_line "⏱  5h" five_hour 18000  && line2=$REPLY
build_limit_line "📅 7d" seven_day 604800 && line3=$REPLY

# ── Daily cost (all sessions/windows) ──
# 二層キャッシュ:
#   - today (今日)        : 60秒。--today-only の軽量スキャンで頻繁に更新
#   - rest  (昨日 + 7d)   : 120秒。フルスキャンでまとめて更新
# rest キャッシュ(フル出力)に today を上書きマージして出力する。
COST_CACHE_FILE="/tmp/claude-daily-cost-cache.json"        # フル出力 (rest 用)
COST_TODAY_CACHE_FILE="/tmp/claude-daily-cost-today.json"  # today-only 出力
COST_REST_TTL=120
COST_TODAY_TTL=60
COST_SCRIPT="$HOME/.claude/daily-cost.py"

cache_age() {
  local f=$1 now=$2 cached_at
  [ -f "$f" ] || { echo 999999; return; }
  cached_at=$(jq -r '.cached_at // 0' "$f" 2>/dev/null || echo "0")
  echo $(( now - cached_at ))
}

get_daily_cost() {
  local now
  now=$(date +%s)
  [ -f "$COST_SCRIPT" ] || return 1

  # rest (昨日 + 7d): フル出力を 120秒 キャッシュ
  if (( $(cache_age "$COST_CACHE_FILE" "$now") >= COST_REST_TTL )); then
    local full
    full=$(python3 "$COST_SCRIPT" 2>/dev/null) || full=""
    if [ -n "$full" ]; then
      echo "$full" | jq --arg ts "$now" '. + {cached_at: ($ts | tonumber)}' > "$COST_CACHE_FILE" 2>/dev/null
    fi
  fi

  # today: 軽量スキャンを 60秒 キャッシュ
  if (( $(cache_age "$COST_TODAY_CACHE_FILE" "$now") >= COST_TODAY_TTL )); then
    local todayj
    todayj=$(python3 "$COST_SCRIPT" --today-only 2>/dev/null) || todayj=""
    if [ -n "$todayj" ]; then
      echo "$todayj" | jq --arg ts "$now" '. + {cached_at: ($ts | tonumber)}' > "$COST_TODAY_CACHE_FILE" 2>/dev/null
    fi
  fi

  [ -f "$COST_CACHE_FILE" ] || return 1
  # フル出力に today/today_tokens と 7d 末尾(=今日)の値を上書きマージ
  if [ -f "$COST_TODAY_CACHE_FILE" ]; then
    jq -rc --slurpfile t "$COST_TODAY_CACHE_FILE" '
      del(.cached_at)
      | ($t[0]) as $td
      | .today = ($td.today // .today)
      | .today_tokens = ($td.today_tokens // .today_tokens)
      | .week = ([.week[]? | if .date == $td.date
            then (.cost = $td.today | .tokens = $td.today_tokens) else . end])
    ' "$COST_CACHE_FILE" 2>/dev/null
  else
    jq -rc 'del(.cached_at)' "$COST_CACHE_FILE" 2>/dev/null
  fi
}

# ── モデル別週次枠 (Fable 等): OAuth usage API から取得 ──
# statusline 入力 JSON には five_hour / seven_day しか来ないため、
# /usage 画面と同じ oauth/usage エンドポイントを Keychain トークンで叩く。
# 5分キャッシュ + curl 3秒タイムアウト。失敗時は古いキャッシュを使い続ける。
OAUTH_USAGE_CACHE="/tmp/claude-oauth-usage-cache.json"
OAUTH_USAGE_TTL=300

get_oauth_usage() {
  local now token resp
  now=$(date +%s)
  if (( $(cache_age "$OAUTH_USAGE_CACHE" "$now") >= OAUTH_USAGE_TTL )); then
    token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
      | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null) || token=""
    if [ -n "$token" ]; then
      resp=$(curl -sS --max-time 3 "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null) || resp=""
      if [ -n "$resp" ] && echo "$resp" | jq -e '.limits' >/dev/null 2>&1; then
        echo "$resp" | jq --arg ts "$now" '. + {cached_at: ($ts | tonumber)}' > "$OAUTH_USAGE_CACHE" 2>/dev/null
      fi
    fi
  fi
  [ -f "$OAUTH_USAGE_CACHE" ] && cat "$OAUTH_USAGE_CACHE"
  return 0
}

scoped=$(get_oauth_usage 2>/dev/null \
  | jq -rc '[.limits[]? | select(.kind == "weekly_scoped")][0] // empty' 2>/dev/null) || scoped=""
if [ -n "$scoped" ]; then
  sc_pct=$(echo "$scoped" | jq -r '.percent // 0')
  sc_name=$(echo "$scoped" | jq -r '.scope.model.display_name // "model"')
  printf -v sc_int "%.0f" "$sc_pct" 2>/dev/null || sc_int="${sc_pct%%.*}"
  sc_color=$(color_for_pct "$sc_int")
  sc_str="${ACCENT}${sc_name}${RESET} $(progress_bar "$sc_int") ${sc_color}${sc_int}%${RESET}"
  if [ -n "$line3" ]; then
    line3+="${sep}${sc_str}"
  else
    line3="${ACCENT}📅 7d${RESET}  ${sc_str}"
  fi
fi

line4=""
cost_json=$(get_daily_cost 2>/dev/null || true)
if [ -n "$cost_json" ]; then
  today_cost=$(echo "$cost_json" | jq -r '.today // 0' 2>/dev/null)
  yest_cost=$(echo "$cost_json" | jq -r '.yesterday // 0' 2>/dev/null)
  # $/Mtok efficiency (lower is better); empty when no tokens
  today_eff=$(echo "$cost_json" | jq -r 'if (.today_tokens // 0) > 0 then (.today / (.today_tokens / 1000000) * 100 | round / 100 | tostring) else "" end' 2>/dev/null)
  yest_eff=$(echo "$cost_json" | jq -r 'if (.yesterday_tokens // 0) > 0 then (.yesterday / (.yesterday_tokens / 1000000) * 100 | round / 100 | tostring) else "" end' 2>/dev/null)
  # 7-day sparklines (oldest -> today): cost
  cost_spark=$(echo "$cost_json" | jq -r '
    [.week[]?.cost] | if length == 0 then "" else
      (max) as $m |
      [ .[] | if $m <= 0 then 0 else (. / $m * 7 | floor) end
        | ["▁","▂","▃","▄","▅","▆","▇","█"][.] ] | join("") end' 2>/dev/null)

  # 5h / 7d のローカル集計コスト・トークン量を rate limit 行に追記
  # (rate_limits が来ない環境ではこの値だけで行を構築)
  five_cost=$(echo "$cost_json" | jq -r '.five_hour.cost // 0' 2>/dev/null)
  five_tok=$(echo "$cost_json" | jq -r '.five_hour.tokens // 0' 2>/dev/null)
  seven_cost=$(echo "$cost_json" | jq -r '.seven_day.cost // 0' 2>/dev/null)
  seven_tok=$(echo "$cost_json" | jq -r '.seven_day.tokens // 0' 2>/dev/null)
  five_str="\$${five_cost} / $(fmt_tok "$five_tok") tok"
  seven_str="\$${seven_cost} / $(fmt_tok "$seven_tok") tok"
  if [ -n "$line2" ]; then
    line2+="${sep}${five_str}"
  else
    line2="${ACCENT}⏱  5h${RESET}  ${five_str}"
  fi
  if [ -n "$line3" ]; then
    line3+="${sep}${seven_str}"
  else
    line3="${ACCENT}📅 7d${RESET}  ${seven_str}"
  fi
  [ -n "$cost_spark" ] && line3+="  ${GRAY}${cost_spark}${RESET}"

  # Arrow comparing today vs yesterday
  arrow=$(awk -v t="$today_cost" -v y="$yest_cost" 'BEGIN{ if (t>y) print "↑"; else if (t<y) print "↓"; else print "→" }')
  arrow_color="$GREEN"
  [ "$arrow" = "↑" ] && arrow_color="$YELLOW"
  today_str="Today \$${today_cost}"
  [ -n "$today_eff" ] && today_str+=" (\$${today_eff}/Mtok)"
  yest_str="Yesterday \$${yest_cost}"
  [ -n "$yest_eff" ] && yest_str+=" (\$${yest_eff}/Mtok)"
  line4="${ACCENT}💰${RESET} ${GREEN}${today_str}${RESET}  ${arrow_color}${arrow}${RESET}  ${GRAY}${yest_str}${RESET}"
  # 価格表に無いモデルを検出したら警告 (フォールバック単価で計算されている)
  unknown_models=$(echo "$cost_json" | jq -r '(.unknown_models // []) | join(", ")' 2>/dev/null)
  if [ -n "$unknown_models" ]; then
    line4+="  ${RED}⚠ unpriced: ${unknown_models}${RESET}"
  fi
fi

# ── Line 5: バックグラウンドエージェントの status 別件数 (waiting → busy → idle, 常時表示・自分も含む) ──
# データ元: ~/.claude/sessions/<pid>.json (claude agents --json と同じ live レジストリ)。
# subprocess を起こさずファイル読みのみ。status 語彙: waiting / busy / idle。
line5=""
SESSIONS_DIR="$HOME/.claude/sessions"
if [ -d "$SESSIONS_DIR" ]; then
  counts=$(jq -rs '
    map(select(.kind=="bg"))
    | group_by(.status)
    | map("\(.[0].status)\t\(length)")
    | .[]
  ' "$SESSIONS_DIR"/*.json 2>/dev/null || true)
  w=0; b=0; idl=0; oth=0
  while IFS=$'\t' read -r st n; do
    [ -z "$st" ] && continue
    case "$st" in
      waiting) w=$n ;;
      busy)    b=$n ;;
      idle)    idl=$n ;;
      *)       oth=$((oth + n)) ;;
    esac
  done <<< "$counts"
  # 常時表示: 1以上はその色 (waiting=赤 / busy=金 / idle=橙)、0のときは灰色
  cw=$GRAY; [ "$w"   -gt 0 ] && cw=$RED
  cb=$GRAY; [ "$b"   -gt 0 ] && cb=$GREEN
  ci=$GRAY; [ "$idl" -gt 0 ] && ci=$YELLOW
  parts="${cw}waiting:${w}${RESET}${GRAY} · ${RESET}${cb}busy:${b}${RESET}${GRAY} · ${RESET}${ci}idle:${idl}${RESET}"
  [ "$oth" -gt 0 ] && parts+="${GRAY} · ${RESET}${GRAY}other:${oth}${RESET}"
  line5="$parts"
fi

# ── Output ──
printf '%b' "$line1"
if [ -n "$line2" ]; then
  printf '\n%b' "$line2"
fi
if [ -n "$line3" ]; then
  printf '\n%b' "$line3"
fi
if [ -n "$line4" ]; then
  printf '\n%b' "$line4"
fi
if [ -n "$line5" ]; then
  printf '\n%b' "$line5"
fi
