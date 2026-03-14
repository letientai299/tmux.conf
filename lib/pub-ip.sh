#!/bin/sh
# Cached public IP lookup. Refreshes every 5 minutes.
f=/tmp/tmux-pub-ip
if [ -s "$f" ] && find "$f" -mmin -5 -print 2>/dev/null | grep -q .; then
  cat "$f"
else
  curl -s --connect-timeout 2 ifconfig.me > "$f" 2>/dev/null
  if [ -s "$f" ]; then cat "$f"; else echo "n/a"; fi
fi
