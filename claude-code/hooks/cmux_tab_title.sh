#!/bin/bash
# Set the cmux tab name to a short Japanese summary of the current Claude session
# topic. Reads Claude Code's auto-generated topic title (surface title), converts
# it to Japanese via `claude -p` (Haiku), and renames the tab. The translation is
# cached per workspace so unchanged topics cost no extra API call.
#
# Every run also re-stamps a "<n>:" prefix on all hook-owned tabs so the number
# matches the ⌘<n> switch shortcut even after tabs are added, closed or reordered.
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
  src=$(printf '%s' "$stdin_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("source") or "")' 2>/dev/null)
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
  # Sidebar fits ~13 full-width chars, minus the "<n>:" prefix; ask for 11 and hard-trim at 12
  ja=$(claude -p --model haiku "次のAIセッションのトピックを、日本語11文字以内の簡潔なタブ名にしてください。タブ名の文字列だけを出力すること。トピック: ${topic}" 2>/dev/null \
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

printf '%s\n%s\n' "$topic" "$ja" > "$CACHE"
# The blank label is a complete title, not a topic to prefix with ✳
[ "$ja" = "$BLANK_LABEL" ] && label="$BLANK_LABEL" || label="✳ $ja"
"$CMUX_BIN" rename-workspace --workspace "$CMUX_WORKSPACE_ID" "$label" >/dev/null 2>&1
renumber
exit 0
