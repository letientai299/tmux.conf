#!/bin/sh
# theme-apply.sh — apply Atom One Dark theme using palette variables
# Run via: run-shell from theme.conf

CONF_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$CONF_DIR/palette.sh"

# Root user gets dark red background.
if [ "$(id -u)" -eq 0 ]; then
  bg=$c_bg_root
else
  bg=$c_bg
fi

# Batch all style settings into a single tmux call to avoid per-command IPC.
tmux \
  set -g status-style "bg=$bg,fg=$c_fg" \; \
  set -g status-left-style "fg=$c_blue,bold" \; \
  set -g status-left \
    " [#{session_name}] #{?client_prefix,#[fg=$c_red]PREFIX,#{?pane_in_mode,#{?#{==:#{pane_mode},copy-mode},#[fg=$c_purple] COPY ,#{?#{==:#{pane_mode},view-mode},#[fg=$c_cyan] VIEW ,#{?#{==:#{pane_mode},tree-mode},#[fg=$c_green] TREE ,#{?#{==:#{pane_mode},buffer-mode},#[fg=$c_yellow] BUFR ,#{?#{==:#{pane_mode},client-mode},#[fg=$c_yellow] CLNT ,#[fg=$c_purple] MODE }}}}},#{?window_zoomed_flag,#[fg=$c_yellow] ZOOM ,#[fg=$c_fg]NORMAL}}}#[fg=$bg,bg=$c_bg_win] " \; \
  set -g status-right-style "fg=$c_fg" \; \
  set -g status-right \
    "#[fg=$c_blue]#{?#{E:LC_SSH_ALIAS},#{E:LC_SSH_ALIAS},#(whoami)#[fg=$c_muted]@#[fg=$c_fg]#H}#[fg=$c_muted]│#[fg=$c_green]#(~/.config/tmux/lib/pub-ip.sh)#[fg=$c_muted]│#[fg=$c_yellow]#(~/.config/tmux/lib/uptime.sh)#[fg=$c_muted]│#[fg=$c_fg]%H:%M " \; \
  set -g window-status-style "bg=$c_bg_win,fg=$c_fg" \; \
  set -g window-status-current-style "bg=$c_bg_win_cur,fg=$c_purple,bold" \; \
  set -g pane-border-style "fg=$c_border" \; \
  set -g pane-active-border-style "fg=$c_blue_bright"
