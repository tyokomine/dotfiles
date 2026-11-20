# Keep interactive Codex hooks in the cmux terminal's process tree.
if [[ -o interactive && -n ${CMUX_WORKSPACE_ID:-} ]]; then
  codex() {
    if [[ $1 == resume && -n $2 && $2 != -* ]] &&
       python3 ~/.codex/hooks/cmux_tab_title.py --shared-resume "$2"; then
      command codex "$@"
      return $?
    fi
    if (( ${@[(Ie)--no-daemon]} )); then
      command codex "$@"
      return $?
    fi
    command codex --no-daemon "$@"
  }
fi
