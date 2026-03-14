#!/bin/sh
# fzf-preview.sh — preview helper for fzf-picker.sh
# Renders pane captures for all panes in the target scope.
# Usage: fzf-preview.sh <target>
#   target = session | session:window | session:window.pane

_prev_dir=$(cd "$(dirname "$0")" && pwd)
. "$_prev_dir/palette.sh"
. "$_prev_dir/tmux-util.sh"

t=$1

# Single pane — just capture, no batching needed.
case "$t" in
  *.*) tmux capture-pane -e -t "$t" -p; exit ;;
esac

# Window or session — batch captures and resolve commands in bulk.
case "$t" in
  *:*) pane_data=$(tmux list-panes -t "$t" \
         -F '#{session_name}:#{window_index}.#{pane_index}	#{window_index}	#{window_name}	#{pane_pid}	#{pane_current_command}	#{pane_current_path}') ;;
  *)   pane_data=$(tmux list-panes -t "$t" -s \
         -F '#{session_name}:#{window_index}.#{pane_index}	#{window_index}	#{window_name}	#{pane_pid}	#{pane_current_command}	#{pane_current_path}') ;;
esac

[ -z "$pane_data" ] && exit 0

# Single ps call for child-process resolution (replaces per-pane pgrep+ps).
ps_data=$(ps -eo ppid=,comm=)

# Batch all capture-pane calls into one tmux invocation.
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

printf '%s\n' "$pane_data" | cut -f1 |
  batch_capture_panes "$tmpdir" "_prev" || exit 0

# Build labels via awk (one process, no per-pane forks), then stream output.
labels=$(printf '%s\n---\n%s\n' "$ps_data" "$pane_data" | awk -F'\t' '
  /^---$/ { phase = 1; next }
  phase == 0 {
    split($0, a, " ")
    children[a[1]] = a[2]
    next
  }
  {
    widx = $2; wname = $3; pid = $4; pcmd = $5; path = $6
    cmd = children[pid]
    if (cmd == "") cmd = pcmd
    n = split(cmd, parts, "/")
    cmd = parts[n]
    printf "%s:%s  %s  %s\n", widx, wname, cmd, path
  }
')

i=0
printf '%s\n' "$labels" | while IFS= read -r label; do
  printf '%b─── %s ───%b\n' "$a_muted" "$label" "$a_reset"
  cat "$tmpdir/$i" 2>/dev/null
  echo
  i=$((i + 1))
done
