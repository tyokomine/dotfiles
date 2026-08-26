#!/bin/bash
# Set the cmux tab name to a short Japanese summary of the current Claude session
# topic. Reads Claude Code's auto-generated topic title (surface title) *and* the
# opening exchange from the session transcript, turns the pair into a Japanese tab
# name via `claude -p` (Haiku), and renames the tab. The transcript matters because
# auto-titles are often content-free ("Slack thread consultation") when the prompt
# was just a URL plus "what should we do?" - the actual subject only shows up in the
# first reply. The result is cached per workspace (topic + transcript fingerprint)
# so an unchanged session costs no extra API call.
#
# Every run also re-stamps a "<n>:" prefix on all hook-owned tabs so the number
# matches the ⌘<n> switch shortcut even after tabs are added, closed or reordered.
#
# Hooks are async and topic mode sleeps 8s, so after /clear the OLD session's last
# UserPromptSubmit/Stop hook routinely finishes *after* the new session's
# SessionStart already blanked the tab - and puts the stale topic name back.
# SessionStart therefore records the live session_id per workspace (SESSION file)
# and topic mode exits when its own session_id is not the recorded one.
#
# Modes:
#   (no args)  UserPromptSubmit / Stop: rename tab to the topic summary
#   --blank    SessionStart: on clear/startup, mark the tab as "◌ blank"
# All modes run async and are no-ops outside cmux.

[ -n "$CMUX_WORKSPACE_ID" ] && [ -n "$CMUX_SURFACE_ID" ] || exit 0

# Only the interactive session owns the tab. A headless `claude -p` started inside
# this pane (this hook's own Haiku call, or one typed by hand) inherits CMUX_* and
# fires its own SessionStart/Stop hooks - which would blank the tab and poison the
# cache. Entrypoint is "cli" for the interactive session and "sdk-cli" for -p.
case "${CLAUDE_CODE_ENTRYPOINT:-cli}" in cli) ;; *) exit 0 ;; esac
CMUX_BIN="/Applications/cmux.app/Contents/Resources/bin/cmux"
[ -x "$CMUX_BIN" ] || exit 0

CACHE="${TMPDIR:-/tmp}/cmux_tab_title_${CMUX_WORKSPACE_ID}"
SESSION="${CACHE}.session"   # session_id of the Claude session that currently owns this tab
BLANK_LABEL="◌ blank"

stdin_field() { printf '%s' "$stdin_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1]) or "")' "$1" 2>/dev/null; }

read_topic() {
  "$CMUX_BIN" --json --id-format both list-pane-surfaces --workspace "$CMUX_WORKSPACE_ID" 2>/dev/null \
    | python3 -c '
import json, os, re, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(1)
data = json.loads(raw)
panes = data if isinstance(data, list) else [data]
target = os.environ.get("CMUX_SURFACE_ID", "").upper()
title = ""
for p in panes:
    for s in p.get("surfaces", []):
        if (s.get("id") or "").upper() == target:
            title = (s.get("title") or "").strip()
# Strip the spinner/status glyph Claude Code prefixes to the topic
title = re.sub(r"^[^\w぀-ヿ一-鿿]+", "", title).strip()
if not title or title.lower() in ("claude code", "claude"):
    sys.exit(1)  # no topic generated (fresh/cleared session)
print(title)
'
}

# Pull the opening exchange (first real user prompt + first substantive assistant
# reply) out of the session transcript. Those two are fixed for the life of the
# session, so the fingerprint stays stable and the cache keeps working.
read_context() {
  [ -n "$1" ] && [ -f "$1" ] || return 1
  python3 -c '
import json, re, sys

SKIP = re.compile(r"^\s*<(command-name|command-message|command-args|local-command|system-reminder|user-prompt-submit-hook)")
user_txt = ""
asst_txt = ""
try:
    fh = open(sys.argv[1], encoding="utf-8")
except OSError:
    sys.exit(1)
with fh:
    for line in fh:
        if user_txt and asst_txt:
            break
        try:
            o = json.loads(line)
        except ValueError:
            continue
        if o.get("type") not in ("user", "assistant") or o.get("isMeta"):
            continue
        m = o.get("message") or {}
        c = m.get("content")
        if isinstance(c, list):
            txt = "\n".join(b.get("text", "") for b in c if b.get("type") == "text")
        else:
            txt = c or ""
        txt = txt.strip()
        if not txt or SKIP.match(txt):
            continue
        if m.get("role") == "user":
            if not user_txt:
                user_txt = txt[:300]
        elif not asst_txt and len(txt) >= 60:
            asst_txt = txt[:900]

if not user_txt and not asst_txt:
    sys.exit(1)
print(("最初の依頼:\n" + user_txt + "\n\n最初の回答:\n" + asst_txt).strip())
' "$1" 2>/dev/null
}

# Re-stamp "<n>:" on every tab this hook owns (✳ topic / ◌ blank). Plain
# terminals are skipped: renaming one would pin its title and stop it from
# following the shell's own OSC title.
renumber() {
  "$CMUX_BIN" --json --id-format both list-workspaces 2>/dev/null \
    | python3 -c '
import json, re, subprocess, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
cmux = sys.argv[1]
for w in json.loads(raw).get("workspaces") or []:
    title = (w.get("title") or "").strip()
    base = re.sub(r"^\d+\s*:\s*", "", title)
    if not base.startswith(("✳", "◌")):
        continue
    want = "%d:%s" % (w.get("index", 0) + 1, base)
    if want != title:
        subprocess.run([cmux, "rename-workspace", "--workspace", w["id"], want],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
' "$CMUX_BIN" 2>/dev/null
}

if [ "$1" = "--blank" ]; then
  stdin_json=$(cat)
  src=$(stdin_field source)
  # Whoever just started (fresh, /clear, resume or compact) owns the tab from now
  # on; late hooks from the previous session compare against this and bail out.
  sid=$(stdin_field session_id)
  [ -n "$sid" ] && printf '%s\n' "$sid" > "$SESSION"
  case "$src" in
    clear|startup) ;;
    # resume/compact keep the existing topic name, but a new tab shifts the
    # numbers of the ones below it, so still re-stamp the prefixes
    *) renumber; exit 0 ;;
  esac
  # If the surface still shows the previous topic, map it to the blank label in
  # the cache so a late-running Stop hook doesn't restore the stale topic.
  topic=$(read_topic) && [ -n "$topic" ] && printf '%s\n%s\n' "$topic" "$BLANK_LABEL" > "$CACHE"
  "$CMUX_BIN" rename-workspace --workspace "$CMUX_WORKSPACE_ID" "$BLANK_LABEL" >/dev/null 2>&1
  renumber
  exit 0
fi

stdin_json=$(cat)
transcript=$(stdin_field transcript_path)
sid=$(stdin_field session_id)

# Claude Code refreshes the topic title shortly after the turn starts;
# wait so we read the new topic, not the previous one.
sleep 8

# Checked after the sleep on purpose: a /clear typed during those 8 seconds
# rewrites SESSION, and this (now stale) hook must not rename the blanked tab.
if [ -n "$sid" ] && [ -s "$SESSION" ] && [ "$(sed -n 1p "$SESSION")" != "$sid" ]; then
  exit 0
fi

topic=$(read_topic) || exit 0
[ -n "$topic" ] || exit 0

context=$(read_context "$transcript")
ctx_fp=$(printf '%s' "$context" | shasum | cut -c1-12)

ja=""
if [ -f "$CACHE" ] && [ "$(sed -n 1p "$CACHE")" = "$topic" ]; then
  cached_ja=$(sed -n 2p "$CACHE")
  # Line 3 is the transcript fingerprint. A blank mapping (written by --blank) has
  # none, so check it first and let the stale-topic swallow below handle it.
  if [ "$cached_ja" = "$BLANK_LABEL" ] || [ "$(sed -n 3p "$CACHE")" = "$ctx_fp" ]; then
    ja="$cached_ja"
  fi
fi
# A cached topic→blank mapping only exists to swallow the one late-running Stop
# hook right after /clear. Honor it briefly WITHOUT re-stamping the cache (a
# rewrite would refresh the mtime every turn and make the mapping immortal).
# If the same topic is still active past the window, the mapping was poisoned
# by a race (topic regenerated before --blank ran) — drop it and re-summarize.
if [ "$ja" = "$BLANK_LABEL" ]; then
  cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || echo 0) ))
  [ "$cache_age" -le 120 ] && exit 0
  ja=""
fi

if [ -z "$ja" ] && command -v claude >/dev/null 2>&1; then
  # Sidebar fits ~13 full-width chars, minus the "<n>:" prefix; ask for 11 and hard-trim at 12
  prompt="AIコーディングセッションのタブ名を作ってください。

# 要件
- 日本語11文字以内
- 何の話題かが一目でわかる固有名詞・対象名（機能名・案件名・ツール名・相手先など）を必ず入れる
- 「相談」「検討」「確認」「対応」「調査」「タスク」「スレッド」など中身のない語だけで終わらせない
- 自動生成タイトルが中身のない語だけの場合は、セッション本文から具体的な話題を拾って名前にする
- タブ名の文字列だけを出力する（説明・引用符・記号の装飾は不要）

# 自動生成タイトル
${topic}"
  if [ -n "$context" ]; then
    prompt="${prompt}

# セッション本文（冒頭）
${context}"
  fi
  ja=$(claude -p --model haiku "$prompt" 2>/dev/null \
    | python3 -c '
import sys
s = sys.stdin.read().strip().splitlines()
s = s[-1].strip().strip("\"「」『』 ") if s else ""
print(s[:12])
')
fi
if [ -z "$ja" ]; then
  # Fall back to the original (English) topic, trimmed to the sidebar width
  ja=$(printf '%s' "$topic" | python3 -c 'import sys; s=sys.stdin.read().strip(); print(s[:24] + ("…" if len(s) > 24 else ""))')
fi

# Only real summaries are cached; blank mappings are written solely by --blank
# mode so their mtime marks the /clear moment.
printf '%s\n%s\n%s\n' "$topic" "$ja" "$ctx_fp" > "$CACHE"
"$CMUX_BIN" rename-workspace --workspace "$CMUX_WORKSPACE_ID" "✳ $ja" >/dev/null 2>&1
renumber
exit 0
