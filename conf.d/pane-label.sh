#!/bin/sh
# Output window tab label: [sudo indicator] <dir> ~ <cmd>
# Resolves through sudo to show the actual command name.
# Usage: pane-label.sh <pane_pid> <dir> <cmd>
pane_pid=$1 dir=$2 cmd=$3

sudo_pid=$(pgrep -xP "$pane_pid" sudo 2>/dev/null)
if [ -n "$sudo_pid" ]; then
  # Walk past intermediate sudo processes to find the real command.
  pid=$sudo_pid
  while true; do
    child=$(pgrep -P "$pid" 2>/dev/null | head -1)
    [ -z "$child" ] && break
    name=$(ps -p "$child" -o comm= 2>/dev/null)
    pid=$child
    [ "$name" != "sudo" ] && break
  done
  if [ "$pid" != "$sudo_pid" ]; then
    cmd=$(ps -p "$pid" -o comm= 2>/dev/null || echo "$cmd")
  fi
  # pane_current_path is unreliable when sudo is foreground — tmux can't
  # read the cwd of root-owned processes on macOS. Fall back to the
  # shell's cwd (which we own) via lsof.
  shell_cwd=$(lsof -a -p "$pane_pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
  [ -n "$shell_cwd" ] && dir=$(basename "$shell_cwd")
  printf '#[fg=#e06c75,bold]!#[fg=default,nobold] %s ~ %s' "$dir" "$cmd"
else
  printf '%s ~ %s' "$dir" "$cmd"
fi
