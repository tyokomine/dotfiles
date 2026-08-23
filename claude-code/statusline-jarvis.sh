#!/usr/bin/env bash
# Claude Code Statusline — J.A.R.V.I.S. (Iron Man) カラー版
# 元版: statusline-command.sh（ロジック同一・配色のみ変更）
# 5-line display: session info, 5h usage+尽きる予測, 7d usage+尽きる予測, daily cost, bg agents
#
# 【性能方針】refreshInterval=1 で毎秒・全セッション並列に走るため、外部コマンドの
# exec 回数を最小化してある (jq 3回 + stat 1回 = 常時5回未満)。exec 1回ごとに
# エンドポイントセキュリティ (AV) の検査が挟まるので、ここを増やすと即ファンが回る。
#   - 入力JSON / コスト / OAuth usage は「1フィールド1jq」ではなく1回でまとめて取る
#   - date(1) は使わず $EPOCHSECONDS (bash 5+)
#   - キャッシュ鮮度は埋め込み cached_at ではなくファイル mtime (stat 1回で3ファイル)
#   - awk の数値整形は jq 側 / bash printf に寄せた
#   - git は .git を純bashで探してから呼ぶ (非リポジトリでは exec 0回)
#   - herestring (<<<) は使用禁止: brew bash 5.3.15 が512B超のherestringで恒久ハングする
#     (heredoc一時ファイル経路のバグ、/bin/bash 3.2は正常)。printf | cmd か < <(printf) で代替

set -euo pipefail

input=$(cat)
NOW=$EPOCHSECONDS

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
  local i=$(( NOW % 12 ))
  printf '\033[%sm%s\033[0m' "${colors[$i]}" "${glyphs[$i]}"
}

# ── 入力JSONの全フィールドを1回のjqで取得 (1行1値) ──
_in=$(printf '%s' "$input" | jq -r '
  [ (.model.display_name // ""),
    (.context_window.used_percentage // "" | tostring),
    (.cost.total_lines_added // 0 | tostring),
    (.cost.total_lines_removed // 0 | tostring),
    (.workspace.current_dir // ""),
    (.rate_limits.five_hour.used_percentage // "" | tostring),
    (.rate_limits.five_hour.resets_at // "" | tostring),
    (.rate_limits.seven_day.used_percentage // "" | tostring),
    (.rate_limits.seven_day.resets_at // "" | tostring)
  ] | .[]' 2>/dev/null) || _in=""
declare -a IN=()
mapfile -t IN < <(printf '%s\n' "$_in")
model=${IN[0]:-}
used_pct=${IN[1]:-}
lines_added=${IN[2]:-0}
lines_removed=${IN[3]:-0}
cwd=${IN[4]:-}
rl5_pct=${IN[5]:-}
rl5_reset=${IN[6]:-}
rl7_pct=${IN[7]:-}
rl7_reset=${IN[8]:-}

# ── Line 1: Session info ──
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

# Git branch — .git の有無を純bashで先に確かめ、リポジトリ内だけ git を exec する
has_git_dir() {
  local d=$1
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    [ -e "$d/.git" ] && return 0
    d=${d%/*}
  done
  [ -e "/.git" ]
}
git_branch=""
if [ -n "$cwd" ] && [ -d "$cwd" ] && has_git_dir "$cwd"; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null) || git_branch=""
  if [ -z "$git_branch" ]; then
    git_branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null) || git_branch=""
  fi
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

build_limit_line() {  # $1=表示ラベル $2=pct $3=resets_at $4=ウィンドウ秒 -> $REPLY に行をセット
  local label=$1 pct=$2 reset_epoch=$3 window=$4
  local pct_int color bar pct_str
  REPLY=""
  [ -z "$pct" ] && return 0
  printf -v pct_int "%.0f" "$pct" 2>/dev/null || pct_int="${pct%%.*}"
  color=$(color_for_pct "$pct_int")
  bar=$(progress_bar "$pct_int")
  printf -v pct_str "%2d" "$pct_int" 2>/dev/null || pct_str="$pct_int"
  REPLY="${ACCENT}${label}${RESET}  ${bar}  ${color}${pct_str}%${RESET}"

  if [ -n "$reset_epoch" ] && (( reset_epoch > NOW )); then
    local remain=$(( reset_epoch - NOW ))
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

build_limit_line "⏱  5h" "$rl5_pct" "$rl5_reset" 18000  && line2=$REPLY
build_limit_line "📅 7d" "$rl7_pct" "$rl7_reset" 604800 && line3=$REPLY

# ── キャッシュ鮮度: mtime を stat 1回で3ファイルまとめて取る ──
COST_CACHE_FILE="/tmp/claude-daily-cost-cache.json"        # フル出力 (rest 用)
COST_TODAY_CACHE_FILE="/tmp/claude-daily-cost-today.json"  # today-only 出力
COST_REST_TTL=120
COST_TODAY_TTL=60
COST_SCRIPT="$HOME/.claude/daily-cost.py"
OAUTH_USAGE_CACHE="/tmp/claude-oauth-usage-cache.json"
OAUTH_USAGE_TTL=300

declare -A MT=()
while read -r _n _m; do
  [ -n "${_n:-}" ] && MT["$_n"]=$_m
done < <(stat -f '%N %m' "$COST_CACHE_FILE" "$COST_TODAY_CACHE_FILE" "$OAUTH_USAGE_CACHE" 2>/dev/null || true)
stale() {  # $1=path $2=TTL  (mtime 不明 = 未作成 → stale)
  (( NOW - ${MT["$1"]:-0} >= $2 ))
}

# ── Daily cost (all sessions/windows) ──
# 二層キャッシュ:
#   - today (今日)        : 60秒。--today-only の軽量スキャンで頻繁に更新
#   - rest  (昨日 + 7d)   : 120秒。フルスキャンでまとめて更新
# rest キャッシュ(フル出力)に today を上書きマージし、表示用の値まで1回のjqで作る。
COST_JQ='
def ftok:
  (. // 0) as $n
  | if $n >= 1000000 then
      (($n / 100000 | round) as $t
        | (($t / 10) | floor | tostring) + "." + (($t % 10) | tostring) + "M")
    elif $n >= 1000 then (($n / 1000 | round) | tostring) + "k"
    else ($n | floor | tostring) end;
($t[0]) as $td
| del(.cached_at)
| .today = ($td.today // .today)
| .today_tokens = ($td.today_tokens // .today_tokens)
| .week = ([.week[]? | if .date == $td.date
      then (.cost = $td.today | .tokens = $td.today_tokens) else . end])
| . as $c
| (($c.today // 0)) as $tc
| (($c.yesterday // 0)) as $yc
| [ ($tc | tostring),
    ($yc | tostring),
    (if ($c.today_tokens // 0) > 0
       then ($tc / (($c.today_tokens) / 1000000) * 100 | round / 100 | tostring) else "" end),
    (if ($c.yesterday_tokens // 0) > 0
       then ($yc / (($c.yesterday_tokens) / 1000000) * 100 | round / 100 | tostring) else "" end),
    ([$c.week[]?.cost] | if length == 0 then "" else
      (max) as $m |
      [ .[] | if $m <= 0 then 0 else (. / $m * 7 | floor) end
        | ["▁","▂","▃","▄","▅","▆","▇","█"][.] ] | join("") end),
    (($c.five_hour.cost // 0) | tostring),
    ($c.five_hour.tokens | ftok),
    (($c.seven_day.cost // 0) | tostring),
    ($c.seven_day.tokens | ftok),
    (if $tc > $yc then "↑" elif $tc < $yc then "↓" else "→" end),
    (($c.unknown_models // []) | join(", "))
  ] | .[]'

refresh_cost_caches() {
  [ -f "$COST_SCRIPT" ] || return 0
  local out
  # rest (昨日 + 7d): フル出力を 120秒 キャッシュ
  if stale "$COST_CACHE_FILE" "$COST_REST_TTL"; then
    out=$(python3 "$COST_SCRIPT" 2>/dev/null) || out=""
    [ -n "$out" ] && printf '%s\n' "$out" > "$COST_CACHE_FILE"
  fi
  # today: 軽量スキャンを 60秒 キャッシュ
  if stale "$COST_TODAY_CACHE_FILE" "$COST_TODAY_TTL"; then
    out=$(python3 "$COST_SCRIPT" --today-only 2>/dev/null) || out=""
    [ -n "$out" ] && printf '%s\n' "$out" > "$COST_TODAY_CACHE_FILE"
  fi
  return 0
}
refresh_cost_caches

declare -a C=()
if [ -f "$COST_CACHE_FILE" ]; then
  _c=""
  if [ -f "$COST_TODAY_CACHE_FILE" ]; then
    _c=$(jq -r --slurpfile t "$COST_TODAY_CACHE_FILE" "$COST_JQ" "$COST_CACHE_FILE" 2>/dev/null) || _c=""
  else
    _c=$(jq -r --argjson t '[]' "$COST_JQ" "$COST_CACHE_FILE" 2>/dev/null) || _c=""
  fi
  [ -n "$_c" ] && mapfile -t C < <(printf '%s\n' "$_c")
fi

# ── モデル別週次枠 (Fable 等): OAuth usage API から取得 ──
# statusline 入力 JSON には five_hour / seven_day しか来ないため、
# /usage 画面と同じ oauth/usage エンドポイントを Keychain トークンで叩く。
# 5分キャッシュ + curl 3秒タイムアウト。失敗時は古いキャッシュを使い続ける。
if stale "$OAUTH_USAGE_CACHE" "$OAUTH_USAGE_TTL"; then
  _tok=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
    | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null) || _tok=""
  if [ -n "$_tok" ]; then
    _resp=$(curl -sS --max-time 3 "https://api.anthropic.com/api/oauth/usage" \
      -H "Authorization: Bearer $_tok" \
      -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null) || _resp=""
    if [ -n "$_resp" ] && printf '%s' "$_resp" | jq -e '.limits' >/dev/null 2>&1; then
      printf '%s\n' "$_resp" > "$OAUTH_USAGE_CACHE"
    fi
  fi
fi

declare -a SC=()
if [ -f "$OAUTH_USAGE_CACHE" ]; then
  _s=$(jq -r '
    ([.limits[]? | select(.kind == "weekly_scoped")][0]) as $s
    | if $s == null then empty
      else [ ($s.percent // 0 | tostring), ($s.scope.model.display_name // "model") ] | .[] end
  ' "$OAUTH_USAGE_CACHE" 2>/dev/null) || _s=""
  [ -n "$_s" ] && mapfile -t SC < <(printf '%s\n' "$_s")
fi

if [ -n "${SC[0]:-}" ]; then
  sc_pct=${SC[0]}
  sc_name=${SC[1]:-model}
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
if [ -n "${C[0]:-}" ] || [ -n "${C[1]:-}" ]; then
  today_cost=${C[0]:-0}
  yest_cost=${C[1]:-0}
  today_eff=${C[2]:-}
  yest_eff=${C[3]:-}
  cost_spark=${C[4]:-}
  five_cost=${C[5]:-0}
  five_tok=${C[6]:-0}
  seven_cost=${C[7]:-0}
  seven_tok=${C[8]:-0}
  arrow=${C[9]:-→}
  unknown_models=${C[10]:-}

  # 5h / 7d のローカル集計コスト・トークン量を rate limit 行に追記
  # (rate_limits が来ない環境ではこの値だけで行を構築)
  five_str="\$${five_cost} / ${five_tok} tok"
  seven_str="\$${seven_cost} / ${seven_tok} tok"
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

  # Arrow comparing today vs yesterday (jq 側で算出済み)
  arrow_color="$GREEN"
  [ "$arrow" = "↑" ] && arrow_color="$YELLOW"
  today_str="Today \$${today_cost}"
  [ -n "$today_eff" ] && today_str+=" (\$${today_eff}/Mtok)"
  yest_str="Yesterday \$${yest_cost}"
  [ -n "$yest_eff" ] && yest_str+=" (\$${yest_eff}/Mtok)"
  line4="${ACCENT}💰${RESET} ${GREEN}${today_str}${RESET}  ${arrow_color}${arrow}${RESET}  ${GRAY}${yest_str}${RESET}"
  # 価格表に無いモデルを検出したら警告 (フォールバック単価で計算されている)
  if [ -n "$unknown_models" ]; then
    line4+="  ${RED}⚠ unpriced: ${unknown_models}${RESET}"
  fi
fi

# ── Line 5: バックグラウンドエージェントの status 別件数 (waiting → busy → idle, 常時表示・自分も含む) ──
# データ元: ~/.claude/sessions/<pid>.json (claude agents --json と同じ live レジストリ)。
# status 語彙: waiting / busy / idle。jq 1回のみ (glob が空なら exec しない)。
line5=""
SESSIONS_DIR="$HOME/.claude/sessions"
if [ -d "$SESSIONS_DIR" ]; then
  shopt -s nullglob
  _sess=("$SESSIONS_DIR"/*.json)
  shopt -u nullglob
  if (( ${#_sess[@]} > 0 )); then
    counts=$(jq -rs '
      map(select(.kind=="bg"))
      | group_by(.status)
      | map("\(.[0].status)\t\(length)")
      | .[]
    ' "${_sess[@]}" 2>/dev/null </dev/null) || counts=""
  else
    counts=""
  fi
  w=0; b=0; idl=0; oth=0
  while IFS=$'\t' read -r st n; do
    [ -z "$st" ] && continue
    case "$st" in
      waiting) w=$n ;;
      busy)    b=$n ;;
      idle)    idl=$n ;;
      *)       oth=$((oth + n)) ;;
    esac
  done < <(printf '%s\n' "$counts")
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
