#!/bin/sh
# fzf-picker.sh — fzf-based tree picker, replaces tmux choose-tree
# Shows sessions/windows/panes in a tree with capture-pane preview.
# Usage: called from a tmux display-popup keybinding.

. "$(cd "$(dirname "$0")" && pwd)/palette.sh"

# Resolve the actual executable name for a pane.
# pane_current_command can be wrong when a process sets its title
# (e.g., Node.js process.title = version). On macOS, ps -o comm= returns
# the full executable path from the kernel, unaffected by title changes.
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

build_tree() {
  tmux list-panes -a \
    -F '#{session_name}	#{window_index}	#{window_name}	#{pane_index}	#{pane_pid}	#{pane_current_command}	#{pane_current_path}' |
  while IFS='	' read -r sess win wname pidx pid pcmd path; do
    cmd=$(resolve_cmd "$pid" "$pcmd")
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$sess" "$win" "$wname" "$pidx" "$cmd" "$path"
  done |
  awk -F'\t' \
    -v cb="${a_bold}${a_blue}" \
    -v cy="$a_yellow" \
    -v cg="$a_green" \
    -v cm="$a_muted" \
    -v cr="$a_reset" \
  '
    { s[NR]=$1; w[NR]=$2; wn[NR]=$3; p[NR]=$4; cmd[NR]=$5; dir[NR]=$6; N=NR }
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
