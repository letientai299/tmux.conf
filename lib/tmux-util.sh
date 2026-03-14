#!/bin/sh
# tmux-util.sh — shared helpers for tmux scripts

# batch_capture_panes — capture multiple panes in a single tmux call
# Usage: printf '%s\n' "$refs" | batch_capture_panes <tmpdir> <prefix> [extra-flags...]
# Reads one pane reference per line from stdin.
# Returns 1 if no panes were provided.
batch_capture_panes() {
  _bcp_dir=$1; _bcp_pfx=$2; shift 2
  # Remaining args = extra capture-pane flags (e.g., -S -500 -E 500).
  # Deliberately unquoted below so they word-split into individual flags.
  _bcp_flags="$*"

  set -- # reset argv for tmux command building
  _bcp_i=0
  while IFS= read -r _bcp_ref; do
    [ -z "$_bcp_ref" ] && continue
    # shellcheck disable=SC2086
    set -- "$@" capture-pane -t "$_bcp_ref" -b "${_bcp_pfx}${_bcp_i}" -e $_bcp_flags \; \
                 save-buffer -b "${_bcp_pfx}${_bcp_i}" "$_bcp_dir/$_bcp_i" \; \
                 delete-buffer -b "${_bcp_pfx}${_bcp_i}" \;
    _bcp_i=$((_bcp_i + 1))
  done
  [ $# -eq 0 ] && return 1
  tmux "$@"
}
