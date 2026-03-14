#!/bin/sh
# Print sudo indicator with tmux style tags if the pane has a sudo child.
# Usage: sudo-indicator.sh <pane_pid> <bg_color>
# bg_color is the window tab background to restore after the indicator.
pane_pid=$1 bg=$2
if pgrep -xP "$pane_pid" sudo >/dev/null 2>&1; then
  printf '#[bg=#5c2020,fg=#e06c75,bold] ! #[bg=%s,nobold]' "$bg"
fi
