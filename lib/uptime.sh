#!/bin/sh
# Compact uptime: 3w2d12h4m
# Minutes hidden when weeks are present.
if [ -f /proc/uptime ]; then
  s=$(cut -d. -f1 /proc/uptime)
else
  boot=$(sysctl -n kern.boottime | sed 's/.*{ sec = \([0-9]*\).*/\1/')
  now=$(date +%s)
  s=$((now - boot))
fi
w=$((s / 604800)); s=$((s % 604800))
d=$((s / 86400));  s=$((s % 86400))
h=$((s / 3600));   s=$((s % 3600))
m=$((s / 60))
r=""
[ "$w" -gt 0 ] && r="${w}w"
[ "$d" -gt 0 ] && r="$r${d}d"
[ "$h" -gt 0 ] && r="$r${h}h"
[ "$w" -eq 0 ] && [ "$m" -gt 0 ] && r="$r${m}m"
printf '%s' "${r:-0m}"
