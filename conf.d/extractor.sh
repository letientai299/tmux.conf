#!/bin/sh
# extractor.sh — extract URLs, paths, git hashes, IPs from all session panes
# Launched via display-popup from a keybind.

set -u

. "$(cd "$(dirname "$0")" && pwd)/palette.sh"

if ! command -v fzf >/dev/null 2>&1; then
  echo "extractor: fzf not found" >&2
  exit 1
fi

# Detect the pane that triggered the popup (action target for insert/open).
pane_id=$(tmux list-panes -F '#{pane_active} #{pane_id}' | awk '/^1/ {print $2}')
session_id=$(tmux display -t "$pane_id" -p '#{session_id}')
hostname=$(hostname -s 2>/dev/null || echo localhost)

# pane_path is set per-pane in the extraction loop; resolve_path reads it.
pane_path=

# --- Colors (mapped from palette.sh) ---
c_reset=$a_reset
c_type_file=$a_orange
c_type_url=$a_blue
c_type_osc8=$a_purple
c_type_path=$a_green
c_type_git=$a_yellow
c_type_ip4=$a_red
c_type_ip6=$a_cyan
c_val=$a_fg

# --- Helpers ---

resolve_path() {
  case "$1" in
    ~/*) echo "$HOME/${1#\~/}" ;;
    /*)  echo "$1" ;;
    *)   echo "$pane_path/$1" ;;
  esac
}

# Format: type:raw_value<TAB>colored_label osc8_value
# Column 1 encodes type for action dispatch after fzf selection.
format_line() {
  _raw=$1 _type=$2 _color=$3 _link=${4:-}
  if [ -n "$_link" ]; then
    printf '%s:%s\t%b%-9s%b %b\033]8;;%s\033\\%s\033]8;;\033\\%b\n' \
      "$_type" "$_raw" "$_color" "$_type" "$c_reset" "$c_val" "$_link" "$_raw" "$c_reset"
  else
    printf '%s:%s\t%b%-9s%b %b%s%b\n' \
      "$_type" "$_raw" "$_color" "$_type" "$c_reset" "$c_val" "$_raw" "$c_reset"
  fi
}

# --- Build candidates from all panes in the session ---
# Each extraction appends to a temp file, then we deduplicate.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

tmux list-panes -s -t "$session_id" -F '#{pane_id}' | while IFS= read -r pid; do
  content=$(tmux capture-pane -t "$pid" -p -S -500 -E 500 2>/dev/null || true)
  [ -z "$content" ] && continue

  raw_content=$(tmux capture-pane -t "$pid" -p -S -500 -E 500 -e 2>/dev/null || true)

  # Set pane_path per-pane so resolve_path resolves relative paths correctly.
  pane_path=$(tmux display -t "$pid" -p '#{pane_current_path}')

  # FILE:LINE — path.ext:123 (optionally :col)
  echo "$content" | grep -oE '[A-Za-z0-9_./-]+\.[A-Za-z0-9]+:[0-9]+(:[0-9]+)?' | while IFS= read -r m; do
    file_part=${m%%:*}
    abs=$(resolve_path "$file_part")
    format_line "$m" "FILE:LINE" "$c_type_file" "file://$hostname$abs"
  done >> "$tmp"

  # URL — http(s)://...
  echo "$content" | grep -oE 'https?://[][A-Za-z0-9._~:/?#@!$&'"'"'()*+,;=%-]+' | \
    sed 's/[]),.]$//' | while IFS= read -r m; do
    format_line "$m" "URL" "$c_type_url" "$m"
  done >> "$tmp"

  # OSC 8 — extract hyperlinks from escape sequences
  if [ -n "$raw_content" ]; then
    printf '%s' "$raw_content" | sed -n 's/.*\x1b\]8;[^;]*;\([^\x1b]*\)\x1b\\.*/\1/gp' | \
      grep -oE 'https?://[^ ]+' | while IFS= read -r m; do
      format_line "$m" "OSC8" "$c_type_osc8" "$m"
    done >> "$tmp"
  fi

  # PATH — ~/paths, absolute (require dir component), relative (dir/file.ext, ./file)
  echo "$content" | grep -oE '~/[A-Za-z0-9_./-]+' | while IFS= read -r m; do
    abs=$(resolve_path "$m")
    format_line "$m" "PATH" "$c_type_path" "file://$hostname$abs"
  done >> "$tmp"

  echo "$content" | grep -oE '(/[A-Za-z0-9_.-]+){2,}' | grep -v '^//' | while IFS= read -r m; do
    format_line "$m" "PATH" "$c_type_path" "file://$hostname$m"
  done >> "$tmp"

  echo "$content" | grep -oE '[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+\.[A-Za-z0-9]+' | while IFS= read -r m; do
    abs=$(resolve_path "$m")
    format_line "$m" "PATH" "$c_type_path" "file://$hostname$abs"
  done >> "$tmp"

  echo "$content" | grep -oE '\./[A-Za-z0-9_./-]+' | while IFS= read -r m; do
    abs=$(resolve_path "$m")
    format_line "$m" "PATH" "$c_type_path" "file://$hostname$abs"
  done >> "$tmp"

  # GIT — 7-40 hex chars, must contain both digit and letter
  echo "$content" | grep -oE '\b[0-9a-f]{7,40}\b' | \
    grep '[0-9]' | grep '[a-f]' | while IFS= read -r m; do
    format_line "$m" "GIT" "$c_type_git"
  done >> "$tmp"

  # IPv4 — dotted quad
  echo "$content" | grep -oE '\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b' | while IFS= read -r m; do
    format_line "$m" "IPv4" "$c_type_ip4"
  done >> "$tmp"

  # IPv6 — require 4+ colon-separated groups (avoids HH:MM:SS timestamps) or ::
  echo "$content" | grep -oE '([0-9a-fA-F]{1,4}:){3,7}[0-9a-fA-F]{1,4}|::([0-9a-fA-F]{1,4}:){0,5}[0-9a-fA-F]{1,4}|[0-9a-fA-F]{1,4}::(%[A-Za-z0-9]+)?' | while IFS= read -r m; do
    format_line "$m" "IPv6" "$c_type_ip6"
  done >> "$tmp"
done

# --- Deduplicate by raw value (column 1) ---
if [ ! -s "$tmp" ]; then
  exit 0
fi

# awk dedup on raw value (after type: prefix), preserving order
selection=$(awk -F'\t' '{ v=substr($1, index($1,":")+1) } !seen[v]++' "$tmp" | \
  fzf \
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

# Split selections: open URLs, collect the rest for copy.
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
