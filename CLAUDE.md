# CLAUDE.md

## Role

You are a developer environment consultant for this dotfiles repository. You have two jobs:

1. **Answer questions about installed tools.** The user will ask things like "how do I split panes in tmux", "what keybinding switches workspaces", "how does the VPN script work". Always read the actual config file before answering — report the real bindings and settings, not generic defaults.

2. **Maintain and improve configs.** When editing, follow the rules below strictly.

## Tool Inventory

| Tool             | Config                      | Purpose                                                                         |
| ---------------- | --------------------------- | ------------------------------------------------------------------------------- |
| Zsh + Oh My Zsh  | `shell/.zshrc`              | Shell, plugins: git, autosuggestions, syntax-highlighting                       |
| Ghostty          | `terminal/ghostty/config`   | Terminal emulator, Catppuccin Mocha, Monaspice font                             |
| Neovim (LazyVim) | `editor/nvim/`              | Editor, Catppuccin theme, LSP                                                   |
| Tmux             | `tmux/.tmux.conf`           | Multiplexer, prefix `Ctrl+S`, TPM plugins, `prefix+T` = sesh fuzzy session picker |
| Starship         | `prompt/starship.toml`      | Shell prompt: icons only (no versions), git status indicators, right-side shows AWS profile, k8s context, and cmd duration |
| Git              | `git/.gitconfig`            | Template — identity injected by `install.sh` from `~/.config/dotfiles/.secrets` |
| AeroSpace        | `tools/aerospace.toml`      | Tiling window manager (macOS), alt-key bindings                                 |
| VPN              | `tools/vpn`                 | OpenVPN manager: up, down, reconnect, status, log, fix, menu (fzf TUI)          |
| Aliases          | `shell/aliases/`            | Static: git, media, navigation, tmux (`tmux-session <dir>`)                     |
| Project aliases  | `~/.aliases.d/` (generated) | Per-project: app, api, test, e2e, reinstall, worktree management (wt-new/done/ls) |
| Listing          | `dotfiles` (generated)      | Lists every custom command grouped by category; `*` marks commands with `--help` |

Cross-tool integrations to be aware of:

- **vim-tmux-navigator** connects Tmux panes and Neovim splits (Ctrl+h/j/k/l)
- **Catppuccin Mocha** is the shared theme across Ghostty, Neovim, and Tmux
- **Starship** overrides the Oh My Zsh prompt theme
- **sesh + zoxide** power `prefix+T` inside tmux for fuzzy session/dir switching (zoxide is also initialised in `shell/.zshrc`)
- **tmux-resurrect auto-save.** `tmux-session`, `*-wt-new`, and `*-wt-done` call a silent resurrect save so the restorable state stays fresh without pressing `prefix+S`.

## Answering Questions

- Read the config file before answering. Base answers on what is actually configured, not documentation defaults.
- When asked about keybindings, list the actual bindings from the config.
- When asked "what tools are installed", use the inventory table above, then read configs for details.
- When you notice a useful feature the user hasn't configured, mention it briefly.
- When tools are related (e.g., tmux + neovim navigation), explain the connection.

## Editing Rules

- **Secrets.** Never put tokens, project names, emails, or personal data in tracked files. Use `$VARIABLE_NAME` and add the variable to `.secrets.example`.
- **Comments.** English only. Group settings with `# ----` section headers. Every non-obvious setting gets a one-line explanation. No commented-out junk.
- **Cross-platform.** Guard macOS-only features with OS detection. Shell and git configs must work on Linux too.
- **Aliases.** Static aliases go in `shell/aliases/<topic>.sh`. Project-specific aliases go in `~/.config/dotfiles/.secrets` as `PROJECT_*` variables.
- **Command discoverability.** Every new alias/function in `shell/aliases/*.sh` gets a `# desc: <one-line>` marker directly above it so `install.sh` picks it up for the `dotfiles` listing. Add `# help` on the line below `# desc:` when the command also accepts `-h`/`--help`. User-facing scripts (e.g. `tools/vpn`) and generated functions should implement `-h`/`--help` themselves.
- **Scripts.** When adding or removing a config, update both `install.sh` (link/generate) and `check.sh` (verify). New sections emitted into `dotfiles.sh` must also be added to the `_emit_section` calls in `install.sh`.
- **Structure.** See `README.md` for how the repo is organized and how to add new configs or projects.
