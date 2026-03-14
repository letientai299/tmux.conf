#!/bin/sh
# Launch tmux with a dedicated server using the config from this repo.
# Separate socket ("tm") avoids conflicts with the default tmux server
# which loads ~/.tmux.conf.
REPO_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
TMUX_CONF_DIR="$REPO_DIR" exec tmux -L tm -f "$REPO_DIR/tmux.conf" "$@"
