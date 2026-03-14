#!/bin/sh
# extractor.sh — extract URLs, paths, git hashes, IPs from all session panes
# Launched via display-popup from a keybind.

set -u

. "$(cd "$(dirname "$0")" && pwd)/palette.sh"

if ! command -v fzf >/dev/null 2>&1; then
  echo "extractor: fzf not found" >&2
  exit 1
fi

# Single list-panes call gets pane_id (action target) and all pane info.
pane_data=$(tmux list-panes -s -F '#{pane_active} #{pane_id} #{pane_current_path}')
pane_id=$(printf '%s\n' "$pane_data" | awk '/^1/ {print $2; exit}')
pane_info=$(printf '%s\n' "$pane_data" | awk '{print $2, $3}')
hn=${HOSTNAME%%.*}
: "${hn:=$(hostname -s 2>/dev/null)}"
: "${hn:=localhost}"

# --- Capture all session panes in a batched tmux call ---
# Build one `tmux` invocation that captures every pane into a named buffer,
# saves each buffer to a temp file, and deletes the buffer — all via `\;`.
# This avoids per-pane IPC round trips (the dominant cost).
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cmd="" i=0
while IFS=' ' read -r pid cwd; do
  cmd="${cmd}capture-pane -t $pid -b _ext$i -e -S -500 -E 500 \; "
  cmd="${cmd}save-buffer -b _ext$i $tmpdir/$i \; "
  cmd="${cmd}delete-buffer -b _ext$i \; "
  i=$((i + 1))
done <<EOF
$pane_info
EOF

[ -z "$cmd" ] && exit 0
eval "tmux $cmd"

# --- Stream pane content (with cwd markers) into a single awk extraction ---
{
  i=0
  while IFS=' ' read -r pid cwd; do
    printf '__PANE__%s\n' "$cwd"
    cat "$tmpdir/$i"
    i=$((i + 1))
  done <<EOF2
$pane_info
EOF2
} | awk \
  -v hostname="$hn" -v home="$HOME" \
  -v reset="$a_reset" -v c_fg="$a_fg" \
  -v c_file="$a_orange" -v c_url="$a_blue" -v c_osc8="$a_purple" \
  -v c_path="$a_green" -v c_git="$a_yellow" \
  -v c_ip4="$a_red" -v c_ip6="$a_cyan" \
'
BEGIN { pp = "" }

/^__PANE__/ { pp = substr($0, 9); next }

{
  plain = $0
  gsub(/\033\[[0-9;]*[a-zA-Z]/, "", plain)
  gsub(/\033\]8;[^;]*;[^\033]*\033\\/, "", plain)

  # Extract OSC 8 hyperlinks from raw escape sequences.
  raw = $0
  while (match(raw, /\033\]8;[^;]*;[^\033]*\033\\/)) {
    chunk = substr(raw, RSTART, RLENGTH)
    sub(/^\033\]8;[^;]*;/, "", chunk)
    sub(/\033\\$/, "", chunk)
    if (chunk ~ /^https?:\/\//) emit(chunk, "OSC8", c_osc8, chunk)
    raw = substr(raw, RSTART + RLENGTH)
  }

  extract(plain)
}

function resolve(p) {
  if (p ~ /^~\//) return home "/" substr(p, 3)
  if (p ~ /^\//) return p
  return pp "/" p
}

function emit(v, t, c, l) {
  if (seen[v]++) return
  k = t ":" v
  if (l != "")
    printf "%s\t%s%-9s%s %s\033]8;;%s\033\\%s\033]8;;\033\\%s\n", \
      k, c, t, reset, c_fg, l, v, reset
  else
    printf "%s\t%s%-9s%s %s%s%s\n", \
      k, c, t, reset, c_fg, v, reset
}

function extract(line,    rest, val, fp, abs) {
  rest = line
  while (match(rest, /https?:\/\/[][A-Za-z0-9._~:\/?#@!$&'"'"'()*+,;=%-]+/)) {
    val = substr(rest, RSTART, RLENGTH); sub(/[]),.]$/, "", val)
    emit(val, "URL", c_url, val); rest = substr(rest, RSTART + RLENGTH)
  }
  rest = line
  while (match(rest, /[A-Za-z0-9_.\/-]+\.[A-Za-z0-9]+:[0-9]+(:[0-9]+)?/)) {
    val = substr(rest, RSTART, RLENGTH); fp = val; sub(/:.*$/, "", fp)
    abs = resolve(fp); emit(val, "FILE:LINE", c_file, "file://" hostname abs)
    rest = substr(rest, RSTART + RLENGTH)
  }
  rest = line
  while (match(rest, /~\/[A-Za-z0-9_.\/-]+/)) {
    val = substr(rest, RSTART, RLENGTH); abs = resolve(val)
    emit(val, "PATH", c_path, "file://" hostname abs)
    rest = substr(rest, RSTART + RLENGTH)
  }
  rest = line
  while (match(rest, /\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.\/-]+/)) {
    val = substr(rest, RSTART, RLENGTH)
    if (val !~ /^\/\//) emit(val, "PATH", c_path, "file://" hostname val)
    rest = substr(rest, RSTART + RLENGTH)
  }
  rest = line
  while (match(rest, /[A-Za-z0-9_.-]+\/[A-Za-z0-9_.\/-]+\.[A-Za-z0-9]+/)) {
    val = substr(rest, RSTART, RLENGTH); abs = resolve(val)
    emit(val, "PATH", c_path, "file://" hostname abs)
    rest = substr(rest, RSTART + RLENGTH)
  }
  rest = line
  while (match(rest, /\.\/[A-Za-z0-9_.\/-]+/)) {
    val = substr(rest, RSTART, RLENGTH); abs = resolve(val)
    emit(val, "PATH", c_path, "file://" hostname abs)
    rest = substr(rest, RSTART + RLENGTH)
  }
  rest = line
  while (match(rest, /[0-9a-f]{7,40}/)) {
    val = substr(rest, RSTART, RLENGTH)
    if (val ~ /[0-9]/ && val ~ /[a-f]/) emit(val, "GIT", c_git, "")
    rest = substr(rest, RSTART + RLENGTH)
  }
  rest = line
  while (match(rest, /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/)) {
    val = substr(rest, RSTART, RLENGTH); emit(val, "IPv4", c_ip4, "")
    rest = substr(rest, RSTART + RLENGTH)
  }
  rest = line
  while (match(rest, /([0-9a-fA-F]{1,4}:){3,7}[0-9a-fA-F]{1,4}/)) {
    val = substr(rest, RSTART, RLENGTH); emit(val, "IPv6", c_ip6, "")
    rest = substr(rest, RSTART + RLENGTH)
  }
  rest = line
  while (match(rest, /::[0-9a-fA-F:]+/)) {
    val = substr(rest, RSTART, RLENGTH); emit(val, "IPv6", c_ip6, "")
    rest = substr(rest, RSTART + RLENGTH)
  }
}
' | {
  selection=$(fzf \
    --ansi \
    --reverse \
    --no-sort \
    --delimiter='	' \
    --with-nth='2..' \
    --multi \
    --header='tab=select  enter=open/copy' \
  || true)

  [ -z "$selection" ] && exit 0

  client_tty=$(tmux display -p '#{client_tty}')

  urls=$(echo "$selection" | cut -f1 | grep -E '^(URL|OSC8):' | sed 's/^[^:]*://' || true)
  copies=$(echo "$selection" | cut -f1 | grep -vE '^(URL|OSC8):' | sed 's/^[^:]*://' || true)

  if [ -n "$urls" ]; then
    echo "$urls" | while IFS= read -r u; do
      open "$u"
    done
  fi

  if [ -n "$copies" ]; then
    printf '%s' "$copies" | tmux load-buffer -
    printf '\033]52;c;%s\033\\' "$(printf '%s' "$copies" | base64)" > "$client_tty"
  fi
}
