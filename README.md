# Falcon Terminal

A fast, native **macOS terminal emulator** written entirely in **Swift 6** with
SwiftUI + AppKit. No Electron, no WebView — a real PTY engine and a from-scratch
VT/ANSI parser rendered with CoreText.

![macOS](https://img.shields.io/badge/macOS-14%2B-black)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

## ⬇️ Download

**[FalconTerminal.dmg](FalconTerminal.dmg)** (in this repo) — or grab it from the
[latest release](https://github.com/4iShmmri/FalconTerminal/releases/latest).

Open the DMG and drag **Falcon Terminal** to **Applications**. On first launch,
right-click ▸ **Open** (the build is ad-hoc signed, not notarized).

## Features

- **Real PTY engine** (`forkpty`) — one shell, environment, and working
  directory per tab. Auto-detects zsh / bash / fish.
- **VT100 / VT220 / xterm parser** — SGR 16/256/truecolor, alternate screen,
  scroll regions, cursor/erase/insert/delete, OSC titles, DSR/DA reports.
  Runs `vim`, `htop`, `lazygit`, `claude`, and other interactive tools.
- **Tabbed, browser-style UI** — create, close, rename (single-click on the
  active tab), duplicate, reorder by drag, pin, and colorize.
- **Split panes** — nested vertical (`⌘D`) and horizontal (`⌘⇧D`) splits with
  draggable dividers.
- **SSH host manager** — saved hosts grouped by environment in a sidebar;
  connects via the system `ssh` so your keys and `~/.ssh/config` just work.
- **Unicode & Arabic** — full UTF-8, wide CJK/emoji, combining marks, and
  proper Arabic shaping + bidi (right-to-left, joined letters).
- **Inline suggestions** — fish-style ghost text from your command history
  (seeded from `~/.zsh_history` / `~/.bash_history`); accept with `→`.
- **Slash commands** — type `/new aaa` at the prompt (or press `⌘K`) to run app
  actions without leaving the keyboard.
- **Themes** — Falcon Dark, Dracula, Nord, Tokyo Night, Solarized Dark/Light.
- **Session restoration** — tabs, split layout, per-pane working directory, and
  window position are restored on launch (with periodic autosave).
- **Profiles & Settings** — General, Appearance, Terminal, SSH, Profiles,
  Keyboard, and AI-tools sections.

## Keyboard shortcuts

| Shortcut | Action | Shortcut | Action |
|----------|--------|----------|--------|
| `⌘T` | New tab | `⌘D` | Split vertically |
| `⌘W` | Close tab | `⌘⇧D` | Split horizontally |
| `⌘⌥T` | Duplicate tab | `⌘⇧W` | Close pane |
| `⌘⌥→ / ←` | Next / previous tab | `⌘K` | Command palette |
| `⌘C / ⌘V` | Copy / paste | `⌘+ / ⌘-` | Font size |

## Requirements

- macOS 14+
- Xcode 16+ / Swift 6 toolchain

## Build & run

```bash
# Run directly via SwiftPM
swift run

# Or open in Xcode
xed Package.swift
```

### Package a distributable app / DMG

```bash
./scripts/make_app.sh release   # builds build/FalconTerminal.app (+ icon)
./scripts/make_dmg.sh           # builds build/FalconTerminal.dmg
```

## Tests

```bash
swift test
```

Covers the VT parser, screen buffer, emulator modes, Unicode/Arabic handling,
and the PTY (27 tests).

## Project structure

```
Sources/FalconTerminal/
├── App/          SwiftUI app, AppState, menu commands
├── Terminal/     PTY, ANSI parser, emulator, buffer model
├── Rendering/    CoreText render view, font metrics, input
├── Views/        Tab bar, splits, settings, SSH sidebar, palette
├── ViewModels/   Tabs, panes, split tree
├── Models/       Profiles, SSH hosts, settings
├── Themes/       Color schemes
└── Services/     Persistence, history, restoration, tool detection
```

## Notes on distribution

Release builds are **ad-hoc signed** only. On another Mac, Gatekeeper will
require right-click ▸ **Open** the first time (or
`xattr -dr com.apple.quarantine /Applications/FalconTerminal.app`). For public
distribution, sign with an Apple Developer ID and notarize.

## License

MIT — see [LICENSE](LICENSE).
