#!/bin/sh
# palette.sh — single source of truth for Atom One Dark colors
# Sourced by theme-apply.sh and shell scripts that need color output.
# https://github.com/atom/one-dark-syntax

# --- Hex values (for tmux style strings) ---
c_bg='#282c34'
c_bg_root='#5c2020'
c_bg_win='#21252b'
c_bg_win_cur='#2c313a'
c_fg='#abb2bf'
c_muted='#5c6370'
c_border='#3e4452'
c_red='#e06c75'
c_orange='#d19a66'
c_yellow='#e5c07b'
c_green='#98c379'
c_blue='#61afef'
c_blue_bright='#528bff'
c_purple='#c678dd'
c_cyan='#56b6c2'

# --- ANSI truecolor sequences (for shell printf/echo output) ---
# Literal escape strings avoid subshell forks when sourced.
a_reset='\033[0m'
a_bold='\033[1m'

a_fg='\033[38;2;171;178;191m'
a_muted='\033[38;2;92;99;112m'
a_red='\033[38;2;224;108;117m'
a_orange='\033[38;2;209;154;102m'
a_yellow='\033[38;2;229;192;123m'
a_green='\033[38;2;152;195;121m'
a_blue='\033[38;2;97;175;239m'
a_purple='\033[38;2;198;120;221m'
a_cyan='\033[38;2;86;182;194m'
