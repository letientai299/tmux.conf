#!/bin/sh
# fzf-preview.sh — preview helper for fzf-picker.sh
# Renders pane captures for all panes in the target scope.
# Usage: fzf-preview.sh <target>
#   target = session | session:window | session:window.pane

. "$(cd "$(dirname "$0")" && pwd)/palette.sh"

t=$1

capture_pane() {
  target=$1
  label=$2
  printf '%b─── %s ───%b\n' "$a_muted" "$label" "$a_reset"
  tmux capture-pane -e -t "$target" -p
  echo
}

resolve_cmd() {
  shell_pid=$1
  fallback=$2
  child=$(pgrep -nP "$shell_pid" 2>/dev/null)
  if [ -n "$child" ]; then
    name=$(ps -p "$child" -o comm= 2>/dev/null)
    basename "${name:-$fallback}"
  else
    echo "$fallback"
  fi
}

pane_label() {
  pid=$1
  pcmd=$2
  path=$3
  cmd=$(resolve_cmd "$pid" "$pcmd")
  printf '%s  %s' "$cmd" "$path"
}

case "$t" in
  *.*)
    # Single pane — just capture
    tmux capture-pane -e -t "$t" -p
    ;;
  *:*)
    # Window — capture every pane in this window
    tmux list-panes -t "$t" \
      -F '#{session_name}:#{window_index}.#{pane_index}	#{pane_pid}	#{pane_current_command}	#{pane_current_path}' |
    while IFS='	' read -r ref pid pcmd path; do
      label=$(pane_label "$pid" "$pcmd" "$path")
      capture_pane "$ref" "$label"
    done
    ;;
  *)
    # Session — capture every pane across all windows
    tmux list-panes -t "$t" -a -F '#{session_name}	#{session_name}:#{window_index}.#{pane_index}	#{window_index}	#{window_name}	#{pane_pid}	#{pane_current_command}	#{pane_current_path}' |
    while IFS='	' read -r sess ref widx wname pid pcmd path; do
      [ "$sess" = "$t" ] || continue
      cmd=$(resolve_cmd "$pid" "$pcmd")
      capture_pane "$ref" "$widx:$wname  $cmd  $path"
    done
    ;;
esac
