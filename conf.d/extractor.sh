#!/bin/sh
# extractor.sh — extract URLs, paths, git hashes, IPs from a tmux pane
# Launched via display-popup from a keybind.

set -u

if ! command -v fzf >/dev/null 2>&1; then
  echo "extractor: fzf not found" >&2
  exit 1
fi

# Detect the pane that triggered the popup (the active pane in the window).
pane_id=$(tmux list-panes -F '#{pane_active} #{pane_id}' | awk '/^1/ {print $2}')
pane_path=$(tmux display -t "$pane_id" -p '#{pane_current_path}')
hostname=$(hostname -s 2>/dev/null || echo localhost)

# --- Colors (Atom One Dark palette) ---
c_reset='\033[0m'
c_type_file='\033[38;5;209m'    # orange
c_type_url='\033[38;5;75m'      # blue
c_type_osc8='\033[38;5;141m'    # purple
c_type_path='\033[38;5;114m'    # green
c_type_git='\033[38;5;180m'     # yellow
c_type_ip4='\033[38;5;173m'     # salmon
c_type_ip6='\033[38;5;139m'     # mauve
c_val='\033[38;5;252m'          # light gray

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

# --- Capture pane content ---
content=$(tmux capture-pane -t "$pane_id" -p -S -500 -E 500 2>/dev/null || true)

if [ -z "$content" ]; then
  exit 0
fi

# --- Extract OSC 8 hyperlinks from raw escape sequences ---
raw_content=$(tmux capture-pane -t "$pane_id" -p -S -500 -E 500 -e 2>/dev/null || true)

# --- Build candidates ---
# Each extraction appends to a temp file, then we deduplicate.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# FILE:LINE — path.ext:123 (optionally :col)
echo "$content" | grep -oE '[A-Za-z0-9_./-]+\.[A-Za-z0-9]+:[0-9]+(:[0-9]+)?' | while IFS= read -r m; do
  file_part=${m%%:*}
  abs=$(resolve_path "$file_part")
  format_line "$m" "FILE:LINE" "$c_type_file" "file://$hostname$abs"
done >> "$tmp"

# URL — http(s)://...
echo "$content" | grep -oE 'https?://[][A-Za-z0-9._~:/?#@!$&'"'"'()*+,;=%-]+'  | \
  sed 's/[]),.]$//' | while IFS= read -r m; do
  format_line "$m" "URL" "$c_type_url" "$m"
done >> "$tmp"

# OSC 8 — extract hyperlinks from escape sequences
# Format: \e]8;;URL\e\\ visible_text \e]8;;\e\\
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
    --expect='alt-enter,ctrl-o' \
    --header='enter=copy  alt-enter=insert  ctrl-o=open' \
    --no-multi \
  || true)

[ -z "$selection" ] && exit 0

# Parse fzf --expect output: first line is the key pressed, second is the selection
key=$(echo "$selection" | head -1)
typed_val=$(echo "$selection" | tail -1 | cut -f1)

[ -z "$typed_val" ] && exit 0

# Split type:raw_value
item_type=${typed_val%%:*}
chosen=${typed_val#*:}

if [ "$key" = "alt-enter" ]; then
  # Insert into the source pane
  tmux send-keys -t "$pane_id" -l "$chosen"
elif [ "$key" = "ctrl-o" ]; then
  # Open: file/path in nvim, url in browser, no-op for git/ip
  case "$item_type" in
    FILE:LINE)
      file_part=${chosen%%:*}
      line_part=${chosen#*:}
      line_num=${line_part%%:*}
      abs=$(resolve_path "$file_part")
      tmux send-keys -t "$pane_id" "nvim +${line_num} $(printf '%q' "$abs")" Enter
      ;;
    PATH)
      abs=$(resolve_path "$chosen")
      tmux send-keys -t "$pane_id" "nvim $(printf '%q' "$abs")" Enter
      ;;
    URL|OSC8)
      open "$chosen"
      ;;
  esac
else
  # Copy to tmux buffer and system clipboard via OSC 52
  printf '%s' "$chosen" | tmux load-buffer -
  printf '\033]52;c;%s\033\\' "$(printf '%s' "$chosen" | base64)" > "$(tmux display -p '#{client_tty}')"
fi
