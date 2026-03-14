# tmux.conf

Plugin-free tmux config for tmux 3.6+. Replaces a TPM-based setup with direct
`set`/`bind` commands.

## Quick Start

```sh
./tm
```

The `tm` launcher starts a dedicated tmux server (socket `tm`) using this repo's
config. It runs independently from the default `tmux` server, so your
`~/.tmux.conf` stays untouched.

Symlink `tm` somewhere on your `$PATH` for convenience:

```sh
ln -s "$PWD/tm" ~/.local/bin/tm
```

## Features

- **Zero plugins.** Everything is built-in tmux.
- **Vi copy mode** with [OSC 52][osc52] clipboard. Yanked text goes straight to
  the system clipboard through the terminal — works over SSH.
- **Mouse** enabled. Scroll, select panes, resize.
- **True color + undercurl.** Terminal features set for RGB, strikethrough, and
  styled underlines.
- **1-indexed** windows and panes. `renumber-windows` keeps gaps closed.
- **Extended keys** for modified key sequences in applications.
- **Local overrides** via `~/.config/tmux/local.conf` (sourced silently if
  present).

## Keybindings

Prefix is `C-b` (default).

### Pane Navigation

| Key          | Action          |
| ------------ | --------------- |
| `prefix C-h` | Focus left      |
| `prefix C-j` | Focus down      |
| `prefix C-k` | Focus up        |
| `prefix C-l` | Focus right     |
| `prefix h`   | Swap pane left  |
| `prefix j`   | Swap pane down  |
| `prefix k`   | Swap pane up    |
| `prefix l`   | Swap pane right |

### Splits and Resize

| Key         | Action                            |
| ----------- | --------------------------------- |
| `prefix \|` | Split horizontally (current path) |
| `prefix -`  | Split vertically (current path)   |
| `prefix H`  | Resize left by 5                  |
| `prefix J`  | Resize down by 5                  |
| `prefix K`  | Resize up by 5                    |
| `prefix L`  | Resize right by 5                 |

### Copy Mode

| Key        | Action                  |
| ---------- | ----------------------- |
| `prefix v` | Enter copy mode         |
| `v`        | Begin selection         |
| `C-v`      | Toggle rectangle select |
| `y`        | Yank and exit copy mode |

Copy-mode keys (`v`, `C-v`, `y`) work inside copy mode only.

### Other

| Key        | Action                                               |
| ---------- | ---------------------------------------------------- |
| `prefix w` | Session/window/pane picker (built-in, `/` to filter) |
| `prefix R` | Reload config                                        |

## Config Layout

`tmux.conf` is the entry point. It sets global options, then sources everything
in `conf.d/` alphabetically. Each file in `conf.d/` handles one concern:

- `copy.conf` — clipboard and copy-mode bindings
- `keybinds.conf` — splits, resize, reload
- `nav.conf` — hjkl pane navigation
- `theme.conf` — status line, window tabs, pane borders

## Local Overrides

Drop a file at `~/.config/tmux/local.conf` to add machine-specific settings.
It's sourced last, so it can override anything.

[osc52]:
  https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Operating-System-Commands
