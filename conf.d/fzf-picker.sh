#!/bin/sh
# fzf-picker.sh — fzf-based tree picker, replaces tmux choose-tree
# Shows sessions/windows/panes in a tree with capture-pane preview.
# Usage: called from a tmux display-popup keybinding.

. "$(cd "$(dirname "$0")" && pwd)/palette.sh"

build_tree() {
  # Single ps call for child-process resolution (replaces per-pane pgrep+ps).
  # Combined with tmux pane data in one awk pass to avoid N shell forks.
  ps_data=$(ps -eo ppid=,comm=)
  pane_data=$(tmux list-panes -a \
    -F '#{session_name}	#{window_index}	#{window_name}	#{pane_index}	#{pane_pid}	#{pane_current_command}	#{pane_current_path}')

  printf '%s\n---\n%s\n' "$ps_data" "$pane_data" |
  awk -F'\t' \
    -v cb="${a_bold}${a_blue}" \
    -v cy="$a_yellow" \
    -v cg="$a_green" \
    -v cm="$a_muted" \
    -v cr="$a_reset" \
  '
    /^---$/ { phase = 1; next }
    phase == 0 {
      # ps output (space-separated): build ppid → basename(cmd) map.
      split($0, a, " ")
      n = split(a[2], parts, "/")
      children[a[1]] = parts[n]
      next
    }
    {
      # Resolve command: prefer child of shell pid over pane_current_command.
      resolved = children[$5]
      if (resolved == "") {
        n = split($6, parts, "/")
        resolved = parts[n]
      }
      N++; s[N]=$1; w[N]=$2; wn[N]=$3; p[N]=$4; cmd[N]=resolved; dir[N]=$7
    }
    END {
      for (i = 1; i <= N; i++) {
        new_s = (i == 1 || s[i] != s[i-1])
        new_w = (new_s || w[i] != w[i-1])

        if (new_s)
          printf "%s\t%s%s%s\n", s[i], cb, s[i], cr

        if (new_w) {
          lw = 1
          for (j = i+1; j <= N; j++) {
            if (s[j] != s[i]) break
            if (w[j] != w[i]) { lw = 0; break }
          }
          wb = lw ? "└─" : "├─"
          wc[s[i], w[i]] = lw ? "   " : "│  "
          printf "%s:%s\t  %s %s%s%s\n", s[i], w[i], wb, cy, wn[i], cr
        }

        lp = (i == N || s[i+1] != s[i] || w[i+1] != w[i])
        pb = lp ? "└─" : "├─"

        printf "%s:%s.%s\t  %s  %s %s%d%s %s %s%s%s\n", \
          s[i], w[i], p[i], wc[s[i], w[i]], pb, cg, p[i], cr, cmd[i], cm, dir[i], cr
      }
    }
  '
}

# Resolve TMUX_CONF_DIR for preview script path.
script_dir=$(cd "$(dirname "$0")" && pwd)

target=$(
  build_tree |
  fzf \
    --ansi \
    --no-multi \
    --reverse \
    --no-sort \
    --delimiter='	' \
    --with-nth=2 \
    --prompt='> ' \
    --header='Switch to session / window / pane' \
    --preview="$script_dir/fzf-preview.sh {1}" \
    --preview-window='down:70%' |
  cut -f1
)

[ -n "$target" ] && tmux switch-client -t "$target"
