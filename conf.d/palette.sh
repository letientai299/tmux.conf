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
_ansi() { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }

a_reset=$(printf '\033[0m')
a_bold=$(printf '\033[1m')

a_fg=$(_ansi 171 178 191)
a_muted=$(_ansi 92 99 112)
a_red=$(_ansi 224 108 117)
a_orange=$(_ansi 209 154 102)
a_yellow=$(_ansi 229 192 123)
a_green=$(_ansi 152 195 121)
a_blue=$(_ansi 97 175 239)
a_purple=$(_ansi 198 120 221)
a_cyan=$(_ansi 86 182 194)
