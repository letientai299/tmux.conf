#!/bin/sh
# Launch tmux on a separate "tm" socket.
# Requires: ln -sfn <this-repo> ~/.config/tmux (or `make install`).
exec tmux -L tm "$@"
