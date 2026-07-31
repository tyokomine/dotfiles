#!/bin/bash
# Set the cmux tab name to a short Japanese summary of the current Claude session
# topic. Reads Claude Code's auto-generated topic title (surface title), converts
# it to Japanese via `claude -p` (Haiku), and renames the tab. The translation is
# cached per workspace so unchanged topics cost no extra API call.
#
# Modes:
#   (no args)  UserPromptSubmit / Stop: rename tab to the topic summary
#   --blank    SessionStart: on clear/startup, mark the tab as "◌ blank"
# All modes run async and are no-ops outside cmux.

[ -n "$CMUX_WORKSPACE_ID" ] && [ -n "$CMUX_SURFACE_ID" ] || exit 0
CMUX_BIN="/Applications/cmux.app/Contents/Resources/bin/cmux"
[ -x "$CMUX_BIN" ] || exit 0

CACHE="${TMPDIR:-/tmp}/cmux_tab_title_${CMUX_WORKSPACE_ID}"
BLANK_LABEL="◌ blank"

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

if [ "$1" = "--blank" ]; then
  stdin_json=$(cat)
  src=$(printf '%s' "$stdin_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("source") or "")' 2>/dev/null)
  case "$src" in
    clear|startup) ;;
    *) exit 0 ;;  # resume/compact keep the existing topic name
  esac
  # If the surface still shows the previous topic, map it to the blank label in
  # the cache so a late-running Stop hook doesn't restore the stale topic.
  topic=$(read_topic) && [ -n "$topic" ] && printf '%s\n%s\n' "$topic" "$BLANK_LABEL" > "$CACHE"
  "$CMUX_BIN" rename-workspace --workspace "$CMUX_WORKSPACE_ID" "$BLANK_LABEL" >/dev/null 2>&1
  exit 0
fi

cat >/dev/null  # hook stdin JSON is unused in topic mode

# Claude Code refreshes the topic title shortly after the turn starts;
# wait so we read the new topic, not the previous one.
sleep 8

topic=$(read_topic) || exit 0
[ -n "$topic" ] || exit 0

ja=""
if [ -f "$CACHE" ] && [ "$(sed -n 1p "$CACHE")" = "$topic" ]; then
  ja=$(sed -n 2p "$CACHE")
fi

if [ -z "$ja" ] && command -v claude >/dev/null 2>&1; then
  # Sidebar fits ~13 full-width chars; ask for 12 and hard-trim at 13
  ja=$(claude -p --model haiku "次のAIセッションのトピックを、日本語12文字以内の簡潔なタブ名にしてください。タブ名の文字列だけを出力すること。トピック: ${topic}" 2>/dev/null \
    | python3 -c '
import sys
s = sys.stdin.read().strip().splitlines()
s = s[-1].strip().strip("\"「」『』 ") if s else ""
print(s[:13])
')
fi
if [ -z "$ja" ]; then
  # Fall back to the original (English) topic, trimmed to the sidebar width
  ja=$(printf '%s' "$topic" | python3 -c 'import sys; s=sys.stdin.read().strip(); print(s[:26] + ("…" if len(s) > 26 else ""))')
fi

printf '%s\n%s\n' "$topic" "$ja" > "$CACHE"
"$CMUX_BIN" rename-workspace --workspace "$CMUX_WORKSPACE_ID" "✳ $ja" >/dev/null 2>&1
exit 0
